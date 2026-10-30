import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'checkout_page.dart';
import 'cart_page.dart';
import 'cart_data.dart';
import 'product.dart';

class ProductDetailsPage extends StatefulWidget {
  final String productId;
  final String productName;
  final String imagePath;
  final List<ProductVariant> variants;

  const ProductDetailsPage({
    super.key,
    required this.productId,
    required this.productName,
    required this.imagePath,
    required this.variants,
  });

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  static const Color headerBlue = Color(0xFF38B6FF);

  String selectedColor = 'Silver';
  String selectedCapacity = '256GB';
  int quantity = 0;

  ProductVariant? get selectedVariant {
    for (final variant in widget.variants) {
      if (variant.capacity == selectedCapacity) return variant;
    }
    return null;
  }

  int get currentPrice => selectedVariant?.price ?? 0;

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

  String get productPrice => formatPrice(currentPrice);

  Future<void> addToCart() async {
    if (quantity <= 0) {
      _showMessage('Pumili muna ng quantity.');
      return;
    }

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw StateError('Sign in before adding items to your cart.');
      }
      final variant = selectedVariant;
      if (variant == null) {
        throw StateError('This product capacity is unavailable.');
      }

      await Supabase.instance.client
          .from('cart_items')
          .insert(
            CartItem(
              productId: widget.productId,
              productVariantId: variant.id,
              productName: widget.productName,
              imagePath: widget.imagePath,
              price: currentPrice,
              color: selectedColor,
              capacity: selectedCapacity,
              quantity: quantity,
            ).toMap(userId: user.id),
          );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CartPage()),
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage('Failed to add to cart: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: headerBlue,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'iFinds PH',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back, size: 30, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            tooltip: 'View Cart',
            icon: const Icon(
              Icons.shopping_cart,
              size: 28,
              color: Colors.black,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CartPage()),
              );
            },
          ),
        ],
      ),

      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 700;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 4, child: _buildImages()),
                      const SizedBox(width: 24),
                      Expanded(flex: 6, child: _buildDetails()),
                    ],
                  )
                : Column(
                    children: [
                      _buildImages(),
                      const SizedBox(height: 20),
                      _buildDetails(),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _buildImages() {
    return Column(
      children: [
        Container(
          height: 300,
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 2),
          ),
          child: Image.asset(
            widget.imagePath,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.phone_iphone,
                size: 150,
                color: Colors.grey,
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          color: const Color(0xFFEEEEEE),
          padding: const EdgeInsets.all(16),
          child: const Column(
            children: [
              Text('Display: 6.9 inches'),
              SizedBox(height: 12),
              Text('Rear cameras: 3 × 48MP'),
              SizedBox(height: 12),
              Text('Storage: 256GB-512GB–1TB'),
              SizedBox(height: 12),
              Text('Weight: varies by model'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: const Color(0xFFEEEEEE),
          padding: const EdgeInsets.all(12),
          child: Text(
            'Apple ${widget.productName.replaceAll('\n', ' ')}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
        ),

        Container(
          color: const Color(0xFFA7D6E8),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Text('PRICE: ', style: TextStyle(fontSize: 17)),
              Text(
                productPrice,
                style: const TextStyle(
                  fontSize: 25,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        const Text('Color:', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 8),

        Wrap(
          spacing: 8,
          children: [
            _colorOption('Silver'),
            _colorOption('black'),
            _colorOption('Cosmic Orange'),
            _colorOption('Deep Blue'),
          ],
        ),

        const SizedBox(height: 18),

        const Text('Capacity:', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 8),

        Wrap(
          spacing: 8,
          children: widget.variants
              .map((variant) => _capacityOption(variant.capacity))
              .toList(),
        ),

        const SizedBox(height: 20),

        Row(
          children: [
            const Text('Quantity:', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () {
                if (quantity > 0) {
                  setState(() => quantity--);
                }
              },
              child: const Text('-'),
            ),
            Container(
              width: 60,
              alignment: Alignment.center,
              child: Text('$quantity', style: const TextStyle(fontSize: 18)),
            ),
            OutlinedButton(
              onPressed: () => setState(() => quantity++),
              child: const Text('+'),
            ),
          ],
        ),

        const SizedBox(height: 24),

        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
              onPressed: () {
                if (quantity == 0) {
                  _showMessage('Pumili muna ng quantity.');
                  return;
                }
                final variant = selectedVariant;
                if (variant == null) {
                  _showMessage('This product capacity is unavailable.');
                  return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CheckoutPage(
                      items: [
                        CartItem(
                          productId: widget.productId,
                          productVariantId: variant.id,
                          productName: widget.productName,
                          imagePath: widget.imagePath,
                          price: currentPrice,
                          color: selectedColor,
                          capacity: selectedCapacity,
                          quantity: quantity,
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: const Text('Buy now'),
            ),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink[100],
                foregroundColor: Colors.black,
                padding: const EdgeInsets.all(16),
              ),
              onPressed: addToCart,
              child: const Text('Add to cart'),
            ),

            OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: headerBlue.withValues(alpha: 0.3),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.all(16),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Back to store',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _colorOption(String color) {
    return ChoiceChip(
      label: Text(color),
      selected: selectedColor == color,
      onSelected: (selected) {
        if (selected) {
          setState(() => selectedColor = color);
        }
      },
    );
  }

  Widget _capacityOption(String capacity) {
    return ChoiceChip(
      label: Text(capacity),
      selected: selectedCapacity == capacity,
      onSelected: (selected) {
        if (selected) {
          setState(() => selectedCapacity = capacity);
        }
      },
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
