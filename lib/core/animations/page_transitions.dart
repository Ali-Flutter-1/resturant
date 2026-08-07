import 'package:flutter/material.dart';

import 'motion.dart';

/// The app's page transition, as a widget.
///
/// Exposed separately from the builder below so any bespoke route — a modal,
/// a nested navigator, a future `PageRouteBuilder` — can wear the same motion
/// without restating it. Nothing in the app should ever hand-roll a page
/// transition again; use this.
///
/// The composition is three things happening on one curve:
///
///  * the incoming page **slides** in from the right,
///  * **fades** from transparent,
///  * and **scales** from 0.98, so it appears to settle forward into place
///    rather than simply arrive.
///
/// The outgoing page drifts a fifth of the viewport to the left rather than
/// sitting still. That parallax is what stops the two pages reading as one
/// flat sheet being swapped, and it is what makes the reverse feel like the
/// forward played backwards.
///
/// Curves are applied with [CurveTween] rather than [CurvedAnimation] on
/// purpose: a `CurvedAnimation` built in `build` attaches a listener that
/// nothing ever disposes, which leaks on every route push.
class AppPageTransition extends StatelessWidget {
  const AppPageTransition({
    super.key,
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  /// Drives this page's own arrival and departure.
  final Animation<double> animation;

  /// Drives this page being covered by the next one.
  final Animation<double> secondaryAnimation;

  final Widget child;

  /// How far the outgoing page drifts, as a fraction of the viewport.
  static const double _parallax = 0.2;

  /// The incoming page starts a touch small, so it reads as settling forward.
  static const double _from = 0.98;

  @override
  Widget build(BuildContext context) {
    final curve = CurveTween(curve: Motion.standard);

    final incoming = animation.drive(curve);
    final outgoing = secondaryAnimation.drive(curve);

    return SlideTransition(
      // Applied outermost so the page under the incoming one moves as a whole.
      position: outgoing.drive(
        Tween<Offset>(begin: Offset.zero, end: const Offset(-_parallax, 0)),
      ),
      child: SlideTransition(
        position: incoming.drive(
          Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero),
        ),
        child: FadeTransition(
          opacity: incoming,
          child: ScaleTransition(
            scale: incoming.drive(Tween<double>(begin: _from, end: 1)),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Supplies [AppPageTransition] to every route through the theme.
///
/// A [PageTransitionsBuilder] rather than a custom route, so the motion
/// applies to any push from anywhere — including routes Flutter creates
/// itself — without a single call site opting in. That is what keeps the
/// transition from being restated per route.
///
/// On Apple platforms it delegates to Cupertino instead. That is not deference
/// to house style: [CupertinoPageTransitionsBuilder] is what installs the
/// edge-swipe back gesture, and substituting any other transition silently
/// removes a gesture iOS users navigate with constantly. Cupertino's own
/// motion is already a right-to-left slide with parallax, so the visual cost
/// of keeping it is close to nothing and the behavioural cost of replacing it
/// is a lost gesture.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder({required this.useCupertino});

  /// Whether to hand over to Cupertino, and with it the back gesture.
  final bool useCupertino;

  @override
  Widget buildTransitions<T>(
    PageRoute<T>? route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Reduce-motion gets the destination outright. Every part of this
    // transition is displacement — slide, parallax, scale — and none of it
    // survives the setting meaningfully, so the honest answer is no
    // transition at all rather than a token one.
    if (Motion.of(context).reduced) return child;

    // Cupertino's builder needs the route: the back gesture hangs off it. A
    // null route only occurs outside a real navigator, where there is nothing
    // to swipe back to.
    if (useCupertino && route != null) {
      return const CupertinoPageTransitionsBuilder().buildTransitions<T>(
        route,
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }

    return AppPageTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}

/// The transition map for [ThemeData.pageTransitionsTheme].
///
/// Every platform is mapped explicitly. Leaving one out sends it to Flutter's
/// default, which is how desktop and web ended up with a different transition
/// from the phones.
const appPageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.iOS: AppPageTransitionsBuilder(useCupertino: true),
    TargetPlatform.macOS: AppPageTransitionsBuilder(useCupertino: true),
    TargetPlatform.android: AppPageTransitionsBuilder(useCupertino: false),
    TargetPlatform.fuchsia: AppPageTransitionsBuilder(useCupertino: false),
    TargetPlatform.linux: AppPageTransitionsBuilder(useCupertino: false),
    TargetPlatform.windows: AppPageTransitionsBuilder(useCupertino: false),
  },
);

/// The route every push in the app goes through.
///
/// It extends [MaterialPageRoute] and deliberately does *not* override
/// `buildTransitions`: doing so bypasses [ThemeData.pageTransitionsTheme]
/// entirely, which is how the iOS back gesture gets lost. The transition comes
/// from the theme; the route contributes only timing.
///
/// Extending `MaterialPageRoute` rather than `PageRouteBuilder` also keeps
/// `settings`, route arguments and result types working exactly as before, so
/// nothing about how routes are pushed or popped has to change.
class AppPageRoute<T> extends MaterialPageRoute<T> {
  AppPageRoute({required super.builder, super.settings});

  /// Reduce-motion is read off the navigator rather than the route's own
  /// context, because this is consulted before the page's element exists.
  bool get _reduced {
    final context = navigator?.context;
    if (context == null) return false;
    return Motion.of(context).reduced;
  }

  @override
  Duration get transitionDuration => _reduced ? Duration.zero : Motion.base;

  /// Symmetric with the forward direction: going back is the same motion
  /// played in reverse, so it should take the same time.
  @override
  Duration get reverseTransitionDuration =>
      _reduced ? Duration.zero : Motion.base;
}
