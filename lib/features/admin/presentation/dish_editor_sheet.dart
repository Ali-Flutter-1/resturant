import 'package:flutter/material.dart';

import '../../../core/animations/shake.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/preview/sample_content.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/dish_image.dart';

/// Create or edit a dish. Returns the result, or null if dismissed.
///
/// Local only — there is nowhere to persist to yet. The shape mirrors what
/// the menu endpoint will need, so wiring it up later is a swap of the
/// submit handler rather than a rewrite.
Future<SampleDish?> showDishEditor({
  required BuildContext context,
  SampleDish? dish,
}) {
  return showAppSheet<SampleDish>(
    context: context,
    title: dish == null ? 'Add a dish' : 'Edit ${dish.name}',
    subtitle: dish == null
        ? 'It appears on the menu straight away.'
        : 'Changes apply to tonight’s menu.',
    child: _DishEditor(dish: dish),
  );
}

class _DishEditor extends StatefulWidget {
  const _DishEditor({this.dish});

  final SampleDish? dish;

  @override
  State<_DishEditor> createState() => _DishEditorState();
}

class _DishEditorState extends State<_DishEditor> {
  late final _name = TextEditingController(text: widget.dish?.name ?? '');
  late final _description = TextEditingController(
    text: widget.dish?.description ?? '',
  );
  late final _price = TextEditingController(
    text: widget.dish?.price.toStringAsFixed(2) ?? '',
  );
  late final _imageUrl = TextEditingController(
    text: widget.dish?.imageUrl ?? '',
  );

  /// A dish carries at most one tag, so this is a single choice and null is a
  /// legitimate answer — plenty of dishes need no label.
  late String? _tag = widget.dish?.tag;

  String? _error;

  /// Bumped on every refusal so the same complaint twice still shakes — the
  /// user pressing submit again wants to know it was rejected again.
  int _rejections = 0;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  void _submit() {
    final price = double.tryParse(_price.text.trim());

    if (_name.text.trim().isEmpty) {
      setState(() {
        _error = 'Give the dish a name.';
        _rejections++;
      });
      return;
    }
    if (price == null || price <= 0) {
      setState(() {
        _error = 'Enter a price, like 12.50.';
        _rejections++;
      });
      return;
    }

    final imageUrl = _imageUrl.text.trim();

    Navigator.of(context).pop(
      SampleDish(
        name: _name.text.trim(),
        description: _description.text.trim().isEmpty
            ? 'No description yet.'
            : _description.text.trim(),
        price: price,
        tag: _tag,
        imageUrl: imageUrl.isEmpty ? null : imageUrl,
      ),
    );
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
            Text('Name', style: context.texts.titleMedium),
            const SizedBox(height: AppSpacing.x2),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Jaffna Crab Curry'),
            ),
            const SizedBox(height: AppSpacing.x4),

            Text('Description', style: context.texts.titleMedium),
            const SizedBox(height: AppSpacing.x2),
            TextField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'What is in it, and how is it cooked?',
              ),
            ),
            const SizedBox(height: AppSpacing.x4),

            Text('Price', style: context.texts.titleMedium),
            const SizedBox(height: AppSpacing.x2),
            TextField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                hintText: '12.50',
                prefixText: '£ ',
              ),
            ),
            const SizedBox(height: AppSpacing.x4),

            Row(
              children: [
                Text('Tag', style: context.texts.titleMedium),
                const SizedBox(width: AppSpacing.x2),
                Text('Optional', style: context.texts.bodySmall),
              ],
            ),
            const SizedBox(height: AppSpacing.x2),
            // Tapping the selected tag clears it, so a dish can go back to
            // having none without a separate "no tag" control.
            Wrap(
              spacing: AppSpacing.x2,
              runSpacing: AppSpacing.x2,
              children: [
                for (final tag in SampleContent.dishTags)
                  SelectableChip(
                    label: tag,
                    selected: _tag == tag,
                    onSelected: () =>
                        setState(() => _tag = _tag == tag ? null : tag),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.x4),

            Text('Photograph', style: context.texts.titleMedium),
            const SizedBox(height: AppSpacing.x2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Live preview. DishImage already shimmers while a network image
                // loads and falls back to the tinted initial if the URL is empty
                // or broken, so this doubles as validation.
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: DishImage(
                      name: _name.text.trim().isEmpty
                          ? 'New dish'
                          : _name.text.trim(),
                      imageUrl: _imageUrl.text.trim(),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.x3),
                Expanded(
                  child: TextField(
                    controller: _imageUrl,
                    keyboardType: TextInputType.url,
                    // Rebuild so the preview follows what is typed.
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'https://…/dish.jpg',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x2),
            Text(
              // Said plainly rather than shipping a picker that cannot work:
              // choosing from the device needs a plugin and per-platform
              // permissions, and uploads need the API.
              'Paste an image URL for now. Picking from the device needs the '
              'upload endpoint.',
              style: context.texts.bodySmall,
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
              onPressed: _submit,
              child: Text(widget.dish == null ? 'Add dish' : 'Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}
