import 'package:flutter/material.dart';

/// Font families bundled under assets/fonts. Japanese glyphs are not in
/// these files and fall back to the platform's own font (Hiragino on iOS,
/// Noto Sans CJK on Android), which keeps the app small.
abstract final class AppFonts {
  static const sans = 'IBMPlexSans';
  static const mono = 'JetBrainsMono';

  /// Prefer Japanese glyph shapes over Chinese ones for kanji on Android.
  static const fallback = ['Hiragino Sans', 'Noto Sans CJK JP', 'Noto Sans JP'];
}

/// Colors the Material scheme has no slot for: tool and diff states, and the
/// surface behind code.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.success,
    required this.running,
    required this.code,
    required this.addedBackground,
    required this.removedBackground,
  });

  /// A finished tool call, a connected server, added lines.
  final Color success;

  /// Something in progress right now.
  final Color running;

  /// Behind inline code and monospace blocks.
  final Color code;

  final Color addedBackground;
  final Color removedBackground;

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  static const dark = AppColors(
    success: Color(0xFF6EE7A0),
    running: Color(0xFF5EEAD4),
    code: Color(0xFF1D232C),
    addedBackground: Color(0x2E6EE7A0),
    removedBackground: Color(0x2EFF8A80),
  );

  static const light = AppColors(
    success: Color(0xFF15803D),
    running: Color(0xFF0E9384),
    code: Color(0xFFE9EDF2),
    addedBackground: Color(0x2615803D),
    removedBackground: Color(0x26C93A32),
  );

  @override
  AppColors copyWith({
    Color? success,
    Color? running,
    Color? code,
    Color? addedBackground,
    Color? removedBackground,
  }) => AppColors(
    success: success ?? this.success,
    running: running ?? this.running,
    code: code ?? this.code,
    addedBackground: addedBackground ?? this.addedBackground,
    removedBackground: removedBackground ?? this.removedBackground,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      success: Color.lerp(success, other.success, t)!,
      running: Color.lerp(running, other.running, t)!,
      code: Color.lerp(code, other.code, t)!,
      addedBackground: Color.lerp(addedBackground, other.addedBackground, t)!,
      removedBackground: Color.lerp(
        removedBackground,
        other.removedBackground,
        t,
      )!,
    );
  }
}

/// "Graphite": a graphite dark theme with a sky-blue accent, and a light
/// counterpart with the same structure.
abstract final class AppTheme {
  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF7CC4FF),
    onPrimary: Color(0xFF0B1220),
    primaryContainer: Color(0xFF1A2230),
    onPrimaryContainer: Color(0xFFDCE9FA),
    secondary: Color(0xFF5EEAD4),
    onSecondary: Color(0xFF06201C),
    secondaryContainer: Color(0xFF15302C),
    onSecondaryContainer: Color(0xFFC6F6EC),
    tertiary: Color(0xFFF5C46B),
    onTertiary: Color(0xFF2A1C00),
    tertiaryContainer: Color(0xFF2A2416),
    onTertiaryContainer: Color(0xFFF7DFAE),
    error: Color(0xFFFF8A80),
    onError: Color(0xFF3B0A06),
    errorContainer: Color(0xFF3A1D1D),
    onErrorContainer: Color(0xFFFFDAD5),
    surface: Color(0xFF0F1216),
    onSurface: Color(0xFFE6E9EE),
    onSurfaceVariant: Color(0xFF8A93A3),
    surfaceContainerLowest: Color(0xFF0B0E11),
    surfaceContainerLow: Color(0xFF12161C),
    surfaceContainer: Color(0xFF161B22),
    surfaceContainerHigh: Color(0xFF1A2028),
    surfaceContainerHighest: Color(0xFF1F2630),
    outline: Color(0xFF3A4352),
    outlineVariant: Color(0xFF262D38),
    inverseSurface: Color(0xFFE6E9EE),
    onInverseSurface: Color(0xFF161B22),
    inversePrimary: Color(0xFF0B6BCB),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    surfaceTint: Colors.transparent,
  );

  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF0B6BCB),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFE3EEFB),
    onPrimaryContainer: Color(0xFF0B2C52),
    secondary: Color(0xFF0E9384),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFD5F3EE),
    onSecondaryContainer: Color(0xFF053B35),
    tertiary: Color(0xFFB7791F),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFFBF0DC),
    onTertiaryContainer: Color(0xFF5A3A06),
    error: Color(0xFFC93A32),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFCE4E2),
    onErrorContainer: Color(0xFF5C1410),
    surface: Color(0xFFF7F8FA),
    onSurface: Color(0xFF161A21),
    onSurfaceVariant: Color(0xFF5B6475),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF1F3F6),
    surfaceContainer: Color(0xFFECEFF3),
    surfaceContainerHigh: Color(0xFFE6EAEF),
    surfaceContainerHighest: Color(0xFFDEE3EA),
    outline: Color(0xFF9AA3B2),
    outlineVariant: Color(0xFFD6DBE3),
    inverseSurface: Color(0xFF1F2630),
    onInverseSurface: Color(0xFFE6E9EE),
    inversePrimary: Color(0xFF7CC4FF),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    surfaceTint: Colors.transparent,
  );

  static ThemeData get dark => _build(_darkScheme, AppColors.dark);
  static ThemeData get light => _build(_lightScheme, AppColors.light);

  static ThemeData _build(ColorScheme scheme, AppColors colors) {
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: AppFonts.sans,
      fontFamilyFallback: AppFonts.fallback,
    );
    final text = base.textTheme.copyWith(
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      labelSmall: base.textTheme.labelSmall?.copyWith(
        fontFamily: AppFonts.mono,
        color: scheme.onSurfaceVariant,
        letterSpacing: 0,
      ),
    );
    final hairline = BorderSide(color: scheme.outlineVariant);

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text,
      extensions: [colors],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 4,
        titleTextStyle: text.titleMedium?.copyWith(
          color: scheme.onSurface,
          fontSize: 17,
        ),
        shape: Border(bottom: hairline),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelSmall?.copyWith(
            fontFamily: AppFonts.sans,
            fontSize: 11,
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: hairline,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        subtitleTextStyle: text.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: hairline,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: hairline,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: TextStyle(
          fontFamily: AppFonts.mono,
          fontFamilyFallback: AppFonts.fallback,
          fontSize: 12,
          color: scheme.onSurface,
        ),
        iconTheme: IconThemeData(size: 16, color: scheme.onSurfaceVariant),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: AppFonts.sans,
            fontFamilyFallback: AppFonts.fallback,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: scheme.outline,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: hairline,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        circularTrackColor: Colors.transparent,
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        shape: Border(),
        collapsedShape: Border(),
      ),
    );
  }
}
