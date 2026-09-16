import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spillcity/services/preferences_service.dart';

enum ThemePreset {
  defaultLight,
  defaultDark,
  oledBlack,
  midnight,
  roseLight,
  roseDark,
}

class ThemeSettingsState {
  final ThemeMode themeMode;
  final ThemePreset themePreset;

  ThemeSettingsState({
    required this.themeMode,
    required this.themePreset,
  });

  ThemeSettingsState copyWith({
    ThemeMode? themeMode,
    ThemePreset? themePreset,
  }) {
    return ThemeSettingsState(
      themeMode: themeMode ?? this.themeMode,
      themePreset: themePreset ?? this.themePreset,
    );
  }
}

class ThemeNotifier extends StateNotifier<ThemeSettingsState> {
  final PreferencesService _prefs = PreferencesService.instance;

  ThemeNotifier() : super(ThemeSettingsState(
    themeMode: ThemeMode.system,
    themePreset: ThemePreset.defaultLight,
  )) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final modeStr = await _prefs.getString('theme_mode');
    final presetStr = await _prefs.getString('theme_preset');

    ThemeMode mode = ThemeMode.system;
    if (modeStr == 'light') mode = ThemeMode.light;
    if (modeStr == 'dark') mode = ThemeMode.dark;

    ThemePreset preset = ThemePreset.defaultLight;
    if (presetStr == 'defaultDark') preset = ThemePreset.defaultDark;
    if (presetStr == 'oledBlack') preset = ThemePreset.oledBlack;
    if (presetStr == 'midnight') preset = ThemePreset.midnight;
    if (presetStr == 'roseLight') preset = ThemePreset.roseLight;
    if (presetStr == 'roseDark') preset = ThemePreset.roseDark;

    state = ThemeSettingsState(themeMode: mode, themePreset: preset);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    String modeStr = 'system';
    if (mode == ThemeMode.light) modeStr = 'light';
    if (mode == ThemeMode.dark) modeStr = 'dark';
    await _prefs.setString('theme_mode', modeStr);
  }

  Future<void> setThemePreset(ThemePreset preset) async {
    state = state.copyWith(themePreset: preset);
    await _prefs.setString('theme_preset', preset.name);
    
    // Automatically align system theme mode depending on chosen preset type
    if (preset == ThemePreset.defaultDark || preset == ThemePreset.oledBlack || preset == ThemePreset.midnight || preset == ThemePreset.roseDark) {
      await setThemeMode(ThemeMode.dark);
    } else {
      await setThemeMode(ThemeMode.light);
    }
  }

  ThemeData getThemeData(bool isDarkMode) {
    final preset = state.themePreset;
    
    Color primary;
    Color bg;
    Color surface;
    Color accent;
    Color border;
    Color textPrimary;
    Color textSecondary;
    Color textMuted;
    
    if (isDarkMode) {
      switch (preset) {
        case ThemePreset.oledBlack:
          primary = const Color(0xFF3B82F6);
          bg = const Color(0xFF000000);
          surface = const Color(0xFF121212);
          accent = const Color(0xFFF87171);
          border = const Color(0xFF262626);
          textPrimary = const Color(0xFFFFFFFF);
          textSecondary = const Color(0xFFE5E7EB);
          textMuted = const Color(0xFF9CA3AF);
          break;
        case ThemePreset.midnight:
          primary = const Color(0xFF818CF8);
          bg = const Color(0xFF020617);
          surface = const Color(0xFF0F172A);
          accent = const Color(0xFFC084FC);
          border = const Color(0xFF1E293B);
          textPrimary = const Color(0xFFF1F5F9);
          textSecondary = const Color(0xFFCBD5E1);
          textMuted = const Color(0xFF94A3B8);
          break;
        case ThemePreset.roseDark:
          primary = const Color(0xFFF43F5E);
          bg = const Color(0xFF1E0B11);
          surface = const Color(0xFF2D121A);
          accent = const Color(0xFFFB7185);
          border = const Color(0xFF4C1D24);
          textPrimary = const Color(0xFFFFF1F2);
          textSecondary = const Color(0xFFFFE4E6);
          textMuted = const Color(0xFFFDA4AF);
          break;
        case ThemePreset.defaultDark:
        default:
          primary = const Color(0xFF3B82F6);
          bg = const Color(0xFF0F172A);
          surface = const Color(0xFF1E293B);
          accent = const Color(0xFFF87171);
          border = const Color(0xFF334155);
          textPrimary = const Color(0xFFF1F5F9);
          textSecondary = const Color(0xFFCBD5E1);
          textMuted = const Color(0xFF94A3B8);
          break;
      }
    } else {
      switch (preset) {
        case ThemePreset.roseLight:
          primary = const Color(0xFFE11D48);
          bg = const Color(0xFFFFF1F2);
          surface = const Color(0xFFFFFFFF);
          accent = const Color(0xFFF43F5E);
          border = const Color(0xFFFFE4E6);
          textPrimary = const Color(0xFF4C0519);
          textSecondary = const Color(0xFF881337);
          textMuted = const Color(0xFFFDA4AF);
          break;
        default:
          // Light Mode colors (Default Light)
          primary = const Color(0xFF2563EB);
          bg = const Color(0xFFF8FAFC);
          surface = const Color(0xFFFFFFFF);
          accent = const Color(0xFFEF4444);
          border = const Color(0xFFE2E8F0);
          textPrimary = const Color(0xFF0F172A);
          textSecondary = const Color(0xFF334155);
          textMuted = const Color(0xFF64748B);
          break;
      }
    }
    
    return ThemeData(
      useMaterial3: true,
      brightness: isDarkMode ? Brightness.dark : Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: bg,
      colorScheme: isDarkMode
          ? ColorScheme.dark(
              primary: primary,
              secondary: primary.withValues(alpha: 0.8),
              error: accent,
              surface: surface,
              onPrimary: Colors.black,
              onSecondary: Colors.white,
              onSurface: textPrimary,
              outline: border,
            )
          : ColorScheme.light(
              primary: primary,
              secondary: primary.withValues(alpha: 0.8),
              error: accent,
              surface: surface,
              onPrimary: Colors.white,
              onSecondary: Colors.white,
              onSurface: textPrimary,
              outline: border,
            ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: 'Inter',
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(fontFamily: 'Inter', fontSize: 32, fontWeight: FontWeight.bold, color: textPrimary),
        headlineMedium: TextStyle(fontFamily: 'Inter', fontSize: 24, fontWeight: FontWeight.bold, color: textPrimary),
        titleLarge: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
        bodyLarge: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.normal, color: textSecondary),
        bodyMedium: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.normal, color: textSecondary),
        labelLarge: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500, color: textMuted),
      ),
    );
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeSettingsState>((ref) {
  return ThemeNotifier();
});
