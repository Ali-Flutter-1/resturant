import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:practice/core/config/app_config.dart';
import 'package:practice/core/network/api_failure.dart';
import 'package:practice/core/theme/app_theme.dart';
import 'package:practice/features/orders/data/demo_order_repository.dart';
import 'package:practice/features/orders/domain/customer_order.dart';
import 'package:practice/features/orders/domain/order_repository.dart';
import 'package:practice/features/orders/presentation/my_orders_screen.dart';
import 'package:practice/features/orders/presentation/orders_cubit.dart';

import 'support/fake_order_repository.dart';

void main() {
  group('CustomerOrderStatus.fromApi', () {
    test('maps the documented statuses', () {
      expect(CustomerOrderStatus.fromApi('placed'), CustomerOrderStatus.placed);
      expect(
        CustomerOrderStatus.fromApi('preparing'),
        CustomerOrderStatus.preparing,
      );
      expect(CustomerOrderStatus.fromApi('ready'), CustomerOrderStatus.ready);
      expect(
        CustomerOrderStatus.fromApi('out_for_delivery'),
        CustomerOrderStatus.outForDelivery,
      );
      expect(
        CustomerOrderStatus.fromApi('completed'),
        CustomerOrderStatus.completed,
      );
      expect(
        CustomerOrderStatus.fromApi('cancelled'),
        CustomerOrderStatus.cancelled,
      );
    });

    test('is case- and whitespace-insensitive', () {
      expect(
        CustomerOrderStatus.fromApi('  PREPARING '),
        CustomerOrderStatus.preparing,
      );
    });

    test('treats an unknown status as in progress rather than throwing', () {
      // A backend that gains a state must not blank the whole history screen.
      expect(
        CustomerOrderStatus.fromApi('quantum_superposition'),
        CustomerOrderStatus.placed,
      );
      expect(CustomerOrderStatus.fromApi(null), CustomerOrderStatus.placed);
    });

    test('folds the kitchen-only "overdue" into a customer-safe state', () {
      // Staff need to see a late order; the customer must never be told their
      // dinner is "overdue".
      expect(
        CustomerOrderStatus.fromApi('overdue'),
        CustomerOrderStatus.placed,
      );
    });

    test('only finished states leave the tracker', () {
      expect(CustomerOrderStatus.completed.isLive, isFalse);
      expect(CustomerOrderStatus.cancelled.isLive, isFalse);
      expect(CustomerOrderStatus.outForDelivery.isLive, isTrue);
    });

    test('a cancelled order has no position on the track', () {
      expect(CustomerOrderStatus.cancelled.step, isNull);
      expect(CustomerOrderStatus.completed.step, CustomerOrderStatus.steps - 1);
    });
  });

  group('CustomerOrder.fromJson', () {
    test('reads the API shape', () {
      final order = CustomerOrder.fromJson({
        'id': 'abc',
        'order_number': '#0042',
        'status': 'preparing',
        'total_pence': 2850,
        'placed_at': '2026-08-01T18:30:00Z',
        'fulfilment_type': 'delivery',
        'items': [
          {'name': 'Hoppers', 'quantity': 2, 'line_total_pence': 1000},
        ],
      });

      expect(order.reference, '#0042');
      expect(order.status, CustomerOrderStatus.preparing);
      expect(order.formattedTotal, '£28.50');
      expect(order.itemCount, 2);
      expect(order.items.single.dishName, 'Hoppers');
      expect(order.isDelivery, isTrue);
    });

    test('falls back to the id tail when the API sends no order number', () {
      final order = CustomerOrder.fromJson({
        'id': '5f1c9e2a-0000-4bcd-9999-abcd0000ef12',
        'status': 'placed',
      });
      // Readable aloud, which a bare UUID is not.
      expect(order.reference, '#EF12');
    });

    test('a missing timestamp is null, not an invented date', () {
      final order = CustomerOrder.fromJson({'id': 'x', 'status': 'placed'});
      expect(order.placedAt, isNull);
    });

    test('prefers the server line total over unit × quantity', () {
      final item = CustomerOrderItem.fromJson({
        'name': 'Curry',
        'quantity': 3,
        'unit_price_pence': 500,
        'line_total_pence': 1400,
      });
      // The server's arithmetic wins — it is the figure the payment matches.
      expect(item.linePence, 1400);
    });

    test('computes the line only when the server sent a unit price alone', () {
      final item = CustomerOrderItem.fromJson({
        'name': 'Curry',
        'quantity': 3,
        'unit_price_pence': 500,
      });
      expect(item.linePence, 1500);
    });

    test('cancellability follows the server when it says', () {
      final locked = CustomerOrder.fromJson({
        'id': 'a',
        'status': 'placed',
        'can_cancel': false,
      });
      // Documented rule says placed is cancellable; the server disagrees, and
      // the server knows whether the kitchen has started.
      expect(locked.canCancel, isFalse);

      final open = CustomerOrder.fromJson({'id': 'b', 'status': 'placed'});
      expect(open.canCancel, isTrue);

      final cooking = CustomerOrder.fromJson({
        'id': 'c',
        'status': 'preparing',
      });
      expect(cooking.canCancel, isFalse);
    });

    test('collection orders are never described as on their way', () {
      final order = CustomerOrder.fromJson({
        'id': 'a',
        'status': 'out_for_delivery',
        'fulfilment_type': 'collection',
      });
      expect(order.isDelivery, isFalse);
      expect(order.statusLabel, 'Ready to collect');
    });
  });

  group('OrdersCubit', () {
    test('splits live from finished orders', () async {
      final cubit = OrdersCubit(
        repository: FakeOrderRepository(
          orders: [
            OrderFixtures.order(id: '1', status: CustomerOrderStatus.preparing),
            OrderFixtures.order(id: '2', status: CustomerOrderStatus.completed),
            OrderFixtures.order(id: '3', status: CustomerOrderStatus.cancelled),
          ],
        ),
      );

      await cubit.load();

      expect(cubit.state.status, OrdersStatus.ready);
      expect(cubit.state.live.map((o) => o.id), ['1']);
      expect(cubit.state.past.map((o) => o.id), ['2', '3']);
    });

    test('reports a failure with the API message', () async {
      final cubit = OrdersCubit(
        repository: FakeOrderRepository(failure: ApiFailure.offline),
      );

      await cubit.load();

      expect(cubit.state.status, OrdersStatus.failure);
      expect(cubit.state.failure, ApiFailure.offline);
    });

    test(
      'a failed silent refresh keeps the orders already on screen',
      () async {
        final repository = FakeOrderRepository(
          orders: [OrderFixtures.order(id: '1')],
        );
        final cubit = OrdersCubit(repository: repository);
        await cubit.load();

        repository.failure = ApiFailure.offline;
        await cubit.load(silent: true);

        // The tracker the user is watching must not blank because one poll
        // happened to land in a tunnel.
        expect(cubit.state.status, OrdersStatus.ready);
        expect(cubit.state.orders, hasLength(1));
      },
    );

    test('cancelling adopts the server status rather than assuming', () async {
      final repository = FakeOrderRepository(
        orders: [
          OrderFixtures.order(
            id: '1',
            status: CustomerOrderStatus.placed,
            canCancel: true,
          ),
        ],
      );
      final cubit = OrdersCubit(repository: repository);
      await cubit.load();

      final error = await cubit.cancelOrder('1');

      expect(error, isNull);
      expect(repository.cancelled, ['1']);
      expect(cubit.state.orders.single.status, CustomerOrderStatus.cancelled);
      expect(cubit.state.cancellingId, isNull);
    });

    test('a refused cancellation leaves the order alone', () async {
      final repository = FakeOrderRepository(
        orders: [
          OrderFixtures.order(
            id: '1',
            status: CustomerOrderStatus.preparing,
            canCancel: true,
          ),
        ],
        cancelFailure: const ApiFailure(
          kind: ApiFailureKind.conflict,
          message: 'The kitchen has already started this order.',
        ),
      );
      final cubit = OrdersCubit(repository: repository);
      await cubit.load();

      final error = await cubit.cancelOrder('1');

      // The one lie this screen must not tell: "cancelled" for an order that
      // is still being cooked.
      expect(error, 'The kitchen has already started this order.');
      expect(cubit.state.orders.single.status, CustomerOrderStatus.preparing);
      expect(cubit.state.cancellingId, isNull);
    });
  });

  group('MyOrdersScreen', () {
    Widget wrap(OrderRepository repository) =>
        RepositoryProvider<OrderRepository>.value(
          value: repository,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const MyOrdersScreen(),
          ),
        );

    testWidgets('shows the tracker for a live order', (tester) async {
      await tester.pumpWidget(
        wrap(
          FakeOrderRepository(
            orders: [
              OrderFixtures.order(
                id: '1',
                reference: '#0042',
                status: CustomerOrderStatus.outForDelivery,
              ),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Happening now'), findsOne);
      expect(find.text('On its way'), findsWidgets);
      expect(find.textContaining('#0042'), findsOne);
      expect(tester.takeException(), isNull);
    });

    testWidgets('separates finished orders into the history list', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          FakeOrderRepository(
            orders: [
              OrderFixtures.order(
                id: '1',
                status: CustomerOrderStatus.preparing,
              ),
              OrderFixtures.order(
                id: '2',
                reference: '#0041',
                status: CustomerOrderStatus.completed,
              ),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Happening now'), findsOne);
      expect(find.text('Earlier orders'), findsOne);
      expect(find.text('#0041'), findsOne);
    });

    testWidgets('offers no cancel once the kitchen has started', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          FakeOrderRepository(
            orders: [
              OrderFixtures.order(
                id: '1',
                status: CustomerOrderStatus.preparing,
              ),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Cancel order'), findsNothing);
    });

    testWidgets('offers cancel while the order is only placed', (tester) async {
      await tester.pumpWidget(
        wrap(
          FakeOrderRepository(
            orders: [
              OrderFixtures.order(
                id: '2',
                status: CustomerOrderStatus.placed,
                canCancel: true,
              ),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Cancel order'), findsOne);
    });

    testWidgets('cancelling asks first, and does nothing if declined', (
      tester,
    ) async {
      final repository = FakeOrderRepository(
        orders: [
          OrderFixtures.order(
            id: '1',
            status: CustomerOrderStatus.placed,
            canCancel: true,
          ),
        ],
      );
      await tester.pumpWidget(wrap(repository));
      await tester.pump(const Duration(seconds: 2));

      await tester.tap(find.text('Cancel order'));
      await tester.pumpAndSettle();
      expect(find.text('Keep my order'), findsOne);

      await tester.tap(find.text('Keep my order'));
      await tester.pumpAndSettle();

      // Nothing irreversible happens behind a sheet the user dismissed.
      expect(repository.cancelled, isEmpty);
    });

    testWidgets('a confirmed cancellation reaches the repository', (
      tester,
    ) async {
      final repository = FakeOrderRepository(
        orders: [
          OrderFixtures.order(
            id: '1',
            status: CustomerOrderStatus.placed,
            canCancel: true,
          ),
        ],
      );
      await tester.pumpWidget(wrap(repository));
      await tester.pump(const Duration(seconds: 2));

      await tester.tap(find.text('Cancel order'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel this order'));
      await tester.pumpAndSettle();

      expect(repository.cancelled, ['1']);
    });

    testWidgets('shows the API message when loading fails', (tester) async {
      await tester.pumpWidget(
        wrap(FakeOrderRepository(failure: ApiFailure.offline)),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(find.text(ApiFailure.offline.message), findsOne);
    });

    testWidgets('an empty history says so and offers the menu', (tester) async {
      await tester.pumpWidget(wrap(FakeOrderRepository(orders: [])));
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('No orders yet'), findsOne);
      // The callback is null here, so the button is absent by design rather
      // than dangling.
      expect(find.text('Browse the menu'), findsNothing);
    });

    testWidgets('polls while an order is live', (tester) async {
      final live = FakeOrderRepository(
        orders: [
          OrderFixtures.order(id: '1', status: CustomerOrderStatus.preparing),
        ],
      );
      await tester.pumpWidget(wrap(live));
      await tester.pump(const Duration(seconds: 2));
      expect(live.loadCount, 1);

      await tester.pump(const Duration(seconds: 31));
      await tester.pump();

      // The tracker moves on its own — nobody should have to pull to refresh
      // to find out whether their food has left the kitchen.
      expect(live.loadCount, 2);
    });

    testWidgets('stops polling once nothing is in progress', (tester) async {
      final settled = FakeOrderRepository(
        orders: [
          OrderFixtures.order(id: '1', status: CustomerOrderStatus.completed),
        ],
      );
      await tester.pumpWidget(wrap(settled));
      await tester.pump(const Duration(seconds: 2));
      expect(settled.loadCount, 1);

      await tester.pump(const Duration(seconds: 61));
      await tester.pump();

      // A history screen with nothing live must not keep waking the network up.
      expect(settled.loadCount, 1);
    });

    testWidgets('tapping a past order opens its receipt', (tester) async {
      await tester.pumpWidget(
        wrap(
          FakeOrderRepository(
            orders: [
              OrderFixtures.order(
                id: '1',
                reference: '#0041',
                status: CustomerOrderStatus.completed,
              ),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));

      await tester.tap(find.text('#0041'));
      await tester.pumpAndSettle();

      expect(find.text('Order #0041'), findsOne);
      expect(find.text('Jaffna Crab'), findsOne);
      expect(find.text('2×'), findsOne);
      expect(find.text('Total'), findsOne);
    });
  });

  group('demo orders', () {
    test('are off unless .env asks for them explicitly', () {
      dotenv.loadFromString(envString: 'API_BASE_URL=https://example.com');
      // A missing key must not enable them: the failure mode is invented orders
      // shown to a real customer.
      expect(AppConfig.useDemoOrders, isFalse);

      dotenv.loadFromString(
        envString: 'API_BASE_URL=https://example.com\nUSE_DEMO_ORDERS=1',
      );
      expect(AppConfig.useDemoOrders, isFalse);

      dotenv.loadFromString(
        envString: 'API_BASE_URL=https://example.com\nUSE_DEMO_ORDERS=TRUE',
      );
      expect(AppConfig.useDemoOrders, isTrue);
    });

    test('cover a live order at each stage plus a full history', () async {
      final orders = await DemoOrderRepository(delay: Duration.zero).myOrders();
      final live = orders.where((o) => o.status.isLive);

      expect(live.map((o) => o.status), contains(CustomerOrderStatus.placed));
      expect(
        live.map((o) => o.status),
        contains(CustomerOrderStatus.outForDelivery),
      );
      expect(orders.any((o) => o.canCancel), isTrue);
      expect(orders.any((o) => !o.isDelivery), isTrue);
      expect(
        orders.map((o) => o.status),
        contains(CustomerOrderStatus.cancelled),
      );
      // The case that used to draw an empty gap in the receipt sheet.
      expect(orders.any((o) => o.items.isEmpty), isTrue);
    });

    test('cancelling one sticks', () async {
      final repository = DemoOrderRepository(delay: Duration.zero);
      final target = (await repository.myOrders()).firstWhere(
        (o) => o.canCancel,
      );

      await repository.cancel(target.id);

      final after = (await repository.myOrders()).firstWhere(
        (o) => o.id == target.id,
      );
      expect(after.status, CustomerOrderStatus.cancelled);
    });
  });
}
