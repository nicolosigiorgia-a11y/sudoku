import 'package:flutter/material.dart';

class DuoColors {
  static const green = Color(0xFF58CC02);
  static const greenDark = Color(0xFF46A302);
  static const greenLight = Color(0xFFD7FFB8);
  static const blue = Color(0xFF1CB0F6);
  static const blueDark = Color(0xFF1899D6);
  static const blueLight = Color(0xFFDDF4FF);
  static const yellow = Color(0xFFFFC800);
  static const yellowDark = Color(0xFFD9A800);
  static const yellowLight = Color(0xFFFFF3C4);
  static const red = Color(0xFFFF4B4B);
  static const redDark = Color(0xFFD93737);
  static const purple = Color(0xFFCE82FF);
  static const purpleLight = Color(0xFFF3E4FF);
  static const text = Color(0xFF3C3C3C);
  static const muted = Color(0xFF777777);
  static const border = Color(0xFFE5E5E5);
  static const surface = Color(0xFFFFFFFF);
  static const background = Color(0xFFF7F9FC);
}

ThemeData duoTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: DuoColors.green,
      primary: DuoColors.green,
      secondary: DuoColors.blue,
      error: DuoColors.red,
      surface: DuoColors.surface,
    ),
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: DuoColors.background,
    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontWeight: FontWeight.w800, color: DuoColors.text),
      titleLarge: TextStyle(fontWeight: FontWeight.w800, color: DuoColors.text),
      titleMedium: TextStyle(fontWeight: FontWeight.w800, color: DuoColors.text),
      bodyMedium: TextStyle(color: DuoColors.text, height: 1.4),
    ),
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: DuoColors.surface,
      foregroundColor: DuoColors.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: DuoColors.text,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: DuoColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: DuoColors.greenLight,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: selected ? DuoColors.greenDark : DuoColors.muted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(color: selected ? DuoColors.greenDark : DuoColors.muted, size: 26);
      }),
    ),
    cardTheme: CardThemeData(
      color: DuoColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: DuoColors.border, width: 2),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: DuoColors.border, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: DuoColors.border, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: DuoColors.blue, width: 2),
      ),
      labelStyle: const TextStyle(color: DuoColors.muted, fontWeight: FontWeight.w700),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: DuoColors.green,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.4),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: DuoColors.blue,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: DuoColors.border, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.4),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: DuoColors.blueLight,
        selectedForegroundColor: DuoColors.blueDark,
        side: const BorderSide(color: DuoColors.border, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
  );
}

enum DuoButtonStyle { primary, secondary, yellow, ghost, danger }

class DuoButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final DuoButtonStyle style;
  final bool expanded;
  final bool dense;

  const DuoButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.style = DuoButtonStyle.primary,
    this.expanded = true,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _palette(style);
    final child = FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: colors.$1,
        disabledBackgroundColor: const Color(0xFFE5E5E5),
        foregroundColor: colors.$2,
        disabledForegroundColor: DuoColors.muted,
        minimumSize: Size(expanded ? double.infinity : 0, dense ? 46 : 52),
        padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: TextStyle(
          fontSize: dense ? 12 : 15,
          fontWeight: FontWeight.w800,
          letterSpacing: dense ? 0 : 0.4,
        ),
      ),
      child: icon == null
          ? Text(label, overflow: TextOverflow.ellipsis)
          : Row(
              mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon!, size: dense ? 16 : 20),
                SizedBox(width: dense ? 5 : 10),
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              ],
            ),
    );
    if (style == DuoButtonStyle.ghost) return child;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.$3,
            offset: const Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(16), child: child),
    );
  }

  (Color, Color, Color) _palette(DuoButtonStyle style) => switch (style) {
        DuoButtonStyle.primary => (DuoColors.green, Colors.white, DuoColors.greenDark),
        DuoButtonStyle.secondary => (DuoColors.blue, Colors.white, DuoColors.blueDark),
        DuoButtonStyle.yellow => (DuoColors.yellow, const Color(0xFF5C4700), DuoColors.yellowDark),
        DuoButtonStyle.ghost => (Colors.transparent, DuoColors.blue, Colors.transparent),
        DuoButtonStyle.danger => (DuoColors.red, Colors.white, DuoColors.redDark),
      };
}

class DuoCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final bool shadows;

  const DuoCard({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(18),
    this.shadows = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? DuoColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: DuoColors.border, width: 2),
        boxShadow: shadows
            ? const [BoxShadow(color: Color(0xFFF0F0F0), offset: Offset(0, 4), blurRadius: 0)]
            : null,
      ),
      child: child,
    );
  }
}

class DuoBadge extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color color;
  final Color textColor;

  const DuoBadge({
    super.key,
    required this.text,
    this.icon,
    this.color = DuoColors.greenLight,
    this.textColor = DuoColors.greenDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) Icon(icon, size: 15, color: textColor),
          if (icon != null) const SizedBox(width: 5),
          Text(text, style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 12)),
        ],
      ),
    );
  }
}

class DuoSectionTitle extends StatelessWidget {
  final String text;
  final String? subtitle;
  final Widget? trailing;

  const DuoSectionTitle({super.key, required this.text, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(subtitle!, style: const TextStyle(fontSize: 12, color: DuoColors.muted)),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
