import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_failure.dart';
import '../domain/admin_contact_repository.dart';
import '../domain/contact_message.dart';

enum InboxStatus { loading, ready, failure }

class AdminContactState extends Equatable {
  const AdminContactState({
    this.status = InboxStatus.loading,
    this.messages = const [],
    this.failure,
    this.filter,
    this.query = '',
    this.busyIds = const {},
  });

  final InboxStatus status;

  /// Newest first, as the API returns them.
  final List<ContactMessage> messages;

  final ApiFailure? failure;

  /// Null means every state.
  final ContactStatus? filter;

  /// Free-text search, applied on the client.
  ///
  /// Unlike the status filter, which the API supports, there is no search
  /// parameter on `/admin/contact` — so this narrows what has been loaded. Said
  /// plainly rather than hidden: it searches this page, not the archive.
  final String query;

  /// Messages with a write in flight, so only that row is disabled.
  final Set<String> busyIds;

  /// How many still want attention. Shown as a badge, because an inbox nobody
  /// is prompted to open is an inbox nobody opens.
  int get openCount => messages.where((m) => m.status.isOpen).length;

  /// What the list shows: [messages] narrowed by [query].
  ///
  /// Searches the sender, the subject and the message itself — somebody looking
  /// for "catering" may remember the word from any of the three.
  List<ContactMessage> get visible {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return messages;
    return messages.where((m) {
      return m.name.toLowerCase().contains(needle) ||
          m.email.toLowerCase().contains(needle) ||
          (m.subject?.toLowerCase().contains(needle) ?? false) ||
          m.message.toLowerCase().contains(needle);
    }).toList();
  }

  /// True when a search has hidden everything — a different situation from an
  /// empty inbox, and it deserves different words.
  bool get isSearchEmpty =>
      status == InboxStatus.ready && messages.isNotEmpty && visible.isEmpty;

  AdminContactState copyWith({
    InboxStatus? status,
    List<ContactMessage>? messages,
    ApiFailure? failure,
    ContactStatus? filter,
    String? query,
    Set<String>? busyIds,
    bool clearFilter = false,
    bool clearFailure = false,
  }) {
    return AdminContactState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      failure: clearFailure ? null : (failure ?? this.failure),
      filter: clearFilter ? null : (filter ?? this.filter),
      query: query ?? this.query,
      busyIds: busyIds ?? this.busyIds,
    );
  }

  @override
  List<Object?> get props => [
    status,
    messages,
    failure,
    filter,
    query,
    busyIds,
  ];
}

/// The contact inbox.
///
/// Filtering happens server-side here rather than in the state, unlike the menu:
/// an inbox grows without bound, and asking for one status is a query the API
/// already supports.
class AdminContactCubit extends Cubit<AdminContactState> {
  AdminContactCubit({required AdminContactRepository repository})
    : _repository = repository,
      super(const AdminContactState());

  final AdminContactRepository _repository;

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      emit(state.copyWith(status: InboxStatus.loading, clearFailure: true));
    }

    try {
      emit(
        state.copyWith(
          status: InboxStatus.ready,
          messages: await _repository.messages(status: state.filter),
          clearFailure: true,
        ),
      );
    } on ApiFailure catch (failure) {
      emit(
        state.copyWith(
          status: silent && state.messages.isNotEmpty
              ? InboxStatus.ready
              : InboxStatus.failure,
          failure: failure,
        ),
      );
    }
  }

  void search(String query) => emit(state.copyWith(query: query));

  Future<void> filterBy(ContactStatus? status) async {
    emit(
      status == null
          ? state.copyWith(clearFilter: true)
          : state.copyWith(filter: status),
    );
    // Refetched rather than filtered locally, so a filtered view is complete
    // rather than being whatever happened to be on the first page.
    await load(silent: state.messages.isNotEmpty);
  }

  /// Changes a message's status, or adds a private note, or both.
  ///
  /// Returns an error message to show, or null on success.
  Future<String?> update(
    String id, {
    ContactStatus? status,
    String? adminNote,
  }) async {
    if (state.busyIds.contains(id)) return null;
    emit(state.copyWith(busyIds: {...state.busyIds, id}));

    try {
      final updated = await _repository.update(
        id,
        status: status,
        adminNote: adminNote,
      );
      emit(
        state.copyWith(
          messages: [
            for (final m in state.messages)
              if (m.id == id) updated else m,
          ],
          busyIds: {...state.busyIds}..remove(id),
        ),
      );
      return null;
    } on ApiFailure catch (failure) {
      emit(state.copyWith(busyIds: {...state.busyIds}..remove(id)));
      return failure.message;
    }
  }

  /// Pulls one message in full.
  ///
  /// The list already carries every field, so this is only for picking up a
  /// change a colleague made while the detail sheet was open. Returns null on
  /// failure; the caller then shows what it already has.
  Future<ContactMessage?> refreshOne(String id) async {
    try {
      final message = await _repository.messageById(id);
      emit(
        state.copyWith(
          messages: [
            for (final m in state.messages)
              if (m.id == id) message else m,
          ],
        ),
      );
      return message;
    } on ApiFailure {
      return null;
    }
  }
}
