import 'package:flutter/material.dart';

class DarkPageRoute<T> extends MaterialPageRoute<T> {
  DarkPageRoute({required super.builder});

  @override
  Color? get barrierColor => const Color(0xFF1A1A1A);

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }
}

PageRouteBuilder<T> createDarkPageRoute<T>({
  required WidgetBuilder builder,
  bool isDarkMode = true,
}) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return Container(
        color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        child: FadeTransition(
          opacity: animation,
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 250),
    barrierColor: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
  );
}
