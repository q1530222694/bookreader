/// PaymentResult represents the outcome of a payment request.
class PaymentResult {
  final bool success;
  final String message;

  const PaymentResult({required this.success, required this.message});
}
