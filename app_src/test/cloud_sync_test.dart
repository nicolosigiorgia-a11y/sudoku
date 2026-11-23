import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/core/app_prefs.dart';

void main() {
  test('snapshot contiene progressi e impostazioni', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await AppPrefs.load();
    await prefs.saveLevelResult(1, 2, 120);
    await prefs.saveLevelResult(2, 3, 90);
    await prefs.setLessonsCompleted();
    await prefs.setBaseUrl('http://192.168.1.5:3000');
    await prefs.setVoiceEnabled(true);

    final progress = prefs.progressSnapshot(8);
    expect((progress['stars'] as Map)['1'], 2);
    expect((progress['stars'] as Map)['2'], 3);
    expect((progress['best_times'] as Map)['1'], 120);
    expect(progress['lessons_completed'], true);
    expect(prefs.settingsSnapshot(), {
      'api_base_url': 'http://192.168.1.5:3000',
      'voice_enabled': true,
    });
  });

  test('merge remoto prende il meglio e le impostazioni solo su richiesta', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await AppPrefs.load();
    await prefs.saveLevelResult(1, 3, 60);
    await prefs.setBaseUrl('http://local:3000');

    await prefs.applyRemote(
      {
        'stars': {'1': 2, '2': 3},
        'best_times': {'1': 90, '2': 45},
        'lessons_completed': true,
      },
      settings: {'api_base_url': 'http://remote:3000', 'voice_enabled': true},
      preferRemoteSettings: false,
    );

    expect(prefs.starsForLevel(1), 3);
    expect(prefs.starsForLevel(2), 3);
    expect(prefs.bestTimeForLevel(1), 60);
    expect(prefs.bestTimeForLevel(2), 45);
    expect(prefs.lessonsCompleted, true);
    expect(prefs.baseUrl, 'http://local:3000');
    expect(prefs.voiceEnabled, false);

    await prefs.applyRemote(
      {},
      settings: {'api_base_url': 'http://remote:3000', 'voice_enabled': true},
      preferRemoteSettings: true,
    );
    expect(prefs.baseUrl, 'http://remote:3000');
    expect(prefs.voiceEnabled, true);
  });

  test('sblocco livelli segue le stelle salvate', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await AppPrefs.load();
    expect(prefs.isLevelUnlocked(1), true);
    expect(prefs.isLevelUnlocked(2), false);
    await prefs.saveLevelResult(1, 2, 100);
    expect(prefs.isLevelUnlocked(2), true);
    expect(prefs.xp, 50);
  });
}
