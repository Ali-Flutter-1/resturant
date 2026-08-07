import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// A raised surface: the app's card.
///
/// The rule was already being followed by hand in eleven places — a standalone
/// panel takes the `lg` radius and the two-layer [AppSurfaces.cardShadow], a
/// row inside a list takes `md` and the single-layer [AppSurfaces.restShadow] —
/// but nothing named it, so each site restated it and a couple had drifted.
///
/// Naming it does two things: a caller picks the *kind* of surface rather than
/// re-deciding its radius and elevation, and the distinction stays legible.
/// Elevation here means depth in the interface, not decoration: a panel sits
/// above the page, a row sits on it.
class AppSurface extends StatelessWidget {
  /// A standalone block of content: a metric card, a form panel, a bento tile.
  const AppSurface.panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.x4),
    this.margin,
    this.clip = false,
  }) : _radius = AppRadius.lg,
       _raised = true;

  /// One item among many, in a list or a stack of siblings.
  const AppSurface.row({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.x4),
    this.margin,
    this.clip = false,
  }) : _radius = AppRadius.md,
       _raised = false;

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  /// Clips the child to the surface's corners. Needed when the child paints to
  /// the edge — an image, an ink splash, a colour stripe.
  final bool clip;

  final double _radius;
  final bool _raised;

  BorderRadius get borderRadius => BorderRadius.circular(_radius);

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: borderRadius,
        boxShadow: _raised ? surfaces.cardShadow : surfaces.restShadow,
      ),
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      child: Padding(padding: padding, child: child),
    );
  }
}
