class User {
  final String username;
  final String email;
  final String skinType;

  User({
    required this.username,
    required this.email,
    required this.skinType,
  });

  // Konversi dari Map (biasanya dari SharedPreferences atau JSON)
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      skinType: json['skinType'] ?? '',
    );
  }

  // Konversi ke Map (untuk disimpan di SharedPreferences atau kirim ke API)
  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'email': email,
      'skinType': skinType,
    };
  }
}
