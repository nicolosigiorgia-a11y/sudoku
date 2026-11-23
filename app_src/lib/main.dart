import 'package:flutter/material.dart';

import 'core/app_prefs.dart';
import 'core/cloud_sync.dart';
import 'screens/home_screen.dart';
import 'screens/learn_screen.dart';
import 'screens/levels_screen.dart';
import 'screens/profile_screen.dart';
import 'ui/duo_theme.dart';
import 'ui/nav_icons.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await AppPrefs.load();
  await CloudSync.instance.init(prefs);
  runApp(SudokuCatApp(prefs: prefs));
}

class SudokuCatApp extends StatefulWidget {
  final AppPrefs? prefs;

  const SudokuCatApp({super.key, this.prefs});

  @override
  State<SudokuCatApp> createState() => _SudokuCatAppState();
}

class _SudokuCatAppState extends State<SudokuCatApp> {
  int _index = 0;

  void _goToLevels() => setState(() => _index = 1);

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const HomeScreen(),
      const LevelsScreen(),
      LearnScreen(onGoToLevels: _goToLevels),
      const ProfileScreen(),
    ];
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Sudoku Vision & Tutor — Cat Edition',
      theme: duoTheme(),
      home: Scaffold(
        body: IndexedStack(index: _index, children: pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
              icon: NavMascotIcon(kind: NavMascotKind.photo, size: 25, scarf: DuoColors.blue),
              selectedIcon: NavMascotIcon(kind: NavMascotKind.photo, size: 27, scarf: DuoColors.blue, selected: true),
              label: 'Foto',
            ),
            NavigationDestination(
              icon: NavMascotIcon(kind: NavMascotKind.levels, size: 25, scarf: DuoColors.yellow),
              selectedIcon: NavMascotIcon(kind: NavMascotKind.levels, size: 27, scarf: DuoColors.yellow, selected: true),
              label: 'Livelli',
            ),
            NavigationDestination(
              icon: NavMascotIcon(kind: NavMascotKind.learn, size: 25, scarf: DuoColors.purple),
              selectedIcon: NavMascotIcon(kind: NavMascotKind.learn, size: 27, scarf: DuoColors.purple, selected: true),
              label: 'Impara',
            ),
            NavigationDestination(
              icon: NavMascotIcon(kind: NavMascotKind.profile, size: 25, scarf: DuoColors.green),
              selectedIcon: NavMascotIcon(kind: NavMascotKind.profile, size: 27, scarf: DuoColors.green, selected: true),
              label: 'Profilo',
            ),
          ],
        ),
      ),
    );
  }
}
