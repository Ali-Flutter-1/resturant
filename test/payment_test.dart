import 'package:flutter_test/flutter_test.dart';
import 'package:practice/core/network/api_failure.dart';
import 'package:practice/features/orders/domain/customer_order.dart';
import 'package:practice/features/orders/domain/payment_flow.dart';
import 'package:practice/features/orders/presentation/orders_cubit.dart';

import 'support/fake_order_repository.dart';

/// Card payment.
///
/// The rule everything here defends: **a closed sheet is not a payment**. The
/// app never decides that money moved — only the server, told by Worldpay's
/// webhook, can say that. Every test below is a way of getting that wrong.
void main() {
  late FakeOrderRepository repository;
  late List<String> opened;

  setUp(() {
    repository = FakeOrderRepository();
    opened = [];
  });

  PaymentFlow flowFor({CustomerPaymentStatus? settleAs}) => PaymentFlow(
    repository: repository,
    // The real schedule waits about half a minute for the webhook. The
    // behaviour under test is what happens at the end of it, not the waiting.
    pollSchedule: const [Duration.zero, Duration.zero],
    open: (url) async {
      opened.add(url);
      // Stands in for the customer doing something on Worldpay's page and the
      // webhook reaching our backend before the sheet closes.
      if (settleAs != null) repository.settlePayment('new-order', settleAs);
    },
  );

  Future<CustomerOrder> placeCardOrder() => repository.place(
    idempotencyKey: 'key-1',
    isDelivery: false,
    lines: const [],
    contactName: 'Ali',
    contactPhone: '07700 900123',
    paymentMethod: PaymentMethod.card,
  );

  group('the order model', () {
    test('a card order that is not paid still owes money', () {
      final order = CustomerOrder.fromJson(const {
        'id': '1',
        'payment_method': 'card',
        'payment_status': 'pending',
        'payment_url': 'https://hpp-sandbox.worldpay.com/x',
      });

      expect(order.isCard, isTrue);
      expect(order.needsPayment, isTrue);
      expect(order.awaitingPayment, isTrue);
    });

    test('a refunded order is not asked to pay again', () {
      final order = CustomerOrder.fromJson(const {
        'id': '1',
        'payment_method': 'card',
        'payment_status': 'refunded',
      });

      // Money moved and moved back. Showing "Pay" here would be asking for it
      // twice.
      expect(order.needsPayment, isFalse);
    });

    test('a cash order never has anything to pay online', () {
      final order = CustomerOrder.fromJson(const {
        'id': '1',
        'payment_method': 'cash',
        'payment_status': 'pending',
      });

      expect(order.needsPayment, isFalse);
      expect(order.awaitingPayment, isFalse);
    });

    test('an unpaid card order is never described as being cooked', () {
      final order = CustomerOrder.fromJson(const {
        'id': '1',
        'status': 'placed',
        'payment_method': 'card',
        'payment_status': 'pending',
      });

      // The backend holds it out of the kitchen until the webhook lands, so
      // the placed-order copy would be a lie the customer acts on.
      expect(order.statusLabel, 'Awaiting payment');
      expect(
        order.statusExplanation,
        'Complete payment to confirm your order.',
      );
      expect(order.statusExplanation, isNot(contains('kitchen')));
    });

    test('a declined card says so, and keeps the order', () {
      final order = CustomerOrder.fromJson(const {
        'id': '1',
        'status': 'placed',
        'payment_method': 'card',
        'payment_status': 'failed',
      });

      expect(order.statusLabel, 'Payment declined');
      expect(order.needsPayment, isTrue);
    });

    test('a paid card order reads like any confirmed order', () {
      final order = CustomerOrder.fromJson(const {
        'id': '1',
        'status': 'preparing',
        'payment_method': 'card',
        'payment_status': 'paid',
        'paid_at': '2026-08-20T18:30:00Z',
      });

      expect(order.needsPayment, isFalse);
      expect(order.statusLabel, 'Being prepared');
      expect(order.paidAt, isNotNull);
    });
  });

  group('the payment flow', () {
    test('opens the page the server gave and then asks the server', () async {
      final order = await placeCardOrder();
      final settled = await flowFor(
        settleAs: CustomerPaymentStatus.paid,
      ).payFor(order);

      expect(opened, ['https://hpp-sandbox.worldpay.com/test-page']);
      expect(settled.isPaid, isTrue);
    });

    test('a sheet closed without paying leaves the order unpaid', () async {
      final order = await placeCardOrder();

      // The sheet closes and nothing else happens — no webhook, no payment.
      final settled = await flowFor().payFor(order);

      expect(opened, hasLength(1));
      // This is the whole point: the flow reports what the server says, and
      // the server says nobody paid.
      expect(settled.isPaid, isFalse);
      expect(settled.needsPayment, isTrue);
    });

    test('asks for a page when the order was placed without one', () async {
      repository.payUrl = 'https://hpp-sandbox.worldpay.com/fresh-page';
      // Worldpay was unreachable at placement: the order exists, with no page.
      final order = CustomerOrder.fromJson(const {
        'id': 'new-order',
        'payment_method': 'card',
        'payment_status': 'pending',
      });
      repository.orders = [order];

      await flowFor(settleAs: CustomerPaymentStatus.paid).payFor(order);

      expect(repository.payCalls, 1);
      expect(opened, ['https://hpp-sandbox.worldpay.com/fresh-page']);
    });

    test('a page that cannot be obtained is an error, not a payment', () async {
      repository.payUrl = null;
      final order = CustomerOrder.fromJson(const {
        'id': 'new-order',
        'payment_method': 'card',
        'payment_status': 'pending',
      });
      repository.orders = [order];

      // The message must not blame the customer or send them round the same
      // loop, and must say the order survived -- it did.
      await expectLater(
        flowFor().payFor(order),
        throwsA(
          isA<ApiFailure>().having(
            (f) => f.message,
            'message',
            allOf(
              contains('unavailable'),
              contains('saved'),
              isNot(contains('try again')),
            ),
          ),
        ),
      );
      expect(opened, isEmpty);
      // Asked once for a page before giving up, rather than assuming.
      expect(repository.payCalls, 1);
    });
  });

  test('refuses a payment link that is not https', () async {
    for (final hostile in [
      'javascript:alert(1)',
      'intent://evil#Intent;scheme=http;end',
      'file:///etc/passwd',
      'http://hpp-sandbox.worldpay.com/x',
    ]) {
      repository.payUrl = hostile;
      final order = CustomerOrder.fromJson({
        'id': 'new-order',
        'payment_method': 'card',
        'payment_status': 'pending',
        'payment_url': hostile,
      });
      repository.orders = [order];

      // launchUrl opens whatever scheme it is handed, so a tampered response
      // could otherwise become an arbitrary launch on the customer's phone.
      await expectLater(
        flowFor().payFor(order),
        throwsA(isA<ApiFailure>()),
        reason: hostile,
      );
    }
    expect(opened, isEmpty);
  });

  group('paying from the orders screen', () {
    test('a successful payment updates that order and nothing else', () async {
      await placeCardOrder();
      final cubit = OrdersCubit(
        repository: repository,
        paymentFlow: flowFor(settleAs: CustomerPaymentStatus.paid),
      );
      await cubit.load();

      final message = await cubit.payOrder('new-order');

      expect(message, isNull);
      expect(cubit.state.orders.single.isPaid, isTrue);
      expect(cubit.state.payingId, isNull);
      await cubit.close();
    });

    test('a decline is reported as retryable, not as a lost order', () async {
      await placeCardOrder();
      final cubit = OrdersCubit(
        repository: repository,
        paymentFlow: flowFor(settleAs: CustomerPaymentStatus.failed),
      );
      await cubit.load();

      final message = await cubit.payOrder('new-order');

      expect(message, contains('declined'));
      expect(message, contains('try again'));
      // The order survives a decline — losing it would mean re-entering
      // everything, and the backend keeps it precisely so that is not needed.
      expect(cubit.state.orders.single.needsPayment, isTrue);
      await cubit.close();
    });

    test(
      'an unconfirmed payment says so rather than claiming either',
      () async {
        await placeCardOrder();
        final cubit = OrdersCubit(
          repository: repository,
          paymentFlow: flowFor(),
        );
        await cubit.load();

        final message = await cubit.payOrder('new-order');

        // Neither "paid" nor "failed": the webhook has not landed, and the
        // backend will resolve it either way.
        expect(message, contains('still confirming'));
        await cubit.close();
      },
    );

    test('a cash order is never sent to a payment page', () async {
      await repository.place(
        idempotencyKey: 'key-2',
        isDelivery: false,
        lines: const [],
        contactName: 'Ali',
        contactPhone: '07700 900123',
      );
      final cubit = OrdersCubit(
        repository: repository,
        paymentFlow: flowFor(settleAs: CustomerPaymentStatus.paid),
      );
      await cubit.load();

      expect(await cubit.payOrder('new-order'), isNull);
      expect(opened, isEmpty);
      expect(repository.payCalls, 0);
      await cubit.close();
    });
  });
}
