import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practice/core/network/api_failure.dart';
import 'package:practice/core/theme/app_theme.dart';
import 'package:practice/features/admin/domain/dashboard_repository.dart';
import 'package:practice/features/admin/domain/dashboard_summary.dart';
import 'package:practice/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:practice/features/admin/presentation/dashboard_cubit.dart';
import 'package:practice/features/notifications/domain/notification_repository.dart';

import 'support/auth_fixtures.dart';
import 'support/fake_dashboard_repository.dart';
import 'support/fake_notification_repository.dart';

/// The admin dashboard.
///
/// The rule that matters most: **zero revenue is a real number**. A quiet
/// Tuesday and a failed request must never look the same, so a failure keeps the
/// previous figures and says they are stale rather than rendering zeros.
void main() {
  late FakeDashboardRepository repository;

  setUp(() {
    repository = FakeDashboardRepository();
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(390, 2000);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  });

  group('money', () {
    test('integer pence render as pounds', () {
      expect(formatPence(14250), '£142.50');
      expect(formatPence(0), '£0.00');
      expect(formatPence(5), '£0.05');
      // Grouped, or £4,310.25 reads as £431025.
      expect(formatPence(431025), '£4,310.25');
      expect(formatPence(100000000), '£1,000,000.00');
    });
  });

  group('parsing', () {
    test('a missing section does not take the screen down', () {
      // The guide's own model casts with `as int` and would throw here. A
      // dashboard that will not render is worse than one showing a zero.
      final summary = DashboardSummary.fromJson(const {});
      expect(summary.revenue.todayPence, 0);
      expect(summary.orders.today, 0);
      expect(summary.attention.isClear, isTrue);
    });

    test('the open queue totals its four stages', () {
      const open = OpenOrders(
        placed: 1,
        preparing: 2,
        ready: 3,
        outForDelivery: 4,
      );
      expect(open.total, 10);
    });

    test('the worked example from the guide parses exactly', () {
      final summary = DashboardSummary.fromJson(const {
        'revenue': {
          'today_pence': 14250,
          'this_week_pence': 108600,
          'this_month_pence': 431025,
        },
        'orders': {
          'today': 18,
          'open': {
            'placed': 1,
            'preparing': 1,
            'ready': 1,
            'out_for_delivery': 0,
          },
        },
        'attention': {'pending_bookings': 2, 'new_messages': 1},
      });

      expect(formatPence(summary.revenue.todayPence), '£142.50');
      expect(summary.orders.today, 18);
      expect(summary.orders.open.total, 3);
      expect(summary.attention.pendingBookings, 2);
    });
  });

  group('the cubit', () {
    test('one request fills the whole screen', () async {
      final cubit = DashboardCubit(repository: repository);
      await cubit.load();

      // The guide is explicit: exactly one call, no pagination, no polling.
      expect(repository.calls, 1);
      expect(cubit.state.status, DashboardStatus.ready);
      expect(cubit.state.summary!.orders.today, 18);
      await cubit.close();
    });

    test('a failed refresh keeps the figures and marks them stale', () async {
      final cubit = DashboardCubit(repository: repository);
      await cubit.load();

      repository.failure = ApiFailure.offline;
      await cubit.load();

      // Never zeros. Zero revenue is a real, meaningful value.
      expect(cubit.state.summary!.revenue.todayPence, 14250);
      expect(cubit.state.isStale, isTrue);
      expect(cubit.state.status, DashboardStatus.ready);
      await cubit.close();
    });

    test('a first-load failure is a failure, not empty tiles', () async {
      final cubit = DashboardCubit(repository: repository);
      repository.failure = ApiFailure.offline;
      await cubit.load();

      expect(cubit.state.status, DashboardStatus.failure);
      expect(cubit.state.summary, isNull);
      await cubit.close();
    });

    test('403 is recognised as a permission problem, not a retry', () async {
      final cubit = DashboardCubit(repository: repository);
      repository.failure = const ApiFailure(
        kind: ApiFailureKind.forbidden,
        message: "You don't have access to this area.",
        code: 'PERMISSION_DENIED',
      );
      await cubit.load();

      // A staff account, or an admin demoted mid-session. Signing in again
      // produces the same role and the same refusal.
      expect(cubit.state.isForbidden, isTrue);
      await cubit.close();
    });
  });

  group('the screen', () {
    Widget wrap() => BlocProvider(
      create: (_) => AuthFixtures.cubit(AuthFixtures.admin),
      child: MultiRepositoryProvider(
        providers: [
          RepositoryProvider<DashboardRepository>.value(value: repository),
          RepositoryProvider<NotificationRepository>(
            create: (_) => FakeNotificationRepository(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const AdminDashboardScreen(),
        ),
      ),
    );

    testWidgets('shows takings, the queue and the to-do list', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('£142.50'), findsOneWidget);
      expect(find.text('£1,086.00'), findsOneWidget);
      expect(find.text('£4,310.25'), findsOneWidget);
      expect(find.text('18 orders today'), findsOneWidget);
      expect(find.text('3 open right now'), findsOneWidget);
      expect(find.text('2 booking requests'), findsOneWidget);
      expect(find.text('1 new message'), findsOneWidget);
    });

    testWidgets('a clear to-do list reads as done, not as empty', (
      tester,
    ) async {
      repository = FakeDashboardRepository(
        result: const DashboardSummary(
          revenue: RevenueTiles(),
          orders: OrdersSummary(),
          attention: AttentionSummary(),
        ),
      );
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.textContaining('Nothing waiting'), findsOneWidget);
      // A genuinely quiet day still shows real zeros rather than an error.
      expect(find.text('£0.00'), findsNWidgets(3));
      expect(find.text('Nothing open right now'), findsOneWidget);
    });

    testWidgets('a staff account is told, not offered a retry', (tester) async {
      repository.failure = const ApiFailure(
        kind: ApiFailureKind.forbidden,
        message: "You don't have access to this area.",
        code: 'PERMISSION_DENIED',
      );
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('Takings are admin only'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });
  });
}
