import '../../../core/network/api_client.dart';
import '../../../core/network/api_constants.dart';
import '../domain/admin_contact_repository.dart';
import '../domain/contact_message.dart';

class ApiAdminContactRepository implements AdminContactRepository {
  ApiAdminContactRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  @override
  Future<List<ContactMessage>> messages({ContactStatus? status}) async {
    final rows = await _client.list(
      ApiConstants.adminContact,
      query: status == null ? null : {'status': status.wire},
    );
    return rows.map(ContactMessage.fromJson).toList();
  }

  @override
  Future<ContactMessage> messageById(String id) async =>
      ContactMessage.fromJson(
        await _client.object(ApiConstants.adminContactMessage(id)),
      );

  @override
  Future<ContactMessage> update(
    String id, {
    ContactStatus? status,
    String? adminNote,
  }) async {
    final data = await _client.object(
      ApiConstants.adminContactMessage(id),
      method: 'PATCH',
      // Only what was passed. Sending both every time would wipe a note when
      // somebody only meant to change the status.
      body: {'status': ?status?.wire, 'admin_note': ?adminNote},
    );
    return ContactMessage.fromJson(data);
  }
}
