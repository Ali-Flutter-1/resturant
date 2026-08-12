import 'contact_message.dart';

/// The inbox behind the Contact Us form.
///
/// The sender's own words are never editable — this is a record of what somebody
/// said, not a document to tidy up — so the only writes here are the status and
/// a private note.
abstract interface class AdminContactRepository {
  /// Newest first. [status] narrows to one state.
  Future<List<ContactMessage>> messages({ContactStatus? status});

  Future<ContactMessage> messageById(String id);

  /// Changes only what is passed, and returns the updated message.
  Future<ContactMessage> update(
    String id, {
    ContactStatus? status,
    String? adminNote,
  });
}
