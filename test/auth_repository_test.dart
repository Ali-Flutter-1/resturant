import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:practice/core/network/api_client.dart';
import 'package:practice/core/network/api_failure.dart';
import 'package:practice/core/network/connectivity_service.dart';
import 'package:practice/core/network/token_store.dart';
import 'package:practice/features/auth/data/api_auth_repository.dart';
import 'package:practice/features/auth/domain/auth_user.dart';

class _AlwaysOnline extends ConnectivityService {
  @override
  Future<bool> get isOnline async => true;
}

class _MemoryTokens extends TokenStore {
  String? access;
  String? refresh;
  int clearCalls = 0;

  @override
  Future<void> restore() async {}

  @override
  String? get accessToken => access;

  @override
  String? get refreshToken => refresh;

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    access = accessToken;
    refresh = refreshToken;
  }

  @override
  Future<void> clear() async {
    clearCalls++;
    access = null;
    refresh = null;
  }
}

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
  final bodies = <String, Object?>{};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    bodies[options.path] = options.data;
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, String body) => ResponseBody.fromString(
  body,
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

void main() {
  setUpAll(() {
    dotenv.loadFromString(
      envString: 'API_BASE_URL=http://localhost:8000\nAPI_TIMEOUT_SECONDS=5',
    );
  });

  ({ApiAuthRepository repo, _MemoryTokens tokens, _StubAdapter adapter}) build(
    Future<ResponseBody> Function(RequestOptions) handler, {
    _MemoryTokens? tokens,
  }) {
    final store = tokens ?? _MemoryTokens();
    final adapter = _StubAdapter(handler);
    final dio = Dio()..httpClientAdapter = adapter;
    final client = ApiClient(
      tokens: store,
      connectivity: _AlwaysOnline(),
      dio: dio,
    );
    return (
      repo: ApiAuthRepository(client: client, tokens: store),
      tokens: store,
      adapter: adapter,
    );
  }

  test('login normalises the email and stores the token pair', () async {
    final built = build(
      (_) async => _json(
        200,
        '{"success": true, "message": "Signed in", "data": {'
        '"user": {"id": "1", "email": "boss@tscafe.co.uk", '
        '"first_name": "Sam", "last_name": "Owner", "role": "admin"}, '
        '"tokens": {"access_token": "a1", "refresh_token": "r1"}}}',
      ),
    );

    final user = await built.repo.login(
      email: '  Boss@TsCafe.co.uk ',
      password: 'secret',
    );

    expect(user.role, UserRole.admin);
    // Trimmed and lower-cased, so a stray capital or a pasted space isn't
    // reported back as "no account for that email".
    final sent = built.adapter.bodies['/auth/login'] as Map;
    expect(sent['email'], 'boss@tscafe.co.uk');
    expect(sent['password'], 'secret');
    // Tokens are persisted here and nowhere else.
    expect(built.tokens.access, 'a1');
    expect(built.tokens.refresh, 'r1');
  });

  test('a token-only sign-in falls back to asking who we are', () async {
    var meCalls = 0;
    final built = build((options) async {
      if (options.path == '/auth/me') {
        meCalls++;
        return _json(
          200,
          '{"success": true, "message": "ok", "data": {"id": "1", '
          '"email": "a@b.com", "first_name": "A", "last_name": "B", '
          '"role": "staff"}}',
        );
      }
      return _json(
        200,
        '{"success": true, "message": "ok", "data": {"tokens": '
        '{"access_token": "a1", "refresh_token": "r1"}}}',
      );
    });

    final user = await built.repo.login(email: 'a@b.com', password: 'x');

    // The role decides which half of the app opens, so guessing is not an
    // option — it asks.
    expect(meCalls, 1);
    expect(user.role, UserRole.staff);
  });

  test('logout clears the local token even when the call fails', () async {
    final tokens = _MemoryTokens()
      ..access = 'a1'
      ..refresh = 'r1';
    final built = build(
      (_) async => _json(500, '{"success": false, "message": "Boom"}'),
      tokens: tokens,
    );

    // Must not throw: the user asked to sign out, and a server problem cannot
    // be allowed to leave them apparently signed in.
    await built.repo.logout();

    expect(tokens.refresh, isNull);
    expect(tokens.clearCalls, 1);
  });

  test('changing the password adopts the new token pair', () async {
    final tokens = _MemoryTokens()
      ..access = 'old'
      ..refresh = 'old-r';
    final built = build(
      (_) async => _json(
        200,
        '{"success": true, "message": "Changed", "data": '
        '{"access_token": "new", "refresh_token": "new-r"}}',
      ),
      tokens: tokens,
    );

    await built.repo.changePassword(currentPassword: 'old', newPassword: 'new');

    // The server revoked the old sessions, so failing to store these would
    // sign this device out a moment later.
    expect(tokens.access, 'new');
    expect(tokens.refresh, 'new-r');
  });

  test('a refused sign-in arrives as a readable ApiFailure', () async {
    final built = build(
      (_) async => _json(
        401,
        '{"success": false, "message": "That email and password do not match."}',
      ),
    );

    await expectLater(
      built.repo.login(email: 'a@b.com', password: 'no'),
      throwsA(
        isA<ApiFailure>().having(
          (f) => f.message,
          'message',
          'That email and password do not match.',
        ),
      ),
    );
  });
}
