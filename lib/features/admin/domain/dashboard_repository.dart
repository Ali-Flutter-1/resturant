import 'dashboard_summary.dart';

/// The admin landing screen.
///
/// One endpoint, one round trip. Admin only — staff and customers get a 403,
/// because takings are the owner's business.
abstract interface class DashboardRepository {
  Future<DashboardSummary> summary();
}
