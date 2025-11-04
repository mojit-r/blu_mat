import 'package:flutter/material.dart';

// ThemeProvider Class
class ThemeProvider extends ChangeNotifier {
  IconData _themeIcon = Icons.nights_stay_rounded;
  ThemeMode _customThemeMode = ThemeMode.light;

  IconData get themeIcon => _themeIcon;
  ThemeMode get customThemeMode => _customThemeMode;

  void themeChanger() {
    if (_customThemeMode == ThemeMode.light) {
      _themeIcon = Icons.sunny;
      _customThemeMode = ThemeMode.dark;
      notifyListeners();
    } else {
      _themeIcon = Icons.nights_stay_rounded;
      _customThemeMode = ThemeMode.light;
      notifyListeners();
    }
  }
}

// lightColorScheme variable
final ColorScheme lightColorScheme = ColorScheme.fromSeed(
  seedColor: Colors.blue,
  brightness: Brightness.light,
);

// darkColorScheme variable
final ColorScheme darkColorScheme = ColorScheme.fromSeed(
  seedColor: Colors.blue,
  brightness: Brightness.dark,
);

// Light Theme data
ThemeData lightMode = ThemeData(
  useMaterial3: true,
  colorScheme: lightColorScheme,

  // Text Theme still used for the isInCart Item text and SnackBar Text
  // textTheme: TextTheme(
  // default body text size in LightTheme
  // bodyMedium: const TextStyle(),
  // labelMedium: TextStyle(color: lightColorScheme.onPrimary),
  // ),
  appBarTheme: AppBarTheme(
    backgroundColor: lightColorScheme.primary,
    foregroundColor: lightColorScheme.onPrimary,
  ),
);

// Dark Thmee data
ThemeData darkMode = ThemeData(
  useMaterial3: true,
  colorScheme: darkColorScheme,

  // Text Theme still used for the isInCart Item text and SnackBar Text
  // textTheme: const TextTheme(
  // default body text size in DarkTheme
  // bodyMedium: TextStyle(),
  // labelSmall: TextStyle(color: darkColorScheme.onSurface),
  // ),
  appBarTheme: AppBarTheme(
    backgroundColor: darkColorScheme.primary,
    foregroundColor: darkColorScheme.onPrimary,
  ),
);
