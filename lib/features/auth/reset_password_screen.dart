import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/animations/motion.dart';
import '../../core/animations/reveal.dart';
import '../../core/haptics/app_haptics.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/widgets/app_buttons.dart';
import '../../shared/widgets/app_sheet.dart';
import 'auth_cubit.dart';
import 'presentation/auth_form_parts.dart';

/// Finish a password reset with the code from the email.
///
/// The API takes `{token, new_password}` and sends the token by email. A deep
/// link would let the app read it straight from the link, but that needs an
/// associated domain and an intent filter agreed with the backend — so until
/// then the token is pasted in, which works today and needs no server change.
///
/// Reached from sign-in after requesting a reset, and also directly, because a
/// reset email read on a laptop half an hour later must still be usable without
/// asking for a second one.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.email, this.onDone});

  /// Shown as a reminder of where the email went. Not sent — the token
  /// identifies the account on its own.
  final String? email;

  /// Called after a successful reset, once the confirmation has been shown.
  final VoidCallback? onDone;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _token = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  Map<String, String> _localErrors = const {};
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthCubit>().clearError();
    });
  }

  @override
  void dispose() {
    _token.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final errors = <String, String>{};
    if (_token.text.trim().isEmpty) {
      errors['token'] = 'Paste the code from the email.';
    }
    final password = AuthRules.password(_password.text);
    if (password != null) errors['new_password'] = password;

    setState(() {
      _localErrors = errors;
      _submitted = true;
    });
    if (errors.isNotEmpty) {
      AppHaptics.failure();
      return;
    }

    final error = await context.read<AuthCubit>().resetPassword(
      token: _token.text.trim(),
      newPassword: _password.text,
    );
    if (!mounted) return;

    if (error != null) {
      AppHaptics.failure();
      return;
    }

    AppHaptics.success();
    // Deliberately does not sign them in. The API returns no tokens here, and a
    // reset is often requested precisely because someone else may have had the
    // old password — so the new one gets typed once more, on purpose.
    showAppSnack(context, 'Password changed. Sign in with your new password.');
    widget.onDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          final motion = context.motion;
          final showServer = _submitted;
          final fieldErrors = {
            ..._localErrors,
            if (showServer) ...state.fieldErrors,
          };
          final formError = showServer ? state.error : null;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.x4,
              AppSpacing.gutter,
              AppSpacing.x12,
            ),
            children: [
              Text('Choose a new password', style: context.texts.displayLarge),
              const SizedBox(height: AppSpacing.x2),
              Text(
                widget.email == null
                    ? 'Paste the code from the reset email, then pick a new '
                          'password.'
                    : 'We sent a code to ${widget.email}. Paste it below, then '
                          'pick a new password.',
                style: context.texts.bodyLarge?.copyWith(
                  color: context.surfaces.inkMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.x8),

              AuthField(
                label: 'Code from the email',
                controller: _token,
                hint: 'Paste it here',
                icon: Icons.key_outlined,
                fieldError: fieldErrors['token'],
              ),
              const SizedBox(height: AppSpacing.x4),

              AuthField(
                label: 'New password',
                controller: _password,
                hint: 'At least 8 characters',
                icon: Icons.lock_outline,
                obscure: _obscure,
                autofillHints: const [AutofillHints.newPassword],
                onSubmitted: (_) => FocusScope.of(context).unfocus(),
                fieldError: fieldErrors['new_password'],
                suffix: IconButton(
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
              const SizedBox(height: AppSpacing.x1),
              Text(
                'Use at least 8 characters, with a letter and a number.',
                style: context.texts.bodySmall?.copyWith(
                  color: context.surfaces.inkMuted,
                ),
              ),

              AnimatedSize(
                duration: motion.move(Motion.base),
                curve: motion.standard,
                alignment: Alignment.topCenter,
                child: formError == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.x4),
                        child: AuthErrorNote(message: formError),
                      ),
              ),

              const SizedBox(height: AppSpacing.x8),
              AnimatedSwitcher(
                duration: motion.fade(Motion.fast),
                child: showServer && state.isSubmitting
                    ? const SubmittingButton()
                    : PrimaryButton(
                        label: 'Set new password',
                        onPressed: _submit,
                      ),
              ),
            ].revealStaggered(),
          );
        },
      ),
    );
  }
}
