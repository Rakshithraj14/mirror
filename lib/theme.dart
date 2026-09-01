import 'package:flutter/material.dart';

/// Yumeko is monochrome: one accent hue, everything else neutral. Identity in
/// the charts comes from lightness steps rather than hue, so the ramps below
/// were checked with the palette validator instead of picked by eye.
@immutable
class Palette extends ThemeExtension<Palette> {
  final Color ground;
  final Color surface;
  final Color raised;
  final Color line;

  final Color ink;
  final Color inkMuted;
  final Color inkFaint;

  /// The brand colour, used as a *fill*.
  final Color accent;

  /// Text and icons drawn on top of [accent].
  final Color onAccent;

  /// The accent when it has to be text or a line rather than a fill. In light
  /// theme this is not [accent]: lime on white is 1.32:1 and disappears.
  final Color accentInk;

  /// Sequential ramp, light → dark, for anything categorical in the charts.
  final List<Color> ramp;

  final List<Color> fabGradient;
  final String blobAsset;
  final String walletAsset;

  const Palette({
    required this.ground,
    required this.surface,
    required this.raised,
    required this.line,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.accent,
    required this.onAccent,
    required this.accentInk,
    required this.ramp,
    required this.fabGradient,
    required this.blobAsset,
    required this.walletAsset,
  });

  static Palette of(BuildContext context) =>
      Theme.of(context).extension<Palette>()!;

  /// Chart step for the nth series, held inside the ramp rather than cycling.
  Color step(int i) => ramp[i % ramp.length];

  static const dark = Palette(
    ground: Color(0xFF0B0B0D),
    surface: Color(0xFF141317),
    raised: Color(0xFF1C1B21),
    line: Color(0xFF262530),
    ink: Color(0xFFF4F3F6),
    inkMuted: Color(0xFF9C99A6),
    inkFaint: Color(0xFF6A6774),
    accent: Color(0xFFBC13FE),
    onAccent: Color(0xFFFFFFFF),
    accentInk: Color(0xFFBC13FE), // 4.37:1 on ground — fine for UI and figures
    ramp: [
      Color(0xFFF2D2FF),
      Color(0xFFDCA0FF),
      Color(0xFFC56AFF),
      Color(0xFFAC3AEE),
      Color(0xFF9328CC),
    ],
    fabGradient: [Color(0xFF7A00CC), Color(0xFFBC13FE), Color(0xFF7A00CC)],
    blobAsset: 'assets/art/blob-dark.webp',
    walletAsset: 'assets/art/wallet-dark.webp',
  );

  static const light = Palette(
    ground: Color(0xFFF6F7F3),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFFFFFFF),
    line: Color(0xFFE6E8E0),
    ink: Color(0xFF101110),
    inkMuted: Color(0xFF63665E),
    inkFaint: Color(0xFF8E9188),
    accent: Color(0xFFC2F13C),
    onAccent: Color(0xFF101110), // 14.37:1 on lime
    accentInk: Color(0xFF5C7A10), // 4.95:1 on white
    // Starts darker than the brand lime on purpose: a lime-topped ramp fails
    // the light-end contrast floor against white.
    ramp: [
      Color(0xFF8FB81A),
      Color(0xFF6F9214),
      Color(0xFF52700F),
      Color(0xFF38500A),
      Color(0xFF223405),
    ],
    fabGradient: [Color(0xFFA8D91F), Color(0xFFC2F13C), Color(0xFFA8D91F)],
    blobAsset: 'assets/art/blob-light.webp',
    walletAsset: 'assets/art/wallet-light.webp',
  );

  @override
  Palette copyWith({
    Color? ground,
    Color? surface,
    Color? raised,
    Color? line,
    Color? ink,
    Color? inkMuted,
    Color? inkFaint,
    Color? accent,
    Color? onAccent,
    Color? accentInk,
    List<Color>? ramp,
    List<Color>? fabGradient,
    String? blobAsset,
    String? walletAsset,
  }) =>
      Palette(
        ground: ground ?? this.ground,
        surface: surface ?? this.surface,
        raised: raised ?? this.raised,
        line: line ?? this.line,
        ink: ink ?? this.ink,
        inkMuted: inkMuted ?? this.inkMuted,
        inkFaint: inkFaint ?? this.inkFaint,
        accent: accent ?? this.accent,
        onAccent: onAccent ?? this.onAccent,
        accentInk: accentInk ?? this.accentInk,
        ramp: ramp ?? this.ramp,
        fabGradient: fabGradient ?? this.fabGradient,
        blobAsset: blobAsset ?? this.blobAsset,
        walletAsset: walletAsset ?? this.walletAsset,
      );

  @override
  Palette lerp(covariant Palette? other, double t) {
    if (other == null) return this;
    // Assets swap at the halfway point; there is no blending two PNGs.
    return Palette(
      ground: Color.lerp(ground, other.ground, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      raised: Color.lerp(raised, other.raised, t)!,
      line: Color.lerp(line, other.line, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      inkFaint: Color.lerp(inkFaint, other.inkFaint, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      accentInk: Color.lerp(accentInk, other.accentInk, t)!,
      ramp: [
        for (var i = 0; i < ramp.length; i++)
          Color.lerp(ramp[i], other.ramp[i], t)!,
      ],
      fabGradient: [
        for (var i = 0; i < fabGradient.length; i++)
          Color.lerp(fabGradient[i], other.fabGradient[i], t)!,
      ],
      blobAsset: t < 0.5 ? blobAsset : other.blobAsset,
      walletAsset: t < 0.5 ? walletAsset : other.walletAsset,
    );
  }
}

const _ui = 'SpaceGrotesk';

/// A null [color] is deliberate: the style then inherits the ambient text
/// colour, so the same call renders correctly in both themes.
TextStyle uiText({
  double size = 14,
  Color? color,
  FontWeight weight = FontWeight.w400,
  double spacing = 0,
}) =>
    TextStyle(
      fontFamily: _ui,
      fontSize: size,
      color: color,
      fontWeight: weight,
      letterSpacing: spacing,
      fontVariations: [FontVariation('wght', weight.value.toDouble())],
    );

/// The hero amount: one heavy weight, tight tracking, nothing else.
TextStyle heroAmount(double size, {Color? color}) => TextStyle(
      fontFamily: _ui,
      fontSize: size,
      color: color,
      height: 1.0,
      fontWeight: FontWeight.w700,
      letterSpacing: -size * 0.03,
      fontVariations: const [FontVariation('wght', 700)],
    );

TextStyle eyebrow({Color? color, double size = 11}) => TextStyle(
      fontFamily: _ui,
      color: color,
      fontSize: size,
      letterSpacing: 1.6,
      fontWeight: FontWeight.w500,
      fontVariations: const [FontVariation('wght', 500)],
    );

ThemeData yumekoTheme(Brightness brightness) {
  final p = brightness == Brightness.dark ? Palette.dark : Palette.light;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: _ui,
    extensions: [p],
    scaffoldBackgroundColor: p.ground,
    canvasColor: p.ground,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: p.accent,
      onPrimary: p.onAccent,
      secondary: p.accent,
      onSecondary: p.onAccent,
      surface: p.surface,
      onSurface: p.ink,
      error: brightness == Brightness.dark
          ? const Color(0xFFFF6B6B)
          : const Color(0xFFB3261E),
      onError: Colors.white,
    ),
    textTheme: Typography.material2021(
      platform: TargetPlatform.android,
    ).black.apply(
          fontFamily: _ui,
          bodyColor: p.ink,
          displayColor: p.ink,
        ),
    iconTheme: IconThemeData(color: p.ink),
    dividerTheme: DividerThemeData(color: p.line, space: 1),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.raised,
      contentTextStyle: uiText(size: 13, color: p.ink),
      actionTextColor: p.accentInk,
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(backgroundColor: p.surface),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        textStyle: uiText(size: 14, weight: FontWeight.w600),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(cursorColor: p.accentInk),
  );
}
