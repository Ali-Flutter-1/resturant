import 'package:practice/core/network/api_failure.dart';
import 'package:practice/features/admin/domain/dashboard_repository.dart';
import 'package:practice/features/admin/domain/dashboard_summary.dart';

/// The admin dashboard, in memory.
class FakeDashboardRepository implements DashboardRepository {
  FakeDashboardRepository({DashboardSummary? result, this.delay})
    : _result = result ?? defaultSummary;

  final Duration? delay;

  /// The guide's own worked example.
  static const defaultSummary = DashboardSummary(
    revenue: RevenueTiles(
      todayPence: 14250,
      thisWeekPence: 108600,
      thisMonthPence: 431025,
    ),
    orders: OrdersSummary(
      today: 18,
      open: OpenOrders(placed: 1, preparing: 1, ready: 1),
    ),
    attention: AttentionSummary(pendingBookings: 2, newMessages: 1),
  );

  DashboardSummary _result;
  set result(DashboardSummary value) => _result = value;

  ApiFailure? failure;
  int calls = 0;

  @override
  Future<DashboardSummary> summary() async {
    calls++;
    final pause = delay;
    if (pause != null) await Future<void>.delayed(pause);
    final error = failure;
    if (error != null) throw error;
    return _result;
  }
}
