import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_sudoku_cat/main.dart';
import 'package:ai_sudoku_cat/core/levels.dart';
import 'package:ai_sudoku_cat/ui/sudoku_grid.dart';
import 'package:ai_sudoku_cat/ui/duo_theme.dart';

void main() {
  testWidgets('la schermata iniziale mostra il titolo e la navigazione', (WidgetTester tester) async {
    await tester.pumpWidget(const SudokuCatApp());
    await tester.pump();

    expect(find.text('AI Sudoku Vision & Tutor — Cat Edition'), findsOneWidget);
    expect(find.text('Risolvi'), findsOneWidget);
    expect(find.text('Suggerimento'), findsOneWidget);
    expect(find.text('Tutor'), findsNWidgets(2)); // pulsante + legenda
    expect(find.text('Riconosci griglia'), findsOneWidget);
    expect(find.text('Riconosci con Gemini'), findsNothing);
    expect(find.text('Riconosci offline'), findsNothing);
    expect(find.byIcon(Icons.settings_outlined), findsNothing, reason: 'Le impostazioni da sviluppatore non devono essere visibili');
    expect(find.byTooltip('Impostazioni backend'), findsNothing);
    expect(find.text('Livelli'), findsOneWidget);
    expect(find.text('Impara'), findsOneWidget);
    expect(find.text('Profilo'), findsOneWidget);
  });

  testWidgets('le lezioni e i livelli sono raggiungibili dalla navigazione', (WidgetTester tester) async {
    await tester.pumpWidget(const SudokuCatApp());
    await tester.pump();

    await tester.tap(find.text('Impara'));
    await tester.pumpAndSettle();
    expect(find.text('Impara a giocare'), findsOneWidget);
    expect(find.text('Benvenuto nel tutor!'), findsOneWidget);

    await tester.tap(find.text('Livelli'));
    await tester.pumpAndSettle();
    expect(find.text('Allenati come in un gioco'), findsOneWidget);
  });

  testWidgets('Livelli: numeri dati bloccati e barra numeri inserisce/annulla', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const SudokuCatApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Livelli'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.ancestor(of: find.text('1'), matching: find.byType(InkWell)).first);
    await tester.pumpAndSettle();

    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields.length, 81);
    for (final field in fields) {
      expect(field.readOnly, isTrue, reason: 'La tastiera del telefono non deve mai aprirsi nei Livelli');
    }

    final level = buildLevels().first;
    final emptyIndex = level.puzzle.indexWhere((value) => value == 0);
    final correctDigit = '${level.solution[emptyIndex]}';
    final emptyController = fields[emptyIndex].controller!;
    final emptyCell = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.controller == emptyController,
    );

    final digit = find.widgetWithText(InkWell, correctDigit);
    await tester.ensureVisible(digit);
    await tester.pumpAndSettle();
    await tester.tap(digit);
    await tester.pumpAndSettle();
    await tester.ensureVisible(emptyCell);
    await tester.pumpAndSettle();
    await tester.tap(emptyCell);
    await tester.pumpAndSettle();
    expect(emptyController.text, correctDigit);

    await tester.ensureVisible(find.text('Annulla'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(emptyController.text, '');

    final beforeHint = fields.where((field) => field.controller!.text.isNotEmpty).length;
    await tester.ensureVisible(find.text('Suggerimento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suggerimento'));
    await tester.pumpAndSettle();
    final afterHint = tester
        .widgetList<TextField>(find.byType(TextField))
        .where((field) => field.controller!.text.isNotEmpty)
        .length;
    expect(afterHint, greaterThan(beforeHint), reason: 'Il suggerimento deve compilare una cella');
    expect(find.text('Suggerimenti 2/3'), findsOneWidget);

    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Suggerimento'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Suggerimenti 0/3'), findsOneWidget);
    final hintButton = tester.widget<DuoButton>(
      find.ancestor(of: find.text('Suggerimento'), matching: find.byType(DuoButton)),
    );
    expect(hintButton.onPressed, isNull, reason: 'Dopo 3 suggerimenti il pulsante deve disattivarsi');
  });

  testWidgets('Livelli: errore immediato toglie un cuore e occorrenze evidenziate', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const SudokuCatApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Livelli'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.ancestor(of: find.text('1'), matching: find.byType(InkWell)).first);
    await tester.pumpAndSettle();

    final level = buildLevels().first;
    final emptyIndex = level.puzzle.indexWhere((value) => value == 0);
    final correct = level.solution[emptyIndex];
    final wrongValue = correct == 1 ? 2 : 1;

    expect(find.byIcon(Icons.favorite), findsNWidgets(3));

    final digit = find.widgetWithText(InkWell, '$wrongValue');
    await tester.ensureVisible(digit);
    await tester.pumpAndSettle();
    await tester.tap(digit);
    await tester.pumpAndSettle();
    final grid = tester.widget<SudokuGrid>(find.byType(SudokuGrid));
    expect(grid.highlightSame, isNotEmpty, reason: 'Toccando un numero si vedono tutte le sue occorrenze');

    final target = tester.widgetList<TextField>(find.byType(TextField)).toList()[emptyIndex];
    final cell = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.controller == target.controller,
    );
    await tester.ensureVisible(cell);
    await tester.pumpAndSettle();
    await tester.tap(cell);
    await tester.pumpAndSettle();

    expect(target.controller!.text, '', reason: 'Il numero sbagliato deve sparire senza premere Controlla');
    expect(find.byIcon(Icons.favorite), findsNWidgets(2), reason: 'Un errore toglie subito un cuore');
    expect(find.byType(SnackBar), findsNothing, reason: 'Nessun messaggio in basso quando si perde un cuore');
  });

  testWidgets('Livelli: riga completata scatena la cascata domino', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const SudokuCatApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Livelli'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.ancestor(of: find.text('1'), matching: find.byType(InkWell)).first);
    await tester.pumpAndSettle();

    final level = buildLevels().first;
    final controllers = tester.widgetList<TextField>(find.byType(TextField)).toList();
    final versionBefore = tester.widget<SudokuGrid>(find.byType(SudokuGrid)).completionVersion;

    for (var col = 0; col < 9; col++) {
      if (level.puzzle[col] != 0) continue;
      final digit = '${level.solution[col]}';
      final pad = find.widgetWithText(InkWell, digit);
      await tester.ensureVisible(pad);
      await tester.pumpAndSettle();
      await tester.tap(pad);
      await tester.pumpAndSettle();
      final cell = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.controller == controllers[col].controller,
      );
      await tester.ensureVisible(cell);
      await tester.pumpAndSettle();
      await tester.tap(cell);
      await tester.pumpAndSettle();
    }

    final grid = tester.widget<SudokuGrid>(find.byType(SudokuGrid));
    expect(grid.completionVersion, greaterThan(versionBefore));
    expect(grid.completedCells, containsAll(List<int>.generate(9, (c) => c)));
    expect(grid.celebrationCells, isNotEmpty);
  });

  testWidgets('Foto: la griglia digitalizzata si gioca come nei Livelli', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const SudokuCatApp());
    await tester.pumpAndSettle();

    final example = find.text('Esempio');
    await tester.ensureVisible(example);
    await tester.pumpAndSettle();
    await tester.tap(example);
    await tester.pumpAndSettle();

    final play = find.text('Gioca come nei Livelli');
    await tester.ensureVisible(play);
    await tester.pumpAndSettle();
    await tester.tap(play);
    await tester.pumpAndSettle();

    expect(find.text('Gioca · griglia dalla foto'), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsNWidgets(3));
    expect(find.text('Suggerimenti 3/3'), findsOneWidget);
    expect(find.text('Controlla'), findsOneWidget);
    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields.length, 81);
    expect(fields.every((field) => field.readOnly), isTrue);

    // Stesso controllo immediato dei Livelli: errore = cuore in meno e cella vuota.
    final level = buildLevels().first;
    final target = 2;
    final wrongValue = level.puzzle[target] == 1 ? 2 : 1;
    final digit = find.widgetWithText(InkWell, '$wrongValue');
    await tester.ensureVisible(digit);
    await tester.pumpAndSettle();
    await tester.tap(digit);
    await tester.pumpAndSettle();
    final cell = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.controller == fields[target].controller,
    );
    await tester.ensureVisible(cell);
    await tester.pumpAndSettle();
    await tester.tap(cell);
    await tester.pumpAndSettle();

    expect(fields[target].controller!.text, '', reason: 'Anche dalla foto il numero sbagliato sparisce');
    expect(find.byIcon(Icons.favorite), findsNWidgets(2));
  });

  testWidgets('il profilo offre entrambi i metodi di accesso', (WidgetTester tester) async {
    await tester.pumpWidget(const SudokuCatApp());
    await tester.pump();

    await tester.tap(find.text('Profilo'));
    await tester.pumpAndSettle();

    expect(find.text('Il tuo album dei record'), findsOneWidget);
    expect(find.text('Accedi'), findsNWidgets(2));
    expect(find.text('Magic link'), findsOneWidget);
    expect(find.text('Crea account con password'), findsOneWidget);
    expect(find.byTooltip('Guida configurazione'), findsNothing);
    expect(find.textContaining('configurare Gemini'), findsNothing);
  });

  testWidgets('Profilo: il nome del giocatore si salva e appare nella home', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const SudokuCatApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profilo'));
    await tester.pumpAndSettle();
    expect(find.text('Come ti chiami?'), findsOneWidget);

    final nameField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == 'Nome giocatore',
    );
    await tester.enterText(nameField, 'Sofia');
    await tester.tap(find.text('Salva nome'));
    await tester.pumpAndSettle();
    expect(find.text('Ciao, Sofia!'), findsOneWidget);
    expect(find.text('Salva nome'), findsNothing);
    expect(find.text('Modifica nome'), findsOneWidget);

    // Il nome si può cambiare in seguito senza rifare il login.
    await tester.tap(find.text('Modifica nome'));
    await tester.pumpAndSettle();
    expect(find.text('Come ti chiami?'), findsOneWidget);
    await tester.enterText(nameField, 'Giulia');
    await tester.tap(find.text('Salva nome'));
    await tester.pumpAndSettle();
    expect(find.text('Ciao, Giulia!'), findsOneWidget);
    expect(find.text('Ciao, Sofia!'), findsNothing);

    await tester.tap(find.text('Foto'));
    await tester.pumpAndSettle();
    expect(find.text('Ciao, Giulia!'), findsOneWidget);
  });
}
