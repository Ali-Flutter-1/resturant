import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_failure.dart';
import 'customer_order.dart';
import 'order_repository.dart';

/// Opens a hosted payment page and then finds out what actually happened.
///
/// The one rule this whole class exists to enforce: **a closed sheet is not a
/// payment**. The customer can dismiss it before paying, after paying, or
/// halfway through a 3-D Secure step, and a success-looking redirect can be
/// faked. The only thing that marks an order paid is Worldpay calling the
/// backend's webhook, server to server -- which it does even if the app is
/// killed the instant the card is charged. So when the sheet closes we ask the
/// server, and keep asking for a short while, rather than believing the screen.
///
/// Card details never reach this app. We receive a URL and open it; that is
/// what keeps the product at PCI SAQ-A, and it is why the page must open in a
/// Chrome Custom Tab / SFSafariViewController rather than an embedded WebView
/// -- Apple Pay, Google Pay and some bank 3-D Secure pages refuse to run inside
/// one, and saved-card autofill does not work there either.
class PaymentFlow {
  PaymentFlow({
    required OrderRepository repository,
    OpenPaymentPage? open,

    /// Overridden in tests, which would otherwise sit through the real
    /// half-minute of waiting.
    List<Duration>? pollSchedule,
  }) : _repository = repository,
       _open = open ?? _launchInAppBrowser,
       _pollSchedule = pollSchedule ?? _defaultPollSchedule;

  final OrderRepository _repository;
  final OpenPaymentPage _open;
  final List<Duration> _pollSchedule;

  /// Webhooks usually land in a second or two. These waits give it about half a
  /// minute in total before the screen falls back to "still confirming", which
  /// is the honest answer -- the order resolves server-side either way.
  static const List<Duration> _defaultPollSchedule = [
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 5),
    Duration(seconds: 5),
    Duration(seconds: 5),
    Duration(seconds: 5),
  ];

  /// Takes an unpaid card order through payment and returns what the server
  /// says about it afterwards.
  ///
  /// Throws [ApiFailure] if a page cannot be obtained; a page that opens and is
  /// then abandoned is not an error, it is an unpaid order.
  Future<CustomerOrder> payFor(CustomerOrder order) async {
    var current = order;

    // No page yet -- either Worldpay was unreachable when the order was placed,
    // or a previous attempt was declined and its page is spent. Asking for one
    // is safe: an unpaid order gets its existing page back rather than a second
    // one, so this cannot produce a double charge.
    if (current.paymentUrl == null) {
      current = await _repository.pay(current.id);
    }

    final url = current.paymentUrl;
    if (url == null) {
      // The server had nothing to open, which for an unpaid order means
      // something is wrong upstream rather than that payment succeeded.
      throw const ApiFailure(
        kind: ApiFailureKind.server,
        message: "We couldn't open the payment page. Please try again.",
      );
    }

    await _open(url);
    return confirm(current.id);
  }

  /// Re-reads the order until it stops being pending, or the schedule runs out.
  ///
  /// Exposed on its own because the same question needs asking whenever an
  /// order screen regains focus, not only after a sheet closes.
  Future<CustomerOrder> confirm(String orderId) async {
    var order = await _repository.orderById(orderId);
    for (final wait in _pollSchedule) {
      if (order.paymentStatus != CustomerPaymentStatus.pending) return order;
      await Future<void>.delayed(wait);
      order = await _repository.orderById(orderId);
    }
    // Still pending. Not a failure -- the backend will resolve it -- so the
    // caller says so plainly rather than claiming the payment did not work.
    return order;
  }
}

/// Opens the hosted page. Injectable so tests do not launch a browser.
typedef OpenPaymentPage = Future<void> Function(String url);

Future<void> _launchInAppBrowser(String url) async {
  try {
    await launchUrl(
      Uri.parse(url),
      // In-app: a Custom Tab on Android, SFSafariViewController on iOS. Not an
      // external browser, which would strand the customer outside the app with
      // no way back other than the task switcher.
      mode: LaunchMode.inAppBrowserView,
    );
  } on PlatformException catch (error) {
    debugPrint('PaymentFlow: could not open the payment page ($error).');
    rethrow;
  }
}
