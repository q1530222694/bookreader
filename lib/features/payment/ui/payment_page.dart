import 'package:flutter/cupertino.dart';

import '../controller/payment_controller.dart';
import '../model/payment_model.dart';

/// PaymentPage exposes separate payment entry points for platform and third-party channels.
class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String _resultText = '请选择支付方式';

  Future<void> _payWithApple() async {
    final result = await PaymentController.payWithApple(
      productId: 'com.bookreader.vip',
    );
    _updateResult(result);
  }

  Future<void> _payWithGoogle() async {
    final result = await PaymentController.payWithGoogle(
      productId: 'com.bookreader.vip',
    );
    _updateResult(result);
  }

  Future<void> _payWithThirdParty(String channel) async {
    final result = await PaymentController.payWithThirdParty(
      channel: channel,
      productId: 'com.bookreader.vip',
    );
    _updateResult(result);
  }

  void _updateResult(PaymentResult result) {
    setState(() {
      _resultText = result.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('支付中心')),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '支付中心',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              CupertinoButton.filled(
                onPressed: _payWithApple,
                child: const Text('Apple 支付'),
              ),
              const SizedBox(height: 12),
              CupertinoButton.filled(
                onPressed: _payWithGoogle,
                child: const Text('Google Play 支付'),
              ),
              const SizedBox(height: 12),
              CupertinoButton(
                onPressed: () => _payWithThirdParty('wechat'),
                child: const Text('微信支付'),
              ),
              const SizedBox(height: 8),
              CupertinoButton(
                onPressed: () => _payWithThirdParty('alipay'),
                child: const Text('支付宝支付'),
              ),
              const SizedBox(height: 24),
              Text(_resultText, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}
