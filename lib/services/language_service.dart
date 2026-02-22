import 'package:inditrans/inditrans.dart' as inditrans;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_translations.dart';

class LanguageService {
  static String _languageCode = 'en';
  static bool _initialized = false;

  static String get languageCode => _languageCode;
  static bool get isEnglish => _languageCode == 'en';

  /// Call once at app start (after WidgetsFlutterBinding.ensureInitialized)
  static Future<void> init() async {
    if (_initialized) return;
    await inditrans.init();
    final prefs = await SharedPreferences.getInstance();
    _languageCode = prefs.getString('app_language') ?? 'en';
    _initialized = true;
  }

  /// Change the app language and persist
  static Future<void> setLanguage(String code) async {
    _languageCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', code);
    // Clear transliteration cache when language changes
    _translitCache.clear();
    _reverseTranslitCache.clear();
  }

  /// Translate a UI string key
  static String tr(String key) {
    return AppTranslations.get(key, _languageCode);
  }

  // ─── Name transliteration ──────────────────────────────────────

  /// In-memory cache: "en_name|langCode" → transliterated string
  static final Map<String, String> _translitCache = {};

  /// In-memory cache for reverse: "indicText|langCode" → Latin string
  static final Map<String, String> _reverseTranslitCache = {};

  /// Transliterate an English name to the current language script.
  /// Returns the original name for English or unknown languages.
  static String translitName(String name) {
    if (_languageCode == 'en' || name.isEmpty) return name;

    final cacheKey = '$name|$_languageCode';
    if (_translitCache.containsKey(cacheKey)) {
      return _translitCache[cacheKey]!;
    }

    final target = _scriptForLang(_languageCode);
    if (target == null) return name;

    try {
      final result = inditrans.transliterate(
        name,
        inditrans.Script.readableLatin,
        target,
      );
      _translitCache[cacheKey] = result;
      return result;
    } catch (_) {
      return name;
    }
  }

  /// Reverse-transliterate Indic script text to Latin for API queries.
  /// If user types "बूंदी" in Hindi, returns "bundi" (readable Latin).
  /// Returns the original text for English or if detection fails.
  static String translitToLatin(String text) {
    if (_languageCode == 'en' || text.isEmpty) return text;

    // Check if any character is non-ASCII (Indic script)
    final hasIndic = text.runes.any((c) => c > 127);
    if (!hasIndic) return text; // Already Latin

    final cacheKey = '$text|$_languageCode';
    if (_reverseTranslitCache.containsKey(cacheKey)) {
      return _reverseTranslitCache[cacheKey]!;
    }

    final source = _scriptForLang(_languageCode);
    if (source == null) return text;

    try {
      final result = inditrans.transliterate(
        text,
        source,
        inditrans.Script.readableLatin,
      );
      _reverseTranslitCache[cacheKey] = result;
      return result;
    } catch (_) {
      return text;
    }
  }

  static inditrans.Script? _scriptForLang(String code) {
    switch (code) {
      case 'hi':
      case 'mr':
        return inditrans.Script.devanagari;
      case 'ta':
        return inditrans.Script.tamil;
      case 'te':
        return inditrans.Script.telugu;
      case 'kn':
        return inditrans.Script.kannada;
      case 'ml':
        return inditrans.Script.malayalam;
      case 'bn':
        return inditrans.Script.bengali;
      case 'gu':
        return inditrans.Script.gujarati;
      case 'pa':
        return inditrans.Script.gurmukhi;
      default:
        return null;
    }
  }

  // ─── Supported languages list ──────────────────────────────────

  static const List<Map<String, String>> supportedLanguages = [
    {'code': 'en', 'name': 'English', 'nativeName': 'English'},
    {'code': 'hi', 'name': 'Hindi', 'nativeName': 'हिन्दी'},
    {'code': 'mr', 'name': 'Marathi', 'nativeName': 'मराठी'},
    {'code': 'ta', 'name': 'Tamil', 'nativeName': 'தமிழ்'},
    {'code': 'te', 'name': 'Telugu', 'nativeName': 'తెలుగు'},
    {'code': 'kn', 'name': 'Kannada', 'nativeName': 'ಕನ್ನಡ'},
    {'code': 'ml', 'name': 'Malayalam', 'nativeName': 'മലയാളം'},
    {'code': 'bn', 'name': 'Bengali', 'nativeName': 'বাংলা'},
    {'code': 'gu', 'name': 'Gujarati', 'nativeName': 'ગુજરાતી'},
    {'code': 'pa', 'name': 'Punjabi', 'nativeName': 'ਪੰਜਾਬੀ'},
  ];

  /// Google News RSS URL language parameters for the current app language.
  /// All supported languages are Indian, so gl=IN is fixed.
  /// Example for Hindi: 'hl=hi-IN&gl=IN&ceid=IN:hi'
  static String get newsGlParams {
    return 'hl=$_languageCode-IN&gl=IN&ceid=IN:$_languageCode';
  }

  /// Get the display name of the current language
  static String get currentLanguageName {
    final lang = supportedLanguages.firstWhere(
      (l) => l['code'] == _languageCode,
      orElse: () => supportedLanguages.first,
    );
    return lang['nativeName']!;
  }
}
