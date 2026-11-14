/// 舊版「正餐」視為午餐，「宵夜」視為點心。
class MealSlots {
  static const fixed = ['早餐', '午餐', '晚餐'];
  static const choices = [...fixed, '點心'];

  static String normalize(Object? value) {
    return switch (value?.toString()) {
      '正餐' => '午餐',
      '宵夜' => '點心',
      final String text => text,
      _ => '',
    };
  }

  static bool isFixed(Object? value) => fixed.contains(normalize(value));

  static String dateKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}'
      '${day.month.toString().padLeft(2, '0')}'
      '${day.day.toString().padLeft(2, '0')}';

  static bool sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
