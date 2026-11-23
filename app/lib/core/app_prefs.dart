import 'package:shared_preferences/shared_preferences.dart';

class AppPrefs {
  static const _baseUrlKey = 'api_base_url';
  static const _voiceKey = 'voice_enabled';
  static const _starsPrefix = 'level_stars_';
  static const _bestTimePrefix = 'level_best_seconds_';
  static const _lessonDoneKey = 'lessons_completed';
  static const _supabaseUrlKey = 'supabase_url';
  static const _supabaseKeyKey = 'supabase_key';

  static const String envBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  static const String defaultSupabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String defaultSupabaseKey = String.fromEnvironment('SUPABASE_KEY', defaultValue: '');
  static const String legacyLocalBaseUrl = 'http://10.0.2.2:3000';

  /// URL of the Gemini Edge Function for the configured Supabase project.
  static String functionsUrl(String supabaseUrl) {
    final root = supabaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    return '$root/functions/v1/gemini-proxy';
  }

  static String get defaultBaseUrl {
    final explicit = envBaseUrl.trim();
    if (explicit.isNotEmpty) return explicit;
    if (defaultSupabaseUrl.trim().isNotEmpty) return functionsUrl(defaultSupabaseUrl);
    return legacyLocalBaseUrl;
  }

  static bool _isLegacyLocalUrl(String url) =>
      url.contains('10.0.2.2:3000') || RegExp(r':3000(/|$)').hasMatch(url);

  final SharedPreferences _prefs;
  AppPrefs(this._prefs);

  static Future<AppPrefs> load() async => AppPrefs(await SharedPreferences.getInstance());

  String get baseUrl {
    final stored = _prefs.getString(_baseUrlKey)?.trim();
    if (stored != null && stored.isNotEmpty) {
      // Installazioni precedenti avevano il proxy locale salvato: con Supabase
      // configurato passiamo automaticamente alla Gemini Edge Function.
      if (hasSupabaseConfig && _isLegacyLocalUrl(stored)) return functionsUrl(supabaseUrl);
      return stored;
    }
    return defaultBaseUrl;
  }

  Future<bool> setBaseUrl(String value) => _prefs.setString(_baseUrlKey, value.trim());

  bool get voiceEnabled => _prefs.getBool(_voiceKey) ?? false;
  Future<bool> setVoiceEnabled(bool value) => _prefs.setBool(_voiceKey, value);

  // ---- Supabase configuration ---------------------------------------------

  String get supabaseUrl => _prefs.getString(_supabaseUrlKey) ?? defaultSupabaseUrl;
  String get supabaseKey => _prefs.getString(_supabaseKeyKey) ?? defaultSupabaseKey;

  /// Public anon/publishable key used as `apikey` header by the Edge Function.
  String get apiKey => supabaseKey.trim();

  bool get hasSupabaseConfig => apiKey.isNotEmpty && supabaseUrl.trim().isNotEmpty;

  Future<void> setSupabaseConfig(String url, String key) async {
    await _prefs.setString(_supabaseUrlKey, url.trim());
    await _prefs.setString(_supabaseKeyKey, key.trim());
  }

  // ---- Progressive levels -------------------------------------------------

  int starsForLevel(int id) => _prefs.getInt('$_starsPrefix$id') ?? 0;

  /// Returns true only when this run improves the previous record.
  Future<bool> saveLevelResult(int id, int stars, int seconds) async {
    var improved = false;
    if (stars > starsForLevel(id)) {
      await _prefs.setInt('$_starsPrefix$id', stars);
      improved = true;
    }
    final best = _prefs.getInt('$_bestTimePrefix$id');
    if (best == null || seconds < best) {
      await _prefs.setInt('$_bestTimePrefix$id', seconds);
      improved = true;
    }
    return improved;
  }

  int? bestTimeForLevel(int id) => _prefs.getInt('$_bestTimePrefix$id');

  bool isLevelUnlocked(int id) => id == 1 || starsForLevel(id - 1) > 0;

  int totalStars(int levelCount) {
    var total = 0;
    for (var id = 1; id <= levelCount; id++) {
      total += starsForLevel(id);
    }
    return total;
  }

  int get xp => totalStars(8) * 25;

  bool get lessonsCompleted => _prefs.getBool(_lessonDoneKey) ?? false;
  Future<bool> setLessonsCompleted() => _prefs.setBool(_lessonDoneKey, true);

  // ---- Cloud sync snapshots -----------------------------------------------

  Map<String, dynamic> progressSnapshot(int levelCount) => {
        'stars': {for (var id = 1; id <= levelCount; id++) '$id': starsForLevel(id)},
        'best_times': {
          for (var id = 1; id <= levelCount; id++)
            if (bestTimeForLevel(id) != null) '$id': bestTimeForLevel(id)!,
        },
        'lessons_completed': lessonsCompleted,
      };

  Map<String, dynamic> settingsSnapshot() => {
        'api_base_url': baseUrl,
        'voice_enabled': voiceEnabled,
      };

  /// Merges remote data into local storage: best star count and fastest time
  /// win. Settings are replaced only when explicitly requested (sign-in),
  /// because that is the point of carrying settings to another phone.
  Future<void> applyRemote(
    dynamic progress, {
    dynamic settings,
    required bool preferRemoteSettings,
  }) async {
    final stars = _asMap(progress is Map ? progress['stars'] : null);
    for (final entry in stars.entries) {
      final id = int.tryParse(entry.key.toString());
      if (id == null || entry.value is! num) continue;
      final value = (entry.value as num).toInt();
      if (value > starsForLevel(id)) await _prefs.setInt('$_starsPrefix$id', value);
    }

    final times = _asMap(progress is Map ? progress['best_times'] : null);
    for (final entry in times.entries) {
      final id = int.tryParse(entry.key.toString());
      if (id == null || entry.value is! num) continue;
      final value = (entry.value as num).toInt();
      final current = bestTimeForLevel(id);
      if (current == null || value < current) await _prefs.setInt('$_bestTimePrefix$id', value);
    }

    if (progress is Map && progress['lessons_completed'] == true) {
      await setLessonsCompleted();
    }

    if (preferRemoteSettings) {
      final remoteSettings = _asMap(settings);
      final url = remoteSettings['api_base_url']?.toString();
      if (url != null && url.isNotEmpty) await setBaseUrl(url);
      final voice = remoteSettings['voice_enabled'];
      if (voice is bool) await setVoiceEnabled(voice);
    }
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value == null) return const {};
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }
}
