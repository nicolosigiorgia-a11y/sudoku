import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_prefs.dart';
import '../core/cloud_sync.dart';
import '../core/levels.dart';
import '../core/sudoku.dart';
import '../ui/avatar.dart';
import '../ui/duo_theme.dart';
import '../ui/sudoku_grid.dart';

class LevelsScreen extends StatefulWidget {
  const LevelsScreen({super.key});

  @override
  State<LevelsScreen> createState() => _LevelsScreenState();
}

class _LevelsScreenState extends State<LevelsScreen> {
  late final List<LevelDef> _levels;
  AppPrefs? _prefs;
  int? _selected;
  int _xp = 0;
  bool _lessonsDone = false;

  @override
  void initState() {
    super.initState();
    _levels = buildLevels();
    CloudSync.instance.progressRevision.addListener(_onProgressChanged);
    _load();
  }

  @override
  void dispose() {
    CloudSync.instance.progressRevision.removeListener(_onProgressChanged);
    super.dispose();
  }

  void _onProgressChanged() {
    if (mounted) _refresh();
  }

  Future<void> _load() async {
    final prefs = await AppPrefs.load();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _xp = prefs.xp;
      _lessonsDone = prefs.lessonsCompleted;
    });
  }

  Future<void> _refresh() async {
    final prefs = _prefs;
    if (prefs == null) return;
    setState(() {
      _xp = prefs.xp;
      _lessonsDone = prefs.lessonsCompleted;
    });
  }

  Future<void> _openLevel(int id) async {
    var prefs = _prefs;
    if (prefs == null) {
      // Un tap molto rapido può arrivare prima del caricamento delle prefs.
      await _load();
      if (!mounted) return;
      prefs = _prefs;
    }
    if (prefs == null) return;
    if (!prefs.isLevelUnlocked(id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa il livello precedente per sbloccare questo.')),
      );
      return;
    }
    setState(() => _selected = id);
  }

  @override
  Widget build(BuildContext context) {
    if (_selected != null) {
      return SudokuGameScreen(
        level: _levels.firstWhere((l) => l.id == _selected),
        prefs: _prefs!,
        onBack: () {
          _refresh();
          setState(() => _selected = null);
        },
        onNext: () {
          _refresh();
          final next = _selected! + 1;
          setState(() => _selected = next <= _levels.length ? next : null);
        },
        hasNext: _selected! < _levels.length,
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Livelli'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(child: _xpBadge()),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DuoCard(
                color: DuoColors.greenLight,
                child: Row(
                  children: [
                    const CatParade(size: 48, scarves: [DuoColors.yellow, DuoColors.green, DuoColors.blue]),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Allenati come in un gioco', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(
                            _lessonsDone
                                ? 'Lezioni completate: puoi affrontare le sfide.'
                                : 'Consiglio: fai prima le lezioni nella scheda "Impara".',
                            style: const TextStyle(fontSize: 13, color: DuoColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _levels.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.05,
                ),
                itemBuilder: (context, i) => _levelCard(_levels[i]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _xpBadge() {
    return DuoBadge(
      text: '$_xp XP',
      icon: Icons.stars,
      color: DuoColors.yellowLight,
      textColor: DuoColors.yellowDark,
    );
  }

  Widget _levelCard(LevelDef level) {
    final prefs = _prefs;
    final unlocked = prefs?.isLevelUnlocked(level.id) ?? level.id == 1;
    final stars = prefs?.starsForLevel(level.id) ?? 0;
    final best = prefs?.bestTimeForLevel(level.id);
    final scarf = [DuoColors.yellow, DuoColors.blue, DuoColors.purple, DuoColors.green][(level.id - 1) % 4];

    return DuoCard(
      color: unlocked ? DuoColors.surface : const Color(0xFFF5F6FA),
      padding: const EdgeInsets.all(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: unlocked ? () => _openLevel(level.id) : null,
        child: Opacity(
          opacity: unlocked ? 1 : 0.55,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CatMascot(
                    size: 44,
                    scarfColor: scarf,
                    mood: unlocked ? AvatarMood.happy : AvatarMood.idle,
                    showShadow: false,
                  ),
                  const SizedBox(width: 8),
                  Text('${level.id}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: DuoColors.text)),
                  const Spacer(),
                  if (!unlocked) const Icon(Icons.lock_outline, color: DuoColors.muted),
                ],
              ),
              const SizedBox(height: 6),
              Text(level.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(height: 2),
              Text(level.subtitle, style: const TextStyle(fontSize: 11, color: DuoColors.muted), maxLines: 2),
              const Spacer(),
              Row(
                children: List.generate(3, (i) => Icon(
                  i < stars ? Icons.star : Icons.star_border,
                  size: 17,
                  color: i < stars ? DuoColors.yellow : DuoColors.border,
                )),
              ),
              const SizedBox(height: 4),
              Text(
                best == null ? '${level.empties} celle vuote' : 'Migliore: ${_formatTime(best)}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: DuoColors.blueDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

/// Il same gameplay usato dai Livelli. Viene riutilizzato anche dalla pagina
/// Foto quando l'utente vuole giocare la griglia appena digitalizzata.
class SudokuGameScreen extends StatefulWidget {
  final LevelDef level;
  final AppPrefs prefs;
  final VoidCallback onBack;
  final VoidCallback? onNext;
  final bool hasNext;
  /// false per le griglie dalla foto: non devono dare XP né sbloccare livelli.
  final bool saveProgress;
  /// Titolo della barra: i Livelli usano quello standard, la foto uno dedicato.
  final String? screenTitle;

  const SudokuGameScreen({
    super.key,
    required this.level,
    required this.prefs,
    required this.onBack,
    this.onNext,
    this.hasNext = false,
    this.saveProgress = true,
    this.screenTitle,
  });

  @override
  State<SudokuGameScreen> createState() => _SudokuGameState();
}

class _SudokuGameState extends State<SudokuGameScreen> {
  late List<int> _cells;
  late List<String> _origins;
  late List<TextEditingController> _controllers;
  final Set<int> _conflicts = <int>{};
  final Set<int> _wrong = <int>{};
  final Set<int> _highlightCell = <int>{};
  final Set<int> _highlightPeers = <int>{};
  final Set<int> _highlightBlock = <int>{};
  final Set<int> _highlightSame = <int>{};
  final Set<String> _completedLines = <String>{};
  final Set<int> _completedCells = <int>{};
  Set<int> _celebrationCells = <int>{};
  int _completionVersion = 0;
  int? _selectedNumber;
  int? _lastTapped;
  final List<_LevelEdit> _undoStack = <_LevelEdit>[];
  int _hintsUsed = 0;
  int _mistakes = 0;
  int _hearts = 3;
  final Stopwatch _stopwatch = Stopwatch()..start();
  Timer? _ticker;
  Timer? _wrongFlashTimer;
  int _elapsed = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _cells = List<int>.from(widget.level.puzzle);
    _origins = List<String>.generate(81, (i) => _cells[i] == 0 ? 'empty' : 'given');
    _controllers = List.generate(81, (i) => TextEditingController(text: _cells[i] == 0 ? '' : '${_cells[i]}'));
    _recomputeCompletions();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_finished) setState(() => _elapsed = _stopwatch.elapsed.inSeconds);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _wrongFlashTimer?.cancel();
    _stopwatch.stop();
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _remember(int index) {
    _undoStack.add(_LevelEdit(index, _cells[index], _origins[index]));
  }

  /// Gestisce un errore in tempo reale: tolto un cuore, numero rimosso e,
  /// se arrivano a zero, dialog di fine partita.
  void _registerMistake({
    Set<int>? cleared,
    int? flashed,
  }) {
    final heartsLeft = _hearts - 1;
    setState(() {
      if (cleared != null) {
        for (final i in cleared) {
          _cells[i] = 0;
          _origins[i] = 'empty';
          _controllers[i].text = '';
        }
        _conflicts
          ..clear()
          ..addAll(conflicts(_cells));
        _recomputeCompletions();
      }
      if (flashed != null) {
        _wrong
          ..clear()
          ..add(flashed);
        _lastTapped = flashed;
      } else {
        _wrong.clear();
      }
      _mistakes++;
      _hearts = heartsLeft;
      if (heartsLeft <= 0) _finished = true;
    });
    if (flashed != null) {
      _wrongFlashTimer?.cancel();
      _wrongFlashTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _wrong.clear());
      });
    }
    if (heartsLeft <= 0) _showGameOver();
  }

  void _showGameOver() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Column(
          children: [
            const CatMascot(size: 70, mood: AvatarMood.error, scarfColor: DuoColors.red),
            const SizedBox(height: 6),
            const Text('Cuori finiti!', textAlign: TextAlign.center),
          ],
        ),
        content: const Text('Hai esaurito i 3 cuori. Riprova il livello da capo.'),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); widget.onBack(); },
            child: Text(widget.saveProgress ? 'Mappa' : 'Torna alla foto'),
          ),
          DuoButton(
            label: 'Riprova',
            icon: Icons.refresh,
            expanded: false,
            onPressed: () { Navigator.pop(context); _restartLevel(); },
          ),
        ],
      ),
    );
  }

  void _syncNumberHighlight() {
    final number = _selectedNumber;
    _highlightSame
      ..clear()
      ..addAll(
        number == null
            ? const <int>[]
            : List<int>.generate(81, (i) => i).where((i) => _cells[i] == number),
      );
  }

  /// Celle di una riga ('rN'), colonna ('cN') o blocco 3x3 ('bN').
  static List<int> _lineCells(String key) {
    final n = int.parse(key.substring(1));
    switch (key[0]) {
      case 'r':
        return List<int>.generate(9, (c) => n * 9 + c);
      case 'c':
        return List<int>.generate(9, (r) => r * 9 + n);
      case 'b':
        final r0 = (n ~/ 3) * 3;
        final c0 = (n % 3) * 3;
        return List<int>.generate(9, (k) => (r0 + k ~/ 3) * 9 + c0 + k % 3);
      default:
        return const <int>[];
    }
  }

  /// Ricalcola righe, colonne e blocchi chiusi. Con [animate] le linee
  /// appena completate diventano una cascata domino nella griglia.
  void _recomputeCompletions({bool animate = false}) {
    final next = <String, List<int>>{};
    for (var n = 0; n < 9; n++) {
      for (final key in ['r$n', 'c$n', 'b$n']) {
        final indices = _lineCells(key);
        if (indices.every((i) => _cells[i] != 0)) next[key] = indices;
      }
    }
    final fresh = animate
        ? next.keys.where((key) => !_completedLines.contains(key)).toList()
        : const <String>[];
    _completedLines
      ..clear()
      ..addAll(next.keys);
    _completedCells
      ..clear()
      ..addAll(next.values.expand((cells) => cells));
    if (fresh.isNotEmpty) {
      _celebrationCells = {for (final key in fresh) ...next[key]!};
      _completionVersion++;
    } else if (!animate) {
      _celebrationCells = <int>{};
    }
  }

  void _applyValue(int index, int value, String origin) {
    if (_origins[index] == 'given' || _finished) return;
    // il controllo avviene subito, senza aspettare il pulsante "Controlla":
    // il numero sbagliato non viene mai scritto nella casella.
    if (value != 0 && origin == 'user' && value != widget.level.solution[index]) {
      _registerMistake(flashed: index);
      return;
    }
    _remember(index);
    setState(() {
      _cells[index] = value;
      _origins[index] = origin;
      _controllers[index].text = value == 0 ? '' : '$value';
      _conflicts
        ..clear()
        ..addAll(conflicts(_cells));
      _wrong.remove(index);
      _lastTapped = index;
      if (value != 0) _selectedNumber = value;
      _syncNumberHighlight();
      _recomputeCompletions(animate: true);
    });
  }

  void _onChanged(int index) {
    if (_origins[index] == 'given' || _finished) return;
    final raw = _controllers[index].text.replaceAll(RegExp(r'[^0-9]'), '');
    final value = raw.isEmpty ? 0 : int.tryParse(raw[0]) ?? 0;
    final text = value == 0 ? '' : '$value';
    if (_controllers[index].text != text) _controllers[index].text = text;
    _applyValue(index, value, value == 0 ? 'empty' : 'user');
  }

  void _onCellTap(int index) {
    if (_finished) return;
    final value = _cells[index];
    if (value != 0) {
      // Toccare un numero già presente (dato o inserito) lo evidenzia
      // insieme a tutte le sue altre occorrenze, senza modificarlo.
      setState(() {
        _lastTapped = index;
        _selectedNumber = value;
        _syncNumberHighlight();
      });
      return;
    }
    final number = _selectedNumber;
    if (number == null) {
      setState(() => _lastTapped = index);
      return;
    }
    FocusScope.of(context).unfocus();
    _applyValue(index, number, 'user');
  }

  void _selectNumber(int number) {
    if (_finished) return;
    setState(() {
      _selectedNumber = number;
      _syncNumberHighlight();
    });
  }

  void _erase() {
    final index = _lastTapped;
    if (index == null || _origins[index] == 'given' || _finished) return;
    if (_cells[index] == 0) return;
    _applyValue(index, 0, 'empty');
  }

  void _undo() {
    if (_undoStack.isEmpty || _finished) return;
    final edit = _undoStack.removeLast();
    setState(() {
      _cells[edit.index] = edit.value;
      _origins[edit.index] = edit.origin;
      _controllers[edit.index].text = edit.value == 0 ? '' : '${edit.value}';
      _conflicts
        ..clear()
        ..addAll(conflicts(_cells));
      _wrong.remove(edit.index);
      _lastTapped = edit.index;
      _selectedNumber = edit.value == 0 ? null : edit.value;
      _syncNumberHighlight();
      _recomputeCompletions();
    });
  }

  void _hint() {
    if (_finished) return;
    if (_hintsUsed >= 3) return;
    final solution = widget.level.solution;

    // Un numero sbagliato inserito dall'utente può rendere la griglia
    // irrisolvibile e bloccare findNextMove: lo escludiamo prima di cercare
    // la mossa, così il suggerimento funziona sempre.
    final clean = List<int>.from(_cells);
    for (var i = 0; i < 81; i++) {
      if (_origins[i] != 'given' && clean[i] != 0 && clean[i] != solution[i]) {
        clean[i] = 0;
      }
    }
    final move = findNextMove(clean);
    var index = move?.index ?? -1;
    if (index == -1) index = clean.indexWhere((value) => value == 0);
    if (index == -1 || index >= 81) return;

    // Il valore mostrato è sempre quello della soluzione del livello.
    final value = solution[index];
    _remember(index);
    setState(() {
      _cells[index] = value;
      _origins[index] = 'hint';
      _controllers[index].text = '$value';
      _selectedNumber = value;
      _syncNumberHighlight();
      _hintsUsed++;
      _conflicts
        ..clear()
        ..addAll(conflicts(_cells));
      _wrong.remove(index);
      _highlightCell
        ..clear()
        ..add(index);
      _highlightPeers
        ..clear()
        ..addAll(peerIndices(index));
      _highlightBlock.clear();
      _recomputeCompletions(animate: true);
    });
  }

  void _restartLevel() {
    final puzzle = widget.level.puzzle;
    _wrongFlashTimer?.cancel();
    setState(() {
      _cells = List<int>.from(puzzle);
      _origins = List<String>.generate(81, (i) => _cells[i] == 0 ? 'empty' : 'given');
      for (var i = 0; i < 81; i++) {
        _controllers[i].text = _cells[i] == 0 ? '' : '${_cells[i]}';
      }
      _conflicts.clear();
      _wrong.clear();
      _highlightCell.clear();
      _highlightPeers.clear();
      _highlightBlock.clear();
      _highlightSame.clear();
      _selectedNumber = null;
      _lastTapped = null;
      _undoStack.clear();
      _hintsUsed = 0;
      _mistakes = 0;
      _hearts = 3;
      _elapsed = 0;
      _finished = false;
      _recomputeCompletions();
    });
    _stopwatch
      ..reset()
      ..start();
  }

  Future<void> _check() async {
    if (_finished) return;
    final wrong = <int>{};
    for (var i = 0; i < 81; i++) {
      if (_cells[i] != 0 && _cells[i] != widget.level.solution[i]) wrong.add(i);
    }
    if (wrong.isNotEmpty) {
      // Difesa residua: in condizioni normali il numero viene già rifiutato
      // al momento dell'inserimento. Qui comunque viene rimosso e costa un cuore.
      _registerMistake(cleared: wrong);
      return;
    }
    if (_cells.any((v) => v == 0)) return;
    final stars = starsForRun(hintsUsed: _hintsUsed, mistakes: _mistakes);
    _stopwatch.stop();
    final seconds = _stopwatch.elapsed.inSeconds;
    setState(() => _finished = true);
    if (widget.saveProgress) {
      await widget.prefs.saveLevelResult(widget.level.id, stars, seconds);
      CloudSync.instance.pushAfterChange();
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Column(
          children: [
            const CatMascot(size: 70, mood: AvatarMood.happy, scarfColor: DuoColors.yellow),
            const SizedBox(height: 6),
            Text(
              widget.saveProgress ? 'Livello completato!' : 'Griglia completata!',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) => Icon(
                i < stars ? Icons.star : Icons.star_border,
                size: 42,
                color: i < stars ? DuoColors.yellow : DuoColors.border,
              )),
            ),
            const SizedBox(height: 12),
            Text('Tempo: ${_format(seconds)}'),
            const SizedBox(height: 4),
            Text('Hint usati: $_hintsUsed · Errori: $_mistakes'),
            const SizedBox(height: 8),
            if (widget.saveProgress)
              Text('+${stars * 25} XP', style: const TextStyle(fontWeight: FontWeight.w800, color: DuoColors.greenDark)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); widget.onBack(); },
            child: Text(widget.saveProgress ? 'Mappa' : 'Torna alla foto'),
          ),
          if (widget.hasNext && widget.onNext != null)
            DuoButton(
              label: 'Livello successivo',
              icon: Icons.arrow_forward,
              expanded: false,
              onPressed: () { Navigator.pop(context); widget.onNext!(); },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filled = _cells.where((v) => v != 0).length;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.screenTitle ?? 'Livello ${widget.level.id} · ${widget.level.title}'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) => Icon(
                i < _hearts ? Icons.favorite : Icons.favorite_border,
                size: 17,
                color: i < _hearts ? DuoColors.red : DuoColors.border,
              )),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(child: Text(_format(_elapsed), style: const TextStyle(fontWeight: FontWeight.w700))),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              DuoCard(
                color: DuoColors.blueLight,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    CatMascot(size: 44, mood: AvatarMood.thinking, scarfColor: DuoColors.blue, showShadow: false),
                    const SizedBox(width: 10),
                    Expanded(child: Text(widget.level.focus, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                    Text('$filled/81', style: const TextStyle(fontSize: 12, color: DuoColors.muted)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: SudokuGrid(
                    controllers: _controllers,
                    origins: _origins,
                    conflicts: _conflicts.union(_wrong),
                    highlightBlock: _highlightBlock,
                    highlightCell: _highlightCell,
                    highlightPeers: _highlightPeers,
                    highlightSame: _highlightSame,
                    wrong: _wrong,
                    completedCells: _completedCells,
                    celebrationCells: _celebrationCells,
                    completionVersion: _completionVersion,
                    readOnlyCells: true,
                    onChanged: _onChanged,
                    onTap: _onCellTap,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DuoButton(
                      label: 'Controlla',
                      icon: Icons.check_circle_outline,
                      onPressed: _finished ? null : _check,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DuoButton(
                      label: 'Suggerimento',
                      icon: Icons.tips_and_updates_outlined,
                      style: DuoButtonStyle.yellow,
                      onPressed: _finished || _hintsUsed >= 3 ? null : _hint,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: DuoColors.yellowLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: DuoColors.yellowDark, width: 1),
                    ),
                    child: Text(
                      'Suggerimenti ${3 - _hintsUsed}/3',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: DuoColors.yellowDark,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _numberPad(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numberPad() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Tocca un numero per evidenziarlo, poi una cella vuota per inserirlo.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: DuoColors.muted),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var number = 1; number <= 9; number++)
              Expanded(child: _digitButton(number)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: _finished ? null : _undo,
              icon: const Icon(Icons.undo, size: 16),
              label: const Text('Annulla'),
            ),
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: _finished ? null : _erase,
              icon: const Icon(Icons.backspace_outlined, size: 16),
              label: const Text('Cancella'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _digitButton(int number) {
    final selected = _selectedNumber == number;
    return InkWell(
      onTap: _finished ? null : () => _selectNumber(number),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: selected ? DuoColors.yellowLight : DuoColors.blueLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? DuoColors.yellowDark : DuoColors.blue,
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '$number',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: selected ? DuoColors.yellowDark : DuoColors.blueDark,
          ),
        ),
      ),
    );
  }

  static String _format(int seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
}

class _LevelEdit {
  final int index;
  final int value;
  final String origin;

  const _LevelEdit(this.index, this.value, this.origin);
}

