// Top-level smoke tests for the Trilho app.
// Feature-level widget tests live in test/features/**/*_test.dart.
// This file covers only cross-cutting assertions that don't belong
// to a single feature.

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('smoke: flutter_test package is importable', () {
    // Ensures the test harness is correctly wired and no import errors exist.
    expect(true, isTrue);
  });
}
