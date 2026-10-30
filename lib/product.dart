class ProductVariant {
  final String id;
  final String capacity;
  final int price;

  const ProductVariant({
    required this.id,
    required this.capacity,
    required this.price,
  });

  factory ProductVariant.fromMap(Map<String, dynamic> data) {
    return ProductVariant(
      id: data['id'] as String,
      capacity: data['capacity'] as String,
      price: (data['price'] as num).toInt(),
    );
  }
}

class Product {
  final String id;
  final String name;
  final String imagePath;
  final List<ProductVariant> variants;

  const Product({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.variants,
  });

  factory Product.fromMap(Map<String, dynamic> data) {
    final rawVariants = data['product_variants'] as List<dynamic>? ?? [];
    return Product(
      id: data['id'] as String,
      name: data['name'] as String,
      imagePath: data['image_path'] as String,
      variants: rawVariants
          .whereType<Map>()
          .map(
            (variant) =>
                ProductVariant.fromMap(Map<String, dynamic>.from(variant)),
          )
          .toList(),
    );
  }
}
