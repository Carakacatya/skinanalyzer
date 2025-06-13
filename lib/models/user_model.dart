// lib/models/user_model.dart
class User {
  String id;
  String username;
  String email;
  String phone;
  String skinType;

  User({
    this.id = '',
    this.username = 'Nama Pengguna',
    this.email = 'user@email.com',
    this.phone = '',
    this.skinType = 'Belum dianalisis',
  });

  factory User.fromMap(Map<String, dynamic> data) {
    return User(
      id: data['id']?.toString() ?? '',
      username: data['name']?.toString() ?? 'Nama Pengguna',
      email: data['email']?.toString() ?? 'user@email.com',
      phone: data['phone']?.toString() ?? '',
      skinType: data['skin_type']?.toString() ?? 'Belum dianalisis',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': username,
      'email': email,
      'phone': phone,
      'skin_type': skinType,
    };
  }

  User copyWith({
    String? id,
    String? username,
    String? email,
    String? phone,
    String? skinType,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      skinType: skinType ?? this.skinType,
    );
  }
}

class Address {
  String id;
  String userId;
  String street;
  String subdistrict;
  String city;
  String province;
  String postalCode;
  bool isDefault;

  Address({
    this.id = '',
    this.userId = '',
    this.street = '',
    this.subdistrict = '',
    this.city = '',
    this.province = '',
    this.postalCode = '',
    this.isDefault = false,
  });

  factory Address.fromMap(Map<String, dynamic> data) {
    return Address(
      id: data['id']?.toString() ?? '',
      userId: data['user_id']?.toString() ?? '',
      street: data['Jalan']?.toString() ?? '',
      subdistrict: data['Kecamatan']?.toString() ?? '',
      city: data['Kota']?.toString() ?? '',
      province: data['Provinsi']?.toString() ?? '',
      postalCode: data['Kode_pos']?.toString() ?? '',
      isDefault: data['is_default'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'Jalan': street,
      'Kecamatan': subdistrict,
      'Kota': city,
      'Provinsi': province,
      'Kode_pos': postalCode,
      'is_default': isDefault,
    };
  }

  String get formattedAddress {
    final parts = [
      if (street.isNotEmpty) street.trim(),
      if (subdistrict.isNotEmpty) subdistrict.trim(),
      if (city.isNotEmpty) city.trim(),
      if (province.isNotEmpty) province.trim(),
      if (postalCode.isNotEmpty) postalCode.trim(),
    ].where((part) => part.isNotEmpty);

    return parts.isEmpty ? '-' : parts.join(', ');
  }
}