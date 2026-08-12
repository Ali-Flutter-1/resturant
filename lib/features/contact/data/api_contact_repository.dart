import '../../../core/network/api_client.dart';
import '../../../core/network/api_constants.dart';
import '../domain/contact_repository.dart';

class ApiContactRepository implements ContactRepository {
  ApiContactRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  @override
  Future<void> send({
    required String name,
    required String email,
    required String message,
    String? phone,
    String? subject,
  }) async {
    // `send`, not `object`: the route answers `{success, message, data: null}`,
    // and asking for an object would throw on the null even though the message
    // arrived.
    await _client.send(
      ApiConstants.contact,
      method: 'POST',
      body: {
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'message': message.trim(),
        'phone': ?_orNull(phone),
        'subject': ?_orNull(subject),
      },
    );
  }

  /// Blank optional fields are omitted rather than sent as empty strings, which
  /// the API would store as a subject of "".
  static String? _orNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
