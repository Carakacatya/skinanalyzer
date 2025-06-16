class Product {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final String description;
  final String category;
  final int stock;
  final String sku;
  final String brand;
  final String ingredients;
  final String howToUse;
  final String benefits;
  final List<String> skinTypes;
  final bool isFeatured;
  final bool isActive;
  final double ratingAverage;
  final int ratingCount;
  final DateTime created;
  final DateTime updated;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.description,
    required this.category,
    required this.stock,
    required this.sku,
    required this.brand,
    required this.ingredients,
    required this.howToUse,
    required this.benefits,
    required this.skinTypes,
    required this.isFeatured,
    required this.isActive,
    required this.ratingAverage,
    required this.ratingCount,
    required this.created,
    required this.updated,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      imageUrl: json['image_url'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      stock: json['stock'] ?? 0,
      sku: json['sku'] ?? '',
      brand: json['brand'] ?? '',
      ingredients: json['ingredients'] ?? '',
      howToUse: json['how_to_use'] ?? '',
      benefits: json['benefits'] ?? '',
      skinTypes: _parseSkinTypes(json['skin_types']),
      isFeatured: json['is_featured'] ?? false,
      isActive: json['is_active'] ?? true,
      ratingAverage: (json['rating_average'] ?? 0).toDouble(),
      ratingCount: json['rating_count'] ?? 0,
      created: DateTime.tryParse(json['created'] ?? '') ?? DateTime.now(),
      updated: DateTime.tryParse(json['updated'] ?? '') ?? DateTime.now(),
    );
  }

  static List<String> _parseSkinTypes(dynamic skinTypes) {
    if (skinTypes == null) return [];
    if (skinTypes is String) {
      try {
        // Try to parse as JSON array
        final decoded = skinTypes.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '');
        return decoded.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      } catch (e) {
        return [skinTypes];
      }
    }
    if (skinTypes is List) {
      return skinTypes.map((e) => e.toString()).toList();
    }
    return [];
  }
}

class Category {
  final String id;
  final String name;
  final String description;
  final String icon;
  final String color;
  final bool isActive;
  final int sortOrder;

  Category({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.isActive,
    required this.sortOrder,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      icon: json['icon'] ?? '',
      color: json['color'] ?? '#EC407A',
      isActive: json['is_active'] ?? true,
      sortOrder: json['sort_order'] ?? 0,
    );
  }
}

class ProductImage {
  final String id;
  final String productId;
  final String imageUrl;
  final String altText;
  final int sortOrder;
  final bool isPrimary;

  ProductImage({
    required this.id,
    required this.productId,
    required this.imageUrl,
    required this.altText,
    required this.sortOrder,
    required this.isPrimary,
  });

  factory ProductImage.fromJson(Map<String, dynamic> json) {
    return ProductImage(
      id: json['id'] ?? '',
      productId: json['product_id'] ?? '',
      imageUrl: json['image_url'] ?? '',
      altText: json['alt_text'] ?? '',
      sortOrder: json['sort_order'] ?? 0,
      isPrimary: json['is_primary'] ?? false,
    );
  }
}

class ProductVariant {
  final String id;
  final String productId;
  final String variantType;
  final String variantValue;
  final double priceAdjustment;
  final int stock;
  final String sku;
  final bool isActive;

  ProductVariant({
    required this.id,
    required this.productId,
    required this.variantType,
    required this.variantValue,
    required this.priceAdjustment,
    required this.stock,
    required this.sku,
    required this.isActive,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      id: json['id'] ?? '',
      productId: json['product_id'] ?? '',
      variantType: json['variant_type'] ?? '',
      variantValue: json['variant_value'] ?? '',
      priceAdjustment: (json['price_adjustment'] ?? 0).toDouble(),
      stock: json['stock'] ?? 0,
      sku: json['sku'] ?? '',
      isActive: json['is_active'] ?? true,
    );
  }
}

class ProductReview {
  final String id;
  final String productId;
  final String userId;
  final int rating;
  final String title;
  final String comment;
  final bool isVerifiedPurchase;
  final int helpfulCount;
  final bool isApproved;
  final DateTime created;
  final String? userName;
  final String? userAvatar;

  ProductReview({
    required this.id,
    required this.productId,
    required this.userId,
    required this.rating,
    required this.title,
    required this.comment,
    required this.isVerifiedPurchase,
    required this.helpfulCount,
    required this.isApproved,
    required this.created,
    this.userName,
    this.userAvatar,
  });

  factory ProductReview.fromJson(Map<String, dynamic> json) {
    return ProductReview(
      id: json['id'] ?? '',
      productId: json['product_id'] ?? '',
      userId: json['user_id'] ?? '',
      rating: json['rating'] ?? 0,
      title: json['title'] ?? '',
      comment: json['comment'] ?? '',
      isVerifiedPurchase: json['is_verified_purchase'] ?? false,
      helpfulCount: json['helpful_count'] ?? 0,
      isApproved: json['is_approved'] ?? true,
      created: DateTime.tryParse(json['created'] ?? '') ?? DateTime.now(),
      userName: json['expand']?['user_id']?['name'],
      userAvatar: json['expand']?['user_id']?['avatar'],
    );
  }
}
