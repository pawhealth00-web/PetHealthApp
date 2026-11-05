import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_app/screens/health_insights.dart';

void main() {
  test('a diet record with vomiting produces an explicit reminder', () {
    final reminder = HealthInsights.reminder({
      'recordType': 'diet',
      'vomited': true,
    });
    expect(reminder, contains('嘔吐'));
  });
}
