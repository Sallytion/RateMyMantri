import 'package:flutter/material.dart';
import '../services/language_service.dart';
import '../pages/home_page.dart';
import '../pages/news_page.dart';
import '../pages/rate_page.dart';
import '../pages/search_page.dart';

/// Centralised language state. Wraps LanguageService so widgets rebuild
/// on language change via `context.watch<LanguageProvider>()`.
class LanguageProvider extends ChangeNotifier {
  String _code = LanguageService.languageCode;

  String get code => _code;

  /// Change language, persist, clear stale caches, and notify listeners.
  Future<void> setLanguage(String code) async {
    await LanguageService.setLanguage(code);
    _code = code;
    // Clear static caches so pages re-fetch in the new language
    HomePage.clearCache();
    NewsPage.clearCache();
    RatePage.clearCache();
    SearchPage.clearCache();
    notifyListeners();
  }

  /// Convenience – delegates to LanguageService.tr
  String tr(String key) => LanguageService.tr(key);
}
