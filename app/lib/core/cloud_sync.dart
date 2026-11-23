// Supabase cloud sync: accounts, magic link / password login and progress.
// The anon (publishable) key is public by design; safety comes from RLS.
// Everything degrades gracefully: with no config the app stays fully offline.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_prefs.dart';

class CloudSync {
  CloudSync._();
  static final CloudSync instance = CloudSync._();

  /// Must be registered verbatim in Supabase -> Auth -> URL Configuration ->
  /// Additional Redirect URLs, and in the Android manifest intent-filter.
  static const String redirectUrl = 'it.sudokatvision.app://login-callback';
  static const String table = 'player_progress';
  static const int levelCount = 8;

  final ValueNotifier<String> userEmail = ValueNotifier<String>('');

  /// Bumped whenever local progress is written or a cloud snapshot is applied.
  /// Screens that cache progress (e.g. Livelli) listen to this to refresh.
  final ValueNotifier<int> progressRevision = ValueNotifier<int>(0);

  AppPrefs? _prefs;
  StreamSubscription<AuthState>? _authSub;
  String? _initializedUrl;
  String? _initializedKey;
  bool _initialized = false;
  bool _syncing = false;

  Future<String?> init(AppPrefs prefs) async {
    _prefs = prefs;
    final error = await _ensureReady();
    _publishUser();
    if (error == null && _initialized) return null;
    // No config or a config change is not an error at startup: offline mode.
    return null;
  }

  SupabaseClient get _client => Supabase.instance.client;

  bool get isSignedIn => _initialized && _client.auth.currentUser != null;
  bool get isConfigured => _prefs?.hasSupabaseConfig ?? false;

  void _publishUser() {
    if (!_initialized) {
      userEmail.value = '';
      return;
    }
    userEmail.value = _client.auth.currentUser?.email ?? '';
  }

  Future<String?> _ensureReady() async {
    final prefs = _prefs ?? await AppPrefs.load();
    _prefs = prefs;
    if (!prefs.hasSupabaseConfig) {
      return 'Accesso non disponibile: questa build non include la configurazione Supabase.';
    }
    if (_initialized) {
      if (_initializedUrl != prefs.supabaseUrl || _initializedKey != prefs.supabaseKey) {
        return 'Configurazione cambiata: riavvia l\'app per applicarla.';
      }
      return null;
    }
    try {
      await Supabase.initialize(
        url: prefs.supabaseUrl,
        publishableKey: prefs.supabaseKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          detectSessionInUri: true,
        ),
      );
      _initialized = true;
      _initializedUrl = prefs.supabaseUrl;
      _initializedKey = prefs.supabaseKey;
      _authSub = _client.auth.onAuthStateChange.listen((state) {
        if (state.event == AuthChangeEvent.signedIn ||
            state.event == AuthChangeEvent.initialSession) {
          if (state.session != null) {
            _publishUser();
            unawaited(sync(preferRemoteSettings: true));
          }
        } else if (state.event == AuthChangeEvent.signedOut) {
          _publishUser();
        }
      });
      return null;
    } catch (e) {
      return 'Supabase non raggiungibile: $e';
    }
  }

  Future<String?> signInWithPassword(String email, String password) async {
    final ready = await _ensureReady();
    if (ready != null) return ready;
    if (email.trim().isEmpty || password.isEmpty) {
      return 'Inserisci email e password.';
    }
    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      _publishUser();
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> signUp(String email, String password) async {
    final ready = await _ensureReady();
    if (ready != null) return ready;
    if (email.trim().isEmpty || password.isEmpty) {
      return 'Inserisci email e password.';
    }
    try {
      await _client.auth.signUp(email: email.trim(), password: password);
      return 'Account creato. Se la conferma email è attiva, apri il link nella mail (o usa il magic link).';
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  /// Sends the magic link. The redirect brings the user back into the app,
  /// where the SDK exchanges the PKCE code for a session automatically.
  Future<String?> sendMagicLink(String email) async {
    final ready = await _ensureReady();
    if (ready != null) return ready;
    if (email.trim().isEmpty) return 'Inserisci la tua email.';
    try {
      await _client.auth.signInWithOtp(
        email: email.trim(),
        emailRedirectTo: redirectUrl,
      );
      return 'Link inviato a ${email.trim()}. Apri la mail sul telefono: tornerai all\'app automaticamente.';
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> setPassword(String password) async {
    final ready = await _ensureReady();
    if (ready != null) return ready;
    if (password.length < 6) return 'La password deve avere almeno 6 caratteri.';
    try {
      await _client.auth.updateUser(UserAttributes(password: password));
      return 'Password aggiornata. Ora puoi accedere anche con email + password.';
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> signOut() async {
    final ready = await _ensureReady();
    if (ready != null) return ready;
    try {
      await _client.auth.signOut();
      _publishUser();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Pulls the remote snapshot, merges best results, then pushes the union.
  /// [preferRemoteSettings] is used after an explicit sign-in (carry settings
  /// to the new phone); at startup local settings win instead.
  Future<String?> sync({bool preferRemoteSettings = false}) async {
    final ready = await _ensureReady();
    if (ready != null) return ready;
    final user = _client.auth.currentUser;
    if (user == null) return 'Accedi per sincronizzare.';
    if (_syncing) return null;
    _syncing = true;
    try {
      final rows = await _client
          .from(table)
          .select('progress,settings')
          .eq('user_id', user.id)
          .limit(1);
      String message;
      if (rows.isEmpty) {
        await _push(user.id);
        message = 'Primo backup caricato sul cloud.';
      } else {
        final remote = rows.first;
        await _prefs!.applyRemote(
          remote['progress'],
          settings: remote['settings'],
          preferRemoteSettings: preferRemoteSettings,
        );
        // Aggiorna subito le schermate che mostrano il progresso: non devono
        // attendere la fine dell'upload né un riavvio dell'app.
        progressRevision.value++;
        await _push(user.id);
        message = 'Sincronizzato: progressi e impostazioni aggiornati.';
      }
      return message;
    } catch (e) {
      return 'Sincronizzazione non riuscita: $e';
    } finally {
      _syncing = false;
    }
  }

  /// Fire-and-forget push used after a local change (level completed, etc.).
  void pushAfterChange() {
    if (!isSignedIn) return;
    final user = _client.auth.currentUser;
    if (user == null) return;
    unawaited(_push(user.id).catchError((_) {}));
  }

  Future<void> _push(String userId) async {
    final prefs = _prefs ?? await AppPrefs.load();
    _prefs = prefs;
    await _client.from(table).upsert(
      {
        'user_id': userId,
        'progress': prefs.progressSnapshot(levelCount),
        'settings': prefs.settingsSnapshot(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id',
    );
    progressRevision.value++;
  }
}
