import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/haptics/app_haptics.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/network_photo.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../menu/domain/dish.dart';
import '../domain/admin_menu_repository.dart';

/// Everything that can be done to a menu section: its picture, its name, and
/// getting rid of it.
///
/// One sheet rather than three entry points. The picture is shown on the
/// customer's home screen in place of a glyph, so it is worth getting right --
/// and worth being able to remove when it is wrong.
///
/// Returns the updated category, [CategoryDeleted] if it was archived, or null
/// if nothing changed.
Future<Object?> showCategorySheet(BuildContext context, MenuCategory category) {
  return showAppSheet<Object>(
    context: context,
    title: category.name,
    subtitle: 'What customers see for this section.',
    child: _CategoryLogoSheet(category: category),
  );
}

/// Returned when the section was archived, so the caller drops it from its list
/// rather than trying to show a category that is no longer there.
class CategoryDeleted {
  const CategoryDeleted(this.id);

  final String id;
}

class _CategoryLogoSheet extends StatefulWidget {
  const _CategoryLogoSheet({required this.category});

  final MenuCategory category;

  @override
  State<_CategoryLogoSheet> createState() => _CategoryLogoSheetState();
}

class _CategoryLogoSheetState extends State<_CategoryLogoSheet> {
  late MenuCategory _category = widget.category;
  String? _preview;
  bool _busy = false;

  /// Owned by the state, not by `_rename`.
  ///
  /// Disposing it as soon as the rename sheet returned killed it while that
  /// sheet was still animating out -- the field rebuilds during the dismissal
  /// and asserts on a controller that has been disposed.
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    if (_busy) return;

    final XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: source,
        // Downscaled before it leaves the phone. A camera produces 4–8MB files
        // and the API caps uploads at 10MB; a section badge needs neither.
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
    } on Object {
      if (!mounted) return;
      showAppSnack(
        context,
        'That image could not be opened. Try another.',
        isError: true,
      );
      return;
    }
    if (file == null || !mounted) return;

    // Shown immediately from the local file, so the upload has something to
    // happen *to* rather than a spinner over the old picture.
    setState(() {
      _preview = file!.path;
      _busy = true;
    });

    try {
      final updated = await context.read<AdminMenuRepository>().setCategoryLogo(
        _category.id,
        file.path,
      );
      if (!mounted) return;
      AppHaptics.success();
      setState(() {
        _category = updated;
        _preview = null;
        _busy = false;
      });
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      AppHaptics.failure();
      // The preview goes with it: leaving the new picture on screen after a
      // failed upload would say it saved.
      setState(() {
        _preview = null;
        _busy = false;
      });
      showAppSnack(context, failure.message, isError: true);
    }
  }

  Future<void> _rename() async {
    _name.text = _category.name;
    final name = await showAppSheet<String>(
      context: context,
      title: 'Rename ${_category.name}',
      child: Builder(
        builder: (sheetContext) => Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            0,
            AppSpacing.gutter,
            MediaQuery.viewInsetsOf(sheetContext).bottom +
                MediaQuery.paddingOf(sheetContext).bottom +
                AppSpacing.x4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _name,
                autofocus: true,
                maxLength: 120,
                textCapitalization: TextCapitalization.words,
                onSubmitted: (value) =>
                    Navigator.of(sheetContext).pop(value.trim()),
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              // The address customers may already have is left alone -- the
              // API keeps name and slug separate for exactly this reason.
              Text(
                'The web address for this section does not change.',
                style: sheetContext.texts.bodySmall?.copyWith(
                  color: sheetContext.surfaces.inkSoft,
                ),
              ),
              const SizedBox(height: AppSpacing.x4),
              PrimaryButton(
                label: 'Save name',
                onPressed: () =>
                    Navigator.of(sheetContext).pop(_name.text.trim()),
              ),
            ],
          ),
        ),
      ),
    );
    if (name == null || name.isEmpty || name == _category.name) return;
    if (!mounted) return;

    setState(() => _busy = true);
    try {
      final updated = await context.read<AdminMenuRepository>().renameCategory(
        _category.id,
        name,
      );
      if (!mounted) return;
      AppHaptics.success();
      setState(() {
        _category = updated;
        _busy = false;
      });
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      AppHaptics.failure();
      setState(() => _busy = false);
      showAppSnack(context, failure.message, isError: true);
    }
  }

  Future<void> _delete() async {
    // Asked first. Archiving a section takes it off the customer's menu
    // immediately, and the dishes in it go with it.
    final confirmed = await showAppSheet<bool>(
      context: context,
      title: 'Delete ${_category.name}?',
      child: Builder(
        builder: (sheetContext) => Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            0,
            AppSpacing.gutter,
            MediaQuery.paddingOf(sheetContext).bottom + AppSpacing.x4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'It disappears from the menu straight away, and any dish that '
                'was only in this section stops being listed. The restaurant '
                'can restore it from the back office.',
                style: sheetContext.texts.bodyMedium?.copyWith(
                  color: sheetContext.surfaces.inkMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.x5),
              // Keeping it is the safe choice, so it gets the filled button.
              PrimaryButton(
                label: 'Keep this section',
                onPressed: () => Navigator.of(sheetContext).pop(false),
              ),
              const SizedBox(height: AppSpacing.x2),
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(true),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: sheetContext.orderColors.overdue,
                ),
                child: const Text('Delete section'),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await context.read<AdminMenuRepository>().deleteCategory(_category.id);
      if (!mounted) return;
      AppHaptics.success();
      Navigator.of(context).pop(CategoryDeleted(_category.id));
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      AppHaptics.failure();
      setState(() => _busy = false);
      showAppSnack(context, failure.message, isError: true);
    }
  }

  Future<void> _remove() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final updated = await context
          .read<AdminMenuRepository>()
          .removeCategoryLogo(_category.id);
      if (!mounted) return;
      AppHaptics.success();
      setState(() {
        _category = updated;
        _busy = false;
      });
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() => _busy = false);
      showAppSnack(context, failure.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = _category.imageUrl;
    final hasLogo = url != null && url.isNotEmpty;

    // Scrollable, because the sheet now carries the picture, both source
    // buttons, the rename row and the delete row -- more than fits above the
    // keyboard-free area of a small phone, where it overflowed by about a
    // hundred pixels.
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        MediaQuery.paddingOf(context).bottom + AppSpacing.x4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: ClipOval(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: context.surfaces.accentContainer),
                  if (_preview != null)
                    Image.file(
                      File(_preview!),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    )
                  else if (hasLogo)
                    // The server's own `image_url`, never a Cloudinary path
                    // assembled here — the guide is explicit about that.
                    NetworkPhoto(
                      url: url,
                      errorBuilder: (context, _, _) => Icon(
                        Icons.broken_image_outlined,
                        color: scheme.primary,
                      ),
                    )
                  else
                    Icon(
                      Icons.local_dining,
                      size: AppIconSize.hero,
                      color: scheme.primary,
                    ),
                  if (_busy)
                    ColoredBox(
                      color: Colors.black.withValues(alpha: 0.35),
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x5),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Camera'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(
            'Uploading replaces the current picture. JPG, PNG, WEBP or AVIF, '
            'up to 10MB.',
            textAlign: TextAlign.center,
            style: context.texts.bodySmall?.copyWith(
              color: context.surfaces.inkSoft,
            ),
          ),

          // Only offered when there is one to remove — the API tolerates it
          // either way, but a button that does nothing is still a button that
          // does nothing.
          if (hasLogo) ...[
            const SizedBox(height: AppSpacing.x3),
            TextButton.icon(
              onPressed: _busy ? null : _remove,
              icon: const Icon(Icons.delete_outline, size: AppIconSize.md),
              label: const Text('Remove picture'),
              style: TextButton.styleFrom(
                foregroundColor: context.orderColors.overdue,
              ),
            ),
          ],

          const Divider(height: AppSpacing.x6),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.edit_outlined, size: AppIconSize.lg),
            title: const Text('Rename section'),
            subtitle: Text(_category.name),
            enabled: !_busy,
            onTap: _busy ? null : _rename,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.delete_outline,
              size: AppIconSize.lg,
              color: _busy ? null : context.orderColors.overdue,
            ),
            title: Text(
              'Delete section',
              style: TextStyle(
                color: _busy ? null : context.orderColors.overdue,
              ),
            ),
            subtitle: const Text('Takes it off the menu straight away'),
            enabled: !_busy,
            onTap: _busy ? null : _delete,
          ),

          const SizedBox(height: AppSpacing.x2),
          TextButton(
            onPressed: _busy
                ? null
                : () => Navigator.of(context).pop(_category),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
