import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'store_page.dart';

class BuyingSuccesPage extends StatelessWidget {
  final String orderId;

  const BuyingSuccesPage({super.key, required this.orderId});

  static const Color headerBlue = Color(0xFF38B6FF);
  static const Color backgroundColor = Color(0xFFF5F8FC);
  static const Color darkBlue = Color(0xFF1769AA);

  Future<Map<String, dynamic>> _loadOrder() async {
    final result = await Supabase.instance.client.rpc(
      'get_order_details',
      params: {'p_order_id': orderId},
    );

    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }
    if (result is List && result.isNotEmpty && result.first is Map) {
      return Map<String, dynamic>.from(result.first as Map);
    }
    throw const FormatException('Order details were not returned.');
  }

  String formatPrice(int amount) {
    final value = amount.toString();
    final result = StringBuffer();

    for (int i = 0; i < value.length; i++) {
      if (i > 0 && (value.length - i) % 3 == 0) {
        result.write(',');
      }
      result.write(value[i]);
    }

    return '₱$result';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _loadOrder(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text('Unable to load order details: ${snapshot.error}'),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: headerBlue),
              );
            }

            if (snapshot.data == null) {
              return const Center(child: Text('No order details found.'));
            }

            final data = snapshot.data!;

            final rawProducts = data['products'] as List<dynamic>? ?? [];
            final products = rawProducts
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList();

            final total =
                ((data['totalPrice'] ?? data['total_price']) as num?)
                    ?.toInt() ??
                0;

            return Column(
              children: [
                // SUCCESS HEADER
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 25, 20, 28),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF38B6FF), Color(0xFF168DE2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 85,
                        height: 85,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 65,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Order Placed Successfully!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Thank you for shopping with iFinds PH.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified, color: Colors.white, size: 18),
                            SizedBox(width: 7),
                            Text(
                              'Order Confirmation',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ORDER DETAILS
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(18),
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.shopping_bag_outlined,
                            color: darkBlue,
                            size: 27,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Your Order',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: darkBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      ...products.map((product) {
                        final name =
                            product['productName'] ??
                            product['product_name'] ??
                            'Product';
                        final imagePath =
                            (product['imagePath'] ?? product['image_path'])
                                ?.toString() ??
                            '';
                        final color =
                            product['selectedColor'] ??
                            product['selected_color'] ??
                            '';
                        final capacity =
                            product['selectedCapacity'] ??
                            product['selected_capacity'] ??
                            '';
                        final quantity =
                            (product['quantity'] as num?)?.toInt() ?? 1;
                        final price = (product['price'] as num?)?.toInt() ?? 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE5EDF5)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withValues(alpha: 0.05),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 85,
                                height: 100,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F7FC),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: imagePath.isNotEmpty
                                    ? Image.asset(
                                        imagePath,
                                        fit: BoxFit.contain,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return const Icon(
                                                Icons.phone_iphone,
                                                size: 48,
                                                color: darkBlue,
                                              );
                                            },
                                      )
                                    : const Icon(
                                        Icons.phone_iphone,
                                        size: 48,
                                        color: darkBlue,
                                      ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name.toString(),
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    _detailRow(
                                      Icons.palette_outlined,
                                      'Color: $color',
                                    ),
                                    _detailRow(
                                      Icons.sd_storage_outlined,
                                      'Capacity: $capacity',
                                    ),
                                    _detailRow(
                                      Icons.shopping_cart_outlined,
                                      'Quantity: $quantity',
                                    ),
                                    const Divider(height: 18),
                                    Text(
                                      'Unit Price: ${formatPrice(price)}',
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Subtotal: ${formatPrice(price * quantity)}',
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      // CUSTOMER INFORMATION
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE5EDF5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.person_outline,
                                  color: darkBlue,
                                  size: 25,
                                ),
                                SizedBox(width: 9),
                                Text(
                                  'Customer Information',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: darkBlue,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 25),
                            _detailRow(
                              Icons.person,
                              'Name: ${data['name'] ?? data['customer_name'] ?? data['customerName'] ?? ''}',
                            ),
                            const SizedBox(height: 10),
                            _detailRow(
                              Icons.phone,
                              'Phone: ${data['phone'] ?? ''}',
                            ),
                            const SizedBox(height: 10),
                            _detailRow(
                              Icons.email_outlined,
                              'Email: ${data['email'] ?? ''}',
                            ),
                            const SizedBox(height: 10),
                            _detailRow(
                              Icons.location_on_outlined,
                              'Address: ${data['address'] ?? ''}',
                            ),
                            const SizedBox(height: 10),
                            _detailRow(
                              Icons.payment,
                              'Payment: ${data['paymentMethod'] ?? data['payment_method'] ?? ''}',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 15),

                      // GRAND TOTAL
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5F4FF),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: headerBlue.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Grand Total',
                                    style: TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.bold,
                                      color: darkBlue,
                                    ),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    'Total amount of your order',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                formatPrice(total),
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  fontSize: 23,
                                  color: Colors.red,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // BACK TO STORE BUTTON
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: headerBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 17),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.storefront),
                      label: const Text(
                        'Back to Store',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const StorePage(),
                          ),
                          (route) => false,
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static Widget _detailRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: darkBlue),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
