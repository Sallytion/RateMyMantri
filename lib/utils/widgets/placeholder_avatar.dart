import 'package:flutter/material.dart';
import '../../services/theme_service.dart';

/// A reusable placeholder avatar that shows a single initial letter inside
/// a gradient (or flat-color) circle / container.
class PlaceholderAvatar extends StatelessWidget {
  /// The name whose first letter is displayed. Falls back to '?' if empty.
  final String name;

  /// Font size of the initial letter. Defaults to 24.
  final double fontSize;

  /// Whether to use a gradient background. Defaults to true.
  final bool useGradient;

  const PlaceholderAvatar({
    super.key,
    required this.name,
    this.fontSize = 24,
    this.useGradient = true,
  });

  @override
  Widget build(BuildContext context) {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      decoration: useGradient
          ? BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  ThemeService.accent,
                  ThemeService.accent.withValues(alpha: 0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            )
          : BoxDecoration(color: ThemeService.accent),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: fontSize,
          ),
        ),
      ),
    );
  }
}
