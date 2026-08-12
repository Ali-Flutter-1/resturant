import 'package:practice/core/network/api_failure.dart';
import 'package:practice/features/admin/domain/admin_contact_repository.dart';
import 'package:practice/features/admin/domain/contact_message.dart';

/// The inbox, in memory.
///
/// Returns copies rather than its own list: handing out a reference lets a write
/// mutate the very list held in cubit state, which makes Equatable see no change
/// and turns `emit` into a no-op — a screen that looks broken because of the
/// double rather than the code.
class FakeAdminContactRepository implements AdminContactRepository {
  FakeAdminContactRepository({List<ContactMessage>? messages, this.delay})
    : _messages = messages ?? [...defaults];

  /// Holds the answer, so a test can observe the loading state. Without it the
  /// fake resolves in a microtask and the skeleton is gone before the first
  /// frame paints.
  final Duration? delay;

  static final defaults = <ContactMessage>[
    ContactMessage(
      id: 'm1',
      name: 'Ali Hassan',
      email: 'ali@example.com',
      phone: '+44 7700 900123',
      subject: 'Catering for 20',
      message: 'Do you cater for office lunches?',
      status: ContactStatus.newMessage,
      createdAt: DateTime(2026, 8, 11, 14, 30),
    ),
    ContactMessage(
      id: 'm2',
      name: 'Priya Raj',
      email: 'priya@example.com',
      message: 'Is the kottu gluten free?',
      status: ContactStatus.resolved,
      adminNote: 'Answered by phone.',
      createdAt: DateTime(2026, 8, 9, 9, 15),
    ),
  ];

  List<ContactMessage> _messages;

  ApiFailure? failure;
  ContactStatus? lastFilter;
  int listCalls = 0;
  Map<String, Object?>? lastUpdate;

  Future<void> _wait() async {
    final pause = delay;
    if (pause != null) await Future<void>.delayed(pause);
  }

  void _check() {
    final error = failure;
    if (error != null) throw error;
  }

  @override
  Future<List<ContactMessage>> messages({ContactStatus? status}) async {
    listCalls++;
    lastFilter = status;
    await _wait();
    _check();
    return status == null
        ? List.of(_messages)
        : _messages.where((m) => m.status == status).toList();
  }

  @override
  Future<ContactMessage> messageById(String id) async {
    _check();
    return _messages.firstWhere((m) => m.id == id);
  }

  @override
  Future<ContactMessage> update(
    String id, {
    ContactStatus? status,
    String? adminNote,
  }) async {
    _check();
    lastUpdate = {'id': id, 'status': status?.wire, 'admin_note': adminNote};
    final existing = _messages.firstWhere((m) => m.id == id);
    final updated = ContactMessage(
      id: existing.id,
      name: existing.name,
      email: existing.email,
      phone: existing.phone,
      subject: existing.subject,
      message: existing.message,
      status: status ?? existing.status,
      adminNote: adminNote ?? existing.adminNote,
      createdAt: existing.createdAt,
    );
    _messages = [
      for (final m in _messages)
        if (m.id == id) updated else m,
    ];
    return updated;
  }
}
