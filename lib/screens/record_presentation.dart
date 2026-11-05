import 'health_insights.dart';

class RecordPresentation {
  static String title(Map<String, dynamic> data) {
    final type = HealthInsights.type(data);
    if (type == 'diet') {
      final parts = <String>[
        if ('${data['mealType'] ?? ''}'.trim().isNotEmpty) '${data['mealType']}'.trim(),
        if ('${data['supplement'] ?? ''}'.trim().isNotEmpty) '${data['supplement']}'.trim(),
        if ('${data['foodName'] ?? data['foodType'] ?? ''}'.trim().isNotEmpty)
          '${data['foodName'] ?? data['foodType']}'.trim(),
      ];
      return parts.isEmpty ? '飲食紀錄' : parts.join(' · ');
    }
    final candidate = data['title'] ?? data['vaccineName'] ?? data['shape'] ??
        data['mood'] ?? data['status'];
    if ('${candidate ?? ''}'.trim().isNotEmpty) return '$candidate';
    return {'poop': '排便紀錄', 'behavior': '行為紀錄',
      'vaccine': '疫苗紀錄', 'medical': '醫療紀錄'}[type] ?? '健康紀錄';
  }

  static String subtitle(Map<String, dynamic> data) {
    final note = '${data['note'] ?? data['notes'] ?? ''}'.trim();
    if (note.isNotEmpty) return note;
    switch (HealthInsights.type(data)) {
      case 'diet':
        final amount = data['amount'];
        return amount == null ? '已記錄餵食時間' : '份量：$amount ${data['unit'] ?? ''}';
      case 'poop':
        return '顏色：${data['color'] ?? '未填'}';
      case 'behavior':
        return '心情：${data['mood'] ?? '未填'}';
      case 'vaccine':
        return '第 ${data['doseNumber'] ?? '?'} 劑 · ${data['clinic'] ?? ''}';
      default:
        return '${data['clinic'] ?? '醫療紀錄'}';
    }
  }
}
