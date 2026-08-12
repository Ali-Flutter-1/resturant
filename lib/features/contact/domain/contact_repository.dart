/// Sending a message through the Contact Us form.
///
/// `POST /contact` needs no authentication — the form is on a public screen and
/// somebody who cannot sign in is exactly who most needs to reach the
/// restaurant. The message lands in the admin inbox.
abstract interface class ContactRepository {
  /// [name], [email] and [message] are required by the API; the rest are
  /// optional and omitted when blank rather than sent empty.
  Future<void> send({
    required String name,
    required String email,
    required String message,
    String? phone,
    String? subject,
  });
}
