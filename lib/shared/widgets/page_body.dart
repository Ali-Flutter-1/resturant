import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// A screen's content column.
///
/// Centres the content and caps it at [AppLayout.readable] once the window is
/// wider than a phone, so a tablet gets a readable column with margin rather
/// than a phone layout stretched to fill it. Below that width it is a plain
/// gutter and costs nothing.
///
/// Deliberately a wrapper rather than a `Padding` each screen writes for itself:
/// the gutter, the cap and the breakpoint are one decision, and a screen that
/// invents its own is exactly how two pages stop matching.
///
/// Use [PageBody.scroll] for a whole scrolling page — it keeps the *scrollbar*
/// at the window edge while the content stays centred, which is what a native
/// wide layout does.
class PageBody extends StatelessWidget {
  const PageBody({
    super.key,
    required this.child,
    this.maxWidth = AppLayout.readable,
    this.padding,
  });

  final Widget child;

  /// Override for content that legitimately wants more room — a wide table, a
  /// grid of cards. Text and forms should keep the default.
  final double maxWidth;

  /// Replaces the horizontal gutter. Vertical padding stays the caller's job.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = AppLayout.gutterFor(constraints.maxWidth);
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: padding ?? EdgeInsets.symmetric(horizontal: gutter),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// The horizontal padding a scrolling page should use for the width on offer.
///
/// For screens whose scrollable already owns its padding — a `ListView` with a
/// bottom inset for the nav bar, say. Wrapping those in [PageBody] would put the
/// scrollbar in the middle of the window and clip the scroll gesture to the
/// column, so they take the numbers instead of the widget.
EdgeInsets pagePadding(
  BuildContext context, {
  double top = 0,
  double bottom = 0,
}) {
  final side = pageSideInset(context);
  return EdgeInsets.fromLTRB(side, top, side, bottom);
}

/// The distance from the window edge to the content column.
///
/// Exposed on its own for the one case that needs the number rather than the
/// padding: a full-bleed element — the home screen's hero pager — that escapes
/// the page padding to run edge to edge, then pads each page back in so its
/// edges land on the same line as everything else. Hardcoding the gutter there
/// worked only while the gutter was one number.
double pageSideInset(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  final gutter = AppLayout.gutterFor(width);
  // On a wide window the column is centred by adding the surplus as margin,
  // which keeps the list's own scrollbar and gesture area at the window edge.
  final surplus = width - 2 * gutter - AppLayout.readable;
  return surplus > 0 ? gutter + surplus / 2 : gutter;
}
