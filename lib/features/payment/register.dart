import 'controller/payment_controller.dart';

/// Payment feature registration entry.
class PaymentRegister {
  static void register() {
    PaymentController.initialize();
  }
}
