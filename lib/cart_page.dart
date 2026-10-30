import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cart_data.dart';
import 'checkout_page.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  static const Color headerBlue = Color(0xFF38B6FF);

  final Set<String> selectedIds = {};
  late Future<List<CartItem>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _itemsFuture = _loadItems();
  }

  Future<List<CartItem>> _loadItems() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw StateError('Sign in before viewing your cart.');
    }

    final rows = await Supabase.instance.client
        .from('cart_items')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return rows.map((row) => CartItem.fromMap(row)).toList();
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
      appBar: AppBar(
        backgroundColor: headerBlue,
        title: const Text(
          'My Cart',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<List<CartItem>>(
        future: _itemsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load cart items: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 80,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 12),
                  Text('Your cart is empty.', style: TextStyle(fontSize: 18)),
                ],
              ),
            );
          }

          final selectedItems = items
              .where((item) => item.id != null && selectedIds.contains(item.id))
              .toList();
          final selectedTotal = selectedItems.fold<int>(
            0,
            (total, item) => total + item.subtotal,
          );

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final id = item.id!;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: selectedIds.contains(id),
                              activeColor: headerBlue,
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    selectedIds.add(id);
                                  } else {
                                    selectedIds.remove(id);
                                  }
                                });
                              },
                            ),
                            SizedBox(
                              width: 75,
                              height: 100,
                              child: item.imagePath.isNotEmpty
                                  ? Image.asset(
                                      item.imagePath,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stack) =>
                                          const Icon(
                                            Icons.phone_iphone,
                                            size: 50,
                                          ),
                                    )
                                  : const Icon(Icons.phone_iphone, size: 50),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text('Color: ${item.color}'),
                                  Text('Capacity: ${item.capacity}'),
                                  Text('Quantity: ${item.quantity}'),
                                  Text(
                                    'Unit Price: ${formatPrice(item.price)}',
                                  ),
                                  Text(
                                    'Subtotal: ${formatPrice(item.subtotal)}',
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Remove item',
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () async {
                                try {
                                  final user =
                                      Supabase.instance.client.auth.currentUser;
                                  if (user == null) {
                                    throw StateError(
                                      'Sign in before removing cart items.',
                                    );
                                  }

                                  await Supabase.instance.client
                                      .from('cart_items')
                                      .delete()
                                      .eq('id', id)
                                      .eq('user_id', user.id);

                                  if (!mounted) return;
                                  setState(() {
                                    selectedIds.remove(id);
                                    _itemsFuture = _loadItems();
                                  });
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Failed to remove item: $e',
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(color: Color(0xFFF2F2F2)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Selected Total:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          formatPrice(selectedTotal),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: headerBlue,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.all(14),
                        ),
                        icon: const Icon(Icons.shopping_bag),
                        label: Text(
                          'Checkout Selected (${selectedItems.length})',
                        ),
                        onPressed: selectedItems.isEmpty
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        CheckoutPage(items: selectedItems),
                                  ),
                                );
                              },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
