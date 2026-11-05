import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'health_insights.dart';
import 'record_detail_page.dart';
import 'record_presentation.dart';

class MedicalRecordPage extends StatefulWidget {
  const MedicalRecordPage({super.key, required this.petId, required this.petName});
  final String petId;
  final String petName;

  @override
  State<MedicalRecordPage> createState() => _MedicalRecordPageState();
}

class _MedicalRecordPageState extends State<MedicalRecordPage> {
  static const _green = Color(0xFF2E7D5B);

  List<(String, String)> _vaccines(String species) {
    if (species.contains('狗') || species.contains('犬') ||
        species.toLowerCase().contains('dog')) {
      return const [
        ('dog_core', '犬核心綜合疫苗（犬瘟熱／腺病毒／小病毒）'),
        ('dog_lepto', '犬鉤端螺旋體'),
        ('rabies', '狂犬病'),
      ];
    }
    if (species.contains('貓') || species.toLowerCase().contains('cat')) {
      return const [
        ('cat_fvrcp', '貓三合一（貓鼻氣管炎／卡里西／泛白血球減少症）'),
        ('cat_felv', '貓白血病（幼貓及依風險評估）'),
        ('rabies', '狂犬病'),
      ];
    }
    return const [];
  }

  String? _legacyKey(Map<String, dynamic> data, String species) {
    final key = data['vaccineKey']?.toString();
    if (key != null && key.isNotEmpty) return key;
    final name = '${data['vaccineName'] ?? data['title'] ?? ''}';
    if (name.contains('狂犬')) return 'rabies';
    if (name.contains('鉤端')) return 'dog_lepto';
    if (name.contains('白血病')) return 'cat_felv';
    if (name.contains('貓三合') || name.contains('FVRCP')) return 'cat_fvrcp';
    if ((species.contains('狗') || species.toLowerCase().contains('dog')) &&
        (name.contains('合一') || name.contains('犬瘟熱'))) return 'dog_core';
    return null;
  }

  Future<void> _setChip(bool value) async {
    try {
      await FirebaseFirestore.instance.collection('pets').doc(widget.petId)
          .update({'microchipped': value, 'updatedAt': FieldValue.serverTimestamp()});
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('晶片狀態更新失敗：$error')));
    }
  }

  Future<void> _setNeutered(bool value) async {
    try {
      await FirebaseFirestore.instance.collection('pets').doc(widget.petId)
          .update({'neutered': value ? '已結紮' : '未結紮',
            'updatedAt': FieldValue.serverTimestamp()});
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('結紮狀態更新失敗：$error')));
    }
  }

  Future<void> _addRecord({bool vaccine = false, String? vaccineKey, String? vaccineName,
      List<(String, String)> vaccineOptions = const [],
      int? doseNumber}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _MedicalEntryForm(
        petId: widget.petId, vaccineOnly: vaccine,
        vaccineOptions: vaccineOptions, vaccineKey: vaccineKey,
        vaccineName: vaccineName, initialDose: doseNumber),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.petName}的醫療紀錄'),
        backgroundColor: _green, foregroundColor: Colors.white),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('pets').doc(widget.petId).snapshots(),
        builder: (context, petSnapshot) {
          if (petSnapshot.hasError) return Center(child: Text('寵物資料讀取失敗：${petSnapshot.error}'));
          if (!petSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          final pet = petSnapshot.data!.data();
          if (pet == null) return const Center(child: Text('找不到寵物資料'));
          final species = '${pet['species'] ?? ''}';
          final suggested = _vaccines(species);
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('health_records')
                .where('petId', isEqualTo: widget.petId).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('醫療紀錄讀取失敗：${snapshot.error}'));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final medical = snapshot.data!.docs.where((doc) =>
                  ['medical', 'vaccine'].contains(HealthInsights.type(doc.data()))).toList()
                ..sort((a, b) => HealthInsights.date(b.data())
                    .compareTo(HealthInsights.date(a.data())));
              final vaccines = medical.where((doc) =>
                  HealthInsights.type(doc.data()) == 'vaccine').toList();
              final visits = medical.where((doc) =>
                  HealthInsights.type(doc.data()) == 'medical').toList();
              return ListView(padding: const EdgeInsets.all(16), children: [
                Text('依寵物種類顯示：${species.isEmpty ? '種類未設定' : species}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text('基本醫療狀態', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
                SwitchListTile(
                  title: const Text('已結紮'),
                  subtitle: Text('目前：${pet['neutered'] ?? '未知'} · 由飼主自行更新'),
                  value: pet['neutered'] == '已結紮',
                  onChanged: _setNeutered,
                ),
                SwitchListTile(
                  title: const Text('晶片已植入'),
                  subtitle: const Text('晶片是身分識別，不是疫苗；由飼主自行更新狀態'),
                  value: pet['microchipped'] == true,
                  onChanged: _setChip,
                ),
                const SizedBox(height: 14),
                const Text('接種表依已儲存紀錄標示；「未記錄」不代表尚未施打。劑次和下次接種日期請依獸醫及疫苗手冊確認。'),
                const SizedBox(height: 16),
                const Text('疫苗接種表', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
                Card(child: ListTile(
                  leading: const Icon(Icons.add_circle_outline, color: _green),
                  title: const Text('新增疫苗接種'),
                  subtitle: const Text('從選項挑選；找不到時選「其他疫苗，自行輸入」'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _addRecord(vaccine: true, vaccineOptions: suggested),
                )),
                if (suggested.isEmpty) const Card(child: ListTile(
                  title: Text('此種類沒有預設疫苗表'), subtitle: Text('可使用上方入口自行輸入疫苗名稱'))),
                for (final item in suggested)
                  Builder(builder: (context) {
                    final entries = vaccines.where((doc) =>
                        _legacyKey(doc.data(), species) == item.$1).toList();
                    final doses = entries.map((doc) => doc.data()['doseNumber'])
                        .whereType<num>().map((v) => v.toInt()).toSet().toList()..sort();
                    final nextDose = doses.isEmpty ? 1 : doses.last + 1;
                    return Card(child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(item.$2, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(entries.isEmpty ? '未記錄接種' : '共 ${entries.length} 筆接種紀錄'),
                        Wrap(spacing: 6, children: [
                          for (final dose in doses)
                            ActionChip(
                              avatar: const Icon(Icons.check_box, color: _green, size: 19),
                              label: Text('第 $dose 劑'),
                              onPressed: () {
                                final record = entries.firstWhere((doc) =>
                                    doc.data()['doseNumber'] == dose);
                                Navigator.push(context, MaterialPageRoute(builder: (_) =>
                                    RecordDetailPage(reference: record.reference,
                                        petId: widget.petId)));
                              },
                            ),
                          ActionChip(
                            avatar: const Icon(Icons.add, color: _green, size: 19),
                            label: const Text('新增接種紀錄'),
                            onPressed: () => _addRecord(vaccine: true,
                                vaccineOptions: suggested, vaccineKey: item.$1,
                                vaccineName: item.$2,
                                doseNumber: nextDose <= 8 ? nextDose : 1)),
                        ]),
                        if (entries.isNotEmpty && doses.isEmpty)
                          const Text('舊紀錄未填劑次，可點下方歷史紀錄補填'),
                      ]),
                    ));
                  }),
                const SizedBox(height: 16),
                const Text('疫苗接種歷史',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
                if (vaccines.isEmpty) const ListTile(title: Text('尚無疫苗接種紀錄')),
                for (final doc in vaccines)
                  _historyTile(doc, Icons.vaccines),
                const SizedBox(height: 22),
                const Text('其他看診與醫療紀錄',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                FilledButton.icon(onPressed: () => _addRecord(),
                  icon: const Icon(Icons.add), label: const Text('新增看診／醫療紀錄'),
                  style: FilledButton.styleFrom(backgroundColor: _green)),
                if (visits.isEmpty) const ListTile(title: Text('尚無其他醫療紀錄')),
                for (final doc in visits)
                  _historyTile(doc, Icons.medical_services),
              ]);
            },
          );
        },
      ),
    );
  }

  Widget _historyTile(QueryDocumentSnapshot<Map<String, dynamic>> doc,
      IconData icon) {
    final date = HealthInsights.date(doc.data());
    return ListTile(
      leading: Icon(icon, color: _green),
      title: Text(RecordPresentation.title(doc.data())),
      subtitle: Text('${date.year}/${date.month}/${date.day} · '
          '${RecordPresentation.subtitle(doc.data())}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => RecordDetailPage(reference: doc.reference,
            petId: widget.petId))),
    );
  }
}

class _MedicalEntryForm extends StatefulWidget {
  const _MedicalEntryForm({required this.petId, required this.vaccineOnly,
      required this.vaccineOptions, this.vaccineKey,
      this.vaccineName, this.initialDose});
  final String petId;
  final bool vaccineOnly;
  final List<(String, String)> vaccineOptions;
  final String? vaccineKey;
  final String? vaccineName;
  final int? initialDose;

  @override
  State<_MedicalEntryForm> createState() => _MedicalEntryFormState();
}

class _MedicalEntryFormState extends State<_MedicalEntryForm> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _clinic = TextEditingController();
  final _doctor = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  DateTime? _nextDate;
  String _type = '看診';
  String? _selectedVaccineKey;
  int _dose = 1;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedVaccineKey = widget.vaccineKey;
    _title.text = widget.vaccineName ?? '';
    _dose = widget.initialDose ?? 1;
  }

  @override
  void dispose() {
    _title.dispose(); _clinic.dispose(); _doctor.dispose(); _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool next}) async {
    final date = await showDatePicker(context: context,
      initialDate: next ? (_nextDate ?? DateTime.now()) : _date,
      firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 3650)));
    if (date != null) setState(() { if (next) { _nextDate = date; } else { _date = date; } });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final vaccine = widget.vaccineOnly;
      final record = FirebaseFirestore.instance.collection('health_records').doc();
      final data = <String, dynamic>{
        'petId': widget.petId,
        'recordType': vaccine ? 'vaccine' : 'medical',
        'type': vaccine ? '疫苗' : _type,
        'title': _title.text.trim(),
        if (vaccine) 'vaccineName': _title.text.trim(),
        if (vaccine) 'vaccineKey': _selectedVaccineKey,
        if (vaccine) 'doseNumber': _dose,
        if (vaccine) 'nextDate': _nextDate == null ? '' :
          '${_nextDate!.year}-${_nextDate!.month.toString().padLeft(2, '0')}-${_nextDate!.day.toString().padLeft(2, '0')}',
        'clinic': _clinic.text.trim(), 'doctor': _doctor.text.trim(),
        'note': _note.text.trim(), 'recordDate': Timestamp.fromDate(_date),
        'owner_uid': FirebaseAuth.instance.currentUser?.uid,
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (_type == '結紮' && !vaccine) {
        final batch = FirebaseFirestore.instance.batch();
        batch.set(record, data);
        batch.update(FirebaseFirestore.instance.collection('pets').doc(widget.petId),
            {'neutered': '已結紮', 'updatedAt': FieldValue.serverTimestamp()});
        await batch.commit();
      } else {
        await record.set(data);
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('儲存失敗：$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(child: Form(key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(widget.vaccineOnly ? '新增疫苗接種紀錄' : '新增看診／醫療紀錄',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (widget.vaccineOnly) ...[
            DropdownButtonFormField<String>(
              value: _selectedVaccineKey, isExpanded: true,
              decoration: const InputDecoration(labelText: '選擇接種疫苗'),
              items: [
                ...widget.vaccineOptions.map((option) => DropdownMenuItem(
                  value: option.$1, child: Text(option.$2,
                    overflow: TextOverflow.ellipsis))),
                const DropdownMenuItem(value: 'custom',
                  child: Text('其他疫苗，自行輸入名稱')),
              ],
              validator: (value) => value == null ? '請選擇疫苗' : null,
              onChanged: (value) {
                setState(() {
                  _selectedVaccineKey = value;
                  _title.text = value == null || value == 'custom' ? '' : widget.vaccineOptions
                      .firstWhere((option) => option.$1 == value).$2;
                });
              },
            ),
            if (_selectedVaccineKey == 'custom')
              TextFormField(controller: _title,
                decoration: const InputDecoration(labelText: '自行輸入疫苗名稱'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? '請輸入疫苗名稱' : null),
            if (_selectedVaccineKey != null && _selectedVaccineKey != 'custom')
              Padding(padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('已選：${_title.text}')),
          ] else ...[
            DropdownButtonFormField<String>(value: _type,
              decoration: const InputDecoration(labelText: '醫療類型'),
              items: ['看診', '驅蟲', '結紮', '其他']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() {
                _type = v ?? '看診';
                if (_type == '結紮' && _title.text.trim().isEmpty) _title.text = '結紮';
              })),
            TextFormField(controller: _title,
              decoration: const InputDecoration(labelText: '醫療項目'),
              validator: (v) => v == null || v.trim().isEmpty ? '請輸入項目名稱' : null),
          ],
          if (widget.vaccineOnly) DropdownButtonFormField<int>(value: _dose,
            decoration: const InputDecoration(labelText: '本次是第幾劑'),
            items: List.generate(8, (i) => DropdownMenuItem(
                value: i + 1, child: Text('第 ${i + 1} 劑'))),
            onChanged: (v) => setState(() => _dose = v ?? 1)),
          TextFormField(controller: _clinic,
            decoration: const InputDecoration(labelText: '醫院（選填）')),
          TextFormField(controller: _doctor,
            decoration: const InputDecoration(labelText: '醫師（選填）')),
          ListTile(title: Text('本次日期：${_date.year}/${_date.month}/${_date.day}'),
            trailing: const Icon(Icons.calendar_month), onTap: () => _pickDate(next: false)),
          if (widget.vaccineOnly) ListTile(
            title: Text(_nextDate == null ? '下次日期（選填）' :
                '下次日期：${_nextDate!.year}/${_nextDate!.month}/${_nextDate!.day}'),
            trailing: const Icon(Icons.calendar_month), onTap: () => _pickDate(next: true)),
          TextFormField(controller: _note,
            decoration: const InputDecoration(labelText: '備註（選填）'), maxLines: 2),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '儲存中…' : '儲存紀錄'))),
        ]),
      )),
    );
  }
}
