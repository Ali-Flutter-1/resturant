import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/animations/motion.dart';
import '../../core/animations/shake.dart';
import '../../core/animations/reveal.dart';
import '../../core/haptics/app_haptics.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../shared/widgets/app_buttons.dart';
import 'auth_cubit.dart';

/// Sign-in.
///
/// No frame for this exists in the Figma file — it is built from the app's
/// own design language. The demo-account panel at the bottom is scaffolding
/// for testing and should come out before anyone sees this.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController(text: 'customer@tscafe.co.uk');
  final _password = TextEditingController(text: 'password');
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    context.read<AuthCubit>().signIn(
      email: _email.text,
      password: _password.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: widget.onBack == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
                tooltip: 'Back',
              ),
      ),
      body: BlocConsumer<AuthCubit, AuthState>(
        // The outcome of a sign-in is exactly the kind of thing haptics are
        // for: the user is looking at the keyboard, not the screen.
        listenWhen: (a, b) =>
            a.isSignedIn != b.isSignedIn ||
            (b.error != null && a.error != b.error),
        listener: (context, state) {
          if (state.isSignedIn) {
            AppHaptics.success();
          } else if (state.error != null) {
            AppHaptics.failure();
          }
        },
        builder: (context, state) {
          final motion = context.motion;
          // The error text sits well below the fold on a small phone, so the
          // shake is often the only signal the user actually sees.
          return Shake(
            trigger: state.error,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.x4,
                AppSpacing.gutter,
                AppSpacing.x12,
              ),
              children: [
                Text('Welcome back', style: context.texts.displayLarge),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  'Sign in to order, book a table, or manage the restaurant.',
                  style: context.texts.bodyLarge?.copyWith(
                    color: context.surfaces.inkMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.x8),

                Text('Email', style: context.texts.titleMedium),
                const SizedBox(height: AppSpacing.x2),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    hintText: 'you@example.com',
                    prefixIcon: Icon(Icons.mail_outline, size: AppIconSize.lg),
                  ),
                ),
                const SizedBox(height: AppSpacing.x5),

                Text('Password', style: context.texts.titleMedium),
                const SizedBox(height: AppSpacing.x2),
                TextField(
                  controller: _password,
                  obscureText: _obscure,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: 'Your password',
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      size: AppIconSize.lg,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: AppIconSize.lg,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                      tooltip: _obscure ? 'Show password' : 'Hide password',
                    ),
                  ),
                ),

                // The note occupies a permanent slot that grows to fit
                // it, rather than being spliced into the list. Keeping
                // the child count fixed matters: the staggered reveal
                // above identifies items by position, so inserting one
                // mid-list would re-run the entrance of everything
                // below it every time a sign-in failed.
                AnimatedSize(
                  duration: motion.move(Motion.base),
                  curve: motion.standard,
                  alignment: Alignment.topCenter,
                  child: state.error == null
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.x4),
                          child: _ErrorNote(message: state.error!),
                        ),
                ),

                const SizedBox(height: AppSpacing.x8),
                // Cross-fade rather than cut, so the button appears to
                // become the spinner and the tap stays connected to its
                // result.
                AnimatedSwitcher(
                  duration: motion.fade(Motion.fast),
                  child: state.isSubmitting
                      ? Container(
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.onPrimary,
                            ),
                          ),
                        )
                      : PrimaryButton(label: 'Sign In', onPressed: _submit),
                ),

                const SizedBox(height: AppSpacing.x12),
                const _DemoAccounts(),
              ].revealStaggered(),
            ),
          );
        },
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colours = context.orderColors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: colours.overdueContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline,
            size: AppIconSize.md,
            color: colours.overdue,
          ),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Text(
              message,
              style: context.texts.bodyMedium?.copyWith(color: colours.overdue),
            ),
          ),
        ],
      ),
    );
  }
}

/// Test scaffolding. Delete with the rest of the mock auth.
class _DemoAccounts extends StatelessWidget {
  const _DemoAccounts();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: context.surfaces.ground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.surfaces.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.science_outlined,
                size: AppIconSize.sm,
                color: context.surfaces.inkSoft,
              ),
              const SizedBox(width: AppSpacing.x2),
              Text(
                'DEMO BUILD',
                style: AppTypography.caption(context.surfaces.inkSoft),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(
            'There is no server yet. Any password works, and these two '
            'accounts jump straight to each side of the app.',
            style: context.texts.bodySmall,
          ),
          const SizedBox(height: AppSpacing.x4),
          Row(
            children: [
              Expanded(
                child: _RoleButton(
                  label: 'Customer',
                  icon: Icons.person_outline,
                  role: UserRole.customer,
                ),
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: _RoleButton(
                  label: 'Admin',
                  icon: Icons.admin_panel_settings_outlined,
                  role: UserRole.admin,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  const _RoleButton({
    required this.label,
    required this.icon,
    required this.role,
  });

  final String label;
  final IconData icon;
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () {
        AppHaptics.commit();
        context.read<AuthCubit>().signInAs(role);
      },
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: AppIconSize.md),
          const SizedBox(width: AppSpacing.x2),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
