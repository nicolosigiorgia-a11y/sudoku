import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'sudoku.dart';

class ApiException implements Exception {
  final String message;
  final int? status;
  final String? code;

  const ApiException(this.message, {this.status, this.code});

  @override
  String toString() => message;
}

class ApiStatus {
  final bool configured;
  final String model;
  const ApiStatus({required this.configured, required this.model});
}

class OcrResult {
  final List<List<int>> grid;
  final String note;
  final String model;
  final String source;
  const OcrResult({
    required this.grid,
    required this.note,
    required this.model,
    required this.source,
  });
}

class MoveExplanation {
  final int row;
  final int col;
  final int value;
  final String explanation;
  final String technique;
  final String source;
  final String? warning;

  const MoveExplanation({
    required this.row,
    required this.col,
    required this.value,
    required this.explanation,
    required this.technique,
    required this.source,
    this.warning,
  });
}

class ApiService {
  ApiService(this.baseUrl, {this.apiKey = '', http.Client? client})
      : _client = client ?? http.Client();

  String baseUrl;
  final String apiKey;
  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 60);

  String get _root => baseUrl.trim().replaceAll(RegExp(r'/+$'), '');

  Uri _uri(String path) => Uri.parse('$_root$path');

  Map<String, String> get _headers {
    final headers = <String, String>{'Content-Type': 'application/json; charset=utf-8'};
    final key = apiKey.trim();
    if (key.isNotEmpty) {
      // Supabase Edge Functions require the anon/publishable key at the gateway.
      headers['apikey'] = key;
      headers['Authorization'] = 'Bearer $key';
    }
    return headers;
  }

  Map<String, dynamic> _decode(http.Response response) {
    final text = utf8.decode(response.bodyBytes);
    dynamic parsed;
    try {
      parsed = jsonDecode(text);
    } catch (_) {
      throw ApiException('Risposta server non valida (HTTP ${response.statusCode})', status: response.statusCode);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = parsed is Map ? parsed['error'] ?? parsed['message'] : null;
      final code = parsed is Map ? parsed['code'] : null;
      throw ApiException(
        message?.toString() ?? 'Errore HTTP ${response.statusCode}',
        status: response.statusCode,
        code: code?.toString(),
      );
    }
    if (parsed is! Map) throw const ApiException('Formato risposta inatteso');
    return Map<String, dynamic>.from(parsed);
  }

  Future<ApiStatus> status() async {
    try {
      final response = await _client.get(_uri('/api/status'), headers: _headers).timeout(_timeout);
      final data = _decode(response);
      return ApiStatus(
        configured: data['configured'] == true,
        model: data['model']?.toString() ?? 'sconosciuto',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Backend non raggiungibile: $e');
    }
  }

  Future<OcrResult> ocr(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) throw const ApiException('File immagine non trovato');
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw const ApiException('Immagine vuota');
    final ext = imagePath.split('.').last.toLowerCase();
    final mime = ext == 'png' ? 'image/png' : ext == 'webp' ? 'image/webp' : 'image/jpeg';
    final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
    try {
      final response = await _client
          .post(_uri('/api/ocr'), headers: _headers, body: jsonEncode({'image': dataUrl}))
          .timeout(_timeout);
      final data = _decode(response);
      final raw = data['grid'];
      if (raw is! List || raw.length != 9 || raw.any((row) => row is! List || row.length != 9)) {
        throw const ApiException('Griglia OCR non valida');
      }
      final grid = raw
          .map((row) => List<int>.from((row as List).map((v) => (v as num).toInt())))
          .toList();
      return OcrResult(
        grid: grid,
        note: data['note']?.toString() ?? 'Griglia riconosciuta',
        model: data['model']?.toString() ?? '',
        source: data['source']?.toString() ?? 'gemini',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Errore durante OCR: $e');
    }
  }

  Future<MoveExplanation> explain(List<List<int>> grid, Move move) async {
    final body = {
      'grid': grid,
      'move': {'row': move.row, 'col': move.col, 'value': move.value},
    };
    try {
      final response = await _client
          .post(_uri('/api/explain'), headers: _headers, body: jsonEncode(body))
          .timeout(_timeout);
      final data = _decode(response);
      return MoveExplanation(
        row: (data['row'] as num?)?.toInt() ?? move.row,
        col: (data['col'] as num?)?.toInt() ?? move.col,
        value: (data['value'] as num?)?.toInt() ?? move.value,
        explanation: data['explanation']?.toString() ?? '',
        technique: data['technique']?.toString() ?? 'verifica',
        source: data['source']?.toString() ?? 'locale',
        warning: data['warning']?.toString(),
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Errore durante la spiegazione: $e');
    }
  }
}
