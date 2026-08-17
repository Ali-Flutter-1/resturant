import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practice/core/network/api_failure.dart';
import 'package:practice/core/theme/app_theme.dart';
import 'package:practice/features/booking/domain/reservation_repository.dart';
import 'package:practice/features/booking/domain/venue_table.dart';
import 'package:practice/features/booking/presentation/admin_venue_screen.dart';
import 'package:practice/features/booking/presentation/venue_cubit.dart';

import 'support/auth_fixtures.dart';
import 'support/fake_venue_repository.dart';

/// Tables and the sitting schedule.
///
/// Two rules from the guide carry real consequences, and both are tested:
///
///  * **A held sitting is closed, not deleted.** Deleting or re-timing a slot a
///    customer already holds takes their table away. The API refuses; the screen
///    must not offer it either.
///  * **Restoring a table does not make it bookable.** The API clears
///    `archived_at` and stops there, so the app must say so rather than leave an
///    admin wondering why nobody can book.
void main() {
  late FakeVenueRepository repository;
  final today = DateTime(2026, 8, 17);

  setUp(() {
    repository = FakeVenueRepository();
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(390, 3000);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  });

  group('the sitting-spacing preview', () {
    test('spacing is length plus cleanup, not the hourly grid', () {
      // The guide's own worked example: 18:00, 19:45, 21:30 for 90 + 15. Most
      // people filling this form in expect 18:00, 19:00, 20:00.
      final preview = SlotPreview.from(
        firstSitting: '18:00',
        lastSitting: '21:30',
        turnMinutes: 90,
        bufferMinutes: 15,
      );
      expect(preview.starts, ['18:00', '19:45', '21:30']);
      expect(preview.perDay, 3);
      // And the last table is not free until its cleanup finishes.
      expect(preview.lastEnds, '23:15');
    });

    test('no cleanup means back-to-back sittings', () {
      final preview = SlotPreview.from(
        firstSitting: '12:00',
        lastSitting: '15:00',
        turnMinutes: 60,
        bufferMinutes: 0,
      );
      expect(preview.starts, ['12:00', '13:00', '14:00', '15:00']);
      expect(preview.lastEnds, '16:00');
    });

    test('a last time before the first produces nothing', () {
      final preview = SlotPreview.from(
        firstSitting: '21:00',
        lastSitting: '18:00',
        turnMinutes: 90,
        bufferMinutes: 0,
      );
      expect(preview.starts, isEmpty);
      // The generate button reads this and stays disabled rather than sending an
      // INVALID_SITTING_RANGE.
      expect(preview.perDay, 0);
    });

    test('it cannot spin on a zero step', () {
      final preview = SlotPreview.from(
        firstSitting: '12:00',
        lastSitting: '23:00',
        turnMinutes: 0,
        bufferMinutes: 0,
      );
      expect(preview.starts, isEmpty);
    });

    test('it stops at the API ceiling of 24 a day', () {
      final preview = SlotPreview.from(
        firstSitting: '00:00',
        lastSitting: '23:45',
        turnMinutes: 15,
        bufferMinutes: 0,
      );
      expect(preview.perDay, 24);
    });
  });

  group('the models', () {
    test('a slot reports when the table is free again', () {
      final slot = FakeVenueRepository.defaultSlots.first;
      // 19:00 + 90 + 15.
      expect(slot.timeLabel, '19:00');
      expect(slot.endsLabel, '20:45');
    });

    test('a late sitting wraps past midnight rather than reading 25:15', () {
      final slot = VenueSlot(
        id: 'x',
        tableId: 't1',
        tableName: 'Late',
        serviceDate: DateTime(2026, 8, 20),
        startTime: '23:00:00',
        durationMinutes: 90,
        bufferMinutes: 15,
        pricePence: 0,
      );
      expect(slot.endsLabel, '00:45');
    });

    test('archived and hidden are different states', () {
      final tables = FakeVenueRepository.defaultTables;
      expect(tables[0].stateLabel, 'Live');
      // Exists, switched off.
      expect(tables[1].stateLabel, 'Hidden');
      expect(tables[1].isArchived, isFalse);
      // Soft-deleted.
      expect(tables[2].stateLabel, 'Archived');
    });

    test('a slot patch never carries the date or the table', () {
      // Moving a sitting means deleting it and making another; `SlotUpdate`
      // accepts neither, and sending them would be silently ignored.
      final json = FakeVenueRepository.defaultSlots.first.updateJson();
      expect(json.keys, containsAll(['duration_minutes', 'buffer_minutes']));
      expect(json.containsKey('service_date'), isFalse);
      expect(json.containsKey('table_id'), isFalse);
      expect(json.containsKey('start_time'), isFalse);
    });

    test('a schedule failure belongs beside the schedule fields', () {
      expect(VenueErrorCodes.isScheduleProblem(VenueErrorCodes.slotOverlaps),
          isTrue);
      expect(
        VenueErrorCodes.isScheduleProblem(VenueErrorCodes.tooManySittings),
        isTrue,
      );
      // Not a schedule problem: the table is in the way, not the times.
      expect(
        VenueErrorCodes.isScheduleProblem(VenueErrorCodes.tableHasBookings),
        isFalse,
      );
    });
  });

  group('the cubit', () {
    test('loads tables and a month of sittings', () async {
      final cubit = VenueCubit(repository: repository, today: today);
      await cubit.load();

      expect(cubit.state.status, VenueStatus.ready);
      // Archived tables are hidden by default — they are history, not room to
      // plan with.
      expect(repository.lastIncludeArchived, isFalse);
      expect(cubit.state.tables, hasLength(2));
      expect(cubit.state.from, today);
      expect(cubit.state.to, today.add(const Duration(days: 30)));
      await cubit.close();
    });

    test('archived tables appear only when asked for', () async {
      final cubit = VenueCubit(repository: repository, today: today);
      await cubit.load();

      await cubit.showArchived(true);
      expect(repository.lastIncludeArchived, isTrue);
      expect(cubit.state.tables, hasLength(3));
      // `liveTables` still excludes them, which is what the sitting filters and
      // the generator offer.
      expect(cubit.state.liveTables, hasLength(2));
      await cubit.close();
    });

    test('sittings group by day in service order', () async {
      final cubit = VenueCubit(repository: repository, today: today);
      await cubit.load();

      final days = cubit.state.byDay;
      expect(days.keys, hasLength(1));
      expect(
        days.values.first.map((s) => s.timeLabel),
        ['19:00', '20:45'],
      );
      await cubit.close();
    });

    test('creating a table sends only the fields the API accepts', () async {
      final cubit = VenueCubit(repository: repository, today: today);
      await cubit.load();

      final error = await cubit.saveTable(
        const VenueTable(
          id: '',
          name: '  Terrace 2  ',
          seats: 6,
          area: TableArea.outdoor,
          bookingPricePence: 0,
        ),
      );

      expect(error, isNull);
      expect(repository.lastTableCreate, {
        'name': 'Terrace 2',
        'seats': 6,
        'area': 'outdoor',
        'booking_price_pence': 0,
        'sort_order': 0,
        'is_active': true,
      });
      await cubit.close();
    });

    test('hiding a table patches only is_active', () async {
      final cubit = VenueCubit(repository: repository, today: today);
      await cubit.load();

      await cubit.setTableActive('t1', false);
      // A PATCH that resent every field would overwrite whatever another admin
      // changed in between.
      expect(repository.lastTablePatch, {'is_active': false});
      await cubit.close();
    });

    test('restoring a table leaves it hidden', () async {
      final cubit = VenueCubit(repository: repository, today: today);
      await cubit.showArchived(true);

      final error = await cubit.restoreTable('t3');
      expect(error, isNull);
      expect(repository.restoredId, 't3');

      final restored = cubit.state.tables.firstWhere((t) => t.id == 't3');
      expect(restored.isArchived, isFalse);
      // Still not bookable — the API leaves that as a second decision, and the
      // screen says so.
      expect(restored.isActive, isFalse);
      await cubit.close();
    });

    test('a table with bookings cannot be archived', () async {
      final cubit = VenueCubit(repository: repository, today: today);
      await cubit.load();
      repository.writeFailure = const ApiFailure(
        kind: ApiFailureKind.conflict,
        message: 'That table has upcoming bookings.',
        code: VenueErrorCodes.tableHasBookings,
      );

      final error = await cubit.archiveTable('t1');
      expect(error, 'That table has upcoming bookings.');
      expect(cubit.state.busyIds, isEmpty);
      await cubit.close();
    });

    test('closing a held sitting is allowed', () async {
      final cubit = VenueCubit(repository: repository, today: today);
      await cubit.load();

      // The one change a booked slot accepts: it stops further sales and leaves
      // the existing reservation alone.
      final error = await cubit.setSlotActive('s2', false);
      expect(error, isNull);
      expect(repository.lastSlotPatch, {'is_active': false});
      await cubit.close();
    });

    test('an overlap is reported in the API\'s own words', () async {
      final cubit = VenueCubit(repository: repository, today: today);
      await cubit.load();
      repository.writeFailure = const ApiFailure(
        kind: ApiFailureKind.conflict,
        message: 'That sitting overlaps another on the same table.',
        code: VenueErrorCodes.slotOverlaps,
      );

      final error = await cubit.retimeSlot(
        's1',
        durationMinutes: 240,
        bufferMinutes: 30,
      );
      expect(error, 'That sitting overlaps another on the same table.');
      await cubit.close();
    });

    test('generation omits empty tables and weekdays', () async {
      final cubit = VenueCubit(repository: repository, today: today);
      await cubit.load();

      final (result, error) = await cubit.generate(
        fromDate: today,
        toDate: today.add(const Duration(days: 30)),
        firstSitting: '18:00',
        lastSitting: '21:30',
        turnMinutes: 90,
        bufferMinutes: 15,
      );

      expect(error, isNull);
      // Empty means "every active table" and "every day" to the API; sending
      // `[]` would mean the opposite.
      expect(repository.lastGenerate!['table_ids'], isEmpty);
      expect(repository.lastGenerate!['weekdays'], isEmpty);
      // Both figures reported: "created 0, skipped 84" is the difference between
      // nothing happening and it already being done.
      expect(result!.created, 84);
      expect(result.skipped, 6);
      await cubit.close();
    });

    test('a failed generation reports rather than throwing', () async {
      final cubit = VenueCubit(repository: repository, today: today);
      await cubit.load();
      repository.writeFailure = const ApiFailure(
        kind: ApiFailureKind.invalid,
        message: 'That range is longer than 180 days.',
        code: VenueErrorCodes.dateRangeTooLong,
      );

      final (result, error) = await cubit.generate(
        fromDate: today,
        toDate: today.add(const Duration(days: 400)),
        firstSitting: '18:00',
        lastSitting: '21:30',
        turnMinutes: 90,
        bufferMinutes: 15,
      );

      expect(result, isNull);
      expect(error, 'That range is longer than 180 days.');
      expect(cubit.state.busyIds, isEmpty);
      await cubit.close();
    });
  });

  group('the screen', () {
    Widget wrap() => BlocProvider(
      create: (_) => AuthFixtures.cubit(AuthFixtures.admin),
      child: RepositoryProvider<VenueRepository>.value(
        value: repository,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const AdminVenueScreen(),
        ),
      ),
    );

    testWidgets('lists the room with each table\'s state', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('Window Table 1'), findsOneWidget);
      // The app's status chips upper-case their label.
      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text('HIDDEN'), findsOneWidget);
      expect(find.text('4 seats'), findsOneWidget);
    });

    testWidgets('a held sitting offers closing but not deleting', (
      tester,
    ) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sittings'));
      await tester.pumpAndSettle();

      // The booked 20:45 slot is the second row.
      await tester.tap(find.byIcon(Icons.more_vert).last);
      await tester.pumpAndSettle();

      expect(find.text('Close for sale'), findsOneWidget);
      // Deleting it would take a table from somebody already told they have it.
      expect(find.text('Delete'), findsNothing);
    });

    testWidgets('an unheld sitting can be deleted', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sittings'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();

      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('the generator previews the real start times', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sittings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate sittings'));
      await tester.pumpAndSettle();

      // The spacing rule, shown before anything is sent.
      expect(find.text('18:00  ·  19:45  ·  21:30'), findsOneWidget);
      expect(find.textContaining('free again at 23:15'), findsOneWidget);
      // And the field most often misread is labelled.
      expect(find.textContaining('latest sitting to *start*'), findsOneWidget);
    });
  });
}
