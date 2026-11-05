import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_app/screens/health_insights.dart';

void main() {
  test('vomiting checkbox reduces the recent observation score', () {
    final records = [
      {'recordType': 'diet', 'recordDate': DateTime.now(), 'vomited': true},
    ];
    expect(HealthInsights.score(records), 75);
    expect(HealthInsights.summary(records), contains('嘔吐'));
  });

  test('behavior subcollection shape contributes and old data is excluded', () {
    final records = [
      {'record_date': DateTime.now(), 'activity_level': 1,
        'abnormal_behaviors': ['躲藏']},
      {'recordType': 'diet', 'recordDate': DateTime.now().subtract(
          const Duration(days: 10)), 'vomited': true},
    ];
    expect(HealthInsights.score(records), 80);
  });

  test('no recent health record has no score', () {
    expect(HealthInsights.score([
      {'recordType': 'vaccine', 'recordDate': DateTime.now()},
    ]), isNull);
  });
}
