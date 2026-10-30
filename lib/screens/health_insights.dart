import 'package:cloud_firestore/cloud_firestore.dart';

/// 最近七天的健康觀察規則。
///
/// 這是專題使用的簡易風險提示，不是獸醫診斷。扣分數值集中在
/// [penaltyRules]，之後要調整規則時只需要修改這個表格。
class HealthInsights {
  static const Map<String, int> penaltyRules = {
    // 飲食
    '嘔吐': 20,
    '拒食': 18,
    '食慾下降': 12,
    '進食量偏低': 10,
    '飲水不足': 8,
    '更換食品': 3,

    // 行為
    '抽搐': 30,
    '活動量偏低': 10,
    '睡眠變化': 6,
    '焦慮或疲倦': 5,
    '吠叫不止': 5,
    '亂吃東西': 8,
    '攻擊性': 8,
    '躲藏': 8,

    // 排便
    '疑似血便': 25,
    '黑色糞便': 25,
    '灰白色糞便': 15,
    '糞便偏軟': 8,
    '糞便乾硬': 6,
  };

  static DateTime date(Map<String, dynamic> data) {
    final value = data['recordDate'] ??
        data['record_date'] ??
        data['createdAt'] ??
        data['updated_at'] ??
        data['date'];
    if (value is Timestamp) return value.toDate();
    return DateTime.tryParse(value?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  static String type(Map<String, dynamic> data) {
    final raw = (data['recordType'] ?? data['type'] ?? '').toString();
    if (data.containsKey('abnormal_behaviors') || raw == '行為') {
      return 'behavior';
    }
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
            ?.map((item) => item.toString())
            .where((item) => item != '無異常')
            .toList() ??
        <String>[];

    if (data['vomited'] == true ||
        RegExp('嘔吐|vomit', caseSensitive: false).hasMatch(note) ||
        abnormal.any((item) => item.contains('嘔吐'))) {
      found.add('嘔吐');
    }

    if (kind == 'diet') {
      final appetite = '${data['appetite'] ?? ''}';
      if (appetite.contains('不佳') || appetite.contains('下降')) {
        found.add('食慾下降');
      }
      if (data['waterStatus'] == '不足') found.add('飲水不足');
      if (data['finishedRatio'] is num &&
          (data['finishedRatio'] as num) < 40) {
        found.add('進食量偏低');
      }
      if (data['changedFood'] == true) found.add('更換食品');
    }

    if (kind == 'poop') {
      final color = '${data['color'] ?? ''}';
      final consistency = '${data['consistency'] ?? ''}';
      if (color.contains('血') || RegExp('血便|帶血').hasMatch(note)) {
        found.add('疑似血便');
      }
      if (color.contains('黑色')) found.add('黑色糞便');
      if (color.contains('灰白')) found.add('灰白色糞便');
      if (consistency.contains('偏軟') ||
          '${data['shape'] ?? ''}'.contains('糊')) {
        found.add('糞便偏軟');
      }
      if (consistency.contains('乾硬')) found.add('糞便乾硬');
    }

    if (kind == 'behavior') {
      final appetiteChange = '${data['appetite_change'] ?? ''}';
      if (appetiteChange == '拒食') {
        found.add('拒食');
      } else if (appetiteChange == '下降') {
        found.add('食慾下降');
      }
      if (data['activity_level'] is num &&
          (data['activity_level'] as num) <= 2) {
        found.add('活動量偏低');
      }
      if (data['sleep_status'] != null && data['sleep_status'] != '良好') {
        found.add('睡眠變化');
      }
      if (['焦慮', '疲倦'].contains(data['mood'])) {
        found.add('焦慮或疲倦');
      }
      for (final item in abnormal) {
        if (penaltyRules.containsKey(item) && !found.contains(item)) {
          found.add(item);
        }
      }
    }

    return found;
  }

  static int penalty(String warning) => penaltyRules[warning] ?? 5;

  static List<Map<String, dynamic>> recent(
    Iterable<Map<String, dynamic>> records,
  ) {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 7));
    return records.where((record) {
      final when = date(record);
      return when.millisecondsSinceEpoch > 0 &&
          !when.isBefore(cutoff) &&
          !when.isAfter(now.add(const Duration(days: 1)));
    }).toList();
  }

  /// 回傳每一種異常在最近七天造成的總扣分。
  /// 同一筆紀錄內的相同異常只扣一次；不同日期重複出現則會累加。
  static Map<String, int> deductionBreakdown(
    Iterable<Map<String, dynamic>> records, {
    String? category,
  }) {
    final items = recent(records).where((record) {
      final recordType = type(record);
      if (category != null) return recordType == category;
      return ['diet', 'poop', 'behavior'].contains(recordType);
    });

    final deductions = <String, int>{};
    for (final record in items) {
      for (final warning in warnings(record).toSet()) {
        deductions.update(
          warning,
          (value) => value + penalty(warning),
          ifAbsent: () => penalty(warning),
        );
      }
    }
    return deductions;
  }

  static Map<String, int> warningCounts(
    Iterable<Map<String, dynamic>> records, {
    String? category,
  }) {
    final counts = <String, int>{};
    final items = recent(records).where((record) {
      final recordType = type(record);
      if (category != null) return recordType == category;
      return ['diet', 'poop', 'behavior'].contains(recordType);
    });
    for (final record in items) {
      for (final warning in warnings(record).toSet()) {
        counts.update(warning, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    return counts;
  }

  static int? score(
    Iterable<Map<String, dynamic>> records, {
    String? category,
  }) {
    final items = recent(records).where((record) {
      final recordType = type(record);
      return category == null
          ? ['diet', 'poop', 'behavior'].contains(recordType)
          : recordType == category;
    }).toList();
    if (items.isEmpty) return null;
    final deductions = deductionBreakdown(items, category: category)
        .values
        .fold<int>(0, (sum, points) => sum + points);
    return (100 - deductions).clamp(0, 100).toInt();
  }

  static String level(int? score) {
    if (score == null) return '資料不足';
    if (score >= 85) return '狀況穩定';
    if (score >= 70) return '建議持續觀察';
    if (score >= 50) return '需要多加留意';
    return '建議諮詢獸醫';
  }

  static String summary(Iterable<Map<String, dynamic>> records) {
    final items = recent(records)
        .where((record) =>
            ['diet', 'poop', 'behavior'].contains(type(record)))
        .toList();
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
