import 'package:flutter/material.dart';

import 'duo_theme.dart';

enum AvatarMood { idle, thinking, happy, error }

/// Maschotta ufficiale: un gatto che cambia espressione con lo stato del tutor.
class CatMascot extends StatelessWidget {
  final AvatarMood mood;
  final double size;
  final Color scarfColor;
  final bool showShadow;

  const CatMascot({
    super.key,
    this.mood = AvatarMood.idle,
    this.size = 72,
    this.scarfColor = DuoColors.yellow,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _CatPainter(mood: mood, scarf: scarfColor, showShadow: showShadow),
    );
  }
}

/// Nome storico usato dalla home: ora disegna il gatto.
class TutorAvatar extends StatelessWidget {
  final AvatarMood mood;
  final double size;

  const TutorAvatar({super.key, required this.mood, this.size = 68});

  @override
  Widget build(BuildContext context) => CatMascot(mood: mood, size: size);
}

/// Decorazione con tre gattini, usata nelle schermate vuote e nel login.
class CatParade extends StatelessWidget {
  final double size;
  final List<Color> scarves;

  const CatParade({
    super.key,
    this.size = 54,
    this.scarves = const [DuoColors.yellow, DuoColors.blue, DuoColors.purple],
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CatMascot(size: size * 0.82, scarfColor: scarves[0], mood: AvatarMood.idle),
        CatMascot(size: size, scarfColor: scarves[1], mood: AvatarMood.happy),
        CatMascot(size: size * 0.82, scarfColor: scarves[2], mood: AvatarMood.idle),
      ],
    );
  }
}

class _CatPainter extends CustomPainter {
  final AvatarMood mood;
  final Color scarf;
  final bool showShadow;

  static const _fur = Color(0xFFFFB74D);
  static const _furLight = Color(0xFFFFE0B2);
  static const _furDark = Color(0xFFF57C00);
  static const _pink = Color(0xFFFF8FA3);
  static const _ink = Color(0xFF3E2C23);
  static const _white = Color(0xFFFFFFFF);
  static const _bell = Color(0xFFFFD54F);

  _CatPainter({required this.mood, required this.scarf, required this.showShadow});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final happy = mood == AvatarMood.happy;
    final thinking = mood == AvatarMood.thinking;
    final error = mood == AvatarMood.error;

    if (showShadow) {
      canvas.drawOval(
        Rect.fromLTWH(w * 0.18, h * 0.88, w * 0.64, h * 0.10),
        Paint()..color = const Color(0x22000000),
      );
    }

    // Coda dietro al corpo.
    _drawTail(canvas, w, h);

    // Zampe posteriori e corpo.
    final light = Paint()..color = _furLight;
    canvas.drawOval(Rect.fromLTWH(w * 0.27, h * 0.78, w * 0.19, h * 0.11), light);
    canvas.drawOval(Rect.fromLTWH(w * 0.54, h * 0.78, w * 0.19, h * 0.11), light);
    canvas.drawOval(
      Rect.fromLTWH(w * 0.24, h * 0.42, w * 0.52, h * 0.46),
      Paint()..color = _fur,
    );
    canvas.drawOval(Rect.fromLTWH(w * 0.33, h * 0.55, w * 0.34, h * 0.31), light);

    // Orecchie, poi testa: la testa copre la base delle orecchie.
    _drawEar(canvas, w, h, left: true);
    _drawEar(canvas, w, h, left: false);
    canvas.drawCircle(Offset(w * 0.5, h * 0.30), w * 0.245, Paint()..color = _fur);

    // Strisce sulla fronte.
    final stripe = Paint()
      ..color = _furDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.018
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(Offset(w * 0.50, h * 0.085), Offset(w * 0.50, h * 0.15), stripe)
      ..drawLine(Offset(w * 0.42, h * 0.10), Offset(w * 0.40, h * 0.16), stripe)
      ..drawLine(Offset(w * 0.58, h * 0.10), Offset(w * 0.60, h * 0.16), stripe);

    // Guance rosa.
    final cheek = Paint()..color = _pink.withValues(alpha: 0.55);
    canvas
      ..drawOval(Rect.fromLTWH(w * 0.29, h * 0.325, w * 0.11, h * 0.055), cheek)
      ..drawOval(Rect.fromLTWH(w * 0.60, h * 0.325, w * 0.11, h * 0.055), cheek);

    // Occhi.
    final eyeY = h * 0.285;
    final eyeGap = w * 0.085;
    final eyeR = w * 0.035;
    if (happy) {
      final line = Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.022
        ..strokeCap = StrokeCap.round;
      for (final x in [w * 0.5 - eyeGap, w * 0.5 + eyeGap]) {
        final arc = Path()
          ..moveTo(x - eyeR * 1.2, eyeY + eyeR * 0.4)
          ..quadraticBezierTo(x, eyeY - eyeR * 1.6, x + eyeR * 1.2, eyeY + eyeR * 0.4);
        canvas.drawPath(arc, line);
      }
    } else {
      for (final x in [w * 0.5 - eyeGap, w * 0.5 + eyeGap]) {
        canvas.drawCircle(Offset(x, eyeY), eyeR, Paint()..color = _ink);
        canvas.drawCircle(
          Offset(x - eyeR * 0.3, eyeY - eyeR * 0.3),
          eyeR * 0.32,
          Paint()..color = _white,
        );
      }
    }

    // Sopracciglia: pensieroso / preoccupato.
    if (thinking || error) {
      final brow = Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.018
        ..strokeCap = StrokeCap.round;
      final leftY = error ? h * 0.205 : h * 0.195;
      final rightY = error ? h * 0.205 : h * 0.185;
      canvas
        ..drawLine(Offset(w * 0.40, leftY), Offset(w * 0.47, h * 0.215), brow)
        ..drawLine(Offset(w * 0.53, h * 0.215), Offset(w * 0.60, rightY), brow);
    }

    // Naso, bocca e baffi.
    final nose = Path()
      ..moveTo(w * 0.47, h * 0.355)
      ..lineTo(w * 0.53, h * 0.355)
      ..lineTo(w * 0.50, h * 0.385)
      ..close();
    canvas.drawPath(nose, Paint()..color = _pink);
    final mouth = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.013
      ..strokeCap = StrokeCap.round;
    final smile = Path()
      ..moveTo(w * 0.50, h * 0.385)
      ..lineTo(w * 0.50, h * 0.405)
      ..moveTo(w * 0.50, h * 0.405)
      ..quadraticBezierTo(w * 0.46, h * 0.44, w * 0.43, h * 0.405)
      ..moveTo(w * 0.50, h * 0.405)
      ..quadraticBezierTo(w * 0.54, h * 0.44, w * 0.57, h * 0.405);
    canvas.drawPath(smile, mouth);
    _drawWhiskers(canvas, w, h);

    // Bandana colorata con campanellino.
    _drawCollar(canvas, w, h);

    // Zampe anteriori.
    canvas
      ..drawOval(Rect.fromLTWH(w * 0.33, h * 0.80, w * 0.14, h * 0.09), light)
      ..drawOval(Rect.fromLTWH(w * 0.53, h * 0.80, w * 0.14, h * 0.09), light);

    if (happy) _drawHearts(canvas, w, h);
    if (thinking) _drawThought(canvas, w, h);
    if (error) _drawSweat(canvas, w, h);
  }

  void _drawTail(Canvas canvas, double w, double h) {
    final tail = Path()
      ..moveTo(w * 0.72, h * 0.74)
      ..cubicTo(w * 0.99, h * 0.78, w * 0.99, h * 0.40, w * 0.80, h * 0.38);
    canvas.drawPath(
      tail,
      Paint()
        ..color = _fur
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.11
        ..strokeCap = StrokeCap.round,
    );
    final dark = Paint()
      ..color = _furDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.022
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(Offset(w * 0.90, h * 0.68), Offset(w * 0.97, h * 0.64), dark)
      ..drawLine(Offset(w * 0.94, h * 0.50), Offset(w * 0.86, h * 0.47), dark);
  }

  void _drawEar(Canvas canvas, double w, double h, {required bool left}) {
    canvas.save();
    if (!left) {
      canvas.translate(w, 0);
      canvas.scale(-1, 1);
    }
    final outer = Path()
      ..moveTo(w * 0.28, h * 0.20)
      ..lineTo(w * 0.24, h * 0.04)
      ..lineTo(w * 0.44, h * 0.15)
      ..close();
    canvas.drawPath(outer, Paint()..color = _fur);
    final inner = Path()
      ..moveTo(w * 0.30, h * 0.175)
      ..lineTo(w * 0.28, h * 0.095)
      ..lineTo(w * 0.39, h * 0.15)
      ..close();
    canvas.drawPath(inner, Paint()..color = _pink);
    canvas.restore();
  }

  void _drawWhiskers(Canvas canvas, double w, double h) {
    final paint = Paint()
      ..color = _ink.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.010
      ..strokeCap = StrokeCap.round;
    for (final side in [-1.0, 1.0]) {
      for (final offset in [-0.025, 0.0, 0.025]) {
        canvas.drawLine(
          Offset(w * (0.5 + side * 0.08), h * (0.375 + offset)),
          Offset(w * (0.5 + side * 0.24), h * (0.35 + offset * 1.4)),
          paint,
        );
      }
    }
  }

  void _drawCollar(Canvas canvas, double w, double h) {
    final paint = Paint()..color = scarf;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.33, h * 0.455, w * 0.34, h * 0.065),
        Radius.circular(h * 0.028),
      ),
      paint,
    );
    final bandana = Path()
      ..moveTo(w * 0.43, h * 0.51)
      ..lineTo(w * 0.57, h * 0.51)
      ..lineTo(w * 0.50, h * 0.59)
      ..close();
    canvas.drawPath(bandana, paint);
    canvas.drawCircle(Offset(w * 0.50, h * 0.545), w * 0.028, Paint()..color = _bell);
    canvas.drawCircle(Offset(w * 0.50, h * 0.545), w * 0.010, Paint()..color = _furDark);
  }

  void _drawHearts(Canvas canvas, double w, double h) {
    final heart = Paint()..color = DuoColors.red;
    for (final offset in [
      Offset(w * 0.10, h * 0.18),
      Offset(w * 0.88, h * 0.26),
    ]) {
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.scale(w * 0.0016);
      final path = Path()
        ..moveTo(0, 10)
        ..cubicTo(-18, -8, -8, -22, 0, -12)
        ..cubicTo(8, -22, 18, -8, 0, 10)
        ..close();
      canvas.drawPath(path, heart);
      canvas.restore();
    }
  }

  void _drawThought(Canvas canvas, double w, double h) {
    final bubble = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(w * 0.82, h * 0.18), w * 0.12, bubble);
    canvas.drawCircle(Offset(w * 0.72, h * 0.12), w * 0.045, bubble);
    canvas.drawCircle(Offset(w * 0.66, h * 0.09), w * 0.022, bubble);
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '?',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: DuoColors.blue),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(w * 0.82 - textPainter.width / 2, h * 0.18 - textPainter.height / 2));
  }

  void _drawSweat(Canvas canvas, double w, double h) {
    final drop = Path()
      ..moveTo(w * 0.86, h * 0.20)
      ..cubicTo(w * 0.91, h * 0.27, w * 0.90, h * 0.34, w * 0.86, h * 0.34)
      ..cubicTo(w * 0.82, h * 0.34, w * 0.81, h * 0.27, w * 0.86, h * 0.20)
      ..close();
    canvas.drawPath(drop, Paint()..color = DuoColors.blue);
  }

  @override
  bool shouldRepaint(covariant _CatPainter old) =>
      old.mood != mood || old.scarf != scarf || old.showShadow != showShadow;
}
