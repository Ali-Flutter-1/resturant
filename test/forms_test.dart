import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:practice/core/theme/app_theme.dart';
import 'package:practice/features/about/presentation/about_contact_screen.dart';
import 'package:practice/features/booking/presentation/book_table_screen.dart';
import 'package:practice/features/cart/cart_cubit.dart';
import 'package:practice/features/checkout/presentation/checkout_screen.dart';
import 'package:practice/features/contact/domain/contact_repository.dart';
import 'package:practice/core/network/api_failure.dart';

import 'support/auth_fixtures.dart';
import 'support/fake_contact_repository.dart';

/// Forms refuse bad input and say why. Each of these was a no-op button
/// before, so the tests exist to keep them honest.
void main() {
  late CartCubit cart;
  late FakeContactRepository contact;

  Widget wrap(Widget home) {
    cart = CartCubit()..add(2);
    contact = FakeContactRepository();
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthFixtures.cubit(AuthFixtures.customer)),
        BlocProvider.value(value: cart),
      ],
      child: RepositoryProvider<ContactRepository>.value(
        value: contact,
        child: MaterialApp(theme: AppTheme.light, home: home),
      ),
    );
  }

  Future<void> pumpForm(WidgetTester tester, Widget home) async {
    await tester.pumpWidget(wrap(home));
    await tester.pumpAndSettle();
  }

  /// Scrolls a control into view, then taps it.
  ///
  /// `ListView(children: ...)` still instantiates its children lazily, so a
  /// control below the fold is genuinely absent from the tree and cannot be
  /// found until scrolled to. The scrollable is named explicitly because
  /// these screens nest horizontal strips inside the vertical list, which
  /// would otherwise make the lookup ambiguous.
  Future<void> tapAt(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('Book a Table', () {
    testWidgets('refuses to book without a time', (tester) async {
      await pumpForm(tester, const BookTableScreen());

      await tapAt(tester, find.text('Confirm Reservation'));

      expect(find.text('Choose a time for your reservation.'), findsOneWidget);
    });

    testWidgets('party size steps up and down within bounds', (tester) async {
      await pumpForm(tester, const BookTableScreen());

      expect(find.text('2'), findsOneWidget);

      await tapAt(tester, find.byIcon(Icons.add));
      expect(find.text('3'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.remove));
      await tapAt(tester, find.byIcon(Icons.remove));
      expect(find.text('1'), findsOneWidget);

      // Floor is one guest — a table for nobody is not a booking.
      await tapAt(tester, find.byIcon(Icons.remove));
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('a seating preference can be chosen', (tester) async {
      await pumpForm(tester, const BookTableScreen());

      await tapAt(tester, find.text('Terrace'));

      expect(find.text('Terrace'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Checkout', () {
    testWidgets('choosing Collection hides the delivery address', (
      tester,
    ) async {
      await pumpForm(tester, const CheckoutScreen());

      expect(find.text('DELIVERY ADDRESS'), findsOneWidget);

      await tapAt(tester, find.text('Collection'));

      // No address to capture when the customer is coming to collect.
      expect(find.text('DELIVERY ADDRESS'), findsNothing);
    });

    testWidgets('switching back to Delivery restores the address', (
      tester,
    ) async {
      await pumpForm(tester, const CheckoutScreen());

      await tapAt(tester, find.text('Collection'));
      await tapAt(tester, find.text('Delivery'));

      expect(find.text('DELIVERY ADDRESS'), findsOneWidget);
    });

    testWidgets('Schedule reveals a time chooser', (tester) async {
      await pumpForm(tester, const CheckoutScreen());

      expect(find.text('Choose a time'), findsNothing);

      await tapAt(tester, find.text('Schedule'));

      expect(find.text('Choose a time'), findsOneWidget);
    });

    testWidgets('scheduling without a time blocks the order', (tester) async {
      await pumpForm(tester, const CheckoutScreen());

      await tapAt(tester, find.text('Schedule'));

      await tapAt(tester, find.textContaining('Place Order'));

      expect(find.text('Pick a delivery time first.'), findsOneWidget);
      expect(cart.state, 2, reason: 'a blocked order must not clear the cart');
    });

    testWidgets('placing an ASAP order empties the cart', (tester) async {
      await pumpForm(tester, const CheckoutScreen());

      await tapAt(tester, find.textContaining('Place Order'));

      expect(cart.state, 0);
      expect(find.textContaining('Order placed'), findsOneWidget);
    });

    testWidgets('payment method can be switched', (tester) async {
      await pumpForm(tester, const CheckoutScreen());

      await tapAt(tester, find.text('Cash on Delivery'));

      expect(tester.takeException(), isNull);
    });
  });

  group('Contact form', () {
    Future<void> openForm(WidgetTester tester) async {
      await pumpForm(tester, const AboutContactScreen());
    }

    testWidgets('requires a name and a message', (tester) async {
      await openForm(tester);

      // The form prefills a signed-in person's name and email; emptying the
      // name is what exercises the refusal.
      await tester.enterText(find.widgetWithText(TextField, 'Your name'), '');
      await tapAt(tester, find.text('Send Message'));

      expect(
        find.text('Add your name and a message so we can reply.'),
        findsOneWidget,
      );
      // Nothing left the device.
      expect(contact.sendCalls, 0);
    });

    testWidgets('rejects an incomplete email', (tester) async {
      await openForm(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Your name'),
        'Sam',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Email address'),
        'sam@nowhere',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'How can we help?'),
        'Do you cater?',
      );

      await tapAt(tester, find.text('Send Message'));

      expect(find.text('That email address looks incomplete.'), findsOneWidget);
      expect(contact.sendCalls, 0);
    });

    testWidgets('a complete message is accepted and clears the form', (
      tester,
    ) async {
      await openForm(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Your name'),
        'Sam',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Email address'),
        'sam@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'How can we help?'),
        'Do you cater?',
      );

      await tapAt(tester, find.text('Send Message'));
      await tester.pumpAndSettle();

      // It really went. This button used to clear the form and claim success
      // with no request behind it at all.
      expect(contact.sendCalls, 1);
      expect(contact.lastSend?['name'], 'Sam');
      expect(contact.lastSend?['email'], 'sam@example.com');
      expect(contact.lastSend?['message'], 'Do you cater?');
      // Blank optional fields are omitted rather than sent as empty strings,
      // which the API would store as a subject of "".
      expect(contact.lastSend?['phone'], isNull);
      expect(contact.lastSend?['subject'], isNull);

      expect(find.textContaining('Message sent'), findsOneWidget);
      // The message is cleared but the name is not: it is almost certainly
      // right for a second message, and re-typing it is what stops people
      // sending one.
      expect(find.text('Do you cater?'), findsNothing);
      expect(find.widgetWithText(TextField, 'Sam'), findsOneWidget);
    });

    testWidgets('a failed send keeps the message and says why', (tester) async {
      await openForm(tester);
      contact.failure = const ApiFailure(
        kind: ApiFailureKind.server,
        message: 'We could not send that just now. Please try again.',
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Your name'),
        'Sam',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'How can we help?'),
        'Do you cater?',
      );
      await tapAt(tester, find.text('Send Message'));
      await tester.pumpAndSettle();

      expect(
        find.text('We could not send that just now. Please try again.'),
        findsOneWidget,
      );
      // A failed send must not cost the user what they wrote.
      expect(find.text('Do you cater?'), findsOneWidget);
    });

    testWidgets('prefills a signed-in person rather than asking again', (
      tester,
    ) async {
      await openForm(tester);

      // Scoped to the inputs: the account panel further down the screen shows
      // the same name and email, so an unscoped finder matches twice.
      expect(find.widgetWithText(TextField, 'Test Customer'), findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'customer@example.com'),
        findsOneWidget,
      );
    });
  });
}
