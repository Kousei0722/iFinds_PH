class CartItem {
  final String? id;
  final String? productId;
  final String? productVariantId;
  final String productName;
  final String imagePath;
  final int price;
  final String color;
  final String capacity;
  final int quantity;

  CartItem({
    this.id,
    this.productId,
    this.productVariantId,
    required this.productName,
    required this.imagePath,
    required this.price,
    required this.color,
    required this.capacity,
    required this.quantity,
  });

  int get subtotal => price * quantity;

  factory CartItem.fromMap(Map<String, dynamic> data) {
    return CartItem(
      id: data['id']?.toString(),
      productId: data['product_id']?.toString(),
      productVariantId: data['product_variant_id']?.toString(),
      productName: data['product_name'] as String? ?? 'Product',
      imagePath: data['image_path'] as String? ?? '',
      price: (data['price'] as num?)?.toInt() ?? 0,
      color: data['selected_color'] as String? ?? '',
      capacity: data['selected_capacity'] as String? ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap({required String userId}) => {
    'user_id': userId,
    'product_id': productId,
    'product_variant_id': productVariantId,
    'product_name': productName,
    'image_path': imagePath,
    'price': price,
    'selected_color': color,
    'selected_capacity': capacity,
    'quantity': quantity,
  };
}

String formatPeso(int amount) {
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
