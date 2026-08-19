import '../../../core/network/api_client.dart';
import '../../../core/network/api_constants.dart';
import '../domain/dashboard_repository.dart';
import '../domain/dashboard_summary.dart';

class ApiDashboardRepository implements DashboardRepository {
  ApiDashboardRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  @override
  Future<DashboardSummary> summary() async =>
      DashboardSummary.fromJson(await _client.object(ApiConstants.adminDashboard));
}
