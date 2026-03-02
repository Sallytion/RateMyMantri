import 'package:shared_preferences/shared_preferences.dart';

/// Pre-fetched SharedPreferences singleton.
/// Call [init] once in main() before runApp().
class PrefsService {
  static late final SharedPreferences instance;

  static Future<void> init() async {
    instance = await SharedPreferences.getInstance();
  }
}
