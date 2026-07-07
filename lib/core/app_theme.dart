import 'package:flutter/material.dart';

/// Shared colours, gradients and text styles giving the game a cohesive,
/// polished "purple & gold" pegboard identity.
class AppColors {
  AppColors._();

  static const Color deepPurple = Color(0xFF1B0E33);
  static const Color panelPurpleDark = Color(0xFF2A1550);
  static const Color panelPurple = Color(0xFF43277E);
  static const Color panelPurpleLight = Color(0xFF6A44B8);
  static const Color accentPurple = Color(0xFF8A5CE0);

  static const Color gold = Color(0xFFF2C14E);
  static const Color goldDark = Color(0xFFB8862B);
  static const Color goldLight = Color(0xFFFFE9A8);

  static const Color textLight = Color(0xFFF4ECFF);
  static const Color textDim = Color(0xFFB9A8E0);

  static const Color success = Color(0xFF4CD07D);
  static const Color danger = Color(0xFFF25C6E);

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [goldLight, gold, goldDark],
    stops: [0.0, 0.45, 1.0],
  );

  static const LinearGradient panelGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [panelPurpleLight, panelPurple, panelPurpleDark],
  );

  static const LinearGradient screenGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF2A1550), deepPurple],
  );
}

class AppText {
  AppText._();

  static const String _family = 'sans-serif';

  static TextStyle title(double size, {Color color = AppColors.textLight}) =>
      TextStyle(
        fontFamily: _family,
        fontSize: size,
        fontWeight: FontWeight.w900,
        color: color,
        letterSpacing: 0.5,
        height: 1.05,
        decoration: TextDecoration.none,
      );

  static TextStyle label(double size, {Color color = AppColors.textLight}) =>
      TextStyle(
        fontFamily: _family,
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: 0.4,
        decoration: TextDecoration.none,
      );

  static TextStyle body(double size, {Color color = AppColors.textDim}) =>
      TextStyle(
        fontFamily: _family,
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color,
        decoration: TextDecoration.none,
      );
}
