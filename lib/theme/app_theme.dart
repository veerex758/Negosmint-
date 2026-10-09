import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AppColors {
  static const forest = Color(0xFF1E3A2B);
  static const sage = Color(0xFF9DB281);
  static const ivory = Color(0xFFF7F6F2);
  static const charcoal = Color(0xFF1A1D1E);
  static const gold = Color(0xFFD98A2B);
  static const mist = Color(0xFFE8ECE5);
  static const mint = Color(0xFFB8D9B2);
  static const terracotta = Color(0xFFB96F5A);

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.sage,
      brightness: Brightness.dark,
      primary: AppColors.sage,
      secondary: AppColors.gold,
      surface: const Color(0xFF121212),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF121212),
      fontFamily: 'sans-serif',
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF121212),
        foregroundColor: AppColors.ivory,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF181A19),
        indicatorColor: const Color(0xFF2A3A31),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF1B1D1C),
        surfaceTintColor: Colors.transparent,
        modalElevation: 20,
        showDragHandle: true,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1B1D1C),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1B1D1C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.forest,
      brightness: Brightness.light,
      primary: AppColors.forest,
      secondary: AppColors.gold,
      surface: AppColors.ivory,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.ivory,
      fontFamily: 'sans-serif',
      visualDensity: VisualDensity.standard,
      dividerColor: AppColors.mist,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.ivory,
        foregroundColor: AppColors.charcoal,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.mist,
        elevation: 0,
        height: 76,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) =>
            TextStyle(
              fontSize: 11,
              letterSpacing: .1,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w800
                  : FontWeight.w600,
              color: states.contains(WidgetState.selected)
                  ? AppColors.forest
                  : AppColors.charcoal.withValues(alpha: .55),
            )),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        modalElevation: 18,
        showDragHandle: true,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: AppColors.forest.withValues(alpha: .06),
        elevation: 1,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFE8ECE5), width: .8),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: .1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.charcoal,
        contentTextStyle: const TextStyle(color: AppColors.ivory),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
