import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_failure.dart';
import '../domain/working_hours.dart';
import '../domain/working_hours_repository.dart';

enum HoursStatus { loading, ready, failure }

class WorkingHoursState extends Equatable {
  const WorkingHoursState({
    this.status = HoursStatus.loading,
    this.saved = const WorkingHours(),
    this.draft = const [],
    this.failure,
    this.saving = false,
  });

  final HoursStatus status;

  /// What the server last said.
  final WorkingHours saved;

  /// What is on screen. Seven entries, always — the full-week PUT requires one
  /// per weekday, and the editor is a week rather than a list of rows.
  final List<DayHours> draft;

  final ApiFailure? failure;
  final bool saving;

  /// Whether anything is worth sending.
  bool get isDirty {
    final week = saved.wholeWeek;
    if (draft.length != week.length) return true;
    for (var i = 0; i < draft.length; i++) {
      if (draft[i] != week[i]) return true;
    }
    return false;
  }

  /// Days that are open but missing a time, which the API refuses.
  List<DayHours> get incomplete =>
      [for (final day in draft) if (!day.isClosed && !day.isComplete) day];

  /// Days whose closing time is not after their opening time.
  ///
  /// Checked as strings because they are wall clocks — `22:00` sorts after
  /// `10:00` lexically, which is exactly the comparison wanted, and parsing them
  /// into instants would be the timezone bug this type exists to avoid.
  List<DayHours> get backwards => [
    for (final day in draft)
      if (!day.isClosed &&
          day.isComplete &&
          day.closesAt!.compareTo(day.opensAt!) <= 0)
        day,
  ];

  bool get canSave =>
      isDirty && !saving && incomplete.isEmpty && backwards.isEmpty;

  WorkingHoursState copyWith({
    HoursStatus? status,
    WorkingHours? saved,
    List<DayHours>? draft,
    ApiFailure? failure,
    bool? saving,
    bool clearFailure = false,
  }) {
    return WorkingHoursState(
      status: status ?? this.status,
      saved: saved ?? this.saved,
      draft: draft ?? this.draft,
      failure: clearFailure ? null : (failure ?? this.failure),
      saving: saving ?? this.saving,
    );
  }

  @override
  List<Object?> get props => [status, saved, draft, failure, saving];
}

/// The weekly opening hours.
///
/// Edits are **staged**, not saved on every tap: a week is one decision, and
/// seven separate PUTs while somebody is still thinking would leave the
/// restaurant advertising a half-finished schedule. One "Save the week" sends
/// all seven days together.
class WorkingHoursCubit extends Cubit<WorkingHoursState> {
  WorkingHoursCubit({required WorkingHoursRepository repository, bool admin = false})
    : _repository = repository,
      _admin = admin,
      super(const WorkingHoursState());

  final WorkingHoursRepository _repository;

  /// Whether to read the admin view, which adds the audit timestamps.
  final bool _admin;

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      emit(state.copyWith(status: HoursStatus.loading, clearFailure: true));
    }

    try {
      final hours = _admin
          ? await _repository.adminHours()
          : await _repository.hours();
      emit(
        state.copyWith(
          status: HoursStatus.ready,
          saved: hours,
          // The draft is reset to what the server said: a reload is how a user
          // discards their edits.
          draft: hours.wholeWeek,
          clearFailure: true,
        ),
      );
    } on ApiFailure catch (failure) {
      emit(
        state.copyWith(
          status: silent && !state.saved.isEmpty
              ? HoursStatus.ready
              : HoursStatus.failure,
          failure: failure,
        ),
      );
    }
  }

  void setClosed(int weekday, bool closed) => _edit(
    weekday,
    (day) => day.copyWith(isClosed: closed),
  );

  void setOpensAt(int weekday, String time) =>
      _edit(weekday, (day) => day.copyWith(opensAt: time, isClosed: false));

  void setClosesAt(int weekday, String time) =>
      _edit(weekday, (day) => day.copyWith(closesAt: time, isClosed: false));

  /// Copies one day's hours onto every other open day.
  ///
  /// Most restaurants keep one schedule with an exception or two, and setting
  /// the same pair of times seven times is the sort of tedium that produces
  /// typos.
  void applyToAll(int weekday) {
    final source = state.draft.firstWhere((d) => d.weekday == weekday);
    emit(
      state.copyWith(
        draft: [
          for (final day in state.draft)
            day.weekday == weekday
                ? day
                : day.copyWith(
                    isClosed: source.isClosed,
                    opensAt: source.opensAt,
                    closesAt: source.closesAt,
                  ),
        ],
      ),
    );
  }

  void discard() => emit(state.copyWith(draft: state.saved.wholeWeek));

  /// Sends the whole week.
  ///
  /// Returns an error message to show, or null on success.
  Future<String?> save() async {
    if (!state.canSave) return null;
    emit(state.copyWith(saving: true, clearFailure: true));

    try {
      final hours = await _repository.setWeek(state.draft);
      emit(
        state.copyWith(
          saved: hours,
          draft: hours.wholeWeek,
          saving: false,
          clearFailure: true,
        ),
      );
      return null;
    } on ApiFailure catch (failure) {
      // The draft survives: the edits are still on screen and still valid, and
      // making somebody retype a week because one field was refused would be
      // its own bug.
      emit(state.copyWith(saving: false, failure: failure));
      return failure.message;
    }
  }

  /// Clears one day back to "not configured".
  ///
  /// Distinct from closing it: a cleared day means nobody has said yet, which is
  /// what the customer-facing screen shows as blank rather than as "Closed".
  Future<String?> clear(int weekday) async {
    emit(state.copyWith(saving: true, clearFailure: true));
    try {
      await _repository.clearDay(weekday);
      await load(silent: true);
      emit(state.copyWith(saving: false));
      return null;
    } on ApiFailure catch (failure) {
      emit(state.copyWith(saving: false));
      // Already gone. Not an error worth showing — the screen and the server
      // agree on the outcome, which is all anybody wanted.
      if (failure.code == WorkingHoursErrorCodes.notSet) {
        await load(silent: true);
        return null;
      }
      return failure.message;
    }
  }

  void _edit(int weekday, DayHours Function(DayHours) change) {
    emit(
      state.copyWith(
        draft: [
          for (final day in state.draft)
            if (day.weekday == weekday) change(day) else day,
        ],
      ),
    );
  }
}
