import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_app/screens/health_insights.dart';

void main() {
  Map<String, dynamic> diet(DateTime day, {bool vomited = false}) => {
        'recordType': '飲食',
        'recordDate': day.toIso8601String(),
        'foodName': '飼料',
        'amount': 40,
        'vomited': vomited,
      };

  test('舊警訊在不同日期的完整正常紀錄後逐步消退', () {
    final today = DateTime.now();
    final warning = diet(today.subtract(const Duration(days: 3)), vomited: true);
    final firstClean = diet(today.subtract(const Duration(days: 2)));
    final secondClean = diet(today.subtract(const Duration(days: 1)));
    final before = HealthInsights.score([warning])!;
    final afterOne = HealthInsights.score([warning, firstClean])!;
    final afterTwo = HealthInsights.score([warning, firstClean, secondClean])!;

    expect(HealthInsights.deductionBreakdown([warning])['嘔吐'], 20);
    expect(HealthInsights.deductionBreakdown([warning, firstClean])['嘔吐'], 10);
    expect(HealthInsights.deductionBreakdown([warning, firstClean, secondClean])
        .containsKey('嘔吐'), isFalse);
    expect(afterOne, greaterThan(before));
    expect(afterTwo, greaterThan(afterOne));
    expect(HealthInsights.warningCounts([warning, firstClean, secondClean])['嘔吐'], 1);
  });

  test('同一天多筆紀錄不會誤算成多天恢復', () {
    final today = DateTime.now();
    final warning = diet(today.subtract(const Duration(days: 2)), vomited: true);
    final clean = diet(today.subtract(const Duration(days: 1)));
    expect(HealthInsights.deductionBreakdown([warning, clean, clean])['嘔吐'], 10);
    final sameDayWarning = diet(today.subtract(const Duration(days: 1)), vomited: true);
    expect(HealthInsights.deductionBreakdown(
        [warning, clean, sameDayWarning])['嘔吐'], 20);
  });
}
