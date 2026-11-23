import 'package:flutter/material.dart';

import '../core/app_prefs.dart';
import '../core/cloud_sync.dart';
import '../core/levels.dart';
import '../core/sudoku.dart';
import '../ui/avatar.dart';
import '../ui/duo_theme.dart';

class LearnScreen extends StatefulWidget {
  final VoidCallback? onGoToLevels;

  const LearnScreen({super.key, this.onGoToLevels});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LessonStep {
  final String title;
  final String body;
  final List<int> cells;
  final Set<int> row;
  final Set<int> col;
  final Set<int> box;
  final Set<int> focus;
  final int? emptyIndex;
  final int? answer;
  final String hint;

  const _LessonStep({
    required this.title,
    required this.body,
    required this.cells,
    required this.row,
    required this.col,
    required this.box,
    required this.focus,
    this.emptyIndex,
    this.answer,
    this.hint = '',
  });

  bool get isExercise => answer != null;
}

class _LearnScreenState extends State<LearnScreen> {
  late final List<_LessonStep> _steps;
  int _step = 0;
  int? _selected;
  bool? _lastAnswerCorrect;
  AppPrefs? _prefs;

  @override
  void initState() {
    super.initState();
    _steps = _buildSteps();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await AppPrefs.load();
    if (mounted) setState(() => _prefs = prefs);
  }

  List<_LessonStep> _buildSteps() {
    final s = baseSolution;
    final row0 = Set<int>.from(List.generate(9, (i) => i));
    final col0 = Set<int>.from(List.generate(9, (i) => i * 9));
    final box0 = boxIndices(0).toSet();
    const center = 40;
    final peers = peerIndices(center);

    final rowExercise = List<int>.from(s)..[8] = 0;
    final colExercise = List<int>.from(s)..[36] = 0;
    final peerExercise = List<int>.from(s)..[center] = 0;

    return [
      _LessonStep(
        title: 'Benvenuto nel tutor!',
        body: 'In pochi passaggi imparerai a giocare a Sudoku. Non devi sapere nulla: '
            'ti mostro le regole e ti faccio provare con esercizi semplici. '
            'Alla fine potrai passare ai livelli o digitalizzare un Sudoku con la fotocamera.',
        cells: s,
        row: row0,
        col: col0,
        box: box0,
        focus: const <int>{},
      ),
      _LessonStep(
        title: 'La regola d’oro',
        body: 'Ogni riga deve contenere i numeri da 1 a 9 una sola volta. '
            'Guarda la riga in alto: c’è ogni numero una sola volta, senza ripetizioni. '
            'La stessa regola vale per le colonne.',
        cells: s,
        row: row0,
        col: const <int>{},
        box: const <int>{},
        focus: const <int>{},
      ),
      _LessonStep(
        title: 'Il blocco 3x3',
        body: 'Il quadrato grande è diviso in 9 blocchi da 3x3 celle. '
            'Anche in ogni blocco i numeri da 1 a 9 compaiono una sola volta. '
            'Qui vedi evidenziato il blocco in alto a sinistra.',
        cells: s,
        row: const <int>{},
        col: const <int>{},
        box: box0,
        focus: const <int>{},
      ),
      _LessonStep(
        title: 'Esercizio: manca un numero',
        body: 'Nella prima riga manca un solo numero (la cella gialla). '
            'Quale deve essere? Tocca un pulsante qui sotto e poi “Verifica”.',
        cells: rowExercise,
        row: row0,
        col: const <int>{},
        box: const <int>{},
        focus: const <int>{8},
        emptyIndex: 8,
        answer: s[8],
        hint: 'Conta quali numeri mancano nella riga evidenziata.',
      ),
      _LessonStep(
        title: 'Esercizio: controlla la colonna',
        body: 'Ora la cella vuota è in una colonna. Ricorda: la regola vale '
            'anche in verticale. Quale numero manca?',
        cells: colExercise,
        row: const <int>{},
        col: col0,
        box: const <int>{},
        focus: const <int>{36},
        emptyIndex: 36,
        answer: s[36],
        hint: 'Guarda i numeri già presenti nella colonna evidenziata.',
      ),
      _LessonStep(
        title: 'Esercizio: usa tutti gli indizi',
        body: 'La cella centrale è vuota. Le celle azzurre sono i suoi “vicini”: '
            'stanno nella stessa riga, colonna e blocco. Il numero giusto è '
            'l’unico che non compare tra i vicini.',
        cells: peerExercise,
        row: const <int>{},
        col: const <int>{},
        box: boxIndices(4).toSet(),
        focus: const <int>{center},
        emptyIndex: center,
        answer: s[center],
        hint: 'Prova a eliminare i numeri che vedi nelle celle azzurre.',
      ),
      _LessonStep(
        title: 'Ora sai giocare!',
        body: 'Hai imparato riga, colonna e blocco. Nel gioco puoi chiedere un '
            'suggerimento, usare 3 hint progressivi o risolvere la griglia. '
            'Vai ai livelli per mettere alla prova quello che hai imparato.',
        cells: s,
        row: const <int>{},
        col: const <int>{},
        box: const <int>{},
        focus: const <int>{center},
      ),
    ];
  }

  Future<void> _next() async {
    if (_step < _steps.length - 1) {
      setState(() {
        _step++;
        _selected = null;
        _lastAnswerCorrect = null;
      });
    } else {
      await _prefs?.setLessonsCompleted();
      CloudSync.instance.pushAfterChange();
      widget.onGoToLevels?.call();
    }
  }

  void _verify() {
    final step = _steps[_step];
    if (step.answer == null || _selected == null) return;
    setState(() => _lastAnswerCorrect = _selected == step.answer);
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_step];
    final canVerify = step.isExercise && _selected != null && _lastAnswerCorrect != true;
    final canGoOn = !step.isExercise || _lastAnswerCorrect == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Impara a giocare'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (_step + 1) / _steps.length,
                color: DuoColors.green,
                backgroundColor: DuoColors.border,
                minHeight: 8,
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DuoCard(
                color: DuoColors.greenLight,
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CatMascot(
                      size: 58,
                      mood: _lastAnswerCorrect == true ? AvatarMood.happy : AvatarMood.thinking,
                      scarfColor: DuoColors.yellow,
                      showShadow: false,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Lezione ${_step + 1} di ${_steps.length}',
                              style: const TextStyle(fontSize: 12, color: DuoColors.greenDark, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(step.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(step.body, style: const TextStyle(fontSize: 15, height: 1.45)),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: _LessonGrid(
                  cells: step.cells,
                  row: step.row,
                  col: step.col,
                  box: step.box,
                  focus: step.focus,
                  wrong: _lastAnswerCorrect == false ? step.focus : const <int>{},
                ),
              ),
              const SizedBox(height: 16),
              if (step.isExercise) ...[
                DuoCard(
                  color: DuoColors.blueLight,
                  padding: const EdgeInsets.all(12),
                  shadows: false,
                  child: Text('💡 $step.hint', style: const TextStyle(fontSize: 12.5, color: DuoColors.text)),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(9, (i) {
                    final value = i + 1;
                    final chosen = _selected == value;
                    return SizedBox(
                      width: 50,
                      child: ChoiceChip(
                        label: Text('$value', style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: chosen ? DuoColors.blueDark : DuoColors.text,
                        )),
                        selected: chosen,
                        showCheckmark: false,
                        selectedColor: DuoColors.blueLight,
                        backgroundColor: Colors.white,
                        side: BorderSide(color: chosen ? DuoColors.blue : DuoColors.border, width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onSelected: _lastAnswerCorrect == true
                            ? null
                            : (_) => setState(() {
                                  _selected = value;
                                  _lastAnswerCorrect = null;
                                }),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                if (_lastAnswerCorrect == true)
                  Row(
                    children: [
                      CatMascot(size: 36, mood: AvatarMood.happy, scarfColor: DuoColors.green, showShadow: false),
                      const SizedBox(width: 8),
                      const Text('Esatto! Ora puoi continuare.',
                          style: TextStyle(color: DuoColors.greenDark, fontWeight: FontWeight.w800)),
                    ],
                  )
                else if (_lastAnswerCorrect == false)
                  const Text('Non ancora. Riprova: osserva bene gli indizi.',
                      style: TextStyle(color: DuoColors.redDark, fontWeight: FontWeight.w800)),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  if (_step > 0)
                    DuoButton(
                      label: 'Indietro',
                      style: DuoButtonStyle.ghost,
                      expanded: false,
                      onPressed: () => setState(() {
                        _step--;
                        _selected = null;
                        _lastAnswerCorrect = null;
                      }),
                    ),
                  const Spacer(),
                  if (canVerify)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: DuoButton(
                        label: 'Verifica',
                        icon: Icons.check,
                        style: DuoButtonStyle.yellow,
                        expanded: false,
                        onPressed: _verify,
                      ),
                    ),
                  DuoButton(
                    label: _step == _steps.length - 1 ? 'Vai ai livelli' : 'Continua',
                    icon: Icons.arrow_forward,
                    expanded: false,
                    onPressed: canGoOn ? _next : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LessonGrid extends StatelessWidget {
  final List<int> cells;
  final Set<int> row;
  final Set<int> col;
  final Set<int> box;
  final Set<int> focus;
  final Set<int> wrong;

  const _LessonGrid({
    required this.cells,
    required this.row,
    required this.col,
    required this.box,
    required this.focus,
    required this.wrong,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: DuoColors.border,
          borderRadius: BorderRadius.circular(18),
        ),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 81,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 9,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemBuilder: (context, index) {
            final r = index ~/ 9;
            final c = index % 9;
            Color background = Colors.white;
            if (box.contains(index)) background = DuoColors.purpleLight;
            if (row.contains(index)) background = const Color(0xFFDCE8FF);
            if (col.contains(index)) background = const Color(0xFFDFF5E6);
            if (focus.contains(index)) background = const Color(0xFFFFD86B);
            if (wrong.contains(index)) background = const Color(0xFFFFD6D6);

            final thickTop = r == 0 || r % 3 == 0;
            final thickLeft = c == 0 || c % 3 == 0;

            return Container(
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(thickTop && thickLeft ? 14 : 6),
              ),
              child: Center(
                child: Text(
                  cells[index] == 0 ? '' : '${cells[index]}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: focus.contains(index) ? FontWeight.w900 : FontWeight.w700,
                    color: const Color(0xFF1B2440),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
