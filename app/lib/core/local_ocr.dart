import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:tesseract_ocr/ocr_engine_config.dart';
import 'package:tesseract_ocr/tesseract_ocr.dart';

import 'api_service.dart';
import 'sudoku.dart';

const _ocrConfig = OCRConfig(language: 'eng', engine: OCREngine.defaultEngine);

class LocalOcrException implements Exception {
  final String message;
  const LocalOcrException(this.message);

  @override
  String toString() => message;
}

class GridBounds {
  final List<int> xLines;
  final List<int> yLines;

  const GridBounds(this.xLines, this.yLines);

  int get left => xLines.first;
  int get top => yLines.first;
  int get right => xLines.last;
  int get bottom => yLines.last;
  int get size => ((right - left) + (bottom - top)) ~/ 2;
}

class _Box {
  final int x;
  final int y;
  final int width;
  final int height;

  const _Box(this.x, this.y, this.width, this.height);

  int get right => x + width;
  int get bottom => y + height;
}

class _Ink {
  final int row;
  final int col;
  final _Box box;
  final int threshold;

  const _Ink(this.row, this.col, this.box, this.threshold);
}

class _Peak {
  final int index;
  final int value;
  const _Peak(this.index, this.value);
}

/// Converte il testo restituito da Tesseract in una cifra 1-9.
///
/// Vengono ignore le cifre 0 (in un Sudoku non esistono) e i caratteri che
/// Tesseract confonde spesso con lo 0. Le lettere più frequenti vengono
/// rimappate sulle cifre corrispondenti perché il plugin Android non applica
/// il whitelist di caratteri.
int? parseOcrDigit(String raw) {
  for (final unit in raw.codeUnits) {
    final code = unit;
    if (code >= 49 && code <= 57) return code - 48;
    final upper = String.fromCharCode(code >= 97 && code <= 122 ? code - 32 : code);
    switch (upper) {
      case 'I':
      case 'L':
      case '|':
        return 1;
      case 'Z':
        return 2;
      case 'A':
        return 4;
      case 'S':
        return 5;
      case 'G':
        return 6;
      case 'T':
        return 7;
      case 'B':
        return 8;
      case '0':
      case 'O':
      case 'D':
      case 'Q':
        continue;
    }
  }
  return null;
}

/// Rileva le 10 righe/colonne della griglia in un'immagine.
///
/// È pubblica per poterla verificare con un test sintetico; l'app la usa
/// soltanto tramite [LocalOcrService.recognize].
GridBounds detectGridBounds(img.Image source) {
  final prepared = _prepareImage(source);
  final gray = _grayscale(prepared);
  return _detectBounds(gray, prepared.width, prepared.height);
}

/// OCR completamente locale: nessuna rete, nessun backend, nessuna API key.
class LocalOcrService {
  Future<OcrResult> recognize(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      throw const LocalOcrException('File immagine non trovato.');
    }

    img.Image? decoded;
    try {
      decoded = img.decodeImage(await file.readAsBytes());
    } catch (_) {
      decoded = null;
    }
    if (decoded == null) {
      throw const LocalOcrException('Impossibile leggere l\'immagine.');
    }

    final prepared = _prepareImage(decoded);
    final gray = _grayscale(prepared);
    final width = prepared.width;
    final height = prepared.height;

    final bounds = _detectBounds(gray, width, height);
    final inks = _findInkCells(gray, width, height, bounds);
    if (inks.isEmpty) {
      throw const LocalOcrException(
        'OCR locale: nessuna cifra rilevata. Inquadra meglio la griglia.',
      );
    }

    final temp = await getTemporaryDirectory();
    final dir = Directory(
      '${temp.path}${Platform.pathSeparator}sudoku_ocr_${DateTime.now().microsecondsSinceEpoch}',
    );
    await dir.create(recursive: true);

    final grid = List<List<int>>.generate(9, (_) => List<int>.filled(9, 0));
    var recognized = 0;
    try {
      for (final ink in inks) {
        final digit = await _recognizeDigit(gray, width, ink, dir.path);
        if (digit != null) {
          grid[ink.row][ink.col] = digit;
          recognized++;
        }
      }
    } finally {
      try {
        await dir.delete(recursive: true);
      } catch (_) {
        // File temporanei: un eventuale fallimento della pulizia non blocca l'OCR.
      }
    }

    if (recognized < 12) {
      throw LocalOcrException(
        'OCR locale: lette solo $recognized cifre. Prova una foto più frontale e senza ombre.',
      );
    }

    final flat = flattenGrid(grid);
    if (!isSolvable(flat)) {
      throw const LocalOcrException(
        'OCR locale: la griglia letta non è valida. Controlla la foto oppure correggi i numeri a mano.',
      );
    }

    final bad = conflicts(flat);
    return OcrResult(
      grid: grid,
      note: bad.isEmpty
          ? 'OCR locale (offline): $recognized cifre lette. Controlla le celle blu.'
          : 'OCR locale (offline): $recognized cifre lette, ma ci sono conflitti da correggere.',
      model: 'tesseract',
      source: 'locale',
    );
  }
}

img.Image _prepareImage(img.Image source) {
  // Le foto della galleria sono ad alta risoluzione: ridurle a 1200 px
  // assottiglia le cifre e Tesseract finisce per leggere solo lo sfondo.
  // 1600 px conserva abbastanza dettaglio senza rallentare il rilevamento.
  const maxSide = 1600;
  final longest = math.max(source.width, source.height);
  if (longest <= maxSide) return source;
  final scale = maxSide / longest;
  return img.copyResize(
    source,
    width: math.max(1, (source.width * scale).round()),
    height: math.max(1, (source.height * scale).round()),
    interpolation: img.Interpolation.average,
  );
}

Uint8List _grayscale(img.Image image) {
  final out = Uint8List(image.width * image.height);
  final histogram = List<int>.filled(256, 0);
  var index = 0;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final p = image.getPixel(x, y);
      final alpha = (p.a / 255).toDouble().clamp(0.0, 1.0);
      // Componiamo su bianco: le PNG con trasparenza altrimenti diventano nere.
      final r = p.r * alpha + 255 * (1 - alpha);
      final g = p.g * alpha + 255 * (1 - alpha);
      final b = p.b * alpha + 255 * (1 - alpha);
      final luminance = (0.299 * r + 0.587 * g + 0.114 * b).round();
      final value = luminance < 0 ? 0 : luminance > 255 ? 255 : luminance;
      out[index++] = value;
      histogram[value]++;
    }
  }

  // Stretch del contrasto basato sui percentili 2%/98%: rimuove ombre e sfondi
  // grigi senza amplificare il rumore dei singoli pixel.
  final total = out.length;
  final target = (total * 0.02).round();
  var low = 0;
  var high = 255;
  var acc = 0;
  for (var i = 0; i < 256; i++) {
    acc += histogram[i];
    if (acc >= target) {
      low = i;
      break;
    }
  }
  acc = 0;
  for (var i = 255; i >= 0; i--) {
    acc += histogram[i];
    if (acc >= target) {
      high = i;
      break;
    }
  }
  if (high - low > 25) {
    final span = high - low;
    for (var i = 0; i < out.length; i++) {
      final stretched = ((out[i] - low) * 255 / span).round();
      out[i] = stretched < 0 ? 0 : stretched > 255 ? 255 : stretched;
    }
  }
  return out;
}

int _otsuThreshold(List<int> histogram, int total) {
  if (total <= 0) return 128;
  var sum = 0;
  for (var i = 0; i < 256; i++) {
    sum += i * histogram[i];
  }
  var weightBackground = 0;
  var sumBackground = 0;
  var bestVariance = -1.0;
  var best = 128;
  for (var t = 0; t < 256; t++) {
    weightBackground += histogram[t];
    if (weightBackground == 0) continue;
    final weightForeground = total - weightBackground;
    if (weightForeground == 0) break;
    sumBackground += t * histogram[t];
    final meanBackground = sumBackground / weightBackground;
    final meanForeground = (sum - sumBackground) / weightForeground;
    final difference = meanBackground - meanForeground;
    final variance = weightBackground * weightForeground * difference * difference;
    if (variance > bestVariance) {
      bestVariance = variance;
      best = t;
    }
  }
  return best.clamp(35, 215);
}

int _globalThreshold(Uint8List gray) {
  final histogram = List<int>.filled(256, 0);
  for (final value in gray) {
    histogram[value]++;
  }
  return _otsuThreshold(histogram, gray.length);
}

List<int> _smooth(List<int> values, int radius) {
  final out = List<int>.filled(values.length, 0);
  for (var i = 0; i < values.length; i++) {
    final from = math.max(0, i - radius);
    final to = math.min(values.length - 1, i + radius);
    var sum = 0;
    for (var j = from; j <= to; j++) {
      sum += values[j];
    }
    out[i] = sum ~/ (to - from + 1);
  }
  return out;
}

List<int> _findLines(List<int> sums, int minDistance) {
  final smooth = _smooth(sums, 2);
  var max = 0;
  for (final value in smooth) {
    if (value > max) max = value;
  }
  if (max <= 0) return <int>[];

  final threshold = max * 0.32;
  final candidates = <_Peak>[];
  for (var i = 1; i < smooth.length - 1; i++) {
    if (smooth[i] >= threshold &&
        smooth[i] >= smooth[i - 1] &&
        smooth[i] >= smooth[i + 1]) {
      candidates.add(_Peak(i, smooth[i]));
    }
  }
  candidates.sort((a, b) => b.value.compareTo(a.value));

  final picked = <int>[];
  for (final peak in candidates) {
    if (picked.every((other) => (other - peak.index).abs() >= minDistance)) {
      picked.add(peak.index);
      if (picked.length == 10) break;
    }
  }
  if (picked.length != 10) return <int>[];
  picked.sort();
  return picked;
}

List<int> _fallbackLines(List<int> sums) {
  final smooth = _smooth(sums, 3);
  var max = 0;
  for (final value in smooth) {
    if (value > max) max = value;
  }
  var start = 0;
  var end = sums.length - 1;
  if (max > 0) {
    final threshold = max * 0.25;
    for (var i = 0; i < smooth.length; i++) {
      if (smooth[i] >= threshold) {
        start = i;
        break;
      }
    }
    for (var i = smooth.length - 1; i >= 0; i--) {
      if (smooth[i] >= threshold) {
        end = i;
        break;
      }
    }
  }
  if (end - start < sums.length * 0.35) {
    start = (sums.length * 0.05).round();
    end = (sums.length * 0.95).round();
  }
  return List<int>.generate(
    10,
    (index) => (start + (end - start) * index / 9).round(),
  );
}

bool _isUniform(List<int> lines) {
  if (lines.length < 2) return false;
  final gaps = <int>[];
  for (var i = 1; i < lines.length; i++) {
    final gap = lines[i] - lines[i - 1];
    if (gap <= 0) return false;
    gaps.add(gap);
  }
  final mean = gaps.reduce((a, b) => a + b) / gaps.length;
  if (mean <= 0) return false;
  final variance =
      gaps.map((g) => (g - mean) * (g - mean)).reduce((a, b) => a + b) /
      gaps.length;
  return math.sqrt(variance) / mean < 0.35;
}

GridBounds _detectBounds(Uint8List gray, int width, int height) {
  final threshold = _globalThreshold(gray);
  final columnSums = List<int>.filled(width, 0);
  final rowSums = List<int>.filled(height, 0);
  final yFrom = (height * 0.08).round();
  final yTo = (height * 0.92).round();
  final xFrom = (width * 0.08).round();
  final xTo = (width * 0.92).round();

  for (var y = yFrom; y < yTo; y++) {
    for (var x = 0; x < width; x++) {
      if (gray[y * width + x] < threshold) columnSums[x]++;
    }
  }
  for (var y = 0; y < height; y++) {
    for (var x = xFrom; x < xTo; x++) {
      if (gray[y * width + x] < threshold) rowSums[y]++;
    }
  }

  var xLines = _findLines(columnSums, math.max(6, (width / 22).round()));
  var yLines = _findLines(rowSums, math.max(6, (height / 22).round()));
  if (xLines.length != 10 || !_isUniform(xLines)) xLines = _fallbackLines(columnSums);
  if (yLines.length != 10 || !_isUniform(yLines)) yLines = _fallbackLines(rowSums);

  // Il fallback può generare indici fuori dall'immagine su foto piccole: li riportiamo in range.
  xLines = xLines.map((v) => v.clamp(0, width - 1)).toList()..sort();
  yLines = yLines.map((v) => v.clamp(0, height - 1)).toList()..sort();
  if (xLines.length != 10 || yLines.length != 10 ||
      xLines.last - xLines.first < width * 0.3 ||
      yLines.last - yLines.first < height * 0.3) {
    throw const LocalOcrException(
      'OCR locale: griglia troppo piccola nella foto. Avvicinati e riprova.',
    );
  }
  return GridBounds(xLines, yLines);
}

List<int> _regionPixels(Uint8List gray, int width, _Box box) {
  final values = <int>[];
  for (var y = box.y; y < box.bottom; y++) {
    for (var x = box.x; x < box.right; x++) {
      values.add(gray[y * width + x]);
    }
  }
  return values;
}

/// Soglia robusta per una singola cella.
///
/// Otsu da solo può sbagliare quando il numero occupa pochissimi pixel: in
/// quel caso usiamo il punto medio tra i percentili 10/90, così lo sfondo
/// resta bianco e le tracce della cifra diventano nere.
int chooseInkThreshold(List<int> values) {
  if (values.isEmpty) return 128;
  final histogram = List<int>.filled(256, 0);
  for (final value in values) {
    final v = value < 0 ? 0 : value > 255 ? 255 : value;
    histogram[v]++;
  }
  var threshold = _otsuThreshold(histogram, values.length);
  var dark = 0;
  for (final value in values) {
    if (value < threshold) dark++;
  }
  final fraction = dark / values.length;
  if (fraction < 0.02 || fraction > 0.45) {
    final sorted = List<int>.from(values)..sort();
    final lowIndex = (sorted.length * 0.10).round().clamp(0, sorted.length - 1);
    final highIndex = (sorted.length * 0.90).round().clamp(0, sorted.length - 1);
    threshold = ((sorted[lowIndex] + sorted[highIndex]) / 2).round();
  }
  return threshold.clamp(35, 215);
}

int _regionThreshold(Uint8List gray, int width, _Box box) =>
    chooseInkThreshold(_regionPixels(gray, width, box));

List<_Ink> _findInkCells(
  Uint8List gray,
  int width,
  int height,
  GridBounds bounds,
) {
  final result = <_Ink>[];
  for (var row = 0; row < 9; row++) {
    for (var col = 0; col < 9; col++) {
      final left = bounds.xLines[col];
      final right = bounds.xLines[col + 1];
      final top = bounds.yLines[row];
      final bottom = bounds.yLines[row + 1];
      final insetX = math.max(2, ((right - left) * 0.12).round());
      final insetY = math.max(2, ((bottom - top) * 0.12).round());
      final inner = _Box(
        left + insetX,
        top + insetY,
        right - left - 2 * insetX,
        bottom - top - 2 * insetY,
      );
      if (inner.width < 8 || inner.height < 8) continue;

      final region = _regionPixels(gray, width, inner);
      if (region.isEmpty) continue;
      var regionMin = 255;
      var regionMax = 0;
      for (final value in region) {
        if (value < regionMin) regionMin = value;
        if (value > regionMax) regionMax = value;
      }
      // Una cella senza contrasto non contiene una cifra: evitiamo di passare
      // a Tesseract un rettangolo tutto bianco o tutto nero.
      if (regionMax - regionMin < 35) continue;
      final threshold = chooseInkThreshold(region);
      var minX = inner.right;
      var minY = inner.bottom;
      var maxX = inner.x;
      var maxY = inner.y;
      var dark = 0;
      for (var y = inner.y; y < inner.bottom; y++) {
        if (y < 0 || y >= height) continue;
        for (var x = inner.x; x < inner.right; x++) {
          if (x < 0 || x >= width) continue;
          if (gray[y * width + x] < threshold) {
            dark++;
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
          }
        }
      }
      final area = inner.width * inner.height;
      final minInk = math.max(10, (area * 0.015).round());
      if (dark < minInk || dark > area * 0.45 || maxX <= minX || maxY <= minY) {
        continue;
      }
      if (maxX - minX < 3 || maxY - minY < 3) continue;

      final padX = math.max(2, ((maxX - minX) * 0.15).round());
      final padY = math.max(2, ((maxY - minY) * 0.15).round());
      final inkBox = _Box(
        math.max(0, minX - padX),
        math.max(0, minY - padY),
        math.min(width, maxX + padX + 1) - math.max(0, minX - padX),
        math.min(height, maxY + padY + 1) - math.max(0, minY - padY),
      );
      if (inkBox.width <= 0 || inkBox.height <= 0) continue;
      result.add(_Ink(row, col, inkBox, threshold));
    }
  }
  return result;
}

img.Image _renderDigit(
  Uint8List gray,
  int imageWidth,
  _Ink ink, {
  int thresholdDelta = 0,
}) {
  const canvas = 176;
  const digitMax = 116;
  final threshold = ink.threshold + thresholdDelta;
  final scale = math.min(digitMax / ink.box.width, digitMax / ink.box.height);
  final drawWidth = math.max(1, (ink.box.width * scale).round());
  final drawHeight = math.max(1, (ink.box.height * scale).round());
  final offsetX = (canvas - drawWidth) ~/ 2;
  final offsetY = (canvas - drawHeight) ~/ 2;

  final mask = Uint8List(canvas * canvas);
  for (var y = 0; y < drawHeight; y++) {
    final sourceY = ink.box.y + (y / scale).round();
    if (sourceY < 0 || sourceY >= ink.box.bottom) continue;
    for (var x = 0; x < drawWidth; x++) {
      final sourceX = ink.box.x + (x / scale).round();
      if (sourceX < 0 || sourceX >= ink.box.right) continue;
      if (gray[sourceY * imageWidth + sourceX] < threshold) {
        mask[(offsetY + y) * canvas + (offsetX + x)] = 1;
      }
    }
  }

  // Leggera dilatazione 3x3: ricollega i tratti spezzati dalle JPEG e rende
  // le cifre più leggibili a Tesseract senza unire numeri diversi (una cella
  // alla volta).
  final out = img.Image(width: canvas, height: canvas);
  for (var y = 0; y < canvas; y++) {
    for (var x = 0; x < canvas; x++) {
      var inked = false;
      for (var dy = -1; dy <= 1 && !inked; dy++) {
        final ny = y + dy;
        if (ny < 0 || ny >= canvas) continue;
        for (var dx = -1; dx <= 1; dx++) {
          final nx = x + dx;
          if (nx < 0 || nx >= canvas) continue;
          if (mask[ny * canvas + nx] == 1) {
            inked = true;
            break;
          }
        }
      }
      final color = inked ? 0 : 255;
      out.setPixelRgb(x, y, color, color, color);
    }
  }
  return out;
}

Future<int?> _recognizeDigit(
  Uint8List gray,
  int imageWidth,
  _Ink ink,
  String directory,
) async {
  // Prima prova con la soglia calcolata; se Tesseract non legge nulla,
  // riproviamo con una soglia più bassa (tratti più spessi).
  for (var attempt = 0; attempt < 2; attempt++) {
    final delta = attempt == 0 ? 0 : -18;
    final rendered = _renderDigit(gray, imageWidth, ink, thresholdDelta: delta);
    final path =
        '$directory${Platform.pathSeparator}r${ink.row}c${ink.col}_$attempt.png';
    await File(path).writeAsBytes(img.encodePng(rendered));
    try {
      final text = await TesseractOcr.extractText(path, config: _ocrConfig);
      final digit = parseOcrDigit(text);
      if (digit != null) return digit;
    } catch (_) {
      // Si passa al tentativo successivo con soglia diversa.
    }
  }
  return null;
}
