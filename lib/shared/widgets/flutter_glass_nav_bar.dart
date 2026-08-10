import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/animations/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class FlutterGlassNavItem {
  const FlutterGlassNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// The non-iOS bar: a floating, blurred pill drawn entirely in Flutter.
///
/// `BackdropFilter` blurs only what Flutter has already painted, which is
/// enough here because everything behind the bar is Flutter's own content.
/// It is not the system material — iOS gets the real thing via `CNTabBar`.
class FlutterGlassNavBar extends StatelessWidget {
  const FlutterGlassNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.tint,
  });

  final List<FlutterGlassNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = tint ?? theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.x4,
        0,
        AppSpacing.x4,
        bottomInset > 0 ? bottomInset : AppSpacing.x4,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg + 8),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(
                alpha: isDark ? 0.72 : 0.78,
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg + 8),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.09)
                    : Colors.black.withValues(alpha: 0.05),
              ),
              boxShadow: context.surfaces.cardShadow,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
              child: Row(
                children: [
                  for (final (index, item) in items.indexed)
                    Expanded(
                      child: _NavButton(
                        item: item,
                        selected: index == currentIndex,
                        accent: accent,
                        onTap: () => onTap(index),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final FlutterGlassNavItem item;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final inactive = context.surfaces.inkSoft;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.x1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: context.motion.fade(Motion.fast),
                curve: context.motion.standard,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x4,
                  vertical: AppSpacing.x1 + 1,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? accent.withValues(alpha: 0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: AppIconSize.xl,
                  color: selected ? accent : inactive,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.navLabel(selected ? accent : inactive),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
