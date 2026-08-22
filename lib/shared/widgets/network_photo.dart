import 'package:flutter/material.dart';

/// A network image decoded at the size it is actually drawn.
///
/// [Image.network] decodes at the source's own resolution and keeps that bitmap
/// in the image cache. A customer's avatar or a category logo arrives at
/// whatever size it was uploaded -- phone cameras produce several thousand
/// pixels a side -- and is then drawn in a circle a centimetre across. One such
/// photo costs about sixteen megabytes of cache against a hundred-megabyte
/// budget, so a screen showing a handful of them evicts its own entries while
/// scrolling and decodes them all again on the way back.
///
/// Passing `cacheWidth` moves the resize into the decoder, which is both faster
/// and where the memory is saved. The width has to be measured rather than
/// assumed, hence the [LayoutBuilder].
class NetworkPhoto extends StatelessWidget {
  const NetworkPhoto({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.fill = true,
    this.errorBuilder,
  });

  final String url;
  final BoxFit fit;

  /// Whether to stretch to the box. Off for an image that should keep its own
  /// intrinsic size.
  final bool fill;

  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Image.network(
        url,
        fit: fit,
        width: fill ? double.infinity : null,
        height: fill ? double.infinity : null,
        cacheWidth: decodeWidthFor(context, constraints.maxWidth),
        errorBuilder: errorBuilder,
      ),
    );
  }
}

/// The width to decode at, in device pixels.
///
/// Null where the box is unbounded: there is no honest answer then, and
/// inventing one would resize the image to something arbitrary.
int? decodeWidthFor(BuildContext context, double width) {
  if (!width.isFinite || width <= 0) return null;
  final pixels = width * MediaQuery.devicePixelRatioOf(context);
  // A little headroom, so a decode that lands slightly under the drawn size
  // never shows as softness on a high-density screen.
  return (pixels * 1.15).round();
}
