import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../lib/core/api_service.dart';
import '../lib/core/app_prefs.dart';

void main() {
  test('ApiService invia apikey e Bearer alle Supabase Edge Functions', () async {
    final client = MockClient((request) async {
      expect(request.headers['apikey'], 'anon-key');
      expect(request.headers['authorization'], 'Bearer anon-key');
      expect(
        request.url.path,
        '/functions/v1/gemini-proxy/api/status',
      );
      return http.Response(
        '{"configured":true,"model":"gemini-3.6-flash","runtime":"supabase-edge-function"}',
        200,
      );
    });

    final api = ApiService(
      'https://demo.supabase.co/functions/v1/gemini-proxy',
      apiKey: 'anon-key',
      client: client,
    );

    final status = await api.status();
    expect(status.configured, isTrue);
    expect(status.model, 'gemini-3.6-flash');
  });

  test('AppPrefs deriva la URL della funzione dal progetto Supabase', () {
    expect(
      AppPrefs.functionsUrl('https://demo.supabase.co/'),
      'https://demo.supabase.co/functions/v1/gemini-proxy',
    );
    expect(
      AppPrefs.functionsUrl('https://demo.supabase.co'),
      'https://demo.supabase.co/functions/v1/gemini-proxy',
    );
  });
}
