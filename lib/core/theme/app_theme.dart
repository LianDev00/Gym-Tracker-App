import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Paleta de colores global de la app.
class AppColors {
  AppColors._();

  static const background = Color(0xFF050511);   // negro profundo con tinte azul
  static const surface    = Color(0xFF0A0A1A);
  static const primary    = Color(0xFF00D4FF);   // cyan neon
  static const secondary  = Color(0xFF7B2FFF);   // púrpura
  static const accent     = Color(0xFFFF3CAC);   // rosa (uso puntual)
  static const onBg       = Color(0xFFE8E8F0);   // blanco suave
  static const onSurface  = Color(0xFFCCCCDD);
  static const muted      = Color(0xFF6666AA);
  static const outline    = Color(0xFF1E1E3A);
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary:                 AppColors.primary,
          onPrimary:               Colors.black,
          primaryContainer:        Color(0xFF001A2E),
          onPrimaryContainer:      AppColors.primary,
          secondary:               AppColors.secondary,
          onSecondary:             Colors.white,
          secondaryContainer:      Color(0xFF1A0040),
          onSecondaryContainer:    AppColors.secondary,
          surface:                 AppColors.surface,
          onSurface:               AppColors.onSurface,
          surfaceContainerHighest: Color(0xFF0F0F22),
          outline:                 AppColors.muted,
          outlineVariant:          AppColors.outline,
          error:                   Color(0xFFFF4466),
        ),
        scaffoldBackgroundColor: AppColors.background,
        // Cards completamente transparentes — se usan GlassCard
        cardTheme: const CardThemeData(
          color: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarBrightness: Brightness.dark,
            statusBarIconBrightness: Brightness.light,
          ),
          iconTheme: IconThemeData(color: AppColors.onBg),
          titleTextStyle: TextStyle(
            color: AppColors.onBg,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        dividerTheme: DividerThemeData(
          color: Colors.white.withValues(alpha: 0.06),
          thickness: 0.5,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.04),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          labelStyle: const TextStyle(color: AppColors.muted),
          hintStyle: TextStyle(color: AppColors.muted.withValues(alpha: 0.6)),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.transparent,
          elevation: 0,
          indicatorColor: AppColors.primary.withValues(alpha: 0.12),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: AppColors.primary, size: 22);
            }
            return IconThemeData(
                color: AppColors.muted.withValues(alpha: 0.9), size: 22);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              );
            }
            return TextStyle(
              color: AppColors.muted.withValues(alpha: 0.9),
              fontSize: 11,
            );
          }),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          foregroundColor: AppColors.primary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.35)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
        ),
        iconTheme: const IconThemeData(color: AppColors.onSurface),
        chipTheme: ChipThemeData(
          backgroundColor: Colors.white.withValues(alpha: 0.04),
          labelStyle: const TextStyle(color: AppColors.onSurface, fontSize: 12),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.primary,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.surface,
          contentTextStyle: const TextStyle(color: AppColors.onBg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
}
