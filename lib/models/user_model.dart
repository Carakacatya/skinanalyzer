class User {
  final String id;
  final String username;
  final String email;
  final String phone;
  final String skinType;
  final String? avatarUrl;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.phone,
    required this.skinType,
    this.avatarUrl,
  });

  User copyWith({
    String? id,
    String? username,
    String? email,
    String? phone,
    String? skinType,
    String? avatarUrl,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      skinType: skinType ?? this.skinType,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'phone': phone,
      'skinType': skinType,
      'avatarUrl': avatarUrl,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      skinType: json['skinType'] ?? 'Belum dianalisis',
      avatarUrl: json['avatarUrl'],
    );
  }
}

class Address {
  final String id;
  final String userId;
  final String street;
  final String subdistrict;
  final String city;
  final String province;
  final String postalCode;
  final bool isDefault;

  const Address({
    required this.id,
    required this.userId,
    required this.street,
    required this.subdistrict,
    required this.city,
    required this.province,
    required this.postalCode,
    this.isDefault = false,
  });

  Address copyWith({
    String? id,
    String? userId,
    String? street,
    String? subdistrict,
    String? city,
    String? province,
    String? postalCode,
    bool? isDefault,
  }) {
    return Address(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      street: street ?? this.street,
      subdistrict: subdistrict ?? this.subdistrict,
      city: city ?? this.city,
      province: province ?? this.province,
      postalCode: postalCode ?? this.postalCode,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'street': street,
      'subdistrict': subdistrict,
      'city': city,
      'province': province,
      'postalCode': postalCode,
      'isDefault': isDefault,
    };
  }

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      street: json['street'] ?? '',
      subdistrict: json['subdistrict'] ?? '',
      city: json['city'] ?? '',
      province: json['province'] ?? '',
      postalCode: json['postalCode'] ?? '',
      isDefault: json['isDefault'] ?? false,
    );
  }
}

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final double rating;
  final String imageUrl;
  final List<String> skinTypes;
  final String? brand;
  final String? ingredients;
  final String? howToUse;
  final String? benefits;
  final String? category;
  final bool isFeatured;
  final DateTime created;
  final DateTime updated;

  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.rating,
    required this.imageUrl,
    required this.skinTypes,
    this.brand,
    this.ingredients,
    this.howToUse,
    this.benefits,
    this.category,
    this.isFeatured = false,
    required this.created,
    required this.updated,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      rating: (json['rating'] ?? 0).toDouble(),
      imageUrl: json['image_url'] ?? '',
      skinTypes: List<String>.from(json['skin_type'] ?? []),
      brand: json['brand'],
      ingredients: json['ingredients'],
      howToUse: json['how_to_use'],
      benefits: json['benefits'],
      category: json['category'],
      isFeatured: json['is_featured'] ?? false,
      created: DateTime.parse(json['created'] ?? DateTime.now().toIso8601String()),
      updated: DateTime.parse(json['updated'] ?? DateTime.now().toIso8601String()),
    );
  }
}
