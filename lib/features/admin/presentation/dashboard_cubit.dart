import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_failure.dart';
import '../domain/dashboard_repository.dart';
import '../domain/dashboard_summary.dart';

enum DashboardStatus { loading, ready, failure }

class DashboardState extends Equatable {
  const DashboardState({
    this.status = DashboardStatus.loading,
    this.summary,
    this.failure,
    this.refreshing = false,
  });

  final DashboardStatus status;

  /// The last figures the server gave. Kept through a failed refresh — see the
  /// cubit's note.
  final DashboardSummary? summary;

  final ApiFailure? failure;

  /// True while a refresh is in flight over numbers already on screen.
  final bool refreshing;

  /// Whether the signed-in user is simply not allowed here. A demoted admin
  /// hits this mid-session, and it is not something a retry can fix.
  bool get isForbidden => failure?.kind == ApiFailureKind.forbidden;

  /// A failed refresh over figures that are still worth reading.
  bool get isStale => summary != null && failure != null;

  DashboardState copyWith({
    DashboardStatus? status,
    DashboardSummary? summary,
    ApiFailure? failure,
    bool? refreshing,
    bool clearFailure = false,
  }) {
    return DashboardState(
      status: status ?? this.status,
      summary: summary ?? this.summary,
      failure: clearFailure ? null : (failure ?? this.failure),
      refreshing: refreshing ?? this.refreshing,
    );
  }

  @override
  List<Object?> get props => [status, summary, failure, refreshing];
}

/// The admin landing screen.
///
/// Three rules from the guide shape this:
///
///  * **Never show zeros on failure.** Zero revenue is a real, meaningful
///    number — a quiet Tuesday — and must not be confused with "could not
///    load". A failed refresh keeps the previous figures and raises a banner.
///  * **No polling.** Staff push notifications announce new orders; the screen
///    refreshes when it is looked at, which is enough for numbers that move
///    slowly and costs nothing when it is not.
///  * **403 is not a retry.** A staff account, or an admin demoted mid-session,
///    is told and sent away rather than offered a button that cannot work.
class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit({required DashboardRepository repository})
    : _repository = repository,
      super(const DashboardState());

  final DashboardRepository _repository;

  Future<void> load() async {
    // A reload over existing figures keeps them on screen with a spinner rather
    // than blanking — the numbers change slowly, and a flash of empty tiles
    // reads as data loss.
    emit(
      state.copyWith(
        status: state.summary == null
            ? DashboardStatus.loading
            : DashboardStatus.ready,
        refreshing: state.summary != null,
        clearFailure: true,
      ),
    );

    try {
      emit(
        state.copyWith(
          status: DashboardStatus.ready,
          summary: await _repository.summary(),
          refreshing: false,
          clearFailure: true,
        ),
      );
    } on ApiFailure catch (failure) {
      emit(
        state.copyWith(
          // Figures already on screen stay there, with a banner over them.
          status: state.summary != null
              ? DashboardStatus.ready
              : DashboardStatus.failure,
          failure: failure,
          refreshing: false,
        ),
      );
    }
  }
}
