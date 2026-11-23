import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_sudoku_cat/core/cloud_sync.dart';
import 'package:ai_sudoku_cat/main.dart';

void main() {
  testWidgets('Il badge XP si aggiorna quando il sync ripristina i progressi', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const SudokuCatApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Livelli'));
    await tester.pumpAndSettle();

    expect(find.text('0 XP'), findsOneWidget);

    // Simula il ripristino dei progressi dal cloud dopo il login.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('level_stars_1', 2); // 2 stelle = 50 XP
    CloudSync.instance.progressRevision.value++;

    await tester.pumpAndSettle();
    expect(find.text('50 XP'), findsOneWidget);
  });
}
