import 'package:flutter/material.dart';
import '../services/language_service.dart';
import '../services/theme_service.dart';

class LanguageSheet extends StatefulWidget {
  final bool isDarkMode;
  final Color cardBackground;
  final Color primaryText;
  final Color secondaryText;
  final Function(String) onLanguageChanged;

  const LanguageSheet({
    super.key,
    required this.isDarkMode,
    required this.cardBackground,
    required this.primaryText,
    required this.secondaryText,
    required this.onLanguageChanged,
  });

  @override
  State<LanguageSheet> createState() => _LanguageSheetState();
}

class _LanguageSheetState extends State<LanguageSheet> {
  late String _selectedCode;

  @override
  void initState() {
    super.initState();
    _selectedCode = LanguageService.languageCode;
  }

  @override
  Widget build(BuildContext context) {
    final accent = ThemeService.accent;
    final languages = LanguageService.supportedLanguages;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      decoration: BoxDecoration(
        color: widget.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: widget.secondaryText.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            LanguageService.tr('language'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: widget.primaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            LanguageService.tr('choose_language'),
            style: TextStyle(
              fontSize: 13,
              color: widget.secondaryText,
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: languages.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: widget.isDarkMode
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.06),
              ),
              itemBuilder: (context, index) {
                final lang = languages[index];
                final code = lang['code']!;
                final isSelected = code == _selectedCode;

                return InkWell(
                  onTap: () {
                    setState(() => _selectedCode = code);
                    widget.onLanguageChanged(code);
                    Navigator.pop(context);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang['nativeName']!,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? accent
                                      : widget.primaryText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                lang['name']!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: widget.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? accent
                                  : widget.secondaryText.withValues(alpha: 0.4),
                              width: isSelected ? 6 : 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
