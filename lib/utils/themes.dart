import 'package:flutter/material.dart';

enum CurrentTheme { dark, light }

final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF4DA3FF),
    brightness: Brightness.dark,
  ),
  scaffoldBackgroundColor: const Color(0xFF0B0F14),
  textTheme: const TextTheme(
    titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
    bodySmall: TextStyle(color: Colors.white70),
  ),
  unselectedWidgetColor: Colors.white70,
);

final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF0057B8),
    brightness: Brightness.light,
  ),
  scaffoldBackgroundColor: const Color(0xFFF7F9FC),
  textTheme: const TextTheme(
    titleLarge:
        TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700),
    bodySmall: TextStyle(color: Color(0xFF475569)),
  ),
  unselectedWidgetColor: const Color(0xFF475569),
);
