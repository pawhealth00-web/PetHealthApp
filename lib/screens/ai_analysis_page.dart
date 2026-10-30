import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
        .where((record) => ['diet', 'behavior', 'poop']
            .contains(HealthInsights.type(record)))
        .toList()
      ..sort((a, b) =>
          HealthInsights.date(b).compareTo(HealthInsights.date(a)));

    final score = HealthInsights.score(recentRecords);
    final deductions = HealthInsights.deductionBreakdown(recentRecords);
    final counts = HealthInsights.warningCounts(recentRecords);
    final sortedDeductions = deductions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 40),
      children: [
        _scoreCard(score, recentRecords.length),
        const SizedBox(height: 16),
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
        const Text(
          '健康扣分明細',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: _green,
          ),
        ),
        const SizedBox(height: 10),
        if (recentRecords.isEmpty)
          _messageCard('最近七天沒有飲食、行為或排便紀錄，請先新增紀錄。')
        else if (sortedDeductions.isEmpty)
          _messageCard('最近七天沒有記錄到明顯異常，目前不扣分。')
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
                      : '100 分起算，依異常紀錄扣分',
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
    final singlePenalty = HealthInsights.penalty(warning);
    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFFFECEC),
        child: Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
      ),
      title: Text(warning, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('出現 $count 次・每次扣 $singlePenalty 分'),
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
