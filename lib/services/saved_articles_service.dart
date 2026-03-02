import 'dart:convert';
import 'prefs_service.dart';

class SavedArticle {
  final String title;
  final String link;
  final String source;
  final String pubDate;
  final String? decodedUrl;
  final String? articleText;
  final String? imageUrl;
  final DateTime savedAt;

  SavedArticle({
    required this.title,
    required this.link,
    required this.source,
    required this.pubDate,
    this.decodedUrl,
    this.articleText,
    this.imageUrl,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'link': link,
      'source': source,
      'pubDate': pubDate,
      'decodedUrl': decodedUrl,
      'articleText': articleText,
      'imageUrl': imageUrl,
      'savedAt': savedAt.toIso8601String(),
    };
  }

  factory SavedArticle.fromJson(Map<String, dynamic> json) {
    return SavedArticle(
      title: json['title'] as String,
      link: json['link'] as String,
      source: json['source'] as String,
      pubDate: json['pubDate'] as String,
      decodedUrl: json['decodedUrl'] as String?,
      articleText: json['articleText'] as String?,
      imageUrl: json['imageUrl'] as String?,
      savedAt: DateTime.parse(json['savedAt'] as String),
    );
  }
}

class SavedArticlesService {
  static const String _key = 'saved_articles';
  static SavedArticlesService? _instance;

  SavedArticlesService._();

  factory SavedArticlesService() {
    _instance ??= SavedArticlesService._();
    return _instance!;
  }

  Future<List<SavedArticle>> getSavedArticles() async {
    final prefs = PrefsService.instance;
    final String? articlesJson = prefs.getString(_key);
    if (articlesJson == null) return [];

    final List<dynamic> articlesList = json.decode(articlesJson);
    return articlesList.map((json) => SavedArticle.fromJson(json)).toList();
  }

  Future<bool> saveArticle(SavedArticle article) async {
    final prefs = PrefsService.instance;
    final articles = await getSavedArticles();
    
    // Check if article already exists (by link)
    if (articles.any((a) => a.link == article.link)) {
      return false; // Already saved
    }

    articles.insert(0, article); // Add to beginning
    final articlesJson = json.encode(articles.map((a) => a.toJson()).toList());
    return await prefs.setString(_key, articlesJson);
  }

  Future<bool> removeArticle(String link) async {
    final prefs = PrefsService.instance;
    final articles = await getSavedArticles();
    articles.removeWhere((a) => a.link == link);
    
    final articlesJson = json.encode(articles.map((a) => a.toJson()).toList());
    return await prefs.setString(_key, articlesJson);
  }

  Future<bool> isArticleSaved(String link) async {
    final articles = await getSavedArticles();
    return articles.any((a) => a.link == link);
  }

  Future<bool> clearAll() async {
    final prefs = PrefsService.instance;
    return await prefs.remove(_key);
  }
}
