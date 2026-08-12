import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practice/core/network/api_failure.dart';
import 'package:practice/core/theme/app_theme.dart';
import 'package:practice/features/admin/domain/admin_contact_repository.dart';
import 'package:practice/features/admin/domain/contact_message.dart';
import 'package:practice/features/admin/presentation/admin_contact_cubit.dart';
import 'package:practice/features/admin/presentation/admin_contact_screen.dart';
import 'package:practice/shared/widgets/app_chip.dart';
import 'package:practice/shared/widgets/dish_list_skeleton.dart';
import 'package:practice/shared/widgets/skeleton.dart';

import 'support/fake_admin_contact_repository.dart';

/// The contact inbox.
///
/// It exists because the Contact Us form now reaches the server, and a form
/// whose messages nobody can read is worse than no form — it promises an answer.
void main() {
  late FakeAdminContactRepository repository;

  setUp(() {
    repository = FakeAdminContactRepository();
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(390, 1600);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  });

  Widget wrap() => RepositoryProvider<AdminContactRepository>.value(
    value: repository,
    child: MaterialApp(theme: AppTheme.light, home: const AdminContactScreen()),
  );

  group('ContactStatus', () {
    test('maps the API spellings', () {
      expect(ContactStatus.fromApi('new'), ContactStatus.newMessage);
      expect(ContactStatus.fromApi('in_progress'), ContactStatus.inProgress);
      expect(ContactStatus.fromApi('resolved'), ContactStatus.resolved);
      expect(ContactStatus.fromApi('closed'), ContactStatus.closed);
    });

    test('an unknown status does not blank the inbox', () {
      expect(ContactStatus.fromApi('escalated'), ContactStatus.newMessage);
      expect(ContactStatus.fromApi(null), ContactStatus.newMessage);
    });

    test('only new and in-progress still want attention', () {
      expect(ContactStatus.newMessage.isOpen, isTrue);
      expect(ContactStatus.inProgress.isOpen, isTrue);
      expect(ContactStatus.resolved.isOpen, isFalse);
      expect(ContactStatus.closed.isOpen, isFalse);
    });
  });

  group('ContactMessage.fromJson', () {
    test('reads the admin shape', () {
      final message = ContactMessage.fromJson({
        'id': 'm1',
        'name': 'Ali',
        'email': 'ali@example.com',
        'phone': '  ',
        'subject': 'Catering',
        'message': 'Do you cater?',
        'status': 'in_progress',
        'admin_note': 'Called back.',
        'created_at': '2026-08-11T14:30:00Z',
      });

      expect(message.status, ContactStatus.inProgress);
      expect(message.subject, 'Catering');
      expect(message.adminNote, 'Called back.');
      // Whitespace-only optionals are absent, not a blank line on the screen.
      expect(message.phone, isNull);
      expect(message.createdAt, isNotNull);
    });

    test('falls back to a heading when no subject was given', () {
      final message = ContactMessage.fromJson({
        'id': 'm1',
        'name': 'Ali',
        'email': 'a@b.com',
        'message': 'Hello',
        'status': 'new',
      });
      expect(message.heading, 'No subject');
    });
  });

  group('filtering', () {
    test('refetches from the API rather than trimming what is loaded', () async {
      final cubit = AdminContactCubit(repository: repository);
      await cubit.load();
      expect(cubit.state.messages, hasLength(2));

      await cubit.filterBy(ContactStatus.resolved);

      // Asked for, not filtered locally: an inbox grows without bound, so a
      // filtered view has to be complete rather than being whatever happened to
      // be on the first page.
      expect(repository.lastFilter, ContactStatus.resolved);
      expect(cubit.state.messages, hasLength(1));
      expect(cubit.state.messages.single.name, 'Priya Raj');
    });

    test('clearing the filter asks for everything again', () async {
      final cubit = AdminContactCubit(repository: repository);
      await cubit.load();
      await cubit.filterBy(ContactStatus.resolved);

      await cubit.filterBy(null);

      expect(repository.lastFilter, isNull);
      expect(cubit.state.messages, hasLength(2));
    });

    test('counts the ones still wanting attention', () async {
      final cubit = AdminContactCubit(repository: repository);
      await cubit.load();

      // One new, one resolved.
      expect(cubit.state.openCount, 1);
    });
  });

  group('inbox', () {
    testWidgets('lists messages newest first with their status', (
      tester,
    ) async {
      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Ali Hassan'), findsOne);
      expect(find.text('Catering for 20'), findsOne);
      expect(find.text('New'), findsWidgets);
      expect(find.text('Resolved'), findsWidgets);
    });

    testWidgets('offers every status as a filter', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(seconds: 2));

      expect(find.widgetWithText(SelectableChip, 'All'), findsOne);
      // Only the chips within the viewport are built — the strip scrolls — so
      // this checks the first two rather than asserting the whole set exists in
      // the tree.
      expect(
        find.widgetWithText(SelectableChip, ContactStatus.newMessage.label),
        findsWidgets,
      );
      expect(
        find.widgetWithText(SelectableChip, ContactStatus.inProgress.label),
        findsWidgets,
      );
    });

    testWidgets('opening a message shows it in full', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(seconds: 2));

      await tester.tap(find.text('Ali Hassan'));
      await tester.pumpAndSettle();

      expect(find.text('Do you cater for office lunches?'), findsWidgets);
      expect(find.text('ali@example.com'), findsWidgets);
      expect(find.text('+44 7700 900123'), findsWidgets);
      expect(find.text('The sender never sees this'), findsOne);
    });

    testWidgets('choosing a status stages it and does not save', (
      tester,
    ) async {
      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(seconds: 2));

      await tester.tap(find.text('Ali Hassan'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('In progress').last);
      await tester.pumpAndSettle();

      // Tapping a chip to see what it says must not commit it — the sheet has a
      // save button, so nothing in it should save itself.
      expect(repository.lastUpdate, isNull);
      expect(find.text('Not saved yet.'), findsOne);
    });

    testWidgets('one save sends the staged status', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(seconds: 2));

      await tester.tap(find.text('Ali Hassan'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('In progress').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(repository.lastUpdate?['id'], 'm1');
      expect(repository.lastUpdate?['status'], 'in_progress');
      // The note was untouched, so it is not sent: rewriting it would wipe a
      // colleague's note when the admin only changed the status.
      expect(repository.lastUpdate?['admin_note'], isNull);
      expect(find.text('Message updated.'), findsOne);
    });

    testWidgets('a status and a note go in one request', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(seconds: 2));

      await tester.tap(find.text('Ali Hassan'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Resolved').last);
      await tester.enterText(
        find.widgetWithText(
          TextField,
          'Who is handling this, and what was agreed?',
        ),
        'Quoted £180.',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(repository.lastUpdate?['status'], 'resolved');
      expect(repository.lastUpdate?['admin_note'], 'Quoted £180.');
    });

    testWidgets('saving is offered only once something has changed', (
      tester,
    ) async {
      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(seconds: 2));

      await tester.tap(find.text('Ali Hassan'));
      await tester.pumpAndSettle();

      // Nothing touched: the button says plainly that there is nothing to save.
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save changes'),
      );
      expect(button.onPressed, isNull);
      expect(find.text('Not saved yet.'), findsNothing);
    });

    testWidgets('an existing note is loaded into the field', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(seconds: 2));

      await tester.tap(find.text('Priya Raj'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Answered by phone.'), findsOne);
    });

    testWidgets('a refused write says why and changes nothing', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(seconds: 2));

      await tester.tap(find.text('Ali Hassan'));
      await tester.pumpAndSettle();

      repository.failure = const ApiFailure(
        kind: ApiFailureKind.server,
        message: 'Could not save that just now.',
      );
      await tester.tap(find.text('Closed').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(find.text('Could not save that just now.'), findsOne);
      // The sheet stays open with the choice intact: a refused save must not
      // cost the admin what they picked.
      expect(find.text('Save changes'), findsOne);
      expect(find.text('Not saved yet.'), findsOne);
    });

    testWidgets('shows the API message when the inbox will not load', (
      tester,
    ) async {
      repository.failure = ApiFailure.offline;
      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(seconds: 2));

      expect(find.text(ApiFailure.offline.message), findsOne);
    });

    testWidgets('an empty inbox says where messages come from', (tester) async {
      await tester.pumpWidget(
        RepositoryProvider<AdminContactRepository>.value(
          value: FakeAdminContactRepository(messages: []),
          child: MaterialApp(
            theme: AppTheme.light,
            home: const AdminContactScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('No messages'), findsOne);
      expect(
        find.text('Messages from the Contact Us form arrive here.'),
        findsOne,
      );
    });
  });

  group('search', () {
    testWidgets('narrows the list as you type', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Ali Hassan'), findsOne);
      expect(find.text('Priya Raj'), findsOne);

      await tester.enterText(
        find.widgetWithText(TextField, 'Search name, subject or message...'),
        'priya',
      );
      await tester.pumpAndSettle();

      expect(find.text('Ali Hassan'), findsNothing);
      expect(find.text('Priya Raj'), findsOne);
    });

    test('matches the sender, the subject and the message', () async {
      final cubit = AdminContactCubit(repository: repository);
      await cubit.load();

      // Somebody hunting for a message may remember a word from any of the
      // three.
      cubit.search('hassan');
      expect(cubit.state.visible.single.id, 'm1');

      cubit.search('catering');
      expect(cubit.state.visible.single.id, 'm1');

      cubit.search('gluten');
      expect(cubit.state.visible.single.id, 'm2');

      cubit.search('  ');
      expect(cubit.state.visible, hasLength(2));
    });

    testWidgets('says so when nothing matches', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump(const Duration(seconds: 2));

      await tester.enterText(
        find.widgetWithText(TextField, 'Search name, subject or message...'),
        'zzzz',
      );
      await tester.pumpAndSettle();

      // Distinct from an empty inbox, which means something else entirely.
      expect(find.text('No matches'), findsOne);
      expect(find.text('No messages'), findsNothing);
    });
  });

  group('loading', () {
    testWidgets('shows message-shaped placeholders, not dish-shaped ones', (
      tester,
    ) async {
      await tester.pumpWidget(
        RepositoryProvider<AdminContactRepository>.value(
          value: FakeAdminContactRepository(
            delay: const Duration(milliseconds: 300),
          ),
          child: MaterialApp(
            theme: AppTheme.light,
            home: const AdminContactScreen(),
          ),
        ),
      );
      await tester.pump();

      // The dish skeleton stood in for a photograph and a price, so the page
      // still jumped when messages arrived.
      expect(find.byType(MessageListSkeleton), findsOne);
      expect(find.byType(DishListSkeleton), findsNothing);

      // The search box and the status chips are real and usable while it loads —
      // a reload used to take them away and put them back, so the filter you had
      // just tapped vanished while its own request was in flight.
      expect(
        find.widgetWithText(TextField, 'Search name, subject or message...'),
        findsOne,
      );
      expect(find.widgetWithText(SelectableChip, 'All'), findsOne);

      // And the placeholder goes away when the messages land.
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(MessageListSkeleton), findsNothing);
      expect(find.text('Ali Hassan'), findsOne);
    });
  });
}
