import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Whether the device has a network to use.
///
/// Deliberately a thin wrapper. `connectivity_plus` reports what the device is
/// *attached* to, not whether the internet is actually reachable — an
/// unreachable Wi-Fi captive portal still reports `wifi`. So this answers "is
/// there any point trying?", and a real failure to reach the server is still
/// classified by [ApiFailure.fromDio] when the attempt fails.
///
/// That split matters: pre-flighting the obvious offline case gives an instant,
/// honest message instead of a twenty-second timeout, while never claiming a
/// request will succeed just because Wi-Fi is on.
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  static bool _isOnline(List<ConnectivityResult> results) =>
      results.isNotEmpty && results.any((r) => r != ConnectivityResult.none);

  /// A single check, for use immediately before a request.
  Future<bool> get isOnline async {
    try {
      return _isOnline(await _connectivity.checkConnectivity());
    } on Object {
      // If the platform channel itself fails, assume online and let the
      // request produce the real error. Blocking every request because a
      // connectivity plugin misbehaved would be worse than the timeout.
      return true;
    }
  }

  /// Emits on every change, for a banner that appears and clears itself.
  Stream<bool> get onStatusChange =>
      _connectivity.onConnectivityChanged.map(_isOnline).distinct();
}
