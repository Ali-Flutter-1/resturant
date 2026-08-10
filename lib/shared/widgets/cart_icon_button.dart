import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/animations/motion.dart';
import '../../core/haptics/app_haptics.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../features/cart/cart_cubit.dart';

/// The cart, and the target the flying product lands on.
///
/// Pass [targetKey] to whatever launches the flight so it can measure where
/// this sits on screen. The icon pops when the count rises — the landing
/// needs an impact, or the item appears to be absorbed by nothing.
class CartIconButton extends StatefulWidget {
  const CartIconButton({super.key, required this.targetKey, this.onTap});

  final GlobalKey targetKey;
  final VoidCallback? onTap;

  @override
  State<CartIconButton> createState() => _CartIconButtonState();
}

class _CartIconButtonState extends State<CartIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: Motion.slow,
  );

  late final Animation<double> _scale = TweenSequence<double>([
    // Squash slightly as it takes the hit, then overshoot, then settle.
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 0.86,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 22,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 0.86,
        end: 1.22,
      ).chain(CurveTween(curve: Motion.playful)),
      weight: 38,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.22,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.elasticOut)),
      weight: 40,
    ),
  ]).animate(_pop);

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  void _bump() {
    if (context.motion.reduced) return;
    _pop.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return BlocListener<CartCubit, int>(
      listenWhen: (previous, current) => current > previous,
      listener: (context, _) => _bump(),
      child: IconButton(
        tooltip: 'Cart',
        onPressed: () {
          AppHaptics.toggle();
          widget.onTap?.call();
        },
        icon: ScaleTransition(
          scale: _scale,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // The key sits on the glyph itself, so the flight lands on the
              // icon rather than the button's larger tap target.
              Icon(
                Icons.shopping_bag_outlined,
                key: widget.targetKey,
                color: scheme.primary,
              ),
              Positioned(right: -6, top: -5, child: _CartBadge()),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = context.watch<CartCubit>().state;

    return AnimatedScale(
      scale: count == 0 ? 0 : 1,
      duration: context.motion.move(Motion.fast),
      curve: context.motion.emphasized,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        constraints: const BoxConstraints(minWidth: 17),
        decoration: BoxDecoration(
          color: scheme.primary,
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: Theme.of(context).colorScheme.surface),
        ),
        child: AnimatedSwitcher(
          duration: context.motion.fade(Motion.fast),
          // The new number rises into place as the old one drops away.
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.6),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: Text(
            '$count',
            key: ValueKey(count),
            textAlign: TextAlign.center,
            style: AppTypography.badge(scheme.onPrimary),
          ),
        ),
      ),
    );
  }
}
