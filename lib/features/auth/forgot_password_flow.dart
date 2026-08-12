import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Resetting a forgotten password: email, then a six-digit code, then the new
/// password.
///
/// One widget with three steps rather than three pushed routes. The reset token
/// from step 2 is a bearer credential for changing a password, and keeping it in
/// a single `State` means it is never passed through a route argument, never
/// stored, and dies with the screen.
///
/// The steps also are not independently reachable: arriving at "enter your code"
/// without the email it belongs to is a dead end, and a back stack would allow
/// exactly that.
class ForgotPasswordFlow extends StatefulWidget {
  const ForgotPasswordFlow({super.key, this.email, this.onFinished});

  /// Prefills step 1 from whatever was typed on the sign-in screen.
  final String? email;

  /// Called after a successful reset, to return to sign-in.
  final VoidCallback? onFinished;

  @override
  State<ForgotPasswordFlow> createState() => _ForgotPasswordFlowState();
}

enum _Step { email, code, password }

class _ForgotPasswordFlowState extends State<ForgotPasswordFlow> {
  late final _email = TextEditingController(text: widget.email ?? '');
  final _code = TextEditingController();
  final _password = TextEditingController();

  _Step _step = _Step.email;
  bool _busy = false;
  bool _obscure = true;

  /// In memory only, for the life of this screen.
  PasswordResetSession? _session;

  String? _error;
  Map<String, String> _fieldErrors = const {};

  /// Seconds left before "Resend code" is offered again.
  ///
  /// The API silently caps requests at five an hour — the sixth returns the same
  /// cheerful 200 and sends nothing. A cooldown is the difference between a user
  /// spending that allowance in ten seconds and then waiting for an email that
  /// will never come.
  int _resendIn = 0;
  Timer? _resendTimer;

  /// Fires once, when the token expires.
  ///
  /// Deliberately not a per-second tick. A countdown that rebuilt the screen
  /// every second bought a live seconds display at the cost of waking the app
  /// sixty times a minute — and it meant the widget tree never went idle, which
  /// is a real problem on device and makes the flow untestable. The remaining
  /// time is stated once, in minutes, and this timer handles the moment it runs
  /// out.
  Timer? _expiryTimer;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _resendTimer?.cancel();
    _expiryTimer?.cancel();
    super.dispose();
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendIn = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _resendIn = _resendIn - 1);
      if (_resendIn <= 0) timer.cancel();
    });
  }

  void _watchExpiry() {
    _expiryTimer?.cancel();
    final session = _session;
    if (session == null) return;

    _expiryTimer = Timer(session.remaining, () {
      if (!mounted) return;
      // Back to the start rather than letting them type a password against a
      // token the server is going to refuse.
      _restart('That code has expired. Ask for a new one.');
    });
  }

  /// Sends the user back to step 1, keeping their email.
  void _restart(String message) {
    _resendTimer?.cancel();
    _expiryTimer?.cancel();
    AppHaptics.failure();
    setState(() {
      _step = _Step.email;
      _session = null;
      _code.clear();
      _password.clear();
      _busy = false;
      _resendIn = 0;
      _error = message;
      _fieldErrors = const {};
    });
  }

  void _fail(String message, [Map<String, String> fields = const {}]) {
    AppHaptics.failure();
    setState(() {
      _busy = false;
      _error = message;
      _fieldErrors = fields;
    });
  }

  // ---------------------------------------------------------------- step 1

  Future<void> _requestCode({bool resend = false}) async {
    FocusScope.of(context).unfocus();

    final emailError = AuthRules.email(_email.text);
    if (emailError != null) {
      _fail('', {'email': emailError});
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _fieldErrors = const {};
    });

    final error = await context.read<AuthCubit>().requestPasswordReset(
      _email.text,
    );
    if (!mounted) return;

    if (error != null) {
      _fail(error);
      return;
    }

    AppHaptics.success();
    _startResendCooldown();
    setState(() {
      _busy = false;
      _step = _Step.code;
    });
    if (resend) {
      showAppSnack(context, 'A new code is on its way.');
    }
  }

  // ---------------------------------------------------------------- step 2

  Future<void> _verifyCode() async {
    FocusScope.of(context).unfocus();

    final digits = _code.text.replaceAll(RegExp(r'\s+'), '');
    if (digits.length != 6) {
      _fail('', {'code': 'Enter the six digits from the email.'});
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _fieldErrors = const {};
    });

    final (session, failure) = await context.read<AuthCubit>().verifyResetCode(
      email: _email.text,
      code: digits,
    );
    if (!mounted) return;

    if (failure != null) {
      // Branching on the code, not the wording: a lockout and a wrong code are
      // both refusals, but only one of them can be retried here.
      if (ResetErrorCodes.sendsUserBackToStart(failure.code)) {
        _restart(failure.message);
        return;
      }
      // A wrong code keeps them here — the message carries the remaining tries.
      _code.clear();
      _fail(failure.message, failure.fieldErrors);
      return;
    }

    AppHaptics.success();
    setState(() {
      _busy = false;
      _session = session;
      _step = _Step.password;
    });
    _watchExpiry();
  }

  // ---------------------------------------------------------------- step 3

  Future<void> _setPassword() async {
    FocusScope.of(context).unfocus();
    final session = _session;
    if (session == null) {
      _restart('Something went wrong. Ask for a new code.');
      return;
    }

    final passwordError = AuthRules.password(_password.text);
    if (passwordError != null) {
      _fail('', {'new_password': passwordError});
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _fieldErrors = const {};
    });

    final failure = await context.read<AuthCubit>().resetPassword(
      token: session.token,
      newPassword: _password.text,
    );
    if (!mounted) return;

    if (failure != null) {
      if (ResetErrorCodes.sendsUserBackToStart(failure.code)) {
        _restart(failure.message);
        return;
      }
      // A weak password leaves the token good, so they stay here.
      _fail(failure.message, failure.fieldErrors);
      return;
    }

    _expiryTimer?.cancel();
    AppHaptics.success();
    // The cubit has already cleared this device's tokens — the reset revoked
    // every session, including this one. Deliberately no auto sign-in.
    showAppSnack(context, 'Password changed. Sign in with your new one.');
    widget.onFinished?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forgot password'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: _busy
              ? null
              // Within the flow, back means "previous step" rather than "leave"
              // — except on the first, where there is nowhere else to go.
              : () {
                  if (_step == _Step.email) {
                    Navigator.of(context).maybePop();
                  } else {
                    _restart('');
                  }
                },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.x4,
          AppSpacing.gutter,
          AppSpacing.x12,
        ),
        children: [
          _StepIndicator(step: _step),
          const SizedBox(height: AppSpacing.x6),
          // Keyed by step so the fields cross-fade rather than the new step's
          // text appearing in the old step's boxes.
          AnimatedSwitcher(
            duration: context.motion.fade(Motion.base),
            child: KeyedSubtree(key: ValueKey(_step), child: _body(context)),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) => switch (_step) {
    _Step.email => _emailStep(context),
    _Step.code => _codeStep(context),
    _Step.password => _passwordStep(context),
  };

  Widget _emailStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('What is your email?', style: context.texts.displayLarge),
        const SizedBox(height: AppSpacing.x2),
        Text(
          'We will send you a six-digit code.',
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
          onSubmitted: (_) => FocusScope.of(context).unfocus(),
          fieldError: _fieldErrors['email'],
        ),
        _errorNote(),
        const SizedBox(height: AppSpacing.x6),
        _submit('Send code', _requestCode),
      ].revealStaggered(),
    );
  }

  Widget _codeStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Enter your code', style: context.texts.displayLarge),
        const SizedBox(height: AppSpacing.x2),
        Text(
          // The address is repeated because a typo in it is the likeliest reason
          // no email arrives, and a wrong email is refused with the same message
          // as a wrong code — so the app cannot tell them apart for you.
          'We sent a six-digit code to ${_email.text.trim()}.',
          style: context.texts.bodyLarge?.copyWith(
            color: context.surfaces.inkMuted,
          ),
        ),
        const SizedBox(height: AppSpacing.x8),
        AuthField(
          label: 'Six-digit code',
          controller: _code,
          hint: '000000',
          icon: Icons.dialpad,
          keyboardType: TextInputType.number,
          // Spaces allowed through: a code pasted from an email arrives as
          // "482 913", and stripping it is the app's job, not the user's.
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
            LengthLimitingTextInputFormatter(7),
          ],
          onSubmitted: (_) => FocusScope.of(context).unfocus(),
          fieldError: _fieldErrors['code'],
        ),
        _errorNote(),
        const SizedBox(height: AppSpacing.x6),
        _submit('Verify code', _verifyCode),
        const SizedBox(height: AppSpacing.x2),
        TextButton(
          onPressed: _busy || _resendIn > 0
              ? null
              : () => _requestCode(resend: true),
          child: Text(
            _resendIn > 0 ? 'Resend code in ${_resendIn}s' : 'Resend code',
          ),
        ),
      ].revealStaggered(),
    );
  }

  Widget _passwordStep(BuildContext context) {
    final session = _session;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Choose a new password', style: context.texts.displayLarge),
        const SizedBox(height: AppSpacing.x2),
        Text(
          'You will be signed out everywhere and can sign in with the new one.',
          style: context.texts.bodyLarge?.copyWith(
            color: context.surfaces.inkMuted,
          ),
        ),
        const SizedBox(height: AppSpacing.x8),
        AuthField(
          label: 'New password',
          controller: _password,
          hint: 'At least 8 characters',
          icon: Icons.lock_outline,
          obscure: _obscure,
          autofillHints: const [AutofillHints.newPassword],
          onSubmitted: (_) => FocusScope.of(context).unfocus(),
          fieldError: _fieldErrors['new_password'],
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
        if (session != null) ...[
          const SizedBox(height: AppSpacing.x2),
          Row(
            children: [
              Icon(
                Icons.schedule,
                size: AppIconSize.sm,
                color: context.surfaces.inkSoft,
              ),
              const SizedBox(width: AppSpacing.x2),
              // Flexible: the sentence is wider than a 320pt screen once the
              // icon and gutters are taken off, and a countdown that overflows
              // hides the number it exists to show.
              Flexible(
                child: Text(
                  'This code is valid for about '
                  '${_formatRemaining(session.remaining)}.',
                  style: context.texts.bodySmall?.copyWith(
                    color: context.surfaces.inkSoft,
                  ),
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ],
        _errorNote(),
        const SizedBox(height: AppSpacing.x6),
        _submit('Set new password', _setPassword),
      ].revealStaggered(),
    );
  }

  /// The form-level message, in a slot that grows rather than a widget spliced
  /// into the list — inserting one would re-run the staggered entrance below it.
  Widget _errorNote() {
    final motion = context.motion;
    final message = _error;

    return AnimatedSize(
      duration: motion.move(Motion.base),
      curve: motion.standard,
      alignment: Alignment.topCenter,
      child: message == null || message.isEmpty
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: AppSpacing.x4),
              child: AuthErrorNote(message: message),
            ),
    );
  }

  Widget _submit(String label, Future<void> Function() onPressed) {
    return AnimatedSwitcher(
      duration: context.motion.fade(Motion.fast),
      child: _busy
          ? const SubmittingButton()
          : PrimaryButton(label: label, onPressed: onPressed),
    );
  }

  /// Coarse on purpose: the figure is written once, when the code is verified,
  /// and "about 10 minutes" stays true for long enough to be worth reading. A
  /// live clock would need a rebuild a second to keep from lying.
  static String _formatRemaining(Duration left) {
    final minutes = left.inMinutes;
    if (minutes <= 0) return 'under a minute';
    return minutes == 1 ? 'a minute' : '$minutes minutes';
  }
}

/// Three dashes, the current one filled.
///
/// Cheap orientation: a three-step flow with no indication of where you are in
/// it feels like it might go on for ever.
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});

  final _Step step;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = context.motion;
    final index = _Step.values.indexOf(step);

    return Row(
      children: [
        for (var i = 0; i < _Step.values.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: AnimatedContainer(
              duration: motion.fade(Motion.base),
              curve: motion.standard,
              height: 4,
              decoration: BoxDecoration(
                // Steps already done stay filled, so progress reads as progress
                // rather than as a single moving dot.
                color: i <= index ? scheme.primary : context.surfaces.line,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
