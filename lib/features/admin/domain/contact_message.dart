import 'package:equatable/equatable.dart';

/// Where a contact message has got to.
///
/// The API's four values, spelled as it spells them. [fromApi] is tolerant: an
/// unknown status maps to [newMessage] rather than throwing, so a backend that
/// gains a state cannot blank the whole inbox.
enum ContactStatus {
  newMessage('new', 'New'),
  inProgress('in_progress', 'In progress'),
  resolved('resolved', 'Resolved'),
  closed('closed', 'Closed');

  const ContactStatus(this.wire, this.label);

  /// What the API calls it. `new` is a Dart keyword, hence [newMessage].
  final String wire;

  final String label;

  static ContactStatus fromApi(String? raw) =>
      switch (raw?.trim().toLowerCase()) {
        'in_progress' || 'in progress' => inProgress,
        'resolved' => resolved,
        'closed' => closed,
        _ => newMessage,
      };

  /// Whether this message still wants somebody's attention.
  bool get isOpen => this == newMessage || this == inProgress;
}

/// One message from the Contact Us form, as an admin sees it.
class ContactMessage extends Equatable {
  const ContactMessage({
    required this.id,
    required this.name,
    required this.email,
    required this.message,
    required this.status,
    this.phone,
    this.subject,
    this.adminNote,
    this.createdAt,
  });

  factory ContactMessage.fromJson(Map<String, dynamic> json) => ContactMessage(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    email: json['email']?.toString() ?? '',
    message: json['message']?.toString() ?? '',
    status: ContactStatus.fromApi(json['status']?.toString()),
    phone: _orNull(json['phone']),
    subject: _orNull(json['subject']),
    adminNote: _orNull(json['admin_note']),
    createdAt: json['created_at'] == null
        ? null
        : DateTime.tryParse(json['created_at'].toString())?.toLocal(),
  );

  static String? _orNull(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  final String id;
  final String name;
  final String email;
  final String message;
  final ContactStatus status;
  final String? phone;
  final String? subject;

  /// Private to staff. Never shown to the sender.
  final String? adminNote;

  final DateTime? createdAt;

  /// What to put on the row when the sender gave no subject.
  String get heading => subject ?? 'No subject';

  @override
  List<Object?> get props => [
    id,
    name,
    email,
    message,
    status,
    phone,
    subject,
    adminNote,
    createdAt,
  ];
}
