import '../../../core/network/api_client.dart';
import '../../../core/network/api_constants.dart';
import '../domain/working_hours.dart';
import '../domain/working_hours_repository.dart';

class ApiWorkingHoursRepository implements WorkingHoursRepository {
  ApiWorkingHoursRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  @override
  Future<WorkingHours> hours() async =>
      WorkingHours.fromList(await _client.list(ApiConstants.workingHours));

  @override
  Future<WorkingHours> adminHours() async =>
      WorkingHours.fromList(await _client.list(ApiConstants.adminWorkingHours));

  @override
  Future<WorkingHours> setWeek(List<DayHours> days) async {
    final rows = await _client.list(
      ApiConstants.adminWorkingHours,
      method: 'PUT',
      body: {
        'days': [for (final day in days) day.toJson()],
      },
    );
    return WorkingHours.fromList(rows);
  }

  @override
  Future<DayHours> setDay(DayHours day) async {
    final data = await _client.object(
      ApiConstants.adminWorkingHoursDay(day.weekday),
      method: 'PUT',
      // The weekday in the path is authoritative, but it goes in the body too —
      // a request that reads unambiguously on its own is worth two extra bytes.
      body: day.toJson(),
    );
    return DayHours.fromJson(data);
  }

  @override
  Future<void> clearDay(int weekday) async {
    // `send`, not `object`: this route answers `data: null`, and asking for an
    // object would report a successful clear as a decode failure.
    await _client.send(
      ApiConstants.adminWorkingHoursDay(weekday),
      method: 'DELETE',
    );
  }
}
