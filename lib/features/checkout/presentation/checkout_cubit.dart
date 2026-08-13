import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_failure.dart';
import '../../cart/cart_cubit.dart';
import '../../orders/domain/customer_order.dart';
import '../../orders/domain/order_quote.dart';
import '../../orders/domain/order_repository.dart';

/// Where a checkout has got to.
///
/// The shape the integration guide suggests: basket → quoting → quote ready →
/// submitting → placed.
enum CheckoutStage { quoting, ready, submitting, placed, failed }

class CheckoutState extends Equatable {
  const CheckoutState({
    this.stage = CheckoutStage.quoting,
    this.isDelivery = true,
    this.quote,
    this.failure,
    this.placedOrder,
    this.fieldErrors = const {},
    this.requestedFor,
    this.prepMinutes,
  });

  final CheckoutStage stage;

  /// Delivery or collection. Changing it re-quotes: the fee and the minimum both
  /// depend on it.
  final bool isDelivery;

  /// The server's price. Null until the first quote lands.
  final OrderQuote? quote;

  final ApiFailure? failure;

  /// Set once the order exists. Its number is what the customer needs.
  final CustomerOrder? placedOrder;

  /// Per-field complaints from a 422, keyed by the API's field names.
  final Map<String, String> fieldErrors;

  /// The chosen slot, verbatim from `quote.available_slots`, or null for ASAP.
  final String? requestedFor;

  /// The kitchen's estimate for this basket, in minutes — the longest dish, not
  /// the sum. Null when no dish carried one.
  final int? prepMinutes;

  /// The earliest moment the kitchen could have this basket ready.
  ///
  /// Captured when the quote lands rather than recomputed on every build, so the
  /// list of offered times does not shuffle while somebody is looking at it.
  DateTime? get readyFrom => _readyFrom;

  /// Slots the kitchen can actually make.
  ///
  /// A **narrowing** of what the server offered, never an addition: the API's
  /// 45-minute lead time is the floor, and this removes anything inside the
  /// basket's own cooking time on top of that. So a twenty-minute dish cannot be
  /// asked for in fifteen.
  List<String> get selectableSlots {
    final quoted = quote?.availableSlots ?? const <String>[];
    final floor = _readyFrom;
    if (floor == null) return quoted;

    return quoted.where((slot) {
      final when = DateTime.tryParse(slot);
      // A slot that will not parse is kept rather than dropped — the server sent
      // it, and hiding a valid time because of a formatting surprise is worse
      // than offering one.
      return when == null || !when.toUtc().isBefore(floor);
    }).toList();
  }

  /// True when the kitchen's estimate rules out every time the server offered.
  bool get everySlotTooSoon =>
      quote != null &&
      (quote!.availableSlots.isNotEmpty) &&
      selectableSlots.isEmpty;

  DateTime? get _readyFrom {
    final minutes = prepMinutes;
    if (minutes == null) return null;
    return DateTime.now().toUtc().add(Duration(minutes: minutes));
  }

  bool get isAsap => requestedFor == null;

  /// Whether the order can be sent. A delivery below the minimum cannot.
  bool get canPlace =>
      quote != null &&
      quote!.meetsMinimum &&
      stage != CheckoutStage.submitting &&
      stage != CheckoutStage.placed;

  CheckoutState copyWith({
    CheckoutStage? stage,
    bool? isDelivery,
    OrderQuote? quote,
    ApiFailure? failure,
    CustomerOrder? placedOrder,
    Map<String, String>? fieldErrors,
    String? requestedFor,
    int? prepMinutes,
    bool clearFailure = false,
    bool clearSlot = false,
  }) {
    return CheckoutState(
      stage: stage ?? this.stage,
      isDelivery: isDelivery ?? this.isDelivery,
      quote: quote ?? this.quote,
      failure: clearFailure ? null : (failure ?? this.failure),
      placedOrder: placedOrder ?? this.placedOrder,
      fieldErrors: fieldErrors ?? this.fieldErrors,
      requestedFor: clearSlot ? null : (requestedFor ?? this.requestedFor),
      prepMinutes: prepMinutes ?? this.prepMinutes,
    );
  }

  @override
  List<Object?> get props => [
    stage,
    isDelivery,
    quote,
    failure,
    placedOrder,
    fieldErrors,
    requestedFor,
    prepMinutes,
  ];
}

/// Pricing and placing one order.
///
/// Two rules from the guide are load-bearing here:
///
///  * **One idempotency key per checkout, reused on every retry.** Generating a
///    fresh key when a request times out is exactly how a customer ends up with
///    two identical orders — the server has no way to tell the second attempt
///    from a second order. The key is made once, in the constructor, and only
///    replaced when the basket meaningfully changes.
///  * **Clear the basket only after the server confirms.** A basket emptied
///    optimistically and a request that then failed leaves the customer with
///    neither an order nor the things they chose.
class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit({required OrderRepository repository, required CartCubit cart})
    : _repository = repository,
      _cart = cart,
      super(const CheckoutState());

  final OrderRepository _repository;
  final CartCubit _cart;

  /// Generated once per checkout attempt. See the class note.
  String _idempotencyKey = _uuidV4();

  /// The basket this key belongs to, so a genuinely different order gets a new
  /// one rather than being deduplicated against the last.
  List<CartLine>? _keyedFor;

  Future<void> quote() async {
    final lines = _cart.state.lines;
    if (lines.isEmpty) {
      emit(
        state.copyWith(
          stage: CheckoutStage.failed,
          failure: const ApiFailure(
            kind: ApiFailureKind.invalid,
            message: 'Your basket is empty.',
          ),
        ),
      );
      return;
    }

    // A changed basket is a new order, so it gets a new key. Same basket,
    // retried — including after a timeout — keeps the old one.
    if (_keyedFor != null && _keyedFor != lines) {
      _idempotencyKey = _uuidV4();
    }
    _keyedFor = List.of(lines);

    emit(state.copyWith(stage: CheckoutStage.quoting, clearFailure: true));
    try {
      final quote = await _repository.quote(
        isDelivery: state.isDelivery,
        lines: lines,
      );
      emit(
        state.copyWith(
          stage: CheckoutStage.ready,
          quote: quote,
          // Recorded from the basket, so the slot list can refuse a time the
          // kitchen could not meet.
          prepMinutes: _cart.state.longestPrepMinutes,
          clearFailure: true,
        ),
      );
    } on ApiFailure catch (failure) {
      emit(state.copyWith(stage: CheckoutStage.failed, failure: failure));
    }
  }

  /// Switches between delivery and collection, then re-prices.
  Future<void> setDelivery(bool isDelivery) async {
    if (isDelivery == state.isDelivery) return;
    // The slot is dropped: the two paths have different lead times, and a slot
    // chosen for one is not necessarily offered for the other.
    emit(state.copyWith(isDelivery: isDelivery, clearSlot: true));
    await quote();
  }

  /// Picks a slot, or null for as soon as possible.
  ///
  /// A slot outside [CheckoutState.selectableSlots] is ignored rather than
  /// stored: the only way to ask for one is a stale screen, and sending it would
  /// earn a TIME_TOO_SOON the customer cannot act on.
  void setSlot(String? slot) {
    if (slot == null) return emit(state.copyWith(clearSlot: true));
    if (!state.selectableSlots.contains(slot)) return;
    emit(state.copyWith(requestedFor: slot));
  }

  /// Sends the order.
  ///
  /// Returns null on success. The basket and the key are cleared only after the
  /// server has answered.
  Future<ApiFailure?> place({
    required String contactName,
    required String contactPhone,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? postcode,
    String? deliveryNotes,
    String? customerNote,
  }) async {
    if (state.stage == CheckoutStage.submitting) return null;
    emit(
      state.copyWith(
        stage: CheckoutStage.submitting,
        clearFailure: true,
        fieldErrors: const {},
      ),
    );

    try {
      final order = await _repository.place(
        idempotencyKey: _idempotencyKey,
        isDelivery: state.isDelivery,
        lines: _cart.state.lines,
        contactName: contactName,
        contactPhone: contactPhone,
        isAsap: state.isAsap,
        requestedFor: state.requestedFor,
        addressLine1: addressLine1,
        addressLine2: addressLine2,
        city: city,
        postcode: postcode,
        deliveryNotes: deliveryNotes,
        customerNote: customerNote,
      );

      // Confirmed, so now the basket goes — and the key with it, since this
      // checkout is over.
      _cart.clear();
      _idempotencyKey = _uuidV4();
      _keyedFor = null;

      emit(state.copyWith(stage: CheckoutStage.placed, placedOrder: order));
      return null;
    } on ApiFailure catch (failure) {
      // Back to ready, not failed: the entered details are still on screen and
      // still valid, and most of these are worth another try with the same key.
      emit(
        state.copyWith(
          stage: CheckoutStage.ready,
          failure: failure,
          fieldErrors: failure.fieldErrors,
        ),
      );
      return failure;
    }
  }

  /// A version-4 UUID.
  ///
  /// Hand-rolled rather than adding a package for sixteen bytes. `Random.secure`
  /// because a guessable key is a way to collide with somebody else's checkout —
  /// the API scopes keys per user, so the risk is small, but the cost of using
  /// the secure generator is nothing.
  static String _uuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    // Version 4, variant 1, as the spec requires.
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String hex(int start, int end) => bytes
        .sublist(start, end)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-'
        '${hex(10, 16)}';
  }

  /// Exposed for tests: proves the key survives a retry.
  String get idempotencyKey => _idempotencyKey;
}
