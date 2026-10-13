import 'package:cloud_firestore/cloud_firestore.dart';

/// An observation score for recent entries; it is not a veterinary diagnosis.
class HealthInsights {
  static DateTime date(Map<String, dynamic> data) {
    final value = data['recordDate'] ?? data['record_date'] ??
        data['createdAt'] ?? data['updated_at'] ?? data['date'];
    if (value is Timestamp) return value.toDate();
    return DateTime.tryParse(value?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  static String type(Map<String, dynamic> data) {
    final raw = (data['recordType'] ?? data['type'] ?? '').toString();
    if (data.containsKey('abnormal_behaviors') || raw == '行為') return 'behavior';
    if (raw == '飲食') return 'diet';
    if (raw == '排便') return 'poop';
    if (raw == '疫苗') return 'vaccine';
    if (raw == 'medical' && data['type'] == '疫苗') return 'vaccine';
    if (['看診', '醫療', '驅蟲'].contains(raw)) return 'medical';
    return raw;
  }

  static List<String> warnings(Map<String, dynamic> data) {
    final found = <String>[];
    final kind = type(data);
    final note = '${data['note'] ?? ''} ${data['notes'] ?? ''}';
    final abnormal = (data['abnormal_behaviors'] as List?)
            ?.map((e) => e.toString()).where((e) => e != '無異常').toList() ??
        <String>[];
    if (data['vomited'] == true || RegExp('嘔吐|vomit', caseSensitive: false).hasMatch(note) ||
        abnormal.any((e) => e.contains('嘔吐'))) found.add('嘔吐');
    if (kind == 'diet') {
      if ('${data['appetite'] ?? ''}'.contains('不佳') ||
          '${data['appetite'] ?? ''}'.contains('下降')) found.add('食慾下降');
      if (data['waterStatus'] == '不足') found.add('飲水不足');
      if (data['finishedRatio'] is num &&
          (data['finishedRatio'] as num) < 40) found.add('進食量偏低');
      if (data['changedFood'] == true) found.add('更換食品');
    }
    if (kind == 'poop') {
      final color = '${data['color'] ?? ''}';
      final consistency = '${data['consistency'] ?? ''}';
      if (color.contains('血') || RegExp('血便|帶血').hasMatch(note)) found.add('疑似血便');
      if (color.contains('黑色')) found.add('黑色糞便');
      if (consistency.contains('偏軟') || '${data['shape'] ?? ''}'.contains('糊')) found.add('糞便偏軟');
      if (consistency.contains('乾硬')) found.add('糞便乾硬');
    }
    if (kind == 'behavior') {
      if (['下降', '拒食'].contains(data['appetite_change'])) found.add('食慾變化');
      if (data['activity_level'] is num &&
          (data['activity_level'] as num) <= 2) found.add('活動量偏低');
      if (data['sleep_status'] != null && data['sleep_status'] != '良好') found.add('睡眠變化');
      for (final item in abnormal) {
        if (!found.contains(item) && item != '其他') found.add(item);
      }
    }
    return found;
  }

  static int penalty(String warning) {
    if (warning.contains('嘔吐') || warning.contains('血便') || warning.contains('黑色糞便') ||
        warning.contains('抽搐')) return 25;
    if (warning.contains('食慾') || warning.contains('活動量')) return 12;
    if (warning == '更換食品') return 3;
    return 8;
  }

  static List<Map<String, dynamic>> recent(Iterable<Map<String, dynamic>> records) {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 7));
    return records.where((record) {
      final when = date(record);
      return when.millisecondsSinceEpoch > 0 &&
          !when.isBefore(cutoff) && !when.isAfter(now.add(const Duration(days: 1)));
    }).toList();
  }

  static int? score(Iterable<Map<String, dynamic>> records, {String? category}) {
    final items = recent(records).where((r) => category == null
        ? ['diet', 'poop', 'behavior'].contains(type(r))
        : type(r) == category);
    if (items.isEmpty) return null;
    var deductions = 0;
    for (final record in items) {
      for (final warning in warnings(record).toSet()) {
        deductions += penalty(warning);
      }
    }
    return (100 - deductions).clamp(0, 100).toInt();
  }

  static String summary(Iterable<Map<String, dynamic>> records) {
    final items = recent(records);
    if (items.isEmpty) return '最近七天沒有紀錄，健康分數暫不計算。';
    final found = items.expand(warnings).toSet().toList();
    if (found.isEmpty) return '最近七天尚無記錄到的異常，請繼續觀察。';
    return '近期記錄：${found.take(4).join('、')}。若症狀持續或加劇，請諮詢獸醫。';
  }

  static String reminder(Map<String, dynamic> data) {
    final found = warnings(data);
    if (found.isEmpty) {
      return type(data) == 'vaccine'
          ? '請留意下次施打日期及接種後反應。'
          : '本次沒有記錄到明顯異常，請持續觀察。';
    }
    return '本次記錄：${found.join('、')}。若持續或加劇，請諮詢獸醫。';
  }
}
