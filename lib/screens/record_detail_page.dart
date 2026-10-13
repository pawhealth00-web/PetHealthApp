import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'health_insights.dart';

class RecordDetailPage extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> reference;
  final String petId;
  const RecordDetailPage({super.key, required this.reference, required this.petId});

  @override
  State<RecordDetailPage> createState() => _RecordDetailPageState();
}

class _RecordDetailPageState extends State<RecordDetailPage> {
  static const _green = Color(0xFF2E7D5B);
  bool _editing = false;
  bool _saving = false;
  DateTime? _date;
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _flags = {};
  final Map<String, String> _choices = {};
  final Set<String> _behaviors = {};

  static const _labels = <String, String>{
    'mealType': '餐別', 'brand': '品牌', 'foodName': '食品名稱',
    'amount': '份量', 'unit': '單位', 'supplement': '補充品',
    'appetite': '食慾', 'waterStatus': '飲水狀況',
    'finishedRatio': '吃完比例 (%)', 'changedFood': '更換食品',
    'vomited': '嘔吐', 'count': '排便次數', 'frequency': '排便頻率',
    'shape': '形狀', 'color': '顏色', 'consistency': '軟硬程度',
    'mood': '心情', 'activity_level': '活動量 (1–5)',
    'sleep_status': '睡眠', 'appetite_change': '食慾變化',
    'abnormal_behaviors': '異常行為', 'vaccineName': '疫苗名稱',
    'nextDate': '下次施打日期', 'title': '醫療項目', 'clinic': '醫院',
    'doctor': '醫師', 'doseNumber': '第幾劑', 'note': '備註', 'notes': '備註',
  };
  static const _fields = <String, List<String>>{
    'diet': ['mealType', 'brand', 'foodName', 'amount', 'unit',
      'supplement', 'appetite', 'waterStatus', 'finishedRatio',
      'changedFood', 'vomited', 'note'],
    'poop': ['count', 'frequency', 'shape', 'color', 'consistency', 'note'],
    'behavior': ['mood', 'activity_level', 'sleep_status',
      'appetite_change', 'abnormal_behaviors', 'notes'],
    'vaccine': ['vaccineName', 'doseNumber', 'clinic', 'doctor', 'nextDate', 'note'],
    'medical': ['title', 'clinic', 'doctor', 'note'],
  };
  static const _options = <String, List<String>>{
    'mealType': ['正餐', '點心', '其他'],
    'appetite': ['正常', '不佳', '增加'],
    'waterStatus': ['正常', '不足', '增加'],
    'mood': ['平靜', '興奮', '焦慮', '疲倦', '警覺'],
    'sleep_status': ['良好', '睡眠增加', '睡眠減少', '容易驚醒', '日夜顛倒'],
    'appetite_change': ['正常', '增加', '下降', '拒食'],
    'shape': ['成條', '糊狀', '顆粒', '水狀', '其他'],
    'color': ['深褐色', '淺褐色', '紅色／帶血', '黑色', '灰白色', '其他'],
    'consistency': ['適中', '偏軟', '乾硬'],
  };
  static const _behaviorOptions = ['無異常', '吠叫不止', '亂吃東西',
    '攻擊性', '躲藏', '抽搐', '其他'];

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _startEdit(Map<String, dynamic> data) {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _flags.clear();
    _choices.clear();
    _behaviors.clear();
    final type = HealthInsights.type(data);
    for (final field in _fields[type] ?? ['title', 'note']) {
      final value = data[field];
      if (value is bool) {
        _flags[field] = value;
      } else if (_options.containsKey(field)) {
        _choices[field] = value?.toString() ?? _options[field]!.first;
      } else if (field == 'abnormal_behaviors') {
        _behaviors.addAll((value as List?)?.map((v) => v.toString()) ?? ['無異常']);
      } else {
        _controllers[field] = TextEditingController(text: value?.toString() ?? '');
      }
    }
    // Older records may not contain the newer checkbox fields.
    if (type == 'diet') {
      _flags.putIfAbsent('vomited', () => data['vomited'] == true);
      _flags.putIfAbsent('changedFood', () => data['changedFood'] == true);
    }
    _date = HealthInsights.date(data);
    if (_date!.millisecondsSinceEpoch == 0) _date = DateTime.now();
    setState(() => _editing = true);
  }

  Future<void> _save(Map<String, dynamic> data) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    try {
      final pet = await FirebaseFirestore.instance.collection('pets').doc(widget.petId).get();
      if (pet.data()?['owner_uid'] != uid || data['petId'] != null && data['petId'] != widget.petId) {
        throw StateError('沒有修改這筆紀錄的權限');
      }
      final updates = <String, dynamic>{};
      for (final entry in _controllers.entries) {
        final raw = entry.value.text.trim();
        if (['amount', 'finishedRatio', 'activity_level', 'count', 'doseNumber'].contains(entry.key)) {
          if (raw.isNotEmpty && num.tryParse(raw) == null) throw FormatException('${_labels[entry.key]}請輸入數字');
          updates[entry.key] = raw.isEmpty ? null : num.parse(raw);
        } else {
          updates[entry.key] = raw;
        }
      }
      updates.addAll(_flags);
      updates.addAll(_choices);
      if (HealthInsights.type(data) == 'behavior') {
        updates['abnormal_behaviors'] = _behaviors.isEmpty ? ['無異常'] : _behaviors.toList();
      }
      if (_date != null) {
        final oldDate = HealthInsights.date(data);
        final chosen = DateTime(_date!.year, _date!.month, _date!.day,
            oldDate.hour, oldDate.minute);
        updates[HealthInsights.type(data) == 'behavior' ? 'record_date' : 'recordDate'] =
            Timestamp.fromDate(chosen);
        if (HealthInsights.type(data) == 'behavior') {
          updates['date_key'] = '${_date!.year.toString().padLeft(4, '0')}-${_date!.month.toString().padLeft(2, '0')}-${_date!.day.toString().padLeft(2, '0')}';
        }
      }
      if (HealthInsights.type(data) == 'diet') {
        updates['foodType'] = updates['foodName'];
      }
      if (HealthInsights.type(data) == 'vaccine') {
        updates['title'] = updates['vaccineName'];
      }
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await widget.reference.update(updates);
      if (mounted) setState(() => _editing = false);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('修改失敗：$error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _editor(String field) {
    final label = _labels[field] ?? field;
    if (_flags.containsKey(field)) {
      return SwitchListTile(title: Text(label), value: _flags[field]!,
        onChanged: (value) => setState(() => _flags[field] = value));
    }
    if (_choices.containsKey(field)) {
      final options = {...?_options[field], _choices[field]!}.toList();
      return DropdownButtonFormField<String>(value: _choices[field],
        decoration: InputDecoration(labelText: label),
        items: options.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: (v) { if (v != null) setState(() => _choices[field] = v); });
    }
    if (field == 'abnormal_behaviors') {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label), Wrap(spacing: 6, children: _behaviorOptions.map((item) =>
          FilterChip(label: Text(item), selected: _behaviors.contains(item),
            onSelected: (selected) => setState(() {
              if (item == '無異常') {
                _behaviors..clear()..add(item);
              } else {
                _behaviors.remove('無異常');
                if (selected) { _behaviors.add(item); } else { _behaviors.remove(item); }
              }
            }))).toList())
      ]);
    }
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child:
      TextField(controller: _controllers[field],
        keyboardType: ['amount', 'finishedRatio', 'activity_level', 'count', 'doseNumber'].contains(field)
            ? TextInputType.number : TextInputType.text,
        maxLines: field == 'note' || field == 'notes' ? 3 : 1,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: widget.reference.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Scaffold(body: Center(child: Text('讀取失敗：${snapshot.error}')));
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final data = snapshot.data!.data();
        if (data == null) return const Scaffold(body: Center(child: Text('紀錄已不存在')));
        final type = HealthInsights.type(data);
        final fields = _fields[type] ?? ['title', 'note'];
        return Scaffold(
          appBar: AppBar(title: Text('${{
            'diet':'飲食', 'poop':'排便', 'behavior':'行為',
            'medical':'醫療', 'vaccine':'疫苗'}[type] ?? '健康'}紀錄詳情'),
            backgroundColor: _green, foregroundColor: Colors.white,
            actions: [if (!_editing) IconButton(tooltip: '修改紀錄',
              icon: const Icon(Icons.edit), onPressed: () => _startEdit(data))]),
          body: ListView(padding: const EdgeInsets.all(18), children: [
            ListTile(title: const Text('紀錄日期'), subtitle: Text('${HealthInsights.date(data).year}/${HealthInsights.date(data).month}/${HealthInsights.date(data).day}'),
              trailing: _editing ? const Icon(Icons.edit_calendar) : null,
              onTap: !_editing ? null : () async {
                final chosen = await showDatePicker(context: context,
                  initialDate: _date ?? DateTime.now(), firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 365)));
                if (chosen != null) setState(() => _date = chosen);
              }),
            if (_editing && _date != null) Text('改為 ${_date!.year}/${_date!.month}/${_date!.day}'),
            for (final field in fields)
              if (_editing) _editor(field) else ListTile(
                title: Text(_labels[field] ?? field),
                subtitle: Text(data[field] is List
                    ? (data[field] as List).join('、')
                    : data[field] is bool ? (data[field] == true ? '是' : '否')
                    : (data[field]?.toString().trim().isNotEmpty == true ? data[field].toString() : '未填寫')),
              ),
            if (!_editing && '${data['photoUrl'] ?? ''}'.isNotEmpty)
              Image.network(data['photoUrl'].toString(), height: 210,
                errorBuilder: (_, __, ___) => const Text('照片無法載入')),
            if (!_editing) Card(child: Padding(padding: const EdgeInsets.all(16),
              child: Text('健康提醒：${HealthInsights.reminder(data)}'))),
            if (_editing) Padding(padding: const EdgeInsets.only(top: 16), child:
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: _saving ? null : () => setState(() => _editing = false),
                    child: const Text('取消'))),
                const SizedBox(width: 12),
                Expanded(child: FilledButton(onPressed: _saving ? null : () => _save(data),
                  child: Text(_saving ? '儲存中…' : '儲存修改'))),
              ])),
          ]),
        );
      },
    );
  }
}
