import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:practice/core/animations/motion.dart';
import 'package:practice/core/animations/page_transitions.dart';
import 'package:practice/core/animations/animated_count.dart';
import 'package:practice/core/animations/collapse.dart';
import 'package:practice/core/animations/reveal.dart';
import 'package:practice/core/animations/shake.dart';
import 'package:practice/core/theme/app_theme.dart';

/// Sets the platform's reduce-motion flag for the duration of a test.
///
/// This goes through the platform dispatcher rather than injecting a
/// [MediaQuery] inside the app, because that is where the real setting comes
/// from — and the difference matters: [AppPageRoute] reads the preference off
/// the navigator's context, which sits *above* anything a screen could
/// override.
void _setReduceMotion(WidgetTester tester, {required bool reduced}) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: reduced);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

/// Uses the real theme, so route transitions go through the app's own
/// [PageTransitionsBuilder] rather than Flutter's default.
Widget _app({required Widget child}) =>
    MaterialApp(theme: AppTheme.light, home: child);

/// Finders scoped inside the [Reveal] under test — a [MaterialApp] brings its
/// own route transitions, so an unscoped `byType` would match those too.
Finder _revealFade() => find.descendant(
  of: find.byType(Reveal),
  matching: find.byType(FadeTransition),
);

Finder _revealSlide() => find.descendant(
  of: find.byType(Reveal),
  matching: find.byType(SlideUpTransition),
);

void main() {
  group('MotionScheme', () {
    test('leaves motion alone by default', () {
      const scheme = MotionScheme();
      expect(scheme.reduced, isFalse);
      expect(scheme.move(Motion.base), Motion.base);
      expect(scheme.fade(Motion.base), Motion.base);
      expect(scheme.slideUp, Motion.slideUp);
      expect(scheme.pressScale, Motion.pressScale);
      expect(scheme.staggerFor(3), Motion.staggerFor(3));
    });

    test('collapses displacement but keeps a brief fade when reduced', () {
      const scheme = MotionScheme.reduced();
      expect(scheme.reduced, isTrue);
      // Movement is removed outright...
      expect(scheme.move(Motion.slow), Duration.zero);
      expect(scheme.slideUp, 0);
      expect(scheme.slideIn, 0);
      expect(scheme.pressScale, 1);
      expect(scheme.pressScaleLarge, 1);
      expect(scheme.staggerFor(5), Duration.zero);
      // ...but an opacity change still gets a moment, so state changes read
      // as changes rather than as cuts.
      expect(scheme.fade(Motion.slow), Motion.instant);
    });

    testWidgets('Motion.of picks up the platform preference', (tester) async {
      _setReduceMotion(tester, reduced: true);
      late MotionScheme seen;
      await tester.pumpWidget(
        _app(
          child: Builder(
            builder: (context) {
              seen = context.motion;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen.reduced, isTrue);
    });
  });

  group('stagger', () {
    test('caps so a long list does not crawl', () {
      expect(Motion.staggerFor(0), Duration.zero);
      expect(Motion.staggerFor(3), Motion.stagger * 3);
      // Everything past the cap lands together with the item at the cap.
      expect(Motion.staggerFor(Motion.staggerCap), Motion.stagger * 8);
      expect(Motion.staggerFor(50), Motion.staggerFor(Motion.staggerCap));
    });
  });

  group('Reveal', () {
    testWidgets('animates from transparent and displaced to settled', (
      tester,
    ) async {
      await tester.pumpWidget(_app(child: const Reveal(child: Text('hello'))));

      double opacity() =>
          tester.widget<FadeTransition>(_revealFade()).opacity.value;

      expect(opacity(), 0);
      expect(_revealSlide(), findsOneWidget);

      await tester.pump(Motion.base ~/ 2);
      expect(opacity(), greaterThan(0));
      expect(opacity(), lessThan(1));

      await tester.pumpAndSettle();
      expect(opacity(), 1);
    });

    testWidgets('is already settled, with no transition, when reduced', (
      tester,
    ) async {
      _setReduceMotion(tester, reduced: true);
      await tester.pumpWidget(_app(child: const Reveal(child: Text('hello'))));

      // No fade, no displacement — the content is simply present.
      expect(_revealFade(), findsNothing);
      expect(_revealSlide(), findsNothing);
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('staggers a list and disposes every controller', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          child: Column(
            children: const [Text('a'), Text('b'), Text('c')].revealStaggered(),
          ),
        ),
      );

      expect(find.byType(Reveal), findsNWidgets(3));

      // Later items start later: at one stagger step in, the first is moving
      // and the last has not begun.
      await tester.pump(Motion.stagger);
      final opacities = tester
          .widgetList<FadeTransition>(_revealFade())
          .map((t) => t.opacity.value)
          .toList();
      expect(opacities.first, greaterThan(opacities.last));

      await tester.pumpAndSettle();

      // Tearing the tree down must not leave a ticker running.
      await tester.pumpWidget(_app(child: const SizedBox()));
      expect(tester.takeException(), isNull);
    });
  });

  group('AppPageRoute', () {
    testWidgets('shares one transition across pushes', (tester) async {
      await tester.pumpWidget(
        _app(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push(AppPageRoute<void>(builder: (_) => const Text('second'))),
              child: const Text('go'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('second'), findsOneWidget);
    });

    testWidgets('slides, fades and scales the incoming page', (tester) async {
      await tester.pumpWidget(
        _app(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push(AppPageRoute<void>(builder: (_) => const Text('second'))),
              child: const Text('go'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(Motion.base ~/ 3);

      final transition = find.byType(AppPageTransition);
      expect(transition, findsWidgets);

      // Mid-flight the page is offset to the right, part-faded and undersized.
      final incoming = find.text('second');
      expect(tester.getTopLeft(incoming).dx, greaterThan(0));

      // Scoped to the *incoming* page. Both routes wear an AppPageTransition
      // mid-flight, and the outgoing one has already finished arriving.
      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(of: incoming, matching: find.byType(FadeTransition))
            .first,
      );
      expect(fade.opacity.value, greaterThan(0));
      expect(fade.opacity.value, lessThan(1));

      final scale = tester.widget<ScaleTransition>(
        find
            .ancestor(of: incoming, matching: find.byType(ScaleTransition))
            .first,
      );
      expect(scale.scale.value, greaterThanOrEqualTo(0.98));
      expect(scale.scale.value, lessThan(1));

      await tester.pumpAndSettle();
      expect(tester.getTopLeft(incoming).dx, 0);
    });

    testWidgets('forward and back take the same time', (tester) async {
      final route = AppPageRoute<void>(builder: (_) => const Text('second'));
      expect(route.transitionDuration, Motion.base);
      expect(route.reverseTransitionDuration, route.transitionDuration);
    });

    testWidgets('is instant, with no transition, when motion is reduced', (
      tester,
    ) async {
      _setReduceMotion(tester, reduced: true);
      late BuildContext pushContext;
      await tester.pumpWidget(
        _app(
          child: Builder(
            builder: (context) {
              pushContext = context;
              return const Text('first');
            },
          ),
        ),
      );

      final route = AppPageRoute<void>(builder: (_) => const Text('second'));
      Navigator.of(pushContext).push(route);
      await tester.pump();

      expect(route.transitionDuration, Duration.zero);
      // No slide, no fade, no scale — the destination, immediately.
      expect(find.byType(AppPageTransition), findsNothing);
      expect(find.text('second'), findsOneWidget);
    });
  });

  group('AnimatedCount', () {
    testWidgets('counts up to its value', (tester) async {
      await tester.pumpWidget(
        _app(
          child: AnimatedCount(
            value: 1248,
            format: (v) => v.round().toString(),
          ),
        ),
      );

      expect(find.text('0'), findsOneWidget);

      await tester.pump(Motion.slow ~/ 2);
      final mid = int.parse(tester.widget<Text>(find.byType(Text).first).data!);
      expect(mid, greaterThan(0));
      expect(mid, lessThan(1248));

      await tester.pumpAndSettle();
      expect(find.text('1248'), findsOneWidget);
    });

    testWidgets('shows the figure outright when motion is reduced', (
      tester,
    ) async {
      _setReduceMotion(tester, reduced: true);
      await tester.pumpWidget(
        _app(
          child: AnimatedCount(
            value: 1248,
            format: (v) => v.round().toString(),
          ),
        ),
      );

      // No counting: a climbing number is movement the user cannot look away
      // from, so reduce-motion gets the answer immediately.
      expect(find.text('1248'), findsOneWidget);
    });
  });

  group('Shake', () {
    Widget host(Object? trigger) => _app(
      child: Shake(trigger: trigger, child: const Text('field')),
    );

    testWidgets('displaces on a changed trigger and settles back', (
      tester,
    ) async {
      await tester.pumpWidget(host(null));
      Offset at() => tester.getTopLeft(find.text('field'));
      final rest = at();

      await tester.pumpWidget(host('bad password'));
      await tester.pump(Motion.slow ~/ 4);
      expect(at().dx, isNot(rest.dx));

      await tester.pumpAndSettle();
      expect(at().dx, rest.dx);
    });

    testWidgets('an unchanged trigger does not re-shake', (tester) async {
      await tester.pumpWidget(host('same error'));
      await tester.pumpAndSettle();
      final rest = tester.getTopLeft(find.text('field'));

      await tester.pumpWidget(host('same error'));
      await tester.pump(Motion.slow ~/ 4);
      expect(tester.getTopLeft(find.text('field')).dx, rest.dx);
    });

    testWidgets('stays still when motion is reduced', (tester) async {
      _setReduceMotion(tester, reduced: true);
      await tester.pumpWidget(host(null));
      final rest = tester.getTopLeft(find.text('field'));

      await tester.pumpWidget(host('rejected'));
      await tester.pump(Motion.slow ~/ 4);
      expect(tester.getTopLeft(find.text('field')).dx, rest.dx);
    });
  });

  group('Collapse', () {
    // Top-aligned so the Collapse takes its child's height rather than being
    // stretched to the viewport, which is what makes it measurable.
    Widget host(bool collapsed, {VoidCallback? onCollapsed}) => _app(
      child: Align(
        alignment: Alignment.topLeft,
        child: Collapse(
          collapsed: collapsed,
          onCollapsed: onCollapsed,
          child: const SizedBox(height: 100, width: 100, child: Text('row')),
        ),
      ),
    );

    testWidgets('folds shut and reports once when it has no height', (
      tester,
    ) async {
      var done = 0;
      await tester.pumpWidget(host(false, onCollapsed: () => done++));
      expect(tester.getSize(find.byType(Collapse)).height, 100);

      await tester.pumpWidget(host(true, onCollapsed: () => done++));
      await tester.pump(Motion.base ~/ 2);

      final mid = tester.getSize(find.byType(Collapse)).height;
      expect(mid, lessThan(100));
      expect(mid, greaterThan(0));
      // The caller must not drop the item while it still occupies space.
      expect(done, 0);

      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(Collapse)).height, 0);
      expect(done, 1);
    });

    testWidgets('reopening mid-fold cancels the removal', (tester) async {
      var done = 0;
      await tester.pumpWidget(host(false, onCollapsed: () => done++));
      await tester.pumpWidget(host(true, onCollapsed: () => done++));
      await tester.pump(Motion.base ~/ 2);

      // This is undo arriving before the fold finished.
      await tester.pumpWidget(host(false, onCollapsed: () => done++));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(Collapse)).height, 100);
      expect(done, 0, reason: 'a reversed fold never completed');
    });

    testWidgets('removes without folding when motion is reduced', (
      tester,
    ) async {
      _setReduceMotion(tester, reduced: true);
      var done = 0;
      await tester.pumpWidget(host(false, onCollapsed: () => done++));
      await tester.pumpWidget(host(true, onCollapsed: () => done++));
      await tester.pump();

      expect(tester.getSize(find.byType(Collapse)).height, 0);
      // The caller still gets told, or the item would never leave state.
      expect(done, 1);
    });
  });
}
