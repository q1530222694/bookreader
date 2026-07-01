import 'dart:async';

import '../model/payment_model.dart';

/// PaymentService isolates payment implementations for different channels.
class PaymentService {
  /// Simulate Apple App Store payment.
  Future<PaymentResult> payWithApple({required String productId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return PaymentResult(success: true, message: 'Apple 支付已发起：$productId');
  }

  /// Simulate Google Play payment.
  Future<PaymentResult> payWithGoogle({required String productId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return PaymentResult(
      success: true,
      message: 'Google Play 支付已发起：$productId',
    );
  }

  /// Simulate third-party payment.
  Future<PaymentResult> payWithThirdParty({
    required String channel,
    required String productId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return PaymentResult(
      success: true,
      message: '第三方支付($channel)已发起：$productId',
    );
  }
}
