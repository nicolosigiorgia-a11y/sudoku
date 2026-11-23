import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'duo_theme.dart';

class SudokuGrid extends StatefulWidget {
  final List<TextEditingController> controllers;
  final List<String> origins;
  final Set<int> conflicts;
  final Set<int> highlightBlock;
  final Set<int> highlightCell;
  final Set<int> highlightPeers;
  final Set<int> highlightSame;
  final Set<int> wrong;
  final Set<int> completedCells;
  final Set<int> celebrationCells;
  final int completionVersion;
  final bool readOnlyCells;
  final ValueChanged<int> onChanged;
  final ValueChanged<int>? onTap;

  const SudokuGrid({
    super.key,
    required this.controllers,
    required this.origins,
    required this.conflicts,
    required this.highlightBlock,
    required this.highlightCell,
    required this.highlightPeers,
    required this.onChanged,
    this.highlightSame = const <int>{},
    this.wrong = const <int>{},
    this.completedCells = const <int>{},
    this.celebrationCells = const <int>{},
    this.completionVersion = 0,
    this.readOnlyCells = false,
    this.onTap,
  });

  @override
  State<SudokuGrid> createState() => _SudokuGridState();
}

class _SudokuGridState extends State<SudokuGrid> with SingleTickerProviderStateMixin {
  AnimationController? _completion;
  final Map<int, Animation<double>> _cellAnimations = <int, Animation<double>>{};

  @override
  void initState() {
    super.initState();
    _syncCompletionAnimation();
  }

  @override
  void didUpdateWidget(covariant SudokuGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.completionVersion != oldWidget.completionVersion ||
        widget.celebrationCells != oldWidget.celebrationCells) {
      _syncCompletionAnimation();
    }
  }

  @override
  void dispose() {
    _completion?.dispose();
    super.dispose();
  }

  /// Casca una dopo l'altra sulle celle appena completate (effetto domino),
  /// poi le lascia verdi perchè la riga/colonna/blocco è chiuso.
  void _syncCompletionAnimation() {
    _completion?.dispose();
    _completion = null;
    _cellAnimations.clear();

    final cells = widget.celebrationCells.toList()..sort();
    if (cells.isEmpty) return;

    _completion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    for (var i = 0; i < cells.length; i++) {
      final start = cells.length == 1 ? 0.0 : (i / (cells.length - 1)) * 0.62;
      final end = (start + 0.32).clamp(0.0, 1.0);
      _cellAnimations[cells[i]] = CurvedAnimation(
        parent: _completion!,
        curve: Interval(start, end, curve: Curves.bounceOut),
      );
    }
    _completion!.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: DuoColors.border,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 81,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 9,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemBuilder: (context, index) => _cell(index),
          ),
          // Linee nere tra i blocchi 3x3: sopra le celle, ma lasciano passare i tap.
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: const _BoxDividerPainter()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(int index) {
    final animation = _cellAnimations[index];
    if (animation == null) return _surface(index, null);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) => _surface(index, animation.value),
    );
  }

  Widget _surface(int index, double? progress) {
    final row = index ~/ 9;
    final col = index % 9;
    final tap = widget.onTap;

    final isWrong = widget.wrong.contains(index);
    Color background;
    if (isWrong) {
      background = const Color(0xFFFFC7C7);
    } else if (widget.conflicts.contains(index)) {
      background = const Color(0xFFFFD6D6);
    } else if (widget.highlightCell.contains(index)) {
      background = const Color(0xFFFFD86B);
    } else if (widget.completedCells.contains(index)) {
      background = const Color(0xFFCFF0BE);
    } else if (widget.highlightSame.contains(index)) {
      // Evidenziazione più marcata: si vedono subito tutte le occorrenze.
      background = const Color(0xFF9BDCFF);
    } else if (widget.highlightBlock.contains(index)) {
      background = const Color(0xFFFFF0B8);
    } else if (widget.highlightPeers.contains(index)) {
      background = const Color(0xFFE7F0FF);
    } else {
      switch (widget.origins[index]) {
        case 'ai':
          background = const Color(0xFFDFF5E6);
          break;
        case 'hint':
          background = const Color(0xFFF0E5FF);
          break;
        case 'ocr':
          background = const Color(0xFFEEF2FF);
          break;
        case 'sample':
          background = const Color(0xFFF3F6FF);
          break;
        default:
          background = Colors.white;
      }
    }

    if (progress != null) {
      // Giallo -> verde mentre il "pezzo domino" cade al suo posto.
      background = Color.lerp(
            const Color(0xFFFFC800),
            const Color(0xFFCFF0BE),
            progress,
          ) ??
          background;
    }

    final thickTop = row == 0 || row % 3 == 0;
    final thickLeft = col == 0 || col % 3 == 0;

    Widget cell = Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(
          thickTop && thickLeft ? 14 : 6,
        ),
        boxShadow: thickTop || thickLeft
            ? const [
                BoxShadow(
                  color: Color(0x18000000),
                  offset: Offset(1, 1),
                  blurRadius: 1,
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: widget.controllers[index],
        maxLength: 1,
        textAlign: TextAlign.center,
        showCursor: false,
        // Nei Livelli la tastiera non deve mai aprirsi: si inserisce solo
        // dalla barra numeri sottostante. Il tap serve comunque a selezionare.
        readOnly: widget.readOnlyCells || widget.origins[index] == 'given',
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (_) => widget.onChanged(index),
        onTap: tap == null ? null : () => tap(index),
        style: TextStyle(
          fontSize: 21,
          fontWeight: widget.highlightSame.contains(index) ||
                  widget.origins[index] == 'ocr' ||
                  widget.origins[index] == 'sample'
              ? FontWeight.w900
              : FontWeight.w700,
          color: isWrong
              ? DuoColors.redDark
              : widget.highlightSame.contains(index)
                  ? DuoColors.blueDark
                  : widget.origins[index] == 'ai' ||
                          widget.completedCells.contains(index)
                      ? DuoColors.greenDark
                      : const Color(0xFF1B2440),
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          counterText: '',
          contentPadding: EdgeInsets.zero,
          isDense: true,
        ),
      ),
    );

    if (progress == null) return cell;
    final fall = (1 - progress) * 15.0;
    final tilt = (1 - progress) * -0.22;
    cell = Transform.translate(
      offset: Offset(0, fall),
      child: Transform.rotate(
        angle: tilt,
        child: Transform.scale(scale: 0.72 + 0.28 * progress, child: cell),
      ),
    );
    return cell;
  }
}

/// Separatori spessi tra i nove riquadri 3x3, più un bordo esterno.
class _BoxDividerPainter extends CustomPainter {
  const _BoxDividerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()
      ..color = const Color(0xFF22262E)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;

    for (var i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      final y = size.height * i / 3;
      canvas
        ..drawLine(Offset(x, 2), Offset(x, size.height - 2), ink)
        ..drawLine(Offset(2, y), Offset(size.width - 2, y), ink);
    }

    // Cornice esterna sottile, per far sembrare la griglia una tavola da gioco.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(14),
      ),
      Paint()
        ..color = const Color(0xFF22262E)
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
