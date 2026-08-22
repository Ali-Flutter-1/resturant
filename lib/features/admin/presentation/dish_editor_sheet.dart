import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/animations/motion.dart';
import '../../../core/animations/shake.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/haptics/app_haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/dish_image.dart';
import '../../menu/domain/dish.dart';
import '../domain/admin_menu_repository.dart';
import 'category_logo_sheet.dart';

/// Create or edit a dish, against the API. Returns the saved dish, or null if
/// dismissed.
///
/// Saving is three calls in sequence, in this order for a reason:
///
///  1. any brand-new category, because a dish needs its **id**, not its name;
///  2. `POST /admin/uploads/images` for the photograph, which returns the
///     `public_id`/`url` pair the dish wants;
///  3. `POST /admin/dishes` (or `PATCH`) with both.
///
/// The upload happens on save rather than the moment a photograph is picked, so
/// abandoning the sheet doesn't leave an orphaned file on the server.
Future<Dish?> showDishEditor({
  required BuildContext context,
  required AdminMenuRepository repository,
  required List<MenuCategory> categories,
  Dish? dish,
}) {
  return showAppSheet<Dish>(
    context: context,
    title: dish == null ? 'Add a dish' : 'Edit ${dish.name}',
    subtitle: dish == null
        ? 'It appears on the menu straight away.'
        : 'Changes apply to tonight’s menu.',
    child: _DishEditor(
      dish: dish,
      repository: repository,
      categories: categories,
    ),
  );
}

class _DishEditor extends StatefulWidget {
  const _DishEditor({
    this.dish,
    required this.repository,
    required this.categories,
  });

  final Dish? dish;
  final AdminMenuRepository repository;
  final List<MenuCategory> categories;

  @override
  State<_DishEditor> createState() => _DishEditorState();
}

class _DishEditorState extends State<_DishEditor> {
  late final _name = TextEditingController(text: widget.dish?.name ?? '');
  late final _description = TextEditingController(
    text: widget.dish?.description ?? '',
  );
  late final _price = TextEditingController(
    text: widget.dish == null
        ? ''
        : (widget.dish!.pricePence / 100).toStringAsFixed(2),
  );
  late final _prepMin = TextEditingController(
    text: widget.dish?.prepMinMinutes?.toString() ?? '15',
  );
  late final _prepMax = TextEditingController(
    text: widget.dish?.prepMaxMinutes?.toString() ?? '20',
  );
  final _newCategory = TextEditingController();

  /// Categories offered as chips. Grows when one is created, so the new chip is
  /// selectable immediately rather than after a reopen.
  late List<MenuCategory> _categories = [...widget.categories];

  /// Selected category ids. A set because the API takes several — a dish can
  /// appear in more than one section of the menu.
  late final Set<String> _selected = {
    for (final c in widget.dish?.categories ?? const <MenuCategory>[]) c.id,
  };

  /// Names typed in but not yet created server-side. Created on save, because
  /// creating one per keystroke would litter the menu with categories from
  /// abandoned edits.
  final List<String> _pendingCategories = [];

  /// A logo picked for a category that does not exist yet, by name.
  ///
  /// Uploaded after the category is created on save, because the endpoint needs
  /// the category's id — which is exactly why the picture has to be held here
  /// rather than sent when it was chosen.
  final Map<String, String> _pendingCategoryLogos = {};

  /// Whether this dish offers Low/Mid/High to the customer.
  late bool _hasSpiceLevels = widget.dish?.hasSpiceLevels ?? false;

  /// Photographs already on the dish, kept so an edit that doesn't touch the
  /// picture doesn't drop it.
  late List<DishPhoto> _existingImages = [...?widget.dish?.images];

  /// A local file path from the camera or gallery, previewed before upload.
  String? _pickedPath;

  bool _picking = false;
  bool _saving = false;

  String? _error;

  /// Bumped on every refusal so the same complaint twice still shakes — the user
  /// pressing submit again wants to know it was rejected again.
  int _rejections = 0;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _prepMin.dispose();
    _prepMax.dispose();
    _newCategory.dispose();
    super.dispose();
  }

  String get _previewSource =>
      _pickedPath ?? (_existingImages.isEmpty ? '' : _existingImages.first.url);

  void _fail(String message) {
    setState(() {
      _error = message;
      _rejections++;
      _saving = false;
    });
    AppHaptics.failure();
  }

  Future<void> _pick(ImageSource source) async {
    if (_picking || _saving) return;
    setState(() => _picking = true);

    try {
      final file = await ImagePicker().pickImage(
        source: source,
        // Downscaled before it leaves the phone. A camera produces 4–8MB files,
        // the API caps uploads at 10MB, and a menu photograph needs neither —
        // this is the difference between adding a dish on café wifi and giving
        // up on it.
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (!mounted) return;
      if (file == null) {
        setState(() => _picking = false);
        return;
      }

      AppHaptics.success();
      setState(() {
        _pickedPath = file.path;
        _picking = false;
      });
    } on Object catch (_) {
      // Most often a declined permission. Reported in the sheet rather than
      // thrown: the dish can still be saved and photographed later.
      if (!mounted) return;
      setState(() => _picking = false);
      _fail(
        source == ImageSource.camera
            ? 'Could not open the camera. Check the app’s permissions.'
            : 'Could not open your photos. Check the app’s permissions.',
      );
    }
  }

  void _addCategory() {
    final value = _newCategory.text.trim();
    if (value.isEmpty) return;

    // Case-insensitive, against both the real categories and the ones queued for
    // creation, so "vegan" doesn't become a second Vegan.
    final existing = _categories.where(
      (c) => c.name.toLowerCase() == value.toLowerCase(),
    );
    if (existing.isNotEmpty) {
      AppHaptics.selection();
      setState(() {
        _selected.add(existing.first.id);
        _newCategory.clear();
      });
      return;
    }
    if (_pendingCategories.any((p) => p.toLowerCase() == value.toLowerCase())) {
      setState(() => _newCategory.clear());
      return;
    }

    AppHaptics.selection();
    setState(() {
      _pendingCategories.add(value);
      _newCategory.clear();
    });
  }

  /// Rename, re-picture or delete a saved section, from the sheet the menu
  /// screen uses for the same job.
  Future<void> _manageCategory(MenuCategory category) async {
    AppHaptics.toggle();
    final result = await showCategorySheet(context, category);
    if (result == null || !mounted) return;

    setState(() {
      if (result is CategoryDeleted) {
        // Gone from the list and from this dish: a dish cannot be filed under
        // a section that no longer exists.
        _categories = [..._categories]..removeWhere((c) => c.id == result.id);
        _selected.remove(result.id);
        return;
      }
      if (result is MenuCategory) {
        _categories = [
          for (final existing in _categories)
            if (existing.id == result.id) result else existing,
        ];
      }
    });
  }

  Future<void> _submit() async {
    if (_saving) return;

    final title = _name.text.trim();
    if (title.isEmpty) return _fail('Give the dish a name.');

    final price = double.tryParse(_price.text.trim());
    if (price == null || price <= 0) {
      return _fail('Enter a price, like 12.50.');
    }
    // Rounded, not truncated: 12.50 in binary floating point is 1249.9999… and
    // `toInt()` would sell it for £12.49.
    final pricePence = (price * 100).round();

    final prepMin = int.tryParse(_prepMin.text.trim());
    final prepMax = int.tryParse(_prepMax.text.trim());
    if (prepMin != null && prepMax != null && prepMin > prepMax) {
      return _fail('The shortest time cannot be longer than the longest.');
    }

    if (_selected.isEmpty && _pendingCategories.isEmpty) {
      // The API requires at least one, and an uncategorised dish would not
      // appear on the public menu even if it accepted one.
      return _fail('Choose at least one category.');
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      // 1. Categories the user typed. Done first because the dish needs ids.
      final categoryIds = {..._selected};
      for (final name in _pendingCategories) {
        final created = await widget.repository.createCategory(name);
        categoryIds.add(created.id);

        // The logo, now that there is an id to attach it to. A failure here is
        // swallowed on purpose: the category exists and the dish is about to be
        // saved, and losing both because a picture would not upload would be a
        // far worse outcome than a section with no badge.
        final logo = _pendingCategoryLogos[name];
        var withLogo = created;
        if (logo != null) {
          try {
            withLogo = await widget.repository.setCategoryLogo(
              created.id,
              logo,
            );
          } on ApiFailure {
            // Left without a picture; it can be set from menu management.
          }
        }

        if (mounted) {
          setState(() => _categories = [..._categories, withLogo]);
        }
      }

      // 2. The photograph, if a new one was picked.
      var images = _existingImages;
      final picked = _pickedPath;
      if (picked != null) {
        final uploaded = await widget.repository.uploadImages([picked]);
        // Replaces rather than appends: this editor offers one picture, and
        // appending would silently leave the old one as the thumbnail.
        images = uploaded;
      }

      // 3. The dish itself.
      final dish = widget.dish;
      final saved = dish == null
          ? await widget.repository.createDish(
              title: title,
              description: _description.text,
              categoryIds: categoryIds.toList(),
              pricePence: pricePence,
              images: images,
              prepMinMinutes: prepMin,
              prepMaxMinutes: prepMax,
              hasSpiceLevels: _hasSpiceLevels,
            )
          : await widget.repository.updateDish(
              dish.id,
              title: title,
              description: _description.text,
              categoryIds: categoryIds.toList(),
              pricePence: pricePence,
              images: images,
              prepMinMinutes: prepMin,
              prepMaxMinutes: prepMax,
              hasSpiceLevels: _hasSpiceLevels,
            );

      if (!mounted) return;
      AppHaptics.success();
      Navigator.of(context).pop(saved);
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      // Already fit to show — it is either the API's own words or a plain-English
      // fallback, so it is reported verbatim rather than rewritten here.
      _fail(failure.message);
      // Any category created before the failure now exists and is selected, so a
      // second attempt must not try to create it again.
      setState(
        () => _pendingCategories.removeWhere(
          (name) => _categories.any(
            (c) => c.name.toLowerCase() == name.toLowerCase(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Shake(
      trigger: _rejections == 0 ? null : _rejections,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The photograph comes first. It was at the bottom, which meant the
            // most visible thing about a dish was the last thing you were asked
            // for — and on a phone it sat below the fold behind the keyboard.
            _PhotographPicker(
              name: _name.text.trim().isEmpty ? 'New dish' : _name.text.trim(),
              source: _previewSource,
              busy: _picking,
              enabled: !_saving,
              onCamera: () => _pick(ImageSource.camera),
              onGallery: () => _pick(ImageSource.gallery),
              onClear: _previewSource.isEmpty
                  ? null
                  : () => setState(() {
                      _pickedPath = null;
                      _existingImages = const [];
                    }),
            ),
            const SizedBox(height: AppSpacing.x5),

            Text('Name', style: context.texts.titleMedium),
            const SizedBox(height: AppSpacing.x2),
            TextField(
              controller: _name,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              // Rebuild so the preview's placeholder initial follows the name.
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(hintText: 'Jaffna Crab Curry'),
            ),
            const SizedBox(height: AppSpacing.x4),

            Text('Description', style: context.texts.titleMedium),
            const SizedBox(height: AppSpacing.x2),
            TextField(
              controller: _description,
              enabled: !_saving,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'What is in it, and how is it cooked?',
              ),
            ),
            const SizedBox(height: AppSpacing.x4),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Labelled(
                    label: 'Price',
                    child: TextField(
                      controller: _price,
                      enabled: !_saving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        hintText: '12.50',
                        prefixText: '£ ',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.x3),
                Expanded(
                  child: _Labelled(
                    label: 'Prep time',
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _prepMin,
                            enabled: !_saving,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(hintText: '15'),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.x1,
                          ),
                          child: Text('–'),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _prepMax,
                            enabled: !_saving,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: '20',
                              suffixText: 'min',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x4),

            Row(
              children: [
                Text('Categories', style: context.texts.titleMedium),
                const SizedBox(width: AppSpacing.x2),
                // Stated, because the API requires one and the reason is not
                // guessable: an uncategorised dish is invisible on the menu.
                Text(
                  'At least one',
                  style: context.texts.bodySmall?.copyWith(
                    color: context.surfaces.inkSoft,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x2),
            AnimatedSize(
              duration: context.motion.move(Motion.fast),
              curve: context.motion.standard,
              alignment: Alignment.topLeft,
              child: Wrap(
                spacing: AppSpacing.x2,
                runSpacing: AppSpacing.x2,
                children: [
                  for (final category in _categories)
                    SelectableChip(
                      label: category.name,
                      selected: _selected.contains(category.id),
                      onSelected: _saving
                          ? null
                          : () => setState(() {
                              if (!_selected.remove(category.id)) {
                                _selected.add(category.id);
                              }
                            }),
                      // The glyph is the way in: rename, picture, delete. It
                      // used to be a long press, which is invisible.
                      onManage: _saving
                          ? null
                          : () => _manageCategory(category),
                      manageIcon: Icons.edit_outlined,
                      manageTooltip: 'Edit ${category.name}',
                    ),
                  // Queued for creation. Shown as selected because that is what
                  // they are — typing one is a statement that this dish is in
                  // it.
                  for (final pending in _pendingCategories)
                    SelectableChip(
                      label: '$pending (new)',
                      selected: true,
                      onSelected: _saving
                          ? null
                          : () => setState(
                              () => _pendingCategories.remove(pending),
                            ),
                    ),
                ],
              ),
            ),
            if (_categories.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.x2),
              Text(
                'Tap the pencil on a section to rename it, change its picture '
                'or delete it.',
                style: context.texts.bodySmall?.copyWith(
                  color: context.surfaces.inkSoft,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.x3),
            // The list used to be five hardcoded strings, so anything the
            // kitchen actually served that wasn't one of them had nowhere to go.
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newCategory,
                    enabled: !_saving,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addCategory(),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Add another category',
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.x2),
                IconButton.filledTonal(
                  onPressed: _saving ? null : _addCategory,
                  icon: const Icon(Icons.add, size: AppIconSize.xl),
                  tooltip: 'Add category',
                ),
              ],
            ),

            // A picture for each new section, chosen here so the whole thing is
            // one job. Customers see it on the home screen in place of a glyph,
            // and an existing section's logo is changed from menu management.
            if (_pendingCategories.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.x3),
              for (final pending in _pendingCategories)
                _CategoryLogoPicker(
                  name: pending,
                  path: _pendingCategoryLogos[pending],
                  enabled: !_saving,
                  onPicked: (path) => setState(() {
                    path == null
                        ? _pendingCategoryLogos.remove(pending)
                        : _pendingCategoryLogos[pending] = path;
                  }),
                ),
            ],

            const SizedBox(height: AppSpacing.x4),
            // Off by default: most dishes are not adjustable, and a selector on
            // every one of them would ask a question nobody in the kitchen can
            // answer.
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _hasSpiceLevels,
              onChanged: _saving
                  ? null
                  : (on) => setState(() => _hasSpiceLevels = on),
              title: const Text('Offer a spice level'),
              subtitle: const Text(
                'Customers can choose Low, Mid or High for this dish.',
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: AppSpacing.x4),
              Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: AppIconSize.md,
                    color: context.orderColors.overdue,
                  ),
                  const SizedBox(width: AppSpacing.x2),
                  Expanded(
                    child: Text(
                      _error!,
                      style: context.texts.bodyMedium?.copyWith(
                        color: context.orderColors.overdue,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: AppSpacing.x6),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: Text(
                _saving
                    // Named because it is three requests: on a slow connection
                    // the upload is most of the wait, and "Saving…" for six
                    // seconds reads as stuck.
                    ? (_pickedPath == null ? 'Saving…' : 'Uploading…')
                    : (widget.dish == null ? 'Add dish' : 'Save changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A label above a field, matching the rest of the form.
class _Labelled extends StatelessWidget {
  const _Labelled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.texts.titleMedium),
        const SizedBox(height: AppSpacing.x2),
        child,
      ],
    );
  }
}

/// The photograph, and the two ways to get one.
///
/// A wide preview rather than a 64pt thumbnail: this is the image customers see
/// first on the card, and judging a crop from a square the size of a stamp is
/// not possible.
class _PhotographPicker extends StatelessWidget {
  const _PhotographPicker({
    required this.name,
    required this.source,
    required this.busy,
    required this.enabled,
    required this.onCamera,
    required this.onGallery,
    this.onClear,
  });

  final String name;
  final String source;
  final bool busy;
  final bool enabled;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Photograph', style: context.texts.titleMedium),
            const Spacer(),
            if (onClear != null && enabled)
              TextButton(onPressed: onClear, child: const Text('Remove')),
          ],
        ),
        const SizedBox(height: AppSpacing.x2),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: SizedBox(
            height: 168,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // A local path previews straight from the file; a URL loads over
                // the network. `DishImage` tells them apart, so a photograph is
                // visible before it has been uploaded anywhere.
                DishImage(name: name, imageUrl: source),
                if (busy)
                  const ColoredBox(
                    color: Color(0x66000000),
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.x3),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy || !enabled ? null : onCamera,
                icon: const Icon(
                  Icons.photo_camera_outlined,
                  size: AppIconSize.lg,
                ),
                label: const Text('Camera'),
              ),
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy || !enabled ? null : onGallery,
                icon: const Icon(
                  Icons.photo_library_outlined,
                  size: AppIconSize.lg,
                ),
                label: const Text('Gallery'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A logo for a category that does not exist yet.
///
/// The picture is only *chosen* here; it is uploaded once the category has been
/// created and has an id. Optional — a section with no picture falls back to a
/// glyph on the customer's home screen, which is a perfectly good look.
class _CategoryLogoPicker extends StatelessWidget {
  const _CategoryLogoPicker({
    required this.name,
    required this.path,
    required this.enabled,
    required this.onPicked,
  });

  final String name;
  final String? path;
  final bool enabled;
  final ValueChanged<String?> onPicked;

  Future<void> _pick(BuildContext context) async {
    final XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        // Smaller than a dish photograph: this is drawn as a 56pt circle.
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
    } on Object {
      if (context.mounted) {
        showAppSnack(context, 'Could not open your photos.', isError: true);
      }
      return;
    }
    if (file != null) onPicked(file.path);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final picked = path;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x2),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: ClipOval(
              child: picked == null
                  ? ColoredBox(
                      color: context.surfaces.accentContainer,
                      child: Icon(
                        Icons.local_dining,
                        size: AppIconSize.lg,
                        color: scheme.primary,
                      ),
                    )
                  : Image.file(
                      File(picked),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: context.texts.titleSmall),
                Text(
                  picked == null ? 'No picture yet' : 'Picture chosen',
                  style: context.texts.bodySmall?.copyWith(
                    color: context.surfaces.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          if (picked != null)
            IconButton(
              onPressed: enabled ? () => onPicked(null) : null,
              icon: const Icon(Icons.close, size: AppIconSize.lg),
              tooltip: 'Remove picture',
            ),
          TextButton(
            onPressed: enabled ? () => _pick(context) : null,
            child: Text(picked == null ? 'Add logo' : 'Change'),
          ),
        ],
      ),
    );
  }
}
