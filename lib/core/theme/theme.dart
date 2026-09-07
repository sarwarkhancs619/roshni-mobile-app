import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF1E3A8A); // Deep Royal Navy Blue
  static const Color secondaryColor = Color(0xFFF97316); // Sunset Orange
  static const Color accentColor = Color(0xFFEA580C); // Deep Orange
  static const Color backgroundColor = Color(0xFFF8FAFC); // Slate Premium Background
  static const Color surfaceColor = Color(0xFFFFFFFF); // Pure White Surface
  static const Color errorColor = Color(0xFFEF4444); // Modern Red
  static const Color warningColor = Color(0xFFF59E0B); // Amber / Warning
  static const Color successColor = Color(0xFF10B981); // Modern Emerald Green

  static const Gradient blueOrangeGradient = LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFFF97316)], // Midnight -> Navy -> Sunset
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: accentColor,
        background: backgroundColor,
        surface: surfaceColor,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onBackground: Colors.black87,
        onSurface: Colors.black87,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme),
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  static ThemeData get darkTheme {
    const darkBackground = Color(0xFF0F172A); // Modern Slate 900
    const darkSurface = Color(0xFF1E293B); // Slate 800
    const darkPrimary = Color(0xFF60A5FA); // Sky Blue 400 (high-contrast on dark)
    const darkTextPrimary = Color(0xFFF8FAFC); // High-contrast White
    const darkTextSecondary = Color(0xFF94A3B8); // Slate 400

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: darkPrimary,
        secondary: Color(0xFFF97316),
        tertiary: Color(0xFF38BDF8),
        background: darkBackground,
        surface: darkSurface,
        error: errorColor,
        onPrimary: Color(0xFF0F172A),
        onSecondary: Colors.white,
        onBackground: darkTextPrimary,
        onSurface: darkTextPrimary,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: darkTextPrimary,
        displayColor: darkTextPrimary,
      ),
      cardTheme: CardTheme(
        color: darkSurface,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      tabBarTheme: const TabBarTheme(
        labelColor: darkPrimary,
        unselectedLabelColor: darkTextSecondary,
        indicatorColor: darkPrimary,
      ),
      listTileTheme: const ListTileThemeData(
        textColor: darkTextPrimary,
        iconColor: darkTextSecondary,
      ),
      dialogTheme: const DialogTheme(
        backgroundColor: darkSurface,
        titleTextStyle: TextStyle(color: darkTextPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        contentTextStyle: TextStyle(color: Color(0xFFE2E8F0), fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkPrimary,
          side: const BorderSide(color: darkPrimary),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF334155), // Slate 700
        hintStyle: const TextStyle(color: darkTextSecondary),
        labelStyle: const TextStyle(color: Color(0xFFCBD5E1)),
        prefixIconColor: darkTextSecondary,
        suffixIconColor: darkTextSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF475569)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF475569)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
