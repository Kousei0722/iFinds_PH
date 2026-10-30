import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'buying_succes_page.dart';
import 'cart_data.dart';

class CheckoutPage extends StatefulWidget {
  /// Items to buy: the selected cart items, or a single "Buy now" item.
  final List<CartItem> items;

  const CheckoutPage({super.key, required this.items});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final addressController = TextEditingController();

  static const Color headerBlue = Color(0xFF38B6FF);

  bool _submitting = false;

  int get total =>
      widget.items.fold<int>(0, (sum, item) => sum + item.subtotal);

  Future<void> saveOrder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _submitting = true);

    try {
      // The Edge Function saves the order, recalculates prices on the
      // server, and asks Xendit for a payment link.
      final response = await Supabase.instance.client.functions.invoke(
        'create-order',
        body: {
          'customerName': nameController.text.trim(),
          'phone': phoneController.text.trim(),
          'email': emailController.text.trim(),
          'address': addressController.text.trim(),
          'items': widget.items
              .map(
                (item) => {
                  'productName': item.productName,
                  'productId': item.productId,
                  'productVariantId': item.productVariantId,
                  'imagePath': item.imagePath,
                  'color': item.color,
                  'capacity': item.capacity,
                  'quantity': item.quantity,
                  'cartItemId': item.id,
                },
              )
              .toList(),
        },
      );

      final data = response.data as Map<String, dynamic>;
      final orderId = data['order_id'] as String;
      final invoiceUrl = data['invoice_url'] as String;

      final opened = await launchUrl(
        Uri.parse(invoiceUrl),
        mode: LaunchMode.externalApplication,
      );

      if (!mounted) return;

      if (!opened) {
        _showSnack('Could not open the payment page.');
        return;
      }

      await _showPaymentDialog(orderId);
    } on FunctionException catch (e) {
      final details = e.details;
      final detailMessage = details is Map && details['error'] != null
          ? details['error'].toString()
          : details?.toString();
      final message = e.status == 0
          ? 'Could not reach the create-order function. Check your connection. '
                '${detailMessage ?? ''}'
          : e.status == 404
          ? 'The create-order function was not found (HTTP 404). '
                'Deploy it to your Supabase project.'
          : 'create-order failed (HTTP ${e.status}): '
                '${detailMessage ?? e.reasonPhrase ?? 'Unknown error'}';
      _showSnack('Failed to create order: $message');
    } catch (e) {
      _showSnack('Failed to create order: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _statusMessage(String? status) {
    switch (status) {
      case null:
        return 'The Xendit payment page was opened. After you pay, '
            'tap "Check status".';
      case 'Pending':
        return 'Payment not received yet. Finish paying on the Xendit '
            'page, then check again.';
      case 'Expired':
        return 'This payment link has expired. Close this and place the '
            'order again.';
      case 'Error':
        return 'Could not check the status. Please try again.';
      default:
        return 'Order status: $status';
    }
  }

  Future<void> _showPaymentDialog(String orderId) {
    String? status;
    bool checking = false;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (innerContext, setDialogState) {
            return AlertDialog(
              title: const Text('Complete your payment'),
              content: Text(_statusMessage(status)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Close'),
                ),
                ElevatedButton(
                  onPressed: checking
                      ? null
                      : () async {
                          setDialogState(() => checking = true);

                          try {
                            final result = await Supabase.instance.client.rpc(
                              'get_order_details',
                              params: {'p_order_id': orderId},
                            );
                            final order = result is List && result.isNotEmpty
                                ? result.first
                                : result;
                            status = order is Map
                                ? order['status']?.toString()
                                : null;
                            if (status == null) {
                              throw const FormatException(
                                'Order status was not returned.',
                              );
                            }
                          } catch (e) {
                            status = 'Error';
                          }

                          if (status == 'Paid') {
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            if (!mounted) return;

                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    BuyingSuccesPage(orderId: orderId),
                              ),
                            );
                            return;
                          }

                          if (innerContext.mounted) {
                            setDialogState(() => checking = false);
                          }
                        },
                  child: const Text('Check status'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: headerBlue,
        foregroundColor: Colors.black,
        centerTitle: true,
        title: const Text(
          'Checkout',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Customer Information',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  _buildField(
                    controller: nameController,
                    label: 'Full Name',
                    icon: Icons.person,
                  ),
                  _buildField(
                    controller: phoneController,
                    label: 'Contact Number',
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                  ),
                  _buildField(
                    controller: emailController,
                    label: 'Email Address',
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  _buildField(
                    controller: addressController,
                    label: 'Complete Delivery Address',
                    icon: Icons.location_on,
                    maxLines: 3,
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Order Summary',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  Card(
                    color: const Color(0xFFF2F2F2),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (int i = 0; i < widget.items.length; i++) ...[
                            if (i > 0) const Divider(height: 24),
                            _buildItemSummary(widget.items[i]),
                          ],
                          const Divider(height: 24),
                          Text(
                            'Total: ${formatPeso(total)}',
                            style: const TextStyle(
                              fontSize: 20,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.payment),
                    label: const Text(
                      'Confirm & Pay',
                      style: TextStyle(fontSize: 17),
                    ),
                    onPressed: _submitting ? null : saveOrder,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemSummary(CartItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.productName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 8),
        Text('Color: ${item.color}'),
        Text('Capacity: ${item.capacity}'),
        Text('Quantity: ${item.quantity}'),
        Text('Unit Price: ${formatPeso(item.price)}'),
        Text(
          'Subtotal: ${formatPeso(item.subtotal)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Pakilagyan ang $label.';
          }

          if (label == 'Email Address' &&
              !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
            return 'Maglagay ng valid na email address.';
          }

          return null;
        },
      ),
    );
  }
}
