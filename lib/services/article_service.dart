import 'package:pocketbase/pocketbase.dart';
import '../models/article.dart';
import '../providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ArticleService {
  final PocketBase pb;

  ArticleService(this.pb);

  // Singleton pattern
  static ArticleService? _instance;
  static ArticleService getInstance(BuildContext context) {
    if (_instance == null) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      _instance = ArticleService(authProvider.pb);
    }
    return _instance!;
  }

  Future<List<Article>> getArticles() async {
    try {
      final records = await pb.collection('articles').getFullList(
        sort: '-created',
      );

      return records.map((record) => Article.fromJson({
        'id': record.id,
        'title': record.data['title'] ?? '',
        'description': record.data['description'] ?? '',
        'image_article': record.data['image_article'] ?? '',
      })).toList();
    } catch (e) {
      print('Error fetching articles: $e');
      return [];
    }
  }

  Future<Article?> getArticleById(String id) async {
    try {
      final record = await pb.collection('articles').getOne(id);
      
      return Article.fromJson({
        'id': record.id,
        'title': record.data['title'] ?? '',
        'description': record.data['description'] ?? '',
        'image_article': record.data['image_article'] ?? '',
      });
    } catch (e) {
      print('Error fetching article: $e');
      return null;
    }
  }

  String getImageUrl(String imageUrl) {
    if (imageUrl.startsWith('http')) {
      return imageUrl;
    }
    return imageUrl;
  }
}