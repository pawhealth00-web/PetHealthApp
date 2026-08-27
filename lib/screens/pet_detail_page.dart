import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'ai_analysis_page.dart';
import 'behavior_record_page.dart';
import 'diet_record_page.dart';
import 'poop_record_page.dart';
import 'vaccine_record_page.dart';

class PetDetailPage extends StatefulWidget {
  final String petId;
  final String petName;

  const PetDetailPage({
    super.key,
    required this.petId,
    required this.petName,
  });

  @override
  State<PetDetailPage> createState() => _PetDetailPageState();
}

class _PetDetailPageState extends State<PetDetailPage> {
  static const Color _green = Color(0xFF2E7D5B);
  static const Color _background = Color(0xFFF5F7F2);
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DietRecordPage(petId: widget.petId, petName: widget.petName),
      BehaviorRecordPage(petId: widget.petId, petName: widget.petName),
      PoopRecordPage(petId: widget.petId, petName: widget.petName),
      _buildHealthDashboard(),
    ];

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: Text('${widget.petName} 的專屬天地'),
        backgroundColor: _currentIndex == 3 ? _green : Colors.brown,
        foregroundColor: Colors.white,
      ),
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: _currentIndex == 3 ? _green : Colors.brown,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.restaurant), label: '飲食紀錄'),
          BottomNavigationBarItem(icon: Icon(Icons.mood), label: '行為紀錄'),
          BottomNavigationBarItem(icon: Icon(Icons.pets), label: '排便追蹤'),
          BottomNavigationBarItem(icon: Icon(Icons.health_and_safety), label: '健康存摺'),
        ],
      ),
    );
  }

  Widget _buildHealthDashboard() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('health_records')
          .where('petId', isEqualTo: widget.petId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('健康紀錄讀取失敗：${snapshot.error}', textAlign: TextAlign.center),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: _green));
        }

        final records = [...snapshot.data!.docs];
        records.sort((a, b) => _recordDate(b.data()).compareTo(_recordDate(a.data())));
        final score = _healthScore(records);
        final dietCount = _countType(records, 'diet');
        final behaviorCount = _countType(records, 'behavior');
        final poopCount = _countType(records, 'poop');
        final vaccineCount = _countType(records, 'vaccine');

        return RefreshIndicator(
          color: _green,
          onRefresh: () async => Future<void>.delayed(const Duration(milliseconds: 300)),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
            children: [
              _buildTopButtons(),
              const SizedBox(height: 16),
              _buildScoreCard(score, records),
              const SizedBox(height: 20),
              const Text('健康項目', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.55,
                children: [
                  _metricCard('飲食', Icons.restaurant, Colors.orange, _categoryScore(records, 'diet'), dietCount),
                  _metricCard('排便', Icons.pets, Colors.brown, _categoryScore(records, 'poop'), poopCount),
                  _metricCard('行為', Icons.mood, Colors.blue, _categoryScore(records, 'behavior'), behaviorCount),
                  _metricCard('疫苗', Icons.vaccines, Colors.pinkAccent, vaccineCount == 0 ? 0 : 100, vaccineCount),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('最近紀錄', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('共 ${records.length} 筆', style: const TextStyle(color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 10),
              if (records.isEmpty)
                _buildEmptyState()
              else
                ...records.take(20).map((record) => _buildRecordCard(record.data())),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VaccineRecordPage(petId: widget.petId, petName: widget.petName),
              ),
            ),
            icon: const Icon(Icons.vaccines),
            label: const Text('疫苗紀錄'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pinkAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HealthAnalysisPage(petId: widget.petId, petName: widget.petName),
              ),
            ),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('AI 健康分析'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScoreCard(
      int score,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> records,
      ) {
    final latest = records.isEmpty ? '尚無紀錄' : _formatDate(_recordDate(records.first.data()));
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D5B), Color(0xFF61A681)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x332E7D5B), blurRadius: 14, offset: Offset(0, 7)),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 9,
                  backgroundColor: Colors.white24,
                  color: Colors.white,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$score', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                    const Text('健康分數', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${widget.petName} 的健康狀況', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_healthSummary(records), style: const TextStyle(color: Colors.white, height: 1.4)),
                const SizedBox(height: 8),
                Text('最新紀錄：$latest', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCard(String title, IconData icon, Color color, int score, int count) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 8)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  count == 0 ? '尚無紀錄' : '$score 分・$count 筆',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> data) {
    final type = (data['recordType'] ?? '').toString();
    final config = _typeConfig(type);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: config.color.withOpacity(0.12),
          child: Icon(config.icon, color: config.color),
        ),
        title: Text(_recordTitle(data, config.label), style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(_recordSubtitle(data), maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Text(_formatDate(_recordDate(data)), style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: const Column(
        children: [
          Icon(Icons.health_and_safety_outlined, size: 56, color: _green),
          SizedBox(height: 10),
          Text('尚無健康紀錄', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 5),
          Text('新增飲食、行為、排便或疫苗紀錄後會顯示在這裡', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  int _countType(List<QueryDocumentSnapshot<Map<String, dynamic>>> records, String type) {
    return records.where((record) => record.data()['recordType'] == type).length;
  }

  int _categoryScore(List<QueryDocumentSnapshot<Map<String, dynamic>>> records, String type) {
    final category = records.where((record) => record.data()['recordType'] == type).take(7).toList();
    if (category.isEmpty) return 0;
    var score = 100;
    for (final record in category) {
      final text = record.data().values.join(' ').toLowerCase();
      if (RegExp('嘔吐|腹瀉|拉肚子|帶血|食慾不佳|食慾下降|精神差|異常').hasMatch(text)) {
        score -= 12;
      }
    }
    return score.clamp(40, 100).toInt();
  }

  int _healthScore(List<QueryDocumentSnapshot<Map<String, dynamic>>> records) {
    if (records.isEmpty) return 0;
    final scores = ['diet', 'poop', 'behavior']
        .map((type) => _categoryScore(records, type))
        .where((score) => score > 0)
        .toList();
    if (scores.isEmpty) return 100;
    return (scores.reduce((a, b) => a + b) / scores.length).round();
  }

  String _healthSummary(List<QueryDocumentSnapshot<Map<String, dynamic>>> records) {
    if (records.isEmpty) return '開始建立健康紀錄後，這裡會顯示健康摘要。';
    final text = records.take(7).map((record) => record.data().values.join(' ')).join(' ');
    if (RegExp('嘔吐|帶血|腹瀉|拉肚子').hasMatch(text)) {
      return '近期有需要留意的症狀，若持續發生，建議諮詢獸醫。';
    }
    if (RegExp('食慾不佳|食慾下降|精神差|喝水量偏少').hasMatch(text)) {
      return '近期有輕微異常，請持續觀察食慾、飲水與精神狀態。';
    }
    return '近期整體狀況穩定，請繼續保持每日健康紀錄。';
  }

  DateTime _recordDate(Map<String, dynamic> data) {
    final value = data['recordDate'] ?? data['createdAt'] ?? data['date'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _formatDate(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) return '--';
    return '${date.month}/${date.day}';
  }

  _RecordTypeConfig _typeConfig(String type) {
    switch (type) {
      case 'diet':
        return const _RecordTypeConfig('飲食', Icons.restaurant, Colors.orange);
      case 'poop':
        return const _RecordTypeConfig('排便', Icons.pets, Colors.brown);
      case 'behavior':
        return const _RecordTypeConfig('行為', Icons.mood, Colors.blue);
      case 'vaccine':
        return const _RecordTypeConfig('疫苗', Icons.vaccines, Colors.pinkAccent);
      default:
        return const _RecordTypeConfig('健康', Icons.health_and_safety, _green);
    }
  }

  String _recordTitle(Map<String, dynamic> data, String fallback) {
    return (data['title'] ??
        data['vaccineName'] ??
        data['foodName'] ??
        data['foodType'] ??
        data['shape'] ??
        data['behavior'] ??
        data['status'] ??
        '$fallback紀錄')
        .toString();
  }

  String _recordSubtitle(Map<String, dynamic> data) {
    final note = (data['note'] ?? '').toString().trim();
    if (note.isNotEmpty) return note;
    if (data['recordType'] == 'diet') {
      return '份量：${data['amount'] ?? '--'} ${data['unit'] ?? ''}';
    }
    if (data['recordType'] == 'poop') {
      return '顏色：${data['color'] ?? '--'}';
    }
    if (data['recordType'] == 'behavior') {
      return (data['energy'] ?? data['mood'] ?? '已完成行為紀錄').toString();
    }
    return '無補充說明';
  }
}

class _RecordTypeConfig {
  final String label;
  final IconData icon;
  final Color color;

  const _RecordTypeConfig(this.label, this.icon, this.color);
}
