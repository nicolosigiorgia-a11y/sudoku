import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../lib/core/local_ocr.dart';
import '../lib/core/sudoku.dart';

void main() {
  test('parseOcrDigit gestisce le confusioni tipiche di Tesseract', () {
    expect(parseOcrDigit('7'), 7);
    expect(parseOcrDigit('l'), 1);
    expect(parseOcrDigit('I'), 1);
    expect(parseOcrDigit('Z'), 2);
    expect(parseOcrDigit('S'), 5);
    expect(parseOcrDigit('B'), 8);
    expect(parseOcrDigit('O 4'), 4);
    expect(parseOcrDigit('0'), isNull);
    expect(parseOcrDigit('cde'), isNull);
  });

  test('detectGridBounds trova le 10 linee di una griglia sintetica', () {
    const size = 1000;
    final image = img.Image(width: size, height: size);
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        image.setPixelRgb(x, y, 255, 255, 255);
      }
    }
    for (var i = 0; i < 10; i++) {
      final pos = 50 + i * 100;
      for (var t = 0; t < 4; t++) {
        for (var y = 0; y < size; y++) {
          image.setPixelRgb(pos + t, y, 0, 0, 0);
        }
        for (var x = 0; x < size; x++) {
          image.setPixelRgb(x, pos + t, 0, 0, 0);
        }
      }
    }

    final bounds = detectGridBounds(image);

    expect(bounds.xLines.length, 10);
    expect(bounds.yLines.length, 10);
    expect((bounds.xLines.first - 50).abs(), lessThanOrEqualTo(6));
    expect((bounds.xLines.last - 950).abs(), lessThanOrEqualTo(6));
    expect((bounds.yLines.first - 50).abs(), lessThanOrEqualTo(6));
    expect((bounds.yLines.last - 950).abs(), lessThanOrEqualTo(6));
    for (var i = 1; i < bounds.xLines.length; i++) {
      final gap = bounds.xLines[i] - bounds.xLines[i - 1];
      expect(gap, greaterThanOrEqualTo(90));
      expect(gap, lessThanOrEqualTo(110));
    }
  });

  test('detectGridBounds non lancia StateError su foto senza linee', () {
    final image = img.Image(width: 400, height: 400);
    for (var y = 0; y < 400; y++) {
      for (var x = 0; x < 400; x++) {
        image.setPixelRgb(x, y, 255, 255, 255);
      }
    }
    final bounds = detectGridBounds(image);
    expect(bounds.xLines.length, 10);
    expect(bounds.yLines.length, 10);
  });

  test('chooseInkThreshold separa la cifra dallo sfondo', () {
    final region = <int>[
      for (var i = 0; i < 900; i++) 245,
      for (var i = 0; i < 60; i++) 40,
    ];
    final threshold = chooseInkThreshold(region);
    expect(threshold, greaterThan(40));
    expect(threshold, lessThan(245));
    final darkFraction = region.where((value) => value < threshold).length / region.length;
    expect(darkFraction, greaterThanOrEqualTo(0.02));
    expect(darkFraction, lessThanOrEqualTo(0.45));
  });

  test('isBlankGrid riconosce una griglia senza cifre', () {
    expect(
      isBlankGrid(List<List<int>>.generate(9, (_) => List<int>.filled(9, 0))),
      isTrue,
    );
    final grid = List<List<int>>.generate(9, (_) => List<int>.filled(9, 0));
    grid[0][0] = 5;
    expect(isBlankGrid(grid), isFalse);
  });
}
