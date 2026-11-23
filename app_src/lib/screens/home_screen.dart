import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../core/api_service.dart';
import '../core/app_prefs.dart';
import '../core/cloud_sync.dart';
import '../core/levels.dart';
import '../core/local_ocr.dart';
import '../core/sudoku.dart';
import '../screens/levels_screen.dart';
import '../ui/avatar.dart';
import '../ui/duo_theme.dart';
import '../ui/sudoku_grid.dart';

const List<int> _samplePuzzle = [
  5, 3, 0, 0, 7, 0, 0, 0, 0, //
  6, 0, 0, 1, 9, 5, 0, 0, 0, //
  0, 9, 8, 0, 0, 0, 0, 6, 0, //
  8, 0, 0, 0, 6, 0, 0, 0, 3, //
  4, 0, 0, 8, 0, 3, 0, 0, 1, //
  7, 0, 0, 0, 2, 0, 0, 0, 6, //
  0, 6, 0, 0, 0, 0, 2, 8, 0, //
  0, 0, 0, 4, 1, 9, 0, 0, 5, //
  0, 0, 0, 0, 8, 0, 0, 7, 9, //
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FlutterTts _tts = FlutterTts();
  final ImagePicker _picker = ImagePicker();
  final List<TextEditingController> _controllers = List.generate(81, (_) => TextEditingController());

  AppPrefs? _prefs;
  ApiService _api = ApiService(AppPrefs.defaultBaseUrl);
  String _baseUrl = AppPrefs.defaultBaseUrl;

  List<int> _cells = List<int>.filled(81, 0);
  List<String> _origins = List<String>.filled(81, 'empty');
  Set<int> _originalEmpty = <int>{};
  List<int>? _solution;

  String? _imagePath;
  String? _busy;
  bool _apiConfigured = false;
  bool _voiceEnabled = false;
  String _model = '—';

  AvatarMood _mood = AvatarMood.idle;
  String _tutorTitle = 'Pronto quando lo sei';
  String _tutorSubtitle = 'Carica una foto, usa l\'esempio o scatta il Sudoku cartaceo.';
  String _statusMessage = 'Nessuna griglia caricata.';

  Move? _currentMove;
  Move? _hintMove;
  String? _explanation;
  String _explanationTag = '';
  int _hintLevel = 0;

  final Set<int> _conflicts = <int>{};
  final Set<int> _highlightBlock = <int>{};
  final Set<int> _highlightCell = <int>{};
  final Set<int> _highlightPeers = <int>{};

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      _prefs = await AppPrefs.load();
      final url = _prefs!.baseUrl;
      final voice = _prefs!.voiceEnabled;
      if (!mounted) return;
      setState(() {
        _baseUrl = url;
        _voiceEnabled = voice;
        _api = ApiService(url, apiKey: _prefs!.apiKey);
      });
      try {
        await _tts.setLanguage('it-IT');
        await _tts.setSpeechRate(0.95);
      } catch (_) {
        // TTS è un bonus: l'app resta utilizzabile senza sintesi vocale.
      }
      await _refreshStatus();
    } catch (e) {
      _setStatus('Preferenze non disponibili: ${e.toString()}', error: true);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    _tts.stop();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    try {
      final status = await _api.status();
      if (!mounted) return;
      setState(() {
        _apiConfigured = status.configured;
        _model = status.model;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _apiConfigured = false;
        _model = 'offline';
      });
    }
  }

  void _clearHighlights() {
    _highlightBlock.clear();
    _highlightCell.clear();
    _highlightPeers.clear();
  }

  void _writeValue(int index, int value, String origin) {
    _cells[index] = value;
    _origins[index] = value == 0 ? 'empty' : origin;
    _controllers[index].text = value == 0 ? '' : '$value';
    _solution = null;
    _conflicts.clear();
  }

  void _loadCells(List<int> cells, String origin) {
    _cells = List<int>.from(cells);
    _origins = List<String>.generate(81, (i) => cells[i] == 0 ? 'empty' : origin);
    _originalEmpty = <int>{};
    for (var i = 0; i < 81; i++) {
      _controllers[i].text = cells[i] == 0 ? '' : '${cells[i]}';
      if (cells[i] == 0) _originalEmpty.add(i);
    }
    _solution = null;
    _conflicts.clear();
    _conflicts.addAll(conflicts(_cells));
    _currentMove = null;
    _hintMove = null;
    _explanation = null;
    _hintLevel = 0;
    _clearHighlights();
  }

  void _onCellChanged(int index) {
    final raw = _controllers[index].text.replaceAll(RegExp(r'[^0-9]'), '');
    final value = raw.isEmpty ? 0 : int.tryParse(raw[0]) ?? 0;
    final text = value == 0 ? '' : '$value';
    if (_controllers[index].text != text) _controllers[index].text = text;
    setState(() {
      _writeValue(index, value, 'user');
      _conflicts.addAll(conflicts(_cells));
      _currentMove = null;
      _explanation = null;
      _hintLevel = 0;
      _hintMove = null;
      _clearHighlights();
      _tutorTitle = 'Griglia aggiornata';
      _tutorSubtitle = 'Controlla righe, colonne e blocchi prima di chiedere un hint.';
      _statusMessage = value == 0 ? 'Cella svuotata.' : 'Cella modificata dall\'utente.';
    });
  }

  void _setMood(AvatarMood mood, String title, String subtitle) {
    if (!mounted) return;
    setState(() {
      _mood = mood;
      _tutorTitle = title;
      _tutorSubtitle = subtitle;
    });
  }

  void _setStatus(String message, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _statusMessage = message;
      if (error) {
        _mood = AvatarMood.error;
        _tutorTitle = 'Qualcosa non torna';
        _tutorSubtitle = message;
      }
    });
  }

  void _showSnack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? const Color(0xFFB3261E) : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(Object error) {
    // I dettagli tecnici del servizio non devono comparire nell'interfaccia.
    final message = error
        .toString()
        .replaceAll(RegExp(r'gemini[-_ ]?[\w.]*', caseSensitive: false), 'servizio online');
    _setStatus(message, error: true);
    _showSnack(message, error: true);
  }

  Future<void> _speak(String text) async {
    if (!_voiceEnabled || text.trim().isEmpty) return;
    try {
      await _tts.setLanguage('it-IT');
      await _tts.speak(text);
    } catch (_) {
      // TTS is a bonus: never block the main flow because of it.
    }
  }

  Future<void> _toggleVoice() async {
    final next = !_voiceEnabled;
    setState(() => _voiceEnabled = next);
    await _prefs?.setVoiceEnabled(next);
    CloudSync.instance.pushAfterChange();
    if (next) {
      await _speak('Tutor vocale attivato. Posso leggerti le spiegazioni.');
    } else {
      await _tts.stop();
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 90, maxWidth: 2200);
      if (picked == null) {
        _showSnack(
          source == ImageSource.camera
              ? 'La fotocamera non ha restituito la foto. Riprova oppure usa la galleria.'
              : 'Nessuna immagine selezionata.',
          error: true,
        );
        return;
      }

      // Alcuni dispositivi restituiscono URI "content://" invece di un percorso
      // file: copiamo i byte in un file temporaneo garantito per anteprima e OCR.
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        _showSnack('L\'immagine risulta vuota. Riprova a scattare la foto.', error: true);
        return;
      }
      final temp = await getTemporaryDirectory();
      final extension = picked.name.contains('.') ? picked.name.split('.').last : 'jpg';
      final localFile = File(
        '${temp.path}${Platform.pathSeparator}sudoku_${DateTime.now().microsecondsSinceEpoch}.$extension',
      );
      await localFile.writeAsBytes(bytes);

      if (!mounted) return;
      setState(() {
        _imagePath = localFile.path;
        _statusMessage = 'Foto acquisita. Premi "Riconosci griglia": provo la lettura online e, se serve, quella locale.';
        _tutorTitle = 'Foto ricevuta';
        _tutorSubtitle = 'Tocca il gatto per chiedere un aiuto.';
        _mood = AvatarMood.thinking;
      });
    } catch (e) {
      _showError(e);
    }
  }

  void _loadSample() {
    setState(() {
      _imagePath = null;
      _loadCells(_samplePuzzle, 'sample');
      _statusMessage = 'Esempio didattico caricato (nessuna foto necessaria).';
      _mood = AvatarMood.happy;
      _tutorTitle = 'Esempio pronto';
      _tutorSubtitle = 'Prova suggerimento, hint progressivi o risoluzione.';
    });
  }

  /// Apre la griglia digitalizzata con lo stesso gameplay dei Livelli:
  /// 3 cuori, errore immediato, occorrenze evidenziate, 3 suggerimenti,
  /// barra numeri e animazione delle righe completate. Nessun XP o sblocco.
  Future<void> _playDigitized() async {
    final puzzle = List<int>.from(_cells);
    final filled = puzzle.where((v) => v != 0).length;
    if (filled == 0) {
      _showSnack('Prima digitalizza una griglia con "Riconosci griglia".', error: true);
      return;
    }
    if (filled == 81) {
      _showSnack('La griglia è già completa: non c\'è niente da giocare.', error: true);
      return;
    }
    if (conflicts(puzzle).isNotEmpty) {
      _showSnack('Correggi i numeri in conflitto nella griglia prima di giocare.', error: true);
      return;
    }
    final solution = solveCells(puzzle);
    if (solution == null) {
      _showSnack('Questa griglia non è risolvibile: controlla i numeri digitalizzati.', error: true);
      return;
    }
    var prefs = _prefs;
    prefs ??= await AppPrefs.load();
    if (!mounted) return;
    final navigator = Navigator.of(context);
    final level = LevelDef(
      id: 0,
      title: 'La tua griglia',
      subtitle: 'Sudoku digitalizzato dalla foto',
      focus: 'Tocca un numero e poi una casella vuota, esattamente come nei Livelli.',
      puzzle: puzzle,
      solution: solution,
      givens: filled,
    );
    await navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SudokuGameScreen(
          level: level,
          prefs: prefs!,
          onBack: () => navigator.pop(),
          saveProgress: false,
          screenTitle: 'Gioca · griglia dalla foto',
        ),
      ),
    );
  }

  /// Controllo rapido della rete sull'host della Edge Function.
  /// Non blocca il tentativo Gemini: serve solo a mostrare un messaggio
  /// comprensibile quando la connessione manca.
  Future<bool> _hasNetwork() async {
    try {
      final host = Uri.tryParse(_api.baseUrl)?.host;
      if (host == null || host.isEmpty) return false;
      final addresses =
          await InternetAddress.lookup(host).timeout(const Duration(seconds: 3));
      return addresses.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _runOcr() async {
    final path = _imagePath;
    if (path == null) {
      _showSnack('Prima carica o scatta una foto.', error: true);
      return;
    }
    setState(() => _busy = 'ocr');
    _setMood(
      AvatarMood.thinking,
      'Digitalizzazione…',
      'Provo la lettura online; se non risponde uso quella locale, senza rete né API key.',
    );
    try {
      late final OcrResult result;
      var usedLocal = false;
      final online = await _hasNetwork();
      if (_apiConfigured) {
        if (!online && mounted) {
          setState(() => _statusMessage = 'Rete non rilevata: tento la lettura online e poi passo a quella locale.');
        }
        try {
          result = await _api.ocr(path);
          if (isBlankGrid(result.grid)) {
            throw const ApiException('Il servizio ha restituito una griglia vuota');
          }
        } catch (_) {
          if (!mounted) return;
          setState(() {
            _statusMessage = 'Lettura online non disponibile. Uso quella locale…';
          });
          usedLocal = true;
          result = await LocalOcrService().recognize(path);
        }
      } else {
        usedLocal = true;
        result = await LocalOcrService().recognize(path);
      }
      if (!mounted) return;
      setState(() {
        _loadCells(flattenGrid(result.grid), 'ocr');
        _statusMessage = usedLocal
            ? '${result.note} Lettura online non disponibile: ho usato quella locale.'
            : result.note;
      });
      _setMood(
        AvatarMood.happy,
        'Griglia digitalizzata',
        'Fonte: ${result.source}. Controlla le celle blu prima di procedere.',
      );
      await _speak('Griglia riconosciuta. Controlla i numeri prima di continuare.');
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  bool _validate() {
    final bad = conflicts(_cells);
    if (bad.isNotEmpty) {
      setState(() {
        _conflicts
          ..clear()
          ..addAll(bad);
        _clearHighlights();
      });
      _setStatus('Ci sono valori duplicati evidenziati in rosso.', error: true);
      return false;
    }
    if (!isSolvable(_cells)) {
      _setStatus('La griglia attuale non ha soluzioni: controlla i numeri inseriti.', error: true);
      return false;
    }
    _conflicts.clear();
    return true;
  }

  Future<MoveExplanation> _explainFor(Move move) async {
    try {
      return await _api.explain(toGrid(_cells), move);
    } catch (e) {
      return MoveExplanation(
        row: move.row,
        col: move.col,
        value: move.value,
        explanation: localExplanation(_cells, move),
        technique: move.technique,
        source: 'locale',
        warning: e.toString(),
      );
    }
  }

  Future<void> _runSuggest() async {
    if (!_validate()) return;
    final move = findNextMove(_cells);
    if (move == null) {
      _setStatus('Non ci sono mosse da suggerire: la griglia è completa o non valida.');
      return;
    }
    setState(() {
      _busy = 'suggest';
      _currentMove = move;
      _hintMove = move;
      _explanation = 'Sto preparando la spiegazione…';
      _explanationTag = 'Tutor';
      _clearHighlights();
      _highlightCell.add(move.index);
      _highlightPeers.addAll(peerIndices(move.index));
      _statusMessage = 'Mossa individuata: riga ${move.row + 1}, colonna ${move.col + 1}.';
    });
    _setMood(AvatarMood.thinking, 'Ci penso…', 'Cerco la mossa più semplice e la sua motivazione.');

    final explanation = await _explainFor(move);
    if (!mounted) return;
    setState(() {
      _explanation = explanation.explanation;
      _explanationTag = explanation.source == 'gemini' ? 'Tutor intelligente' : 'Spiegazione locale';
      _busy = null;
      if (explanation.source != 'gemini') {
        _statusMessage = 'Lettura online non disponibile: spiegazione generata in locale.';
      }
    });
    _setMood(AvatarMood.happy, 'Ecco la mossa', 'La spiegazione è pronta. Puoi applicarla con il pulsante dedicato.');
    await _speak(explanation.explanation);
  }

  void _applySuggestion() {
    final move = _currentMove;
    if (move == null) return;
    if (_cells[move.index] != 0) {
      _showSnack('La cella è già compilata.', error: true);
      return;
    }
    setState(() {
      _writeValue(move.index, move.value, 'hint');
      _currentMove = null;
      _explanation = null;
      _hintLevel = 0;
      _clearHighlights();
      _statusMessage = 'Mossa applicata in riga ${move.row + 1}, colonna ${move.col + 1}.';
    });
    _setMood(AvatarMood.happy, 'Mossa applicata', isComplete(_cells) ? 'Griglia completata!' : 'Continua pure con la prossima mossa.');
  }

  Future<void> _cycleHint() async {
    if (!_validate()) return;

    if (_hintLevel == 3) {
      setState(() {
        _hintLevel = 0;
        _hintMove = null;
        _explanation = null;
        _clearHighlights();
        _statusMessage = 'Hint azzerato. Puoi ricominciare dal livello 1.';
      });
      return;
    }

    if (_hintLevel == 0) {
      final move = findNextMove(_cells);
      if (move == null) {
        _setStatus('Nessun hint disponibile: griglia completa o non risolvibile.');
        return;
      }
      _hintMove = move;
    }

    final move = _hintMove;
    if (move == null) return;

    final next = _hintLevel + 1;
    setState(() => _hintLevel = next);

    if (next == 1) {
      setState(() {
        _clearHighlights();
        _highlightBlock.addAll(boxIndices(boxOf(move.index)));
        _statusMessage = 'Livello 1: osserva il blocco 3x3 evidenziato.';
      });
      _setMood(AvatarMood.thinking, 'Hint 1 di 3', 'Quale numero manca in questo blocco?');
      return;
    }

    if (next == 2) {
      setState(() {
        _clearHighlights();
        _highlightCell.add(move.index);
        _highlightPeers.addAll(peerIndices(move.index));
        _statusMessage = 'Livello 2: la cella gialla è quella giusta.';
      });
      _setMood(AvatarMood.thinking, 'Hint 2 di 3', 'Le celle azzurre sono i vincoli da considerare.');
      return;
    }

    // Livello 3: rivela il numero con spiegazione.
    setState(() => _busy = 'hint');
    final explanation = await _explainFor(move);
    if (!mounted) return;
    setState(() {
      _writeValue(move.index, move.value, 'hint');
      _explanation = explanation.explanation;
      _explanationTag = explanation.source == 'gemini' ? 'Tutor intelligente' : 'Spiegazione locale';
      _clearHighlights();
      _highlightCell.add(move.index);
      _statusMessage = 'Livello 3: numero rivelato con spiegazione.';
      _busy = null;
      _hintMove = null;
    });
    _setMood(AvatarMood.happy, 'Numero rivelato', 'Ora sai anche perché quel valore è corretto.');
    await _speak(explanation.explanation);
  }

  Future<void> _runSolve() async {
    if (!_validate()) return;
    setState(() => _busy = 'solve');
    _setMood(AvatarMood.thinking, 'Risoluzione…', 'Il solutore backtracking sta completando la griglia.');
    final solved = solveCells(_cells);
    if (!mounted) return;
    if (solved == null) {
      setState(() => _busy = null);
      _setStatus('Solutore impossibile: la griglia non è valida.', error: true);
      return;
    }
    setState(() {
      for (var i = 0; i < 81; i++) {
        if (_cells[i] == 0) {
          _cells[i] = solved[i];
          _origins[i] = 'ai';
          _controllers[i].text = '${solved[i]}';
        }
      }
      _solution = List<int>.from(solved);
      _conflicts.clear();
      _currentMove = null;
      _hintMove = null;
      _explanation = null;
      _hintLevel = 0;
      _clearHighlights();
      _busy = null;
      _statusMessage = 'Sudoku risolto: le celle verdi sono state inserite dall\'AI.';
    });
    _setMood(AvatarMood.happy, 'Fatto!', 'Soluzione completa verificata dal solutore locale.');
    await _speak('Sudoku risolto. Le celle verdi sono state aggiunte dal tutor.');
  }

  Future<void> _runTutor() async {
    if (_explanation != null && _currentMove != null) {
      _setMood(AvatarMood.happy, 'Tutor', 'Ti leggo la spiegazione della mossa corrente.');
      await _speak(_explanation!);
      return;
    }
    // Nessuna spiegazione aperta: il tutor cerca la mossa più semplice e ne
    // chiede la motivazione a Gemini (con fallback locale).
    await _runSuggest();
  }

  void _showOverlay() {
    final path = _imagePath;
    if (path == null) {
      _showSnack('L\'overlay richiede una foto.', error: true);
      return;
    }
    final solved = _solution ?? solveCells(_cells);
    if (solved == null || conflicts(_cells).isNotEmpty) {
      _showSnack('Risolvi prima il Sudoku per sovrapporre i numeri.', error: true);
      return;
    }
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Overlay AR lite', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('I numeri mancanti sono disegnati sopra la foto. Per un allineamento perfetto usa una foto frontale.'),
              const SizedBox(height: 12),
              SizedBox(
                height: 360,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(File(path), fit: BoxFit.fill),
                    CustomPaint(painter: _OverlayPainter(solved, _originalEmpty)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Chiudi')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return DuoBadge(
      text: text,
      color: color.withValues(alpha: 0.14),
      textColor: color,
    );
  }

  Widget _card({required Widget child, Color? color}) {
    return DuoCard(color: color, child: child);
  }

  Widget _tutorHeader() {
    return _card(
      color: DuoColors.greenLight,
      child: Row(
        children: [
          Semantics(
            button: true,
            tooltip: 'Chiedi una mossa al gatto',
            child: InkWell(
              onTap: _busy == null ? _runSuggest : null,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: CatMascot(size: 74, mood: _mood, scarfColor: DuoColors.yellow),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_tutorTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(_tutorSubtitle, style: const TextStyle(fontSize: 13, color: DuoColors.muted)),
                const SizedBox(height: 8),
                Text(_statusMessage, style: const TextStyle(fontSize: 12, color: DuoColors.text)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _acquisitionCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DuoSectionTitle(
            text: '1. Scatta la foto',
            subtitle: 'Riconoscimento automatico: prova online, poi lettura locale se serve.',
          ),
          const SizedBox(height: 12),
          Container(
            height: 210,
            width: double.infinity,
            decoration: BoxDecoration(
              color: DuoColors.blueLight,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: DuoColors.border, width: 2),
            ),
            child: _imagePath == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CatMascot(size: 76, mood: AvatarMood.thinking, scarfColor: DuoColors.blue),
                      const SizedBox(height: 8),
                      const Text('Nessuna foto selezionata', style: TextStyle(color: DuoColors.muted, fontWeight: FontWeight.w700)),
                    ],
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(File(_imagePath!), fit: BoxFit.cover),
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DuoButton(
                  label: 'Galleria',
                  icon: Icons.photo_library_outlined,
                  style: DuoButtonStyle.secondary,
                  onPressed: _busy == null ? () => _pickImage(ImageSource.gallery) : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DuoButton(
                  label: 'Fotocamera',
                  icon: Icons.photo_camera_outlined,
                  style: DuoButtonStyle.secondary,
                  onPressed: _busy == null ? () => _pickImage(ImageSource.camera) : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DuoButton(
                  label: 'Esempio',
                  icon: Icons.auto_awesome_outlined,
                  style: DuoButtonStyle.yellow,
                  onPressed: _busy == null ? _loadSample : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DuoButton(
                  label: 'Overlay AR',
                  icon: Icons.layers_outlined,
                  style: DuoButtonStyle.ghost,
                  onPressed: _busy == null ? _showOverlay : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DuoButton(
            label: 'Riconosci griglia',
            icon: Icons.document_scanner_outlined,
            onPressed: _busy == null ? _runOcr : null,
          ),
          const SizedBox(height: 10),
          Text(
            _apiConfigured
                ? 'Lettura automatica attiva · riserva locale sempre disponibile'
                : 'Lettura locale attiva, senza rete né API key.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _apiConfigured ? DuoColors.greenDark : DuoColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: DuoColors.muted)),
      ],
    );
  }

  Widget _gridCard() {
    final filled = _cells.where((v) => v != 0).length;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DuoSectionTitle(
            text: '2. Griglia & Tutor',
            subtitle: 'Tocca il gatto o usa Risolvi / Suggerimento / Tutor.',
            trailing: _badge('$filled/81 celle', filled == 81 ? DuoColors.green : DuoColors.blue),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: AspectRatio(
              aspectRatio: 1,
              child: SudokuGrid(
                controllers: _controllers,
                origins: _origins,
                conflicts: _conflicts,
                highlightBlock: _highlightBlock,
                highlightCell: _highlightCell,
                highlightPeers: _highlightPeers,
                onChanged: _onCellChanged,
              ),
            ),
          ),
          const SizedBox(height: 12),
          DuoButton(
            label: 'Gioca come nei Livelli',
            icon: Icons.sports_esports_outlined,
            style: DuoButtonStyle.primary,
            onPressed: _busy == null && _cells.any((v) => v != 0) ? _playDigitized : null,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _legendDot(const Color(0xFFEEF2FF), 'OCR'),
              _legendDot(const Color(0xFFFFD86B), 'Mossa/Hint'),
              _legendDot(const Color(0xFFF0E5FF), 'Tutor'),
              _legendDot(const Color(0xFFDFF5E6), 'AI solver'),
              _legendDot(const Color(0xFFFFD6D6), 'Errore'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: DuoButton(
                  label: 'Risolvi',
                  icon: Icons.check_circle_outline,
                  style: DuoButtonStyle.yellow,
                  dense: true,
                  onPressed: _busy == null ? _runSolve : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DuoButton(
                  label: 'Suggerimento',
                  icon: Icons.lightbulb_outline,
                  style: DuoButtonStyle.secondary,
                  dense: true,
                  onPressed: _busy == null ? _runSuggest : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DuoButton(
                  label: 'Tutor',
                  icon: Icons.school_outlined,
                  style: DuoButtonStyle.primary,
                  dense: true,
                  onPressed: _busy == null ? _runTutor : null,
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _busy == null ? _cycleHint : null,
              icon: const Icon(Icons.tips_and_updates_outlined, size: 16),
              label: Text(_hintLevel == 0 ? 'Hint progressivi' : 'Hint $_hintLevel/3'),
            ),
          ),
          if (_currentMove != null) ...[
            const SizedBox(height: 10),
            DuoButton(
              label: 'Applica la mossa suggerita',
              icon: Icons.add_circle_outline,
              onPressed: _applySuggestion,
            ),
          ],
        ],
      ),
    );
  }

  Widget _explanationCard() {
    return _card(
      color: DuoColors.yellowLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CatMascot(size: 44, mood: AvatarMood.happy, scarfColor: DuoColors.yellow, showShadow: false),
              const SizedBox(width: 10),
              _badge(_explanationTag, DuoColors.yellowDark),
              const Spacer(),
              IconButton(
                tooltip: 'Leggi ad alta voce',
                onPressed: () => _speak(_explanation ?? ''),
                icon: const Icon(Icons.volume_up_outlined, color: DuoColors.blue),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(_explanation ?? '', style: const TextStyle(fontSize: 15, height: 1.45)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tutorHeader(),
        const SizedBox(height: 12),
        _gridCard(),
        if (_explanation != null) ...[
          const SizedBox(height: 12),
          _explanationCard(),
        ],
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Sudoku Vision & Tutor — Cat Edition'),
        actions: [
          _badge(_apiConfigured ? 'ONLINE' : 'OFFLINE', _apiConfigured ? DuoColors.green : DuoColors.blue),
          const SizedBox(width: 6),
          IconButton(
            tooltip: _voiceEnabled ? 'Disattiva voce' : 'Attiva voce',
            onPressed: _toggleVoice,
            icon: Icon(_voiceEnabled ? Icons.volume_up : Icons.volume_off, color: DuoColors.blue),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: _acquisitionCard()),
                        const SizedBox(width: 16),
                        Expanded(flex: 3, child: gameColumn),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _acquisitionCard(),
                        const SizedBox(height: 12),
                        gameColumn,
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final List<int> solved;
  final Set<int> originalEmpty;

  _OverlayPainter(this.solved, this.originalEmpty);

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.width < size.height ? size.width * 0.9 : size.height * 0.9;
    final left = (size.width - side) / 2;
    final top = (size.height - side) / 2;
    final cell = side / 9;

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.65)
      ..strokeWidth = 1.4;

    for (var i = 0; i <= 9; i++) {
      final width = i % 3 == 0 ? 2.6 : 1.0;
      gridPaint.strokeWidth = width;
      canvas.drawLine(Offset(left + i * cell, top), Offset(left + i * cell, top + side), gridPaint);
      canvas.drawLine(Offset(left, top + i * cell), Offset(left + side, top + i * cell), gridPaint);
    }

    for (final index in originalEmpty) {
      if (index < 0 || index > 80) continue;
      final row = index ~/ 9;
      final col = index % 9;
      final painter = TextPainter(
        text: TextSpan(
          text: '${solved[index]}',
          style: TextStyle(
            color: Colors.white,
            fontSize: cell * 0.58,
            fontWeight: FontWeight.w900,
            shadows: const [Shadow(blurRadius: 5, color: Colors.black87)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(left + col * cell + (cell - painter.width) / 2, top + row * cell + (cell - painter.height) / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) =>
      oldDelegate.solved != solved || oldDelegate.originalEmpty != originalEmpty;
}
