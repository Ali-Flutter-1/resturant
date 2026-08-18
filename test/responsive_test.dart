import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practice/core/theme/app_spacing.dart';
import 'package:practice/core/theme/app_theme.dart';
import 'package:practice/shared/widgets/page_body.dart';

/// Adapting to a wide window, rather than stretching to fill one.
///
/// The rule this pins: past [AppLayout.wide] the content column stops growing
/// and the surplus becomes margin. A line of text that runs the full width of a
/// tablet is tiring to read, and a form turns into far-apart labels and fields —
/// which is the difference between a tablet layout and a blown-up phone.
void main() {
  Future<void> pumpAt(WidgetTester tester, double width, Widget child) async {
    final view = tester.view;
    view.physicalSize = Size(width, 1200);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: child));
    await tester.pumpAndSettle();
  }

  group('the page inset', () {
    testWidgets('a phone gets the plain gutter', (tester) async {
      late double inset;
      await pumpAt(
        tester,
        390,
        Builder(
          builder: (context) {
            inset = pageSideInset(context);
            return const SizedBox.shrink();
          },
        ),
      );
      expect(inset, AppSpacing.gutter);
    });

    testWidgets('a tablet centres the column instead of stretching it', (
      tester,
    ) async {
      late double inset;
      await pumpAt(
        tester,
        1024,
        Builder(
          builder: (context) {
            inset = pageSideInset(context);
            return const SizedBox.shrink();
          },
        ),
      );

      // The content column stays readable and the rest becomes margin.
      final column = 1024 - 2 * inset;
      expect(column, closeTo(AppLayout.readable, 0.5));
      expect(inset, greaterThan(AppSpacing.gutter));
    });

    testWidgets('the column never exceeds the readable width', (tester) async {
      for (final width in [600.0, 834.0, 1280.0, 1920.0]) {
        late double inset;
        await pumpAt(
          tester,
          width,
          Builder(
            builder: (context) {
              inset = pageSideInset(context);
              return const SizedBox.shrink();
            },
          ),
        );
        expect(
          width - 2 * inset,
          lessThanOrEqualTo(AppLayout.readable + 0.5),
          reason: 'column ran wide at ${width}px',
        );
      }
    });
  });

  group('PageBody', () {
    testWidgets('caps and centres its child on a wide window', (tester) async {
      await pumpAt(
        tester,
        1200,
        Scaffold(
          body: PageBody(
            child: Container(key: const Key('content'), height: 100),
          ),
        ),
      );

      final content = tester.getRect(find.byKey(const Key('content')));
      expect(content.width, lessThanOrEqualTo(AppLayout.readable));
      // Centred: equal margin either side.
      expect(content.left, closeTo(1200 - content.right, 1));
    });

    testWidgets('a phone keeps the full width minus the gutter', (
      tester,
    ) async {
      await pumpAt(
        tester,
        390,
        Scaffold(
          body: PageBody(
            child: Container(key: const Key('content'), height: 100),
          ),
        ),
      );

      final content = tester.getRect(find.byKey(const Key('content')));
      expect(content.width, closeTo(390 - 2 * AppSpacing.gutter, 0.5));
    });
  });

  test('the breakpoint is a width, not a device', () {
    // A phone in landscape and a small tablet in portrait are the same problem,
    // so there is one number rather than a device list.
    expect(AppLayout.isWide(599), isFalse);
    expect(AppLayout.isWide(600), isTrue);
    expect(AppLayout.gutterFor(390), AppSpacing.gutter);
    expect(AppLayout.gutterFor(900), AppSpacing.x8);
  });
}
