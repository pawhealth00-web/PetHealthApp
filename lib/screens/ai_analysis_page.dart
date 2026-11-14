import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'health_insights.dart';

class HealthAnalysisPage extends StatelessWidget {
  const HealthAnalysisPage({
    super.key,
    required this.petId,
    required this.petName,
  });

  final String petId;
  final String petName;

  static const _green = Color(0xFF174D3A);
  static const _lightGreen = Color(0xFFEAF4EC);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F6),
      appBar: AppBar(
        title: Text('$petName 的健康分析'),
        backgroundColor: _green,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('health_records')
            .where('petId', isEqualTo: petId)
            .snapshots(),
        builder: (context, healthSnapshot) {
          if (healthSnapshot.hasError) {
            return _error('健康紀錄讀取失敗：${healthSnapshot.error}');
          }
          if (!healthSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _green),
            );
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('pets')
                .doc(petId)
                .collection('behavior_records')
                .snapshots(),
            builder: (context, behaviorSnapshot) {
              if (behaviorSnapshot.hasError) {
                return _error('行為紀錄讀取失敗：${behaviorSnapshot.error}');
              }
              if (!behaviorSnapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: _green),
                );
              }

              final records = <Map<String, dynamic>>[
                ...healthSnapshot.data!.docs.map((doc) => doc.data()),
                ...behaviorSnapshot.data!.docs.map((doc) => doc.data()),
              ];
              return _analysis(records);
            },
          );
        },
      ),
    );
  }

  Widget _analysis(List<Map<String, dynamic>> allRecords) {
    final recentRecords = HealthInsights.recent(allRecords)
        .where((record) => ['diet', 'behavior', 'poop', 'medical']
            .contains(HealthInsights.type(record)))
        .toList()
      ..sort((a, b) =>
          HealthInsights.date(b).compareTo(HealthInsights.date(a)));
    final scoredRecords = recentRecords.where((record) =>
        ['diet', 'behavior', 'poop'].contains(HealthInsights.type(record)))
        .toList();

    final score = HealthInsights.score(recentRecords);
    final deductions = HealthInsights.deductionBreakdown(recentRecords);
    final bonuses = HealthInsights.bonusBreakdown(recentRecords);
    final counts = HealthInsights.warningCounts(recentRecords);
    final sortedDeductions = deductions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 40),
      children: [
        _scoreCard(score, scoredRecords.length),
        const SizedBox(height: 16),
        _GeminiHealthCard(
          petName: petName,
          score: score,
          records: recentRecords,
        ),
        _catNutritionCard(recentRecords),
        const SizedBox(height: 22),
        const Text(
          '最近 7 天資料來源',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: _green,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _categoryCard(
                '飲食',
                'diet',
                Icons.restaurant_outlined,
                Colors.orange,
                recentRecords,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _categoryCard(
                '行為',
                'behavior',
                Icons.mood_outlined,
                Colors.blue,
                recentRecords,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _categoryCard(
                '排便',
                'poop',
                Icons.pets_outlined,
                Colors.brown,
                recentRecords,
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const Text('穩定與恢復加分',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                color: _green)),
        const SizedBox(height: 10),
        if (bonuses.isEmpty)
          _messageCard('目前沒有符合加分條件的穩定或恢復紀錄。')
        else
          Card(child: Column(children: bonuses.entries.map((entry) =>
              ListTile(title: Text(entry.key), trailing: Text('+${entry.value}',
                  style: const TextStyle(color: _green,
                      fontWeight: FontWeight.bold)))).toList())),
        const SizedBox(height: 22),
        const Text(
          '目前健康扣分明細',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: _green,
          ),
        ),
        const SizedBox(height: 10),
        if (scoredRecords.isEmpty)
          _messageCard('最近七天沒有飲食、行為或排便紀錄，請先新增紀錄。')
        else if (sortedDeductions.isEmpty)
          _messageCard(counts.isEmpty
              ? '最近七天沒有記錄到明顯異常，目前不扣分。'
              : '近期曾有異常紀錄；同類紀錄後續恢復穩定，目前舊警訊不再扣分。請繼續觀察。')
        else
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                for (var i = 0; i < sortedDeductions.length; i++) ...[
                  _deductionRow(
                    sortedDeductions[i].key,
                    counts[sortedDeductions[i].key] ?? 1,
                    sortedDeductions[i].value,
                  ),
                  if (i < sortedDeductions.length - 1)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                ],
              ],
            ),
          ),
        const SizedBox(height: 22),
        ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          collapsedBackgroundColor: Colors.white,
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            '查看我們設定的扣分規則',
            style: TextStyle(fontWeight: FontWeight.bold, color: _green),
          ),
          children: HealthInsights.penaltyRules.entries
              .map(
                (rule) => ListTile(
                  dense: true,
                  title: Text(rule.key),
                  trailing: Text(
                    '-${rule.value} 分',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        const Text(
          '※ 此分數是依照使用者填寫的紀錄進行簡易觀察，不代表醫療診斷。若出現血便、黑便、抽搐、持續嘔吐或精神明顯不佳，請儘快諮詢獸醫。',
          style: TextStyle(color: Colors.grey, height: 1.55),
        ),
      ],
    );
  }

  Widget _catNutritionCard(List<Map<String, dynamic>> records) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('pets').doc(petId).snapshots(),
      builder: (context, snapshot) {
        final pet = snapshot.data?.data();
        final species = (pet?['species'] ?? '').toString().toLowerCase();
        if (!species.contains('貓') && !species.contains('cat')) {
          return const SizedBox.shrink();
        }
        final birthday = pet?['birthday'];
        int? age;
        if (birthday is Timestamp) {
          final born = birthday.toDate();
          final now = DateTime.now();
          age = now.year - born.year;
          if (now.month < born.month ||
              (now.month == born.month && now.day < born.day)) age--;
          if (age < 0) age = null;
        }
        final treatRecords = records.where((record) {
          if (HealthInsights.type(record) != 'diet') return false;
          final food = '${record['foodName'] ?? record['foodType'] ?? ''}';
          return food.contains('貓條') || food.contains('肉泥');
        }).length;
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Card(
            color: _lightGreen,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('貓咪飲食提醒',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                          color: _green)),
                  const SizedBox(height: 8),
                  Text(age == null
                      ? '若補上生日，可依年齡顯示照護討論提示。'
                      : age >= 10
                          ? '目前約 $age 歲；10 歲以上屬高齡階段，可在定期看診時請獸醫評估飲食與是否需要補充品。'
                          : '目前約 $age 歲；是否需要保養品應依飲食、身體狀況與獸醫評估，不能只按年齡決定。'),
                  const SizedBox(height: 8),
                  Text(treatRecords >= 4
                      ? '最近 7 天已記錄 $treatRecords 次貓條／肉泥。記錄較頻繁，請確認零食總熱量是否超過每日熱量的 10%，並詢問獸醫合適份量。'
                      : treatRecords > 0
                          ? '最近 7 天已記錄 $treatRecords 次貓條／肉泥。零食總熱量宜控制在每日熱量的 10% 以內；不確定份量可詢問獸醫。'
                          : '貓條等零食宜留意總熱量；若不確定份量或保養品是否適合，請詢問獸醫。'),
                  const SizedBox(height: 8),
                  const Text('參考：WSAVA 寵物營養資料、FelineVMA 高齡貓照護指引。',
                      style: TextStyle(fontSize: 12, color: _green)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _scoreCard(int? score, int recordCount) {
    final displayScore = score?.toString() ?? '--';
    final color = score == null
        ? Colors.grey
        : score >= 85
            ? Colors.green
            : score >= 70
                ? Colors.orange
                : Colors.redAccent;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF174D3A), Color(0xFF5B9275)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 94,
            height: 94,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 7),
            ),
            child: Text(
              displayScore,
              style: TextStyle(
                color: color,
                fontSize: 29,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  HealthInsights.level(score),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  score == null
                      ? '尚無足夠資料可以計算'
                      : '80 分起算；穩定加分，後續正常紀錄逐日減少舊警訊扣分',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 5),
                Text(
                  '本次分析 $recordCount 筆紀錄',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryCard(
    String title,
    String category,
    IconData icon,
    Color color,
    List<Map<String, dynamic>> records,
  ) {
    final categoryRecords = records
        .where((record) => HealthInsights.type(record) == category)
        .toList();
    final categoryScore = HealthInsights.score(
      categoryRecords,
      category: category,
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 7),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 3),
          Text(
            categoryScore == null ? '-- 分' : '$categoryScore 分',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          Text(
            '${categoryRecords.length} 筆',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _deductionRow(String warning, int count, int totalPoints) {
    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFFFECEC),
        child: Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
      ),
      title: Text(warning, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('近七天出現 $count 次・恢復後目前仍計入 $totalPoints 分'),
      trailing: Text(
        '-$totalPoints',
        style: const TextStyle(
          color: Colors.redAccent,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _messageCard(String message) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _lightGreen,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: _green, height: 1.5),
      ),
    );
  }

  Widget _error(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

class _GeminiHealthCard extends StatefulWidget {
  const _GeminiHealthCard({
    required this.petName,
    required this.score,
    required this.records,
  });

  final String petName;
  final int? score;
  final List<Map<String, dynamic>> records;

  @override
  State<_GeminiHealthCard> createState() => _GeminiHealthCardState();
}

class _GeminiHealthCardState extends State<_GeminiHealthCard> {
  static final _endpoint = Uri.parse(
    'https://pethealth-backend.onrender.com/analyze-health',
  );
  bool _loading = false;
  String? _analysis;
  String? _advice;
  String? _error;
  String? _photoNotice;

  Map<String, dynamic> _recordSummary(Map<String, dynamic> record) {
    final category = HealthInsights.type(record);
    final date = HealthInsights.date(record).toIso8601String().split('T').first;
    final observations = <String>[];
    void add(String label, Object? value) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text != 'null') {
        final full = '$label：$text';
        observations.add(full.length > 120 ? full.substring(0, 120) : full);
      }
    }

    if (category == 'diet') {
      add('餐別', record['mealType']);
      add('食慾', record['appetite']);
      add('飲水', record['waterStatus']);
      add('進食比例', record['finishedRatio']);
      if (record['vomited'] == true) observations.add('有嘔吐');
      if (record['changedFood'] == true) observations.add('有更換食品');
    } else if (category == 'behavior') {
      add('情緒', record['mood']);
      add('活動量', record['activity_level']);
      add('睡眠', record['sleep_status']);
      add('食慾變化', record['appetite_change']);
      add('異常行為', (record['abnormal_behaviors'] as List?)?.join('、'));
    } else if (category == 'poop') {
      add('形狀', record['shape']);
      add('顏色', record['color']);
      add('軟硬', record['consistency']);
      add('次數', record['frequency']);
    } else if (category == 'medical') {
      add('醫療項目', record['title']);
      add('類型', record['type']);
      add('醫院', record['clinic']);
      add('醫師', record['doctor']);
      final note = (record['note'] ?? '').toString().trim();
      if (note.isNotEmpty) observations.add('醫師備註：${note.length > 1800 ? note.substring(0, 1800) : note}');
      final report = (record['reportText'] ?? '').toString().trim();
      if (report.isNotEmpty) observations.add('醫師報告全文：$report');
      if ((record['reportPhotoUrl'] ?? '').toString().isNotEmpty) {
        observations.add('本次醫療紀錄附有醫師報告照片');
      }
    }
    if (category != 'medical') add('補充', record['note'] ?? record['notes']);
    return {
      'record_date': date,
      'category': category,
      'observations': observations.take(12).toList(),
      'warnings': HealthInsights.warnings(record)
          .take(12)
          .map((warning) => warning.length > 60
              ? warning.substring(0, 60) : warning)
          .toList(),
    };
  }

  Future<void> _analyze() async {
    if (_loading || widget.records.isEmpty) return;
    setState(() {
      _loading = true;
      _analysis = null;
      _advice = null;
      _error = null;
      _photoNotice = null;
    });
    try {
      final body = <String, dynamic>{
        'pet_name': widget.petName,
        'score': widget.score,
        'records': widget.records.take(30).map(_recordSummary).toList(),
      };
      final reportRecords = widget.records.take(30).where((record) =>
          HealthInsights.type(record) == 'medical' &&
          (record['reportPhotoUrl'] ?? '').toString().isNotEmpty);
      if (reportRecords.isNotEmpty) {
        final url = reportRecords.first['reportPhotoUrl'].toString();
        try {
          final bytes = await FirebaseStorage.instance.refFromURL(url)
              .getData(2 * 1024 * 1024)
              .timeout(const Duration(seconds: 20));
          if (bytes == null) throw StateError('照片為空');
          body['report_image_base64'] = base64Encode(bytes);
          body['report_image_mime'] = url.toLowerCase().contains('.png')
              ? 'image/png' : 'image/jpeg';
        } catch (_) {
          _photoNotice = '報告照片未能讀取；本次只分析文字紀錄。';
        }
      }
      final response = await http.post(
        _endpoint,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 100));
      final result = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode != 200) {
        final detail = result is Map ? result['detail']?.toString() : null;
        throw Exception(detail ?? '伺服器回應 ${response.statusCode}');
      }
      if (result is! Map ||
          result['analysis'] is! String ||
          result['advice'] is! String ||
          (result['analysis'] as String).trim().isEmpty ||
          (result['advice'] as String).trim().isEmpty) {
        throw const FormatException('回覆格式不完整');
      }
      if (!mounted) return;
      setState(() {
        _analysis = (result['analysis'] as String).trim();
        _advice = (result['advice'] as String).trim();
      });
    } catch (error) {
      if (!mounted) return;
      final reason = error.toString().replaceFirst('Exception: ', '');
      setState(() => _error = reason.length > 180
          ? '${reason.substring(0, 180)}…'
          : reason);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFFEAF4EC),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Gemini 健康提醒',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                    color: Color(0xFF174D3A))),
            const SizedBox(height: 8),
            const Text('依最近七天的飲食、行為、排便與醫療紀錄整理趨勢。醫師備註只作為文字參考，不自動加分。'),
            if (_photoNotice != null) Text(_photoNotice!,
                style: const TextStyle(color: Colors.deepOrange)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loading || widget.records.isEmpty ? null : _analyze,
              icon: _loading
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome),
              label: Text(_loading ? '分析中…' : '分析最近七天紀錄'),
            ),
            if (widget.records.isEmpty)
              const Padding(padding: EdgeInsets.only(top: 10),
                  child: Text('請先新增至少一筆健康紀錄。')),
            if (_error != null)
              Padding(padding: const EdgeInsets.only(top: 12),
                  child: Text('分析失敗：$_error',
                      style: const TextStyle(color: Colors.red))),
            if (_analysis != null) ...[
              const SizedBox(height: 14),
              const Text('趨勢觀察', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(_analysis!),
              const SizedBox(height: 10),
              const Text('照護建議', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(_advice!),
            ],
            const SizedBox(height: 10),
            const Text('此為紀錄輔助整理，不是獸醫診斷。',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

