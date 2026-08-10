import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/animations/motion.dart';
import '../../../core/animations/shake.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// The pieces sign-in and sign-up share.
///
/// Both screens ask for the same things in the same way, so the field, the
/// error note and the submit button live here. Two copies would drift, and on
/// an auth screen drift shows: a differently-worded password error on the
/// register screen reads as a different rule.

/// A labelled text field.
///
/// [fieldError] is the API's own complaint about this field — from
/// `ApiFailure.fieldErrors` — shown under the input so the user can see which
/// box is wrong rather than reading a message at the top and guessing.
class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.icon,
    this.obscure = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.onSubmitted,
    this.suffix,
    this.fieldError,
    this.autofillHints,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final IconData? icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;
  final String? fieldError;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    final motion = context.motion;
    final colours = context.orderColors;
    final hasError = fieldError != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.texts.titleMedium),
        const SizedBox(height: AppSpacing.x2),
        // The shake belongs to the field that was refused, not to the page.
        // Shaking the whole screen for one bad character is disproportionate,
        // and it says nothing about *where* to look.
        Shake(
          trigger: fieldError,
          child: TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            autocorrect: !obscure && keyboardType != TextInputType.emailAddress,
            autofillHints: autofillHints,
            onSubmitted: onSubmitted,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: icon == null
                  ? null
                  : Icon(icon, size: AppIconSize.lg),
              suffixIcon: suffix,
              // Only the border turns: recolouring the whole field would make a
              // single wrong character look like a failure of the whole form.
              enabledBorder: hasError
                  ? OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(color: colours.overdue),
                    )
                  : null,
            ),
          ),
        ),
        // A permanent slot that grows, rather than a widget spliced into the
        // parent list: inserting one would shift every sibling's position and
        // re-run the staggered entrance below it.
        AnimatedSize(
          duration: motion.move(Motion.fast),
          curve: motion.standard,
          alignment: Alignment.topLeft,
          child: hasError
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.x1),
                  child: Text(
                    fieldError!,
                    style: context.texts.bodySmall?.copyWith(
                      color: colours.overdue,
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// The form-level error: what went wrong with the request as a whole.
class AuthErrorNote extends StatelessWidget {
  const AuthErrorNote({super.key, required this.message});

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

/// Client-side checks, matching the API's documented rules.
///
/// These exist to answer instantly rather than to be authoritative — the server
/// is the authority, and its message wins whenever it disagrees. The point is
/// that a mistyped email shouldn't cost a round trip to discover.
abstract final class AuthRules {
  /// Deliberately permissive. Rejecting valid-but-unusual addresses is a worse
  /// failure than letting the server refuse one, so this only catches the
  /// obviously incomplete.
  static String? email(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Enter your email address.';
    if (!trimmed.contains('@') || !trimmed.contains('.')) {
      return 'That email address looks incomplete.';
    }
    return null;
  }

  /// The API's rule: 8–128 characters, at least one letter and one digit, and
  /// no more than 72 UTF-8 **bytes** — bcrypt truncates beyond that, so a long
  /// password with emoji would be silently cut.
  static String? password(String value) {
    if (value.isEmpty) return 'Choose a password.';
    if (value.length < 8) return 'Use at least 8 characters.';
    if (value.length > 128) return 'Use no more than 128 characters.';
    if (!value.contains(RegExp('[A-Za-z]'))) {
      return 'Include at least one letter.';
    }
    if (!value.contains(RegExp('[0-9]'))) return 'Include at least one number.';
    if (utf8.encode(value).length > 72) {
      return 'That password is too long. Try a shorter one.';
    }
    return null;
  }

  static String? name(String value, String field) =>
      value.trim().isEmpty ? 'Enter your $field.' : null;

  /// Sign-in only checks for emptiness. The server decides whether the password
  /// is *right*, and pre-judging its strength here would refuse an existing
  /// account whose password predates the current rule.
  static String? presentPassword(String value) =>
      value.isEmpty ? 'Enter your password.' : null;
}
