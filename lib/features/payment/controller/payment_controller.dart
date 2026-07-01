import '../model/payment_model.dart';
import '../service/payment_service.dart';

/// PaymentController exposes platform-specific payment interfaces.
class PaymentController {
  PaymentController._();

  static void initialize() {
    // Payment feature initialization.
  }

  /// Request Apple in-app purchase flow.
  static Future<PaymentResult> payWithApple({required String productId}) {
    return PaymentService().payWithApple(productId: productId);
  }

  /// Request Google Play payment flow.
  static Future<PaymentResult> payWithGoogle({required String productId}) {
    return PaymentService().payWithGoogle(productId: productId);
  }

  /// Request generic third-party payment flow.
  static Future<PaymentResult> payWithThirdParty({
    required String channel,
    required String productId,
  }) {
    return PaymentService().payWithThirdParty(
      channel: channel,
      productId: productId,
    );
  }
}
