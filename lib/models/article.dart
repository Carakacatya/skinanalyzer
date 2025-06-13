class Article {
  final String id;
  final String title;
  final String description;
  final String imageUrl;

  Article({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['image_article'] ?? '',
    );
  }

  Map<String, String> toMap() {
    return {
      'id': id,
      'title': title,
      'content': description,
      'image': imageUrl,
    };
  }
}