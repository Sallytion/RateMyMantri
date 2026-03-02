import 'package:flutter/material.dart';
import '../services/language_service.dart';

/// Centralised language state. Wraps LanguageService so widgets rebuild
/// on language change via `context.watch<LanguageProvider>()`.
class LanguageProvider extends ChangeNotifier {
  String _code = LanguageService.languageCode;

  String get code => _code;

  /// Change language, persist, and notify listeners.
  Future<void> setLanguage(String code) async {
    await LanguageService.setLanguage(code);
    _code = code;
    notifyListeners();
  }

  /// Convenience – delegates to LanguageService.tr
  String tr(String key) => LanguageService.tr(key);
}
