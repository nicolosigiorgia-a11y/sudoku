import 'package:flutter/material.dart';

import 'avatar.dart';
import 'duo_theme.dart';

/// Icone della barra in basso: il gatto interacts with the topic of each tab.
enum NavMascotKind { photo, levels, learn, profile }

class NavMascotIcon extends StatelessWidget {
  final NavMascotKind kind;
  final double size;
  final Color scarf;
  final bool selected;

  const NavMascotIcon({
    super.key,
    required this.kind,
    required this.size,
    required this.scarf,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (kind == NavMascotKind.levels)
            Positioned.fill(child: _SudokuBackdrop(size: size)),
          CatMascot(
            size: size * 0.92,
            scarfColor: scarf,
            showShadow: false,
            mood: selected ? AvatarMood.happy : AvatarMood.idle,
          ),
          if (kind == NavMascotKind.photo)
            Positioned(
              right: -size * 0.03,
              bottom: size * 0.01,
              child: _Camera(size: size * 0.46),
            ),
          if (kind == NavMascotKind.learn) ...[
            Positioned(
              left: size * 0.30,
              top: size * 0.24,
              child: Row(
                children: [
                  _GlassLens(size: size * 0.19),
                  Container(width: size * 0.02, height: 1, color: const Color(0xFF1B2440)),
                  _GlassLens(size: size * 0.19),
                ],
              ),
            ),
            Positioned(
              right: -size * 0.02,
              bottom: size * 0.01,
              child: _MiniPlate(
                size: size * 0.52,
                text: 'SUDOKU',
                color: DuoColors.purple,
                background: DuoColors.purpleLight,
              ),
            ),
          ],
          if (kind == NavMascotKind.profile)
            Positioned(
              right: -size * 0.02,
              bottom: size * 0.01,
              child: _MiniPlate(
                size: size * 0.52,
                text: 'DATI',
                color: const Color(0xFF9A6428),
                background: const Color(0xFFF3D9AE),
              ),
            ),
        ],
      ),
    );
  }
}

class _SudokuBackdrop extends StatelessWidget {
  final double size;
  const _SudokuBackdrop({required this.size});

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: const _SudokuGridPainter(),
      );
}

class _SudokuGridPainter extends CustomPainter {
  const _SudokuGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(s * 0.12)),
      Paint()..color = const Color(0xFFEAF3FF),
    );
    final line = Paint()
      ..color = DuoColors.blue
      ..strokeWidth = s * 0.045;
    for (var i = 1; i < 3; i++) {
      final p = s * i / 3;
      canvas.drawLine(Offset(p, s * 0.08), Offset(p, s * 0.92), line);
      canvas.drawLine(Offset(s * 0.08, p), Offset(s * 0.92, p), line);
    }
    final ink = Paint()..color = DuoColors.blueDark;
    canvas.drawRect(Rect.fromLTWH(s * 0.12, s * 0.12, s * 0.13, s * 0.13), ink);
    canvas.drawRect(Rect.fromLTWH(s * 0.63, s * 0.45, s * 0.13, s * 0.13), ink);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GlassLens extends StatelessWidget {
  final double size;
  const _GlassLens({required this.size});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size * 0.85,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF1B2440), width: size * 0.12),
          borderRadius: BorderRadius.circular(size * 0.4),
        ),
      );
}

class _Camera extends StatelessWidget {
  final double size;
  const _Camera({required this.size});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size * 0.78,
        decoration: BoxDecoration(
          color: DuoColors.blue,
          borderRadius: BorderRadius.circular(size * 0.14),
          border: Border.all(color: Colors.white, width: size * 0.08),
        ),
        child: Center(
          child: Container(
            width: size * 0.42,
            height: size * 0.42,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: DuoColors.blueDark, width: size * 0.09),
            ),
          ),
        ),
      );
}

class _MiniPlate extends StatelessWidget {
  final double size;
  final String text;
  final Color color;
  final Color background;

  const _MiniPlate({
    required this.size,
    required this.text,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size * 0.62,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(size * 0.12),
          border: Border.all(color: color, width: size * 0.06),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: EdgeInsets.all(size * 0.05),
            child: Text(
              text,
              style: TextStyle(
                fontSize: size * 0.32,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
        ),
      );
}
