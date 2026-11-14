import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_app/screens/meal_slots.dart';

void main() {
  test('早餐午餐晚餐為每日固定餐別，點心可重複', () {
    expect(MealSlots.fixed, ['早餐', '午餐', '晚餐']);
    expect(MealSlots.isFixed('早餐'), isTrue);
    expect(MealSlots.isFixed('午餐'), isTrue);
    expect(MealSlots.isFixed('晚餐'), isTrue);
    expect(MealSlots.isFixed('點心'), isFalse);
  });

  test('舊正餐按午餐檢查，宵夜不占固定餐別', () {
    expect(MealSlots.normalize('正餐'), '午餐');
    expect(MealSlots.normalize('宵夜'), '點心');
    expect(MealSlots.isFixed('正餐'), isTrue);
    expect(MealSlots.isFixed('宵夜'), isFalse);
  });

  test('同一天不同時間仍屬同一餐別日期', () {
    expect(MealSlots.sameDay(DateTime(2026, 11, 15, 8),
        DateTime(2026, 11, 15, 20)), isTrue);
    expect(MealSlots.sameDay(DateTime(2026, 11, 15),
        DateTime(2026, 11, 16)), isFalse);
  });
}
