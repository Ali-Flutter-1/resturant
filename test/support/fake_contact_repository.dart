import 'package:practice/core/network/api_failure.dart';
import 'package:practice/features/contact/domain/contact_repository.dart';

/// Records what the Contact Us form sent.
///
/// The form used to clear itself and claim success without a request existing at
/// all, so what matters here is that a real send happened with the right fields.
class FakeContactRepository implements ContactRepository {
  ApiFailure? failure;
  int sendCalls = 0;
  Map<String, String?>? lastSend;

  @override
  Future<void> send({
    required String name,
    required String email,
    required String message,
    String? phone,
    String? subject,
  }) async {
    sendCalls++;
    final error = failure;
    if (error != null) throw error;
    lastSend = {
      'name': name,
      'email': email,
      'message': message,
      'phone': phone,
      'subject': subject,
    };
  }
}
