import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/core/utils/line_colors.dart';

void main() {
  group('LineColors', () {
    test('light color for L1 is #0455A1', () {
      expect(LineColors.forLine('L1', Brightness.light), const Color(0xFF0455A1));
    });

    test('dark color for L1 is #2979FF (lighter)', () {
      expect(LineColors.forLine('L1', Brightness.dark), const Color(0xFF2979FF));
    });

    test('dark colors have equal or higher luminance than light counterparts', () {
      for (final code in LineColors.allCodes) {
        final light = LineColors.forLine(code, Brightness.light);
        final dark  = LineColors.forLine(code, Brightness.dark);
        expect(
          dark.computeLuminance(),
          greaterThanOrEqualTo(light.computeLuminance() - 0.01),
          reason: '$code dark luminance should be >= light luminance',
        );
      }
    });

    test('allCodes contains all 16 lines', () {
      final expected = {'L1','L2','L3','L4','L5','L15','L7','L8','L9','L10','L11','L12','L13','L17','LA','LB'};
      expect(LineColors.allCodes.toSet(), equals(expected));
    });

    test('unknown line returns grey', () {
      expect(LineColors.forLine('UNKNOWN', Brightness.light), Colors.grey);
      expect(LineColors.forLine('UNKNOWN', Brightness.dark), Colors.grey);
    });
  });
}
