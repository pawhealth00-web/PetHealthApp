import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'health_insights.dart';
import 'record_detail_page.dart';
import 'category_history_page.dart';
import 'record_presentation.dart';
import 'medical_record_page.dart';

class HistoryRecordPage extends StatefulWidget {
  const HistoryRecordPage({super.key});

  @override
  State<HistoryRecordPage> createState() => _HistoryRecordPageState();
}

class _HistoryRecordPageState extends State<HistoryRecordPage> {
  static const _green = Color(0xFF2E7D5B);
  String? _selectedPetId;

  Query<Map<String, dynamic>> get _petsQuery => FirebaseFirestore.instance
      .collection('pets')
      .where('owner_uid', isEqualTo: FirebaseAuth.instance.currentUser?.uid ?? '');

  Query<Map<String, dynamic>> _recordsQuery(String petId) => FirebaseFirestore
      .instance
      .collection('health_records')
      .where('petId', isEqualTo: petId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F2),
      appBar: AppBar(
        title: const Text('健康存摺', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: _green,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _petsQuery.snapshots(),
        builder: (context, petSnapshot) {
          if (petSnapshot.hasError) return _error('寵物資料讀取失敗：${petSnapshot.error}');
          if (!petSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: _green));
          final pets = petSnapshot.data!.docs;
          if (pets.isEmpty) return _error('尚未建立寵物資料');

          final selectedId = pets.any((p) => p.id == _selectedPetId)
              ? _selectedPetId!
              : pets.first.id;
          final selectedPet = pets.firstWhere((p) => p.id == selectedId);

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _recordsQuery(selectedId).snapshots(),
            builder: (context, recordSnapshot) {
              if (recordSnapshot.hasError) return _error('健康紀錄讀取失敗：${recordSnapshot.error}');
              if (!recordSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: _green));
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('pets').doc(selectedId)
                    .collection('behavior_records').snapshots(),
                builder: (context, behaviorSnapshot) {
                  if (behaviorSnapshot.hasError) return _error('行為紀錄讀取失敗：${behaviorSnapshot.error}');
                  if (!behaviorSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: _green));
                  final records = [...recordSnapshot.data!.docs, ...behaviorSnapshot.data!.docs];
                  records.sort((a, b) => _dateOf(b.data()).compareTo(_dateOf(a.data())));
                  return _dashboard(pets, selectedPet, records);
                },
              );
            },
          );
        },
      ),
      floatingActionButton: _selectedPetId == null
          ? null
          : FloatingActionButton.extended(
        onPressed: () => _showAddMedicalRecord(_selectedPetId!),
        backgroundColor: _green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('新增醫療紀錄'),
      ),
    );
  }

  Widget _dashboard(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> pets,
      QueryDocumentSnapshot<Map<String, dynamic>> selectedPet,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> records,
      ) {
    if (_selectedPetId != selectedPet.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedPetId = selectedPet.id);
      });
    }
    final pet = selectedPet.data();
    final score = _healthScore(records);
    final latest = records.isEmpty ? '尚無紀錄' : _displayDate(_dateOf(records.first.data()));
    final medical = records.where((r) => _isMedical(r.data())).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        _petSelector(pets, selectedPet.id),
        const SizedBox(height: 16),
        _summaryCard(pet, score, latest, records),
        const SizedBox(height: 16),
        const Text('健康項目', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.65,
          children: [
            _metric('飲食', 'diet', selectedPet.id, Icons.restaurant, Colors.orange, _categoryScore(records, 'diet'), _count(records, 'diet')),
            _metric('排便', 'poop', selectedPet.id, Icons.pets, Colors.brown, _categoryScore(records, 'poop'), _count(records, 'poop')),
            _metric('行為', 'behavior', selectedPet.id, Icons.mood, Colors.blue, _categoryScore(records, 'behavior'), _count(records, 'behavior')),
            _metric('醫療', 'medical', selectedPet.id, Icons.medical_services, Colors.redAccent, 0, medical.length, showScore: false),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('最近紀錄', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('顯示最近 ${records.length < 5 ? records.length : 5} 筆 · 共 ${records.length} 筆', style: const TextStyle(color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 10),
        if (records.isEmpty)
          _emptyCard()
        else
          ...records.take(5).map((r) => _recordCard(r, selectedPet.id)),
      ],
    );
  }

  Widget _petSelector(List<QueryDocumentSnapshot<Map<String, dynamic>>> pets, String selectedId) {
    return SizedBox(
      height: 82,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: pets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, index) {
          final doc = pets[index];
          final data = doc.data();
          final selected = doc.id == selectedId;
          final image = (data['imageUrl'] ?? data['image_url'] ?? '').toString();
          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() => _selectedPetId = doc.id),
            child: Container(
              width: 142,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFE1F1E8) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: selected ? _green : Colors.grey.shade200, width: selected ? 2 : 1),
              ),
              child: Row(children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: image.isEmpty ? null : NetworkImage(image),
                  child: image.isEmpty ? const Icon(Icons.pets, color: _green) : null,
                ),
                const SizedBox(width: 9),
                Expanded(child: Text((data['name'] ?? '未命名').toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.w500))),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _summaryCard(Map<String, dynamic> pet, int score, String latest, List<QueryDocumentSnapshot<Map<String, dynamic>>> records) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2E7D5B), Color(0xFF5EA47F)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x332E7D5B), blurRadius: 12, offset: Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SizedBox(
            width: 92,
            height: 92,
            child: Stack(alignment: Alignment.center, fit: StackFit.expand, children: [
              CircularProgressIndicator(value: score / 100, strokeWidth: 9, backgroundColor: Colors.white24, color: Colors.white),
              Column(mainAxisSize: MainAxisSize.min, children: [Text(HealthInsights.score(records.map((r) => r.data())) == null ? '--' : '$score', style: const TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.bold)), const Text('近七天觀察分數', style: TextStyle(color: Colors.white70, fontSize: 10))]),
            ]),
          ),
          const SizedBox(width: 18),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${pet['name'] ?? '寵物'}的健康狀況', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 7),
            Text(_summary(records), style: const TextStyle(color: Colors.white, height: 1.4)),
            const SizedBox(height: 7),
            Text('最新紀錄：$latest', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ])),
        ]),
      ]),
    );
  }

  Widget _metric(String title, String category, String petId, IconData icon, Color color, int score, int count, {bool showScore = true}) => InkWell(
    borderRadius: BorderRadius.circular(18),
    onTap: () => Navigator.push(context, MaterialPageRoute(
      builder: (_) => CategoryHistoryPage(petId: petId, category: category))),
    child: Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 8)]),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: .12), shape: BoxShape.circle), child: Icon(icon, color: color)),
      const SizedBox(width: 10),
      Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), Text(count == 0 ? '尚無紀錄' : showScore ? '$score 分・$count 筆' : '$count 筆', style: const TextStyle(color: Colors.grey, fontSize: 12))])),
    ]),
  ));

  Widget _recordCard(QueryDocumentSnapshot<Map<String, dynamic>> doc, String petId) {
    final data = doc.data();
    final type = HealthInsights.type(data);
    final config = _typeConfig(type);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: CircleAvatar(backgroundColor: config.$3.withValues(alpha: .12), child: Icon(config.$2, color: config.$3)),
        title: Text(RecordPresentation.title(data), style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(RecordPresentation.subtitle(data), maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Text(_displayDate(_dateOf(data)), style: const TextStyle(color: Colors.grey, fontSize: 12)),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
          RecordDetailPage(reference: doc.reference, petId: petId))),
      ),
    );
  }

  Future<void> _showAddMedicalRecord(String petId) async {
    final pet = await FirebaseFirestore.instance.collection('pets').doc(petId).get();
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => MedicalRecordPage(
      petId: petId, petName: '${pet.data()?['name'] ?? '寵物'}')));
  }

  int _count(List<QueryDocumentSnapshot<Map<String, dynamic>>> records, String type) => records.where((r) => HealthInsights.type(r.data()) == type).length;

  int _categoryScore(List<QueryDocumentSnapshot<Map<String, dynamic>>> records, String type) {
    return HealthInsights.score(records.map((r) => r.data()), category: type) ?? 0;
  }

  int _healthScore(List<QueryDocumentSnapshot<Map<String, dynamic>>> records) {
    if (records.isEmpty) return 0;
    return HealthInsights.score(records.map((r) => r.data())) ?? 0;
  }

  String _summary(List<QueryDocumentSnapshot<Map<String, dynamic>>> records) {
    return HealthInsights.summary(records.map((r) => r.data()));
  }

  bool _isMedical(Map<String, dynamic> d) => ['medical', 'vaccine'].contains(HealthInsights.type(d));

  DateTime _dateOf(Map<String, dynamic> data) {
    return HealthInsights.date(data);
  }

  String _displayDate(DateTime date) => date.millisecondsSinceEpoch == 0 ? '--' : '${date.month}/${date.day}';

  (String, IconData, Color) _typeConfig(String type) {
    if (type == 'diet' || type == '飲食') return ('飲食', Icons.restaurant, Colors.orange);
    if (type == 'poop' || type == '排便') return ('排便', Icons.pets, Colors.brown);
    if (type == 'behavior' || type == '行為') return ('行為', Icons.mood, Colors.blue);
    if (type == '疫苗' || type == 'vaccine') return ('疫苗', Icons.vaccines, Colors.green);
    return ('醫療', Icons.medical_services, Colors.redAccent);
  }

  String _recordTitle(Map<String, dynamic> d, String fallback) {
    final value = (d['title'] ?? d['vaccineName'] ?? d['foodName'] ??
        d['foodType'] ?? d['shape'] ?? d['mood'] ?? d['status'] ?? '').toString().trim();
    return value.isEmpty ? '$fallback紀錄' : value;
  }
  String _recordSubtitle(Map<String, dynamic> d) => (d['note'] ?? d['clinic'] ?? d['appetite'] ?? '無補充說明').toString();

  Widget _emptyCard() => Container(padding: const EdgeInsets.all(28), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)), child: const Column(children: [Icon(Icons.health_and_safety_outlined, size: 54, color: _green), SizedBox(height: 10), Text('尚無健康紀錄'), Text('新增飲食、排便、行為或醫療紀錄後會顯示在這裡', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))]));
  Widget _error(String message) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(message, textAlign: TextAlign.center)));
}
