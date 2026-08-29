import 'package:flutter/material.dart';

const String kSans = 'Poppins';
const String kMono = 'WakeMono';

/// Every colour in the app, carried as a ThemeExtension so light and dark
/// resolve from the same call site. Read it via `context.wake` -- never
/// hardcode a hex in a widget.
@immutable
class WakeColors extends ThemeExtension<WakeColors> {
  final Color bg;
  final Color card;
  final Color accent;

  /// Orange is a *fill* colour. On light it fails contrast as text, so the
  /// design specifies a separate darker orange for text/icons on the page.
  final Color accentInk;

  /// Ink that sits on top of an [accent] fill.
  final Color onAccent;

  final Color done;
  final Color personal;
  final Color physics;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textFaint;

  final Color divider;

  /// Light uses a soft shadow and no border; dark uses a hairline border and
  /// no shadow. Only one of these is ever non-null.
  final Color? cardBorder;
  final List<BoxShadow> cardShadow;

  const WakeColors({
    required this.bg,
    required this.card,
    required this.accent,
    required this.accentInk,
    required this.onAccent,
    required this.done,
    required this.personal,
    required this.physics,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textFaint,
    required this.divider,
    required this.cardBorder,
    required this.cardShadow,
  });

  static const light = WakeColors(
    bg: Color(0xFFFAF7F4),
    card: Color(0xFFFFFFFF),
    accent: Color(0xFFEF6A00),
    accentInk: Color(0xFF9A4A00),
    onAccent: Color(0xFF1A1614),
    done: Color(0xFF15803D),
    personal: Color(0xFF6D28D9),
    physics: Color(0xFF0369A1),
    textPrimary: Color(0xFF1A1614),
    textSecondary: Color(0xFF3C3630),
    textMuted: Color(0xFF655C55),
    // Distinct from textMuted rather than a duplicate of it: the dark
    // palette has four levels of type and light only had three, so hints and
    // captions carried the same weight as body text on one theme but not the
    // other.
    textFaint: Color(0xFF7A716A),
    divider: Color(0x141A1614), // rgba(26,22,20,.08)
    cardBorder: null,
    cardShadow: [
      BoxShadow(
        color: Color(0x121A1614), // rgba(26,22,20,.07)
        blurRadius: 3,
        offset: Offset(0, 1),
      ),
    ],
  );

  static const dark = WakeColors(
    bg: Color(0xFF0D1117),
    card: Color(0xFF161C24),
    accent: Color(0xFFFF7A1A),
    accentInk: Color(0xFFFF7A1A),
    onAccent: Color(0xFF1A1614),
    done: Color(0xFF22C55E),
    personal: Color(0xFF8B5CF6),
    physics: Color(0xFF38BDF8),
    textPrimary: Color(0xFFF4F6F8),
    textSecondary: Color(0xFFC3CAD3),
    textMuted: Color(0xFF7D8794),
    textFaint: Color(0xFF5F6874),
    divider: Color(0x12FFFFFF), // rgba(255,255,255,.07)
    cardBorder: Color(0x12FFFFFF),
    cardShadow: [],
  );

  @override
  WakeColors copyWith({
    Color? bg,
    Color? card,
    Color? accent,
    Color? accentInk,
    Color? onAccent,
    Color? done,
    Color? personal,
    Color? physics,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? textFaint,
    Color? divider,
    Color? cardBorder,
    List<BoxShadow>? cardShadow,
  }) {
    return WakeColors(
      bg: bg ?? this.bg,
      card: card ?? this.card,
      accent: accent ?? this.accent,
      accentInk: accentInk ?? this.accentInk,
      onAccent: onAccent ?? this.onAccent,
      done: done ?? this.done,
      personal: personal ?? this.personal,
      physics: physics ?? this.physics,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textFaint: textFaint ?? this.textFaint,
      divider: divider ?? this.divider,
      cardBorder: cardBorder ?? this.cardBorder,
      cardShadow: cardShadow ?? this.cardShadow,
    );
  }

  @override
  WakeColors lerp(ThemeExtension<WakeColors>? other, double t) {
    if (other is! WakeColors) return this;
    return WakeColors(
      bg: Color.lerp(bg, other.bg, t)!,
      card: Color.lerp(card, other.card, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentInk: Color.lerp(accentInk, other.accentInk, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      done: Color.lerp(done, other.done, t)!,
      personal: Color.lerp(personal, other.personal, t)!,
      physics: Color.lerp(physics, other.physics, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textFaint: Color.lerp(textFaint, other.textFaint, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t),
      cardShadow: t < 0.5 ? cardShadow : other.cardShadow,
    );
  }
}

extension WakeThemeX on BuildContext {
  WakeColors get wake => Theme.of(this).extension<WakeColors>()!;
}

/// 18px screen padding, 14-16px card padding, 9-14px gaps between cards.
class AppSpacing {
  AppSpacing._();
  static const screen = 18.0;
  static const card = 16.0;
  static const cardTight = 14.0;
  static const gap = 12.0;
  static const gapTight = 9.0;
  static const gapWide = 14.0;
  static const xs = 8.0;
  static const sm = 16.0;
  static const md = 24.0;
  static const lg = 32.0;
  static const xl = 40.0;
}

class AppRadius {
  AppRadius._();
  static const card = 18.0;
  static const control = 12.0;
  static const chip = 10.0;
  static const pill = 999.0;
  static const fab = 19.0;

  // Retained so older call sites keep compiling; both map onto the new scale.
  static const button = control;
  static const field = control;
}

/// Minimum tap target, per the spec.
const double kMinHitTarget = 44.0;

/// Clocks, timers and any figure meant to be read as data.
///
/// Poppins rather than mono: the spec's "clocks & timers in mono" line was
/// overridden deliberately so numerals match the rest of the type. The
/// trade-off is that digits no longer share a fixed advance width, so a
/// ticking timer can shift by a pixel or two as it counts.
TextStyle numberStyle({
  double fontSize = 32,
  FontWeight weight = FontWeight.w700,
  Color? color,
}) =>
    TextStyle(
      fontFamily: kSans,
      // Keeps a running clock from jittering as digits change width.
      fontFeatures: const [FontFeature.tabularFigures()],
      fontSize: fontSize,
      fontWeight: weight,
      color: color,
      height: 1.1,
    );

/// Small uppercase mono label above a card or section ("QUESTIONS SOLVED").
TextStyle sectionLabelStyle(Color color) => TextStyle(
      fontFamily: kMono,
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.14 * 10,
      color: color,
    );

TextTheme _textTheme(WakeColors c) {
  const base = TextTheme();
  return base.copyWith(
    // Screen title
    headlineSmall: TextStyle(
      fontFamily: kSans,
      
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: c.textPrimary,
    ),
    titleLarge: TextStyle(
      fontFamily: kSans,
      
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: c.textPrimary,
    ),
    // Card heading
    titleMedium: TextStyle(
      fontFamily: kSans,
      
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: c.textPrimary,
    ),
    titleSmall: TextStyle(
      fontFamily: kSans,
      
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: c.textPrimary,
    ),
    // Body / list row
    bodyMedium: TextStyle(
      fontFamily: kSans,
      
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: c.textSecondary,
    ),
    bodyLarge: TextStyle(
      fontFamily: kSans,
      
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: c.textPrimary,
    ),
    // Caption
    bodySmall: TextStyle(
      fontFamily: kSans,
      
      fontSize: 11,
      fontWeight: FontWeight.w400,
      color: c.textMuted,
    ),
    labelSmall: TextStyle(
      fontFamily: kSans,
      
      fontSize: 11,
      fontWeight: FontWeight.w400,
      color: c.textMuted,
    ),
    labelLarge: TextStyle(
      fontFamily: kSans,
      
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: c.textPrimary,
    ),
  );
}

ThemeData _build(WakeColors c, Brightness brightness) {
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.accent,
    onPrimary: c.onAccent,
    secondary: c.accent,
    onSecondary: c.onAccent,
    surface: c.card,
    onSurface: c.textPrimary,
    error: const Color(0xFFDC2626),
    onError: Colors.white,
  );

  final text = _textTheme(c);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    dividerColor: c.divider,
    textTheme: text,
    extensions: [c],
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: c.textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
      fontFamily: kSans,
      
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: c.textPrimary,
      ),
    ),
    cardTheme: CardThemeData(
      color: c.card,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: c.cardBorder == null
            ? BorderSide.none
            : BorderSide(color: c.cardBorder!),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.accent,
      foregroundColor: c.onAccent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.fab),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
        minimumSize: const Size.fromHeight(kMinHitTarget),
        elevation: 0,
        textStyle: TextStyle(
      fontFamily: kSans,
      fontSize: 15, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.textPrimary,
        minimumSize: const Size.fromHeight(kMinHitTarget),
        side: BorderSide(color: c.divider),
        textStyle: TextStyle(
      fontFamily: kSans,
      fontSize: 13, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: c.accentInk),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.bg,
      hintStyle: text.bodyMedium?.copyWith(color: c.textMuted),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: BorderSide(color: c.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: BorderSide(color: c.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: BorderSide(color: c.accent),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : c.card,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? c.accent
            : c.textMuted.withValues(alpha: 0.35),
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.card,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      elevation: 0,
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          size: 22,
          color: s.contains(WidgetState.selected) ? c.accent : c.textMuted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
      fontFamily: kSans,
      
          fontSize: 11,
          fontWeight:
              s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? c.accent : c.textMuted,
        ),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: c.card,
        foregroundColor: c.textSecondary,
        selectedBackgroundColor: c.accent.withValues(alpha: 0.14),
        selectedForegroundColor: c.accentInk,
        side: BorderSide(color: c.divider),
        textStyle: TextStyle(
      fontFamily: kSans,
      fontSize: 13, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.card,
      side: BorderSide(color: c.divider),
      labelStyle: TextStyle(
      fontFamily: kSans,
      fontSize: 12, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: c.textMuted,
      textColor: c.textPrimary,
      minVerticalPadding: 12,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.accent,
      linearTrackColor: c.divider,
      circularTrackColor: c.divider,
    ),
  );
}

ThemeData buildWakeForceLightTheme() =>
    _build(WakeColors.light, Brightness.light);

ThemeData buildWakeForceDarkTheme() => _build(WakeColors.dark, Brightness.dark);
