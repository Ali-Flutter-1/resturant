import 'dart:io';

import 'package:dio/dio.dart';

/// Why a request didn't produce data.
///
/// Every failure in the app is one of these. The point is that [message] is
/// always safe to show a person: no status codes, no exception class names, no
/// stack traces leaking into the interface. Where the API sends its own
/// `message` — and this API always does — that wins, because the server knows
/// what actually went wrong; the fallbacks below only cover the cases where
/// nothing readable arrived.
enum ApiFailureKind {
  /// No usable connection. Checked before the request is even attempted.
  offline,

  /// The request was sent but nothing came back in time.
  timeout,

  /// The server could not be reached, or hung up.
  unreachable,

  /// 401 — signed out, or the session expired.
  unauthorised,

  /// 403 — signed in, but this role may not do it.
  ///
  /// Deliberately not folded into [unauthorised]. A customer reaching an
  /// admin route is not a session problem, and telling them to sign in again
  /// sends them round a loop that cannot help: signing in again produces the
  /// same role and the same refusal.
  forbidden,

  /// 404.
  notFound,

  /// 409 — someone else got there first.
  conflict,

  /// 422 and other validation refusals.
  invalid,

  /// 429.
  tooManyRequests,

  /// 5xx.
  server,

  /// Anything we could not classify.
  unknown,
}

class ApiFailure implements Exception {
  const ApiFailure({
    required this.kind,
    required this.message,
    this.statusCode,
    this.code,
    this.fieldErrors = const {},
  });

  final ApiFailureKind kind;

  /// Shown to the user verbatim. Always a complete sentence.
  final String message;

  final int? statusCode;

  /// The API's machine-readable reason, e.g. `ORDER_TOO_LATE_TO_CANCEL` or
  /// `DISH_SOLD_OUT`.
  ///
  /// [message] is what a person reads; this is what code branches on, for the
  /// handful of cases where the app should do something specific rather than
  /// just report. Never shown.
  final String? code;

  /// Per-field complaints, keyed by the API's field name, for forms that can
  /// point at the offending input rather than showing one message at the top.
  final Map<String, String> fieldErrors;

  /// True when retrying the identical request could plausibly succeed. Drives
  /// whether the UI offers a "Try again" button.
  bool get isRetryable => switch (kind) {
    ApiFailureKind.offline ||
    ApiFailureKind.timeout ||
    ApiFailureKind.unreachable ||
    ApiFailureKind.server ||
    ApiFailureKind.tooManyRequests => true,
    _ => false,
  };

  /// True when the session is gone and the user must sign in again.
  ///
  /// 401 only. A 403 means the account is fine and the *role* is not allowed.
  bool get requiresSignIn => kind == ApiFailureKind.unauthorised;

  /// The offline case, raised before a request is attempted.
  static const offline = ApiFailure(
    kind: ApiFailureKind.offline,
    message:
        "You're offline. Check your connection and try again — nothing has "
        'been sent.',
  );

  /// Translates whatever Dio threw into something a person can read.
  ///
  /// Ordering matters: the API's own `message` is preferred over any fallback,
  /// because "That email is already registered" is worth more than "Something
  /// went wrong (409)".
  factory ApiFailure.fromDio(DioException error) {
    final response = error.response;
    final status = response?.statusCode;
    final envelope = response?.data;

    final serverMessage = _messageFrom(envelope);
    final fields = _fieldErrorsFrom(envelope);
    final code = _codeFrom(envelope);

    final kind = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => ApiFailureKind.timeout,
      DioExceptionType.connectionError => ApiFailureKind.unreachable,
      DioExceptionType.cancel => ApiFailureKind.unknown,
      _ => _kindForStatus(status),
    };

    // A socket error dressed up as something else still means unreachable.
    final resolved = error.error is SocketException
        ? ApiFailureKind.unreachable
        : kind;

    return ApiFailure(
      kind: resolved,
      message: serverMessage ?? _fallbackMessage(resolved),
      statusCode: status,
      code: code,
      fieldErrors: fields,
    );
  }

  static ApiFailureKind _kindForStatus(int? status) => switch (status) {
    null => ApiFailureKind.unknown,
    401 => ApiFailureKind.unauthorised,
    403 => ApiFailureKind.forbidden,
    404 => ApiFailureKind.notFound,
    409 => ApiFailureKind.conflict,
    422 || 400 => ApiFailureKind.invalid,
    429 => ApiFailureKind.tooManyRequests,
    _ when status >= 500 => ApiFailureKind.server,
    _ => ApiFailureKind.unknown,
  };

  /// Deliberately plain English, and never a bare code. Each one says what
  /// happened and, where there is one, what to do next.
  static String _fallbackMessage(ApiFailureKind kind) => switch (kind) {
    ApiFailureKind.offline => offline.message,
    ApiFailureKind.timeout =>
      'That took too long to respond. Please try again.',
    ApiFailureKind.unreachable =>
      "We couldn't reach the restaurant's server. Please try again in a "
          'moment.',
    ApiFailureKind.unauthorised =>
      'Your session has expired. Please sign in again.',
    ApiFailureKind.forbidden => "You don't have permission to do that.",
    ApiFailureKind.notFound => "We couldn't find that.",
    ApiFailureKind.conflict =>
      'Someone just got there first. Please choose something else.',
    ApiFailureKind.invalid => 'Please check the details and try again.',
    ApiFailureKind.tooManyRequests =>
      'Too many attempts. Please wait a moment and try again.',
    ApiFailureKind.server =>
      'The restaurant’s server is having trouble. Please try again shortly.',
    ApiFailureKind.unknown => 'Something went wrong. Please try again.',
  };

  /// The API's `error.code`, where it sent one.
  static String? _codeFrom(Object? body) {
    if (body is! Map) return null;
    final error = body['error'];
    if (error is! Map) return null;
    final code = error['code'];
    return code is String && code.isNotEmpty ? code : null;
  }

  /// Pulls `message` out of the API's `{success, message, data}` envelope.
  static String? _messageFrom(Object? body) {
    if (body is! Map) return null;
    final message = body['message'];
    if (message is String && message.trim().isNotEmpty) return message.trim();

    // FastAPI's own validation shape, for anything not wrapped by the app's
    // envelope: {"detail": "..."} or {"detail": [{"msg": ...}]}.
    final detail = body['detail'];
    if (detail is String && detail.trim().isNotEmpty) return detail.trim();
    if (detail is List && detail.isNotEmpty) {
      final first = detail.first;
      if (first is Map && first['msg'] is String) {
        return (first['msg'] as String).trim();
      }
    }
    return null;
  }

  /// Per-field complaints, flattened to `{field: message}` so a form can mark
  /// the offending input rather than showing one message at the top.
  ///
  /// This API sends them as `error.details: [{field, message}]`. The app was
  /// only reading FastAPI's raw `detail: [{loc, msg}]` shape, which this
  /// backend never emits — so every field error was silently dropped and a
  /// rejected sign-up showed one sentence at the top with no indication of
  /// which box was wrong. Both shapes are read now: the API's own first, the
  /// framework's as a fallback for anything not wrapped by the envelope.
  static Map<String, String> _fieldErrorsFrom(Object? body) {
    if (body is! Map) return const {};
    final errors = <String, String>{};

    final error = body['error'];
    if (error is Map && error['details'] is List) {
      for (final entry in error['details'] as List) {
        if (entry is! Map) continue;
        final field = entry['field'];
        final message = entry['message'];
        if (field is String && field.isNotEmpty && message is String) {
          errors[field] = message;
        }
      }
      if (errors.isNotEmpty) return errors;
    }

    final detail = body['detail'];
    if (detail is! List) return errors;
    for (final entry in detail) {
      if (entry is! Map) continue;
      final loc = entry['loc'];
      final msg = entry['msg'];
      if (loc is! List || loc.isEmpty || msg is! String) continue;
      final field = loc.last;
      if (field is String) errors[field] = msg;
    }
    return errors;
  }

  @override
  String toString() => 'ApiFailure($kind, $statusCode): $message';
}
