import 'package:flutter/material.dart';
import '../services/language_service.dart';

/// Shared utilities for party-related display logic.
class PartyUtils {
  PartyUtils._();

  /// Returns a brand color for major Indian political parties.
  static Color getPartyColor(String party) {
    switch (party.toUpperCase()) {
      case 'BJP':
        return const Color(0xFFFF9933);
      case 'INC':
        return const Color(0xFF19AAED);
      case 'AAP':
        return const Color(0xFF0066B3);
      case 'TMC':
        return const Color(0xFF00A651);
      case 'DMK':
        return const Color(0xFFE71C23);
      case 'SP':
        return const Color(0xFFE40612);
      case 'BSP':
        return const Color(0xFF22409A);
      default:
        return const Color(0xFF5A5A5A);
    }
  }

  /// Returns a localized label for a representative's office type.
  static String getOfficeLabel(String officeType) {
    switch (officeType) {
      case 'LOK_SABHA':
        return LanguageService.tr('member_of_parliament');
      case 'STATE_ASSEMBLY':
        return LanguageService.tr('mla');
      case 'RAJYA_SABHA':
        return LanguageService.tr('rajya_sabha_mp');
      case 'VIDHAN_PARISHAD':
        return LanguageService.tr('mlc');
      default:
        return LanguageService.translitName(officeType);
    }
  }

  /// Transliterate text to the active language only when needed.
  /// If the text already contains non-ASCII (Indic) characters, it's returned
  /// as-is. English mode also short-circuits.
  static String safeTranslit(String text) {
    if (text.isEmpty || LanguageService.isEnglish) return text;
    if (text.runes.any((r) => r > 127)) return text; // already transliterated
    return LanguageService.translitName(text);
  }
}
