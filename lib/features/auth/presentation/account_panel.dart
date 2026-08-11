import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/haptics/app_haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../auth_cubit.dart';
import 'auth_form_parts.dart';

/// Who you are signed in as, and the three things you can do about it.
///
/// Sign out, change password and close the account live together because they
/// are the same decision at three levels of finality, and separating them is how
/// an app ends up with a delete buried where nobody can find it — or worse, next
/// to sign out with the same weight.
///
/// The visual hierarchy does the safety work: sign out is an ordinary button,
/// change password is quieter, and closing the account is text in the warning
/// colour, below a divider, behind a confirmation that asks for the password.
class AccountPanel extends StatelessWidget {
  const AccountPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final email = context.select((AuthCubit c) => c.state.email);
    final name = context.select((AuthCubit c) => c.state.user?.displayName);

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
          Text(
            'SIGNED IN AS',
            style: AppTypography.caption(context.surfaces.inkSoft),
          ),
          const SizedBox(height: AppSpacing.x1),
          if (name != null && name.isNotEmpty)
            Text(name, style: context.texts.titleMedium),
          Text(
            email ?? 'Unknown',
            style: context.texts.bodyLarge?.copyWith(
              color: context.surfaces.inkMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.x4),

          OutlinedButton(
            onPressed: () {
              AppHaptics.commit();
              // Clears locally first and revokes in the background — the user
              // asked to leave, so they should not wait on the network to do it,
              // and a failed call must not leave them apparently signed in.
              context.read<AuthCubit>().signOut();
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout, size: AppIconSize.md),
                SizedBox(width: AppSpacing.x2),
                Text('Sign out'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x2),

          TextButton.icon(
            onPressed: () => _showChangePassword(context),
            icon: const Icon(Icons.lock_reset, size: AppIconSize.md),
            label: const Text('Change password'),
          ),

          Divider(height: AppSpacing.x6, color: context.surfaces.line),

          TextButton.icon(
            onPressed: () => _showDeleteAccount(context),
            icon: const Icon(Icons.delete_forever, size: AppIconSize.md),
            label: const Text('Delete my account'),
            style: TextButton.styleFrom(
              foregroundColor: context.orderColors.overdue,
            ),
          ),
        ],
      ),
    );
  }
}

/// Change the password on the signed-in account.
void _showChangePassword(BuildContext context) {
  final cubit = context.read<AuthCubit>();
  showAppSheet<void>(
    context: context,
    title: 'Change password',
    subtitle: 'You will stay signed in on this device.',
    child: BlocProvider.value(value: cubit, child: const _ChangePasswordForm()),
  );
}

class _ChangePasswordForm extends StatefulWidget {
  const _ChangePasswordForm();

  @override
  State<_ChangePasswordForm> createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends State<_ChangePasswordForm> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  Map<String, String> _errors = const {};
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final errors = <String, String>{};
    if (_current.text.isEmpty) {
      errors['current_password'] = 'Enter your current password.';
    }
    final next = AuthRules.password(_next.text);
    if (next != null) {
      errors['new_password'] = next;
    } else if (_next.text == _current.text) {
      // Caught here rather than at the server: the API may well accept it, and
      // "changed" for a password that did not change is a confusing success.
      errors['new_password'] = 'That is your current password.';
    }

    setState(() => _errors = errors);
    if (errors.isNotEmpty) {
      AppHaptics.failure();
      return;
    }

    setState(() => _busy = true);
    final error = await context.read<AuthCubit>().changePassword(
      currentPassword: _current.text,
      newPassword: _next.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (error != null) {
      AppHaptics.failure();
      setState(() => _errors = {'current_password': error});
      return;
    }

    AppHaptics.success();
    Navigator.of(context).pop();
    showAppSnack(context, 'Password changed.');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.x4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthField(
            label: 'Current password',
            controller: _current,
            obscure: true,
            icon: Icons.lock_outline,
            autofillHints: const [AutofillHints.password],
            fieldError: _errors['current_password'],
          ),
          const SizedBox(height: AppSpacing.x4),
          AuthField(
            label: 'New password',
            controller: _next,
            obscure: true,
            icon: Icons.lock_reset,
            hint: 'At least 8 characters',
            autofillHints: const [AutofillHints.newPassword],
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
            fieldError: _errors['new_password'],
          ),
          const SizedBox(height: AppSpacing.x5),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'Saving…' : 'Change password'),
          ),
        ],
      ),
    );
  }
}

/// Close the account.
void _showDeleteAccount(BuildContext context) {
  final cubit = context.read<AuthCubit>();
  showAppSheet<void>(
    context: context,
    title: 'Delete your account?',
    subtitle: 'This cannot be undone.',
    child: BlocProvider.value(value: cubit, child: const _DeleteAccountForm()),
  );
}

class _DeleteAccountForm extends StatefulWidget {
  const _DeleteAccountForm();

  @override
  State<_DeleteAccountForm> createState() => _DeleteAccountFormState();
}

class _DeleteAccountFormState extends State<_DeleteAccountForm> {
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });

    final error = await context.read<AuthCubit>().deleteAccount(_password.text);
    if (!mounted) return;

    if (error != null) {
      AppHaptics.failure();
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }

    // The cubit has already cleared the session, so the app is on its way back
    // to sign-in; this only closes the sheet on the way out.
    AppHaptics.commit();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colours = context.orderColors;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.x4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Your orders, bookings and saved details are removed. You will need '
            'to create a new account to order again.',
            style: context.texts.bodyMedium?.copyWith(
              color: context.surfaces.inkMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.x4),

          // Required for accounts that have a password, and ignored for
          // Google-only ones — which is why an empty field is still sent rather
          // than refused here. Re-authenticating is what separates closing an
          // account from a mis-tap on an unlocked phone.
          AuthField(
            label: 'Confirm your password',
            controller: _password,
            obscure: true,
            icon: Icons.lock_outline,
            hint: 'Leave blank if you signed in with Google',
            autofillHints: const [AutofillHints.password],
            fieldError: _error,
          ),
          const SizedBox(height: AppSpacing.x5),

          FilledButton(
            onPressed: _busy ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: colours.overdue,
              foregroundColor: Colors.white,
            ),
            child: Text(_busy ? 'Deleting…' : 'Delete my account'),
          ),
          const SizedBox(height: AppSpacing.x2),
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Keep my account'),
          ),
        ],
      ),
    );
  }
}
