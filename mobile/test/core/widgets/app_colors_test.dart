import 'package:flutter_test/flutter_test.dart';
import 'package:trilho/core/widgets/app_colors.dart';

void main() {
  group('AppColors.forDensity', () {
    test('density 0.05 → crowdEmpty', () {
      expect(AppColors.forDensity(0.05), AppColors.crowdEmpty);
    });
    test('density 0.25 → crowdLow', () {
      expect(AppColors.forDensity(0.25), AppColors.crowdLow);
    });
    test('density 0.50 → crowdModerate', () {
      expect(AppColors.forDensity(0.50), AppColors.crowdModerate);
    });
    test('density 0.70 → crowdHigh', () {
      expect(AppColors.forDensity(0.70), AppColors.crowdHigh);
    });
    test('density 1.00 → crowdFull', () {
      expect(AppColors.forDensity(1.00), AppColors.crowdFull);
    });
  });

  test('crowd label Vazio for density 0.0', () {
    expect(AppColors.crowdLabel(0.0), 'Vazio');
  });
  test('crowd label Moderado for density 0.55', () {
    expect(AppColors.crowdLabel(0.55), 'Moderado');
  });
  test('crowd label Lotado for density 1.0', () {
    expect(AppColors.crowdLabel(1.0), 'Lotado');
  });
}
