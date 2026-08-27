import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
              final records = [...recordSnapshot.data!.docs];
              records.sort((a, b) => _dateOf(b.data()).compareTo(_dateOf(a.data())));
              return _dashboard(pets, selectedPet, records);
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
            _metric('飲食', Icons.restaurant, Colors.orange, _categoryScore(records, 'diet'), _count(records, 'diet')),
            _metric('排便', Icons.pets, Colors.brown, _categoryScore(records, 'poop'), _count(records, 'poop')),
            _metric('行為', Icons.mood, Colors.blue, _categoryScore(records, 'behavior'), _count(records, 'behavior')),
            _metric('醫療', Icons.medical_services, Colors.redAccent, 100, medical.length),
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
          _emptyCard()
        else
          ...records.take(20).map((r) => _recordCard(r.data())),
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
            child: Stack(alignment: Alignment.center, children: [
              CircularProgressIndicator(value: score / 100, strokeWidth: 9, backgroundColor: Colors.white24, color: Colors.white),
              Column(mainAxisSize: MainAxisSize.min, children: [Text('$score', style: const TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.bold)), const Text('健康分數', style: TextStyle(color: Colors.white70, fontSize: 11))]),
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

  Widget _metric(String title, IconData icon, Color color, int score, int count) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 8)]),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: .12), shape: BoxShape.circle), child: Icon(icon, color: color)),
      const SizedBox(width: 10),
      Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), Text(count == 0 ? '尚無紀錄' : '$score 分・$count 筆', style: const TextStyle(color: Colors.grey, fontSize: 12))])),
    ]),
  );

  Widget _recordCard(Map<String, dynamic> data) {
    final type = (data['recordType'] ?? data['type'] ?? '其他').toString();
    final config = _typeConfig(type);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: CircleAvatar(backgroundColor: config.$3.withValues(alpha: .12), child: Icon(config.$2, color: config.$3)),
        title: Text(_recordTitle(data, config.$1), style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(_recordSubtitle(data), maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Text(_displayDate(_dateOf(data)), style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ),
    );
  }

  Future<void> _showAddMedicalRecord(String petId) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MedicalRecordForm(petId: petId),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ 醫療紀錄已儲存至 Firestore'), backgroundColor: _green));
    }
  }

  int _count(List<QueryDocumentSnapshot<Map<String, dynamic>>> records, String type) => records.where((r) => (r.data()['recordType'] ?? r.data()['type']) == type).length;

  int _categoryScore(List<QueryDocumentSnapshot<Map<String, dynamic>>> records, String type) {
    final list = records.where((r) => (r.data()['recordType'] ?? r.data()['type']) == type).take(7);
    if (list.isEmpty) return 0;
    var score = 100;
    for (final r in list) {
      final text = r.data().values.join(' ').toLowerCase();
      if (RegExp('嘔吐|腹瀉|拉肚子|帶血|食慾不佳|異常|精神差').hasMatch(text)) score -= 12;
    }
    return score.clamp(40, 100);
  }

  int _healthScore(List<QueryDocumentSnapshot<Map<String, dynamic>>> records) {
    if (records.isEmpty) return 0;
    final scores = ['diet', 'poop', 'behavior'].map((t) => _categoryScore(records, t)).where((s) => s > 0).toList();
    return scores.isEmpty ? 100 : (scores.reduce((a, b) => a + b) / scores.length).round();
  }

  String _summary(List<QueryDocumentSnapshot<Map<String, dynamic>>> records) {
    if (records.isEmpty) return '開始記錄飲食、排便與行為後，這裡會顯示健康摘要。';
    final recent = records.take(7).map((r) => r.data().values.join(' ')).join(' ');
    if (RegExp('嘔吐|帶血|腹瀉|拉肚子').hasMatch(recent)) return '最近紀錄中有需要留意的症狀，建議持續觀察，若未改善請諮詢獸醫。';
    if (RegExp('食慾不佳|精神差|喝水量偏少').hasMatch(recent)) return '近期有輕微異常紀錄，請注意食慾、飲水與精神狀態。';
    return '近期整體狀況穩定，請繼續維持每日健康紀錄。';
  }

  bool _isMedical(Map<String, dynamic> d) => ['medical', '看診', '疫苗', '驅蟲', '醫療'].contains(d['recordType'] ?? d['type']);

  DateTime _dateOf(Map<String, dynamic> data) {
    final value = data['recordDate'] ?? data['createdAt'] ?? data['date'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _displayDate(DateTime date) => date.millisecondsSinceEpoch == 0 ? '--' : '${date.month}/${date.day}';

  (String, IconData, Color) _typeConfig(String type) {
    if (type == 'diet' || type == '飲食') return ('飲食', Icons.restaurant, Colors.orange);
    if (type == 'poop' || type == '排便') return ('排便', Icons.pets, Colors.brown);
    if (type == 'behavior' || type == '行為') return ('行為', Icons.mood, Colors.blue);
    if (type == '疫苗') return ('疫苗', Icons.vaccines, Colors.green);
    return ('醫療', Icons.medical_services, Colors.redAccent);
  }

  String _recordTitle(Map<String, dynamic> d, String fallback) => (d['title'] ?? d['foodName'] ?? d['foodType'] ?? d['shape'] ?? d['status'] ?? '$fallback紀錄').toString();
  String _recordSubtitle(Map<String, dynamic> d) => (d['note'] ?? d['clinic'] ?? d['appetite'] ?? '無補充說明').toString();

  Widget _emptyCard() => Container(padding: const EdgeInsets.all(28), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)), child: const Column(children: [Icon(Icons.health_and_safety_outlined, size: 54, color: _green), SizedBox(height: 10), Text('尚無健康紀錄'), Text('新增飲食、排便、行為或醫療紀錄後會顯示在這裡', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))]));
  Widget _error(String message) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(message, textAlign: TextAlign.center)));
}

class _MedicalRecordForm extends StatefulWidget {
  final String petId;
  const _MedicalRecordForm({required this.petId});

  @override
  State<_MedicalRecordForm> createState() => _MedicalRecordFormState();
}

class _MedicalRecordFormState extends State<_MedicalRecordForm> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _clinic = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  String _type = '看診';
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _clinic.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('health_records').add({
        'petId': widget.petId,
        'recordType': 'medical',
        'type': _type,
        'title': _title.text.trim(),
        'clinic': _clinic.text.trim(),
        'note': _note.text.trim(),
        'recordDate': Timestamp.fromDate(_date),
        'createdAt': FieldValue.serverTimestamp(),
        'owner_uid': FirebaseAuth.instance.currentUser?.uid,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('儲存失敗：$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('新增醫療紀錄', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: Color(0xFF2E7D5B))),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(value: _type, decoration: const InputDecoration(labelText: '紀錄類型', border: OutlineInputBorder()), items: ['看診', '疫苗', '驅蟲', '其他'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => _type = v!)),
            const SizedBox(height: 12),
            TextFormField(controller: _title, decoration: const InputDecoration(labelText: '項目名稱', border: OutlineInputBorder()), validator: (v) => v == null || v.trim().isEmpty ? '請輸入項目名稱' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _clinic, decoration: const InputDecoration(labelText: '醫院／地點（選填）', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.calendar_month), title: Text('${_date.year}/${_date.month}/${_date.day}'), trailing: const Text('選擇日期'), onTap: () async { final value = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 365))); if (value != null) setState(() => _date = value); }),
            TextFormField(controller: _note, maxLines: 3, decoration: const InputDecoration(labelText: '備註（選填）', border: OutlineInputBorder())),
            const SizedBox(height: 18),
            FilledButton(onPressed: _saving ? null : _save, style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2E7D5B), padding: const EdgeInsets.symmetric(vertical: 15)), child: _saving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('儲存紀錄')),
          ]),
        ),
      ),
    );
  }
}
