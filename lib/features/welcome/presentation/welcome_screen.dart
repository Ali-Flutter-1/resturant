import 'package:flutter/material.dart';

import '../../../core/animations/motion.dart';
import '../../../core/animations/reveal.dart';
import '../../../core/theme/app_spacing.dart';

/// The splash: photograph, logo, promise. No controls.
///
/// It used to offer "Get Started" and "Login to your account", which asked the
/// user to choose between two paths that led to the same screen. The app now
/// decides for them — see `SplashGate` in `main.dart`: a returning user goes
/// straight to their dashboard and everyone else lands on sign-in. Nothing here
/// is tappable, so there is nothing to mis-tap during the entrance.
///
/// Built as an orchestrated entrance rather than scattered effects — the
/// photograph settles, then the logo and headline arrive in sequence.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _HeroBackdrop(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.gutter,
                AppSpacing.gutter,
                AppSpacing.x12,
              ),
              child: const Column(children: [Expanded(child: _Branding())]),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBackdrop extends StatelessWidget {
  const _HeroBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // The Figma frame sized this 512×279 image at top-left inside an
        // 852pt-tall frame, so the photograph tiled visibly. Cover fixes the
        // repeat; the source asset is still low-resolution — see the note in
        // the handover.
        Image.asset(
          'assets/images/welcome_hero.jpg',
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
        // Bottom-up scrim, so the actions always sit on enough contrast
        // regardless of what the photograph is doing behind them.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              stops: [0.0, 0.5, 1.0],
              colors: [Color(0xE6000000), Color(0x80000000), Color(0x33000000)],
            ),
          ),
        ),
      ],
    )
    // The photograph settles inward as it fades up, so the screen reads
    // as coming to rest rather than simply appearing. No travel — a
    // full-bleed image sliding would show its own edges.
    .reveal(duration: Motion.slow, distance: 0, scaleFrom: 1.06);
  }
}

class _Branding extends StatelessWidget {
  const _Branding();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Image.asset(
            'assets/images/logo.jpg',
            width: 192,
            fit: BoxFit.contain,
          ),
        ).reveal(delay: Motion.cinematicFor(1)),
        const SizedBox(height: AppSpacing.x8),
        Text(
          'Heritage in Every Bite',
          textAlign: TextAlign.center,
          style: context.textTheme.displayLarge?.copyWith(color: Colors.white),
        ).reveal(delay: Motion.cinematicFor(2)),
        const SizedBox(height: AppSpacing.x2),
        Text(
          'Experience a symphony of British and Sri Lankan flavors.',
          textAlign: TextAlign.center,
          style: context.textTheme.bodyLarge?.copyWith(
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ).reveal(delay: Motion.cinematicFor(3)),
      ],
    );
  }
}

extension on BuildContext {
  TextTheme get textTheme => Theme.of(this).textTheme;
}
