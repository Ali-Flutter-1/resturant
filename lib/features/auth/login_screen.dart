import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/animations/motion.dart';
import '../../core/animations/page_transitions.dart';
import '../../core/animations/reveal.dart';
import '../../core/haptics/app_haptics.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/widgets/app_buttons.dart';
import '../../shared/widgets/app_sheet.dart';
import 'auth_cubit.dart';
import 'presentation/auth_form_parts.dart';
import 'register_screen.dart';

/// Sign-in.
///
/// No frame for this exists in the Figma file — it is built from the app's own
/// design language.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  /// Client-side complaints, keyed like the API's own `fieldErrors` so both
  /// sources render through the same slot under each input.
  Map<String, String> _localErrors = const {};

  /// Whether the user has pressed submit on *this* screen.
  ///
  /// Guards against showing the shared cubit's error or spinner for an attempt
  /// made somewhere else. Nothing about a request appears until it was asked
  /// for here.
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    // Belt and braces with [_submitted]: entering the screen also drops
    // whatever the previous one left behind.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthCubit>().clearError();
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();

    final errors = <String, String>{};
    final email = AuthRules.email(_email.text);
    final password = AuthRules.presentPassword(_password.text);
    if (email != null) errors['email'] = email;
    if (password != null) errors['password'] = password;

    setState(() {
      _localErrors = errors;
      _submitted = true;
    });
    // Nothing is sent until the form is plausible. Failing locally is instant;
    // failing at the server costs a round trip to learn the field was blank.
    if (errors.isNotEmpty) {
      AppHaptics.failure();
      return;
    }

    context.read<AuthCubit>().signIn(
      email: _email.text,
      password: _password.text,
    );
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (AuthRules.email(email) != null) {
      setState(
        () => _localErrors = {
          'email': 'Enter your email address first, then tap this again.',
        },
      );
      return;
    }

    final error = await context.read<AuthCubit>().requestPasswordReset(email);
    if (!mounted) return;

    showAppSnack(
      context,
      error ??
          // Worded to match the API's deliberate silence about which addresses
          // exist. Saying "we've sent you an email" would confirm the account.
          'If that address has an account, a reset link is on its way.',
      isError: error != null,
    );
  }

  @override
  Widget build(BuildContext context) {
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
          // Server complaints win: it knows things the client cannot, and its
          // wording is already fit to show.
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
              Text('Welcome back', style: context.texts.displayLarge),
              const SizedBox(height: AppSpacing.x2),
              Text(
                'Sign in to order, book a table, or manage the restaurant.',
                style: context.texts.bodyLarge?.copyWith(
                  color: context.surfaces.inkMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.x8),

              AuthField(
                label: 'Email',
                controller: _email,
                hint: 'you@example.com',
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.username],
                fieldError: fieldErrors['email'],
              ),
              const SizedBox(height: AppSpacing.x4),

              AuthField(
                label: 'Password',
                controller: _password,
                hint: 'Your password',
                icon: Icons.lock_outline,
                obscure: _obscure,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _submit(),
                fieldError: fieldErrors['password'],
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

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: state.isSubmitting ? null : _forgotPassword,
                  child: const Text('Forgot password?'),
                ),
              ),

              // A permanent slot that grows to fit. Keeping the child count
              // fixed matters: the staggered reveal identifies items by
              // position, so splicing one in would re-run the entrance of
              // everything below it on every failed sign-in.
              AnimatedSize(
                duration: motion.move(Motion.base),
                curve: motion.standard,
                alignment: Alignment.topCenter,
                child: formError == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.x4),
                        child: AuthErrorNote(message: formError),
                      ),
              ),

              // Cross-fade rather than cut, so the button appears to become
              // the spinner and the tap stays connected to its result.
              AnimatedSwitcher(
                duration: motion.fade(Motion.fast),
                child: showServer && state.isSubmitting
                    ? const _SubmittingButton()
                    : PrimaryButton(label: 'Sign In', onPressed: _submit),
              ),

              const SizedBox(height: AppSpacing.x6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'New here?',
                    style: context.texts.bodyMedium?.copyWith(
                      color: context.surfaces.inkMuted,
                    ),
                  ),
                  TextButton(
                    onPressed: state.isSubmitting
                        ? null
                        : () => Navigator.of(context).push(
                            AppPageRoute<void>(
                              builder: (_) => RegisterScreen(
                                onBack: () => Navigator.of(context).pop(),
                              ),
                            ),
                          ),
                    child: const Text('Create an account'),
                  ),
                ],
              ),
            ].revealStaggered(),
          );
        },
      ),
    );
  }
}

/// The submit button mid-request: the same size and colour, so the row does not
/// change height when it swaps in.
class _SubmittingButton extends StatelessWidget {
  const _SubmittingButton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
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
    );
  }
}
