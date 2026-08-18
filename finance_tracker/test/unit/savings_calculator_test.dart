import 'package:flutter_test/flutter_test.dart';
import 'package:finance_tracker/src/features/savings/domain/savings_goal.dart';

void main() {
  group('SavingsGoal', () {
    test('progressPercent menghitung persentase progres dengan benar', () {
      final goal = SavingsGoal(
        id: '1',
        title: 'Dana Darurat',
        targetAmount: 1000000,
        currentAmount: 500000,
      );

      expect(goal.progressPercent, 0.5);
    });

    test('progressPercent mengembalikan 0 jika targetAmount 0', () {
      final goal = SavingsGoal(
        id: '1',
        title: 'Dana Darurat',
        targetAmount: 0,
        currentAmount: 500000,
      );

      expect(goal.progressPercent, 0.0);
    });

    test('progressPercent dibatasi maksimal 1.0', () {
      final goal = SavingsGoal(
        id: '1',
        title: 'Dana Darurat',
        targetAmount: 1000000,
        currentAmount: 1500000,
      );

      expect(goal.progressPercent, 1.0);
    });

    test('remaining menghitung sisa yang perlu dikumpulkan', () {
      final goal = SavingsGoal(
        id: '1',
        title: 'Dana Darurat',
        targetAmount: 1000000,
        currentAmount: 300000,
      );

      expect(goal.remaining, 700000);
    });

    test('remaining bisa bernilai negatif jika sudah terkumpul lebih', () {
      final goal = SavingsGoal(
        id: '1',
        title: 'Dana Darurat',
        targetAmount: 1000000,
        currentAmount: 1200000,
      );

      expect(goal.remaining, -200000);
    });

    test('progressPercent mengembalikan 0 jika currentAmount 0', () {
      final goal = SavingsGoal(
        id: '1',
        title: 'Dana Darurat',
        targetAmount: 1000000,
        currentAmount: 0,
      );

      expect(goal.progressPercent, 0.0);
    });
  });
}
