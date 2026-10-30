import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'buying_succes_page.dart';
import 'store_page.dart';

class PaymentReturnPage extends StatefulWidget {
  final String orderId;

  const PaymentReturnPage({super.key, required this.orderId});

  @override
  State<PaymentReturnPage> createState() => _PaymentReturnPageState();
}

class _PaymentReturnPageState extends State<PaymentReturnPage> {
  static const Color headerBlue = Color(0xFF38B6FF);

  bool _checking = true;
  String? _status;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkPayment(retryPending: true);
  }

  Future<String> _loadStatus() async {
    final result = await Supabase.instance.client.rpc(
      'get_order_details',
      params: {'p_order_id': widget.orderId},
    );
    final order = result is List && result.isNotEmpty ? result.first : result;
    if (order is! Map || order['status'] == null) {
      throw const FormatException('Order status was not returned.');
    }
    return order['status'].toString();
  }

  Future<void> _checkPayment({bool retryPending = false}) async {
    if (mounted) {
      setState(() {
        _checking = true;
        _error = null;
      });
    }

    try {
      final attempts = retryPending ? 10 : 1;
      for (var attempt = 0; attempt < attempts; attempt++) {
        final status = await _loadStatus();
        if (!mounted) return;

        if (status == 'Paid') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => BuyingSuccesPage(orderId: widget.orderId),
            ),
          );
          return;
        }

        setState(() => _status = status);
        if (status != 'Pending' || attempt == attempts - 1) break;
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  String get _message {
    if (_error != null) {
      return 'We returned to iFinds PH, but could not verify the payment. '
          'Check your connection and try again.';
    }
    switch (_status) {
      case 'Paid':
        return 'Payment confirmed.';
      case 'Expired':
        return 'This payment link expired. You can return to the store and '
            'place the order again.';
      case 'Error':
        return 'The payment could not be completed. Please try again.';
      case 'Pending':
        return 'Payment is still processing. You are back in iFinds PH; '
            'check again in a moment.';
      default:
        return 'Checking your payment with Supabase.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: headerBlue,
        title: const Text('Payment status'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_checking) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
              ],
              Text(_message, textAlign: TextAlign.center),
              if (!_checking) ...[
                const SizedBox(height: 20),
                if (_status == 'Pending' || _error != null)
                  ElevatedButton(
                    onPressed: _checkPayment,
                    child: const Text('Check again'),
                  ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute<void>(
                        builder: (_) => const StorePage(),
                      ),
                      (route) => route.isFirst,
                    );
                  },
                  child: const Text('Back to store'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
