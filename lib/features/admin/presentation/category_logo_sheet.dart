import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/haptics/app_haptics.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../menu/domain/dish.dart';
import '../domain/admin_menu_repository.dart';

/// The picture on a menu section.
///
/// Shown on the customer's home screen in place of a glyph, so it is worth
/// getting right — and worth being able to remove when it is wrong.
///
/// Returns the updated category, or null if nothing changed.
Future<MenuCategory?> showCategoryLogoSheet(
  BuildContext context,
  MenuCategory category,
) {
  return showAppSheet<MenuCategory>(
    context: context,
    title: category.name,
    subtitle: 'The picture customers see on this section.',
    child: _CategoryLogoSheet(category: category),
  );
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

    return Padding(
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
                    Image.network(
                      url,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
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
