import 'package:flutter/material.dart';

Route<T> appPageRoute<T>(Widget page) => PageRouteBuilder<T>(
  pageBuilder: (_, _, _) => page,
  transitionDuration: const Duration(milliseconds: 220),
  reverseTransitionDuration: const Duration(milliseconds: 180),
  transitionsBuilder: (_, animation, _, child) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(.035, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  },
);
