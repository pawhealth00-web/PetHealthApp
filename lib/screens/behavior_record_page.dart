import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'health_insights.dart';
import 'record_detail_page.dart';

class BehaviorRecordPage extends StatefulWidget {
  const BehaviorRecordPage({
    super.key,
    required this.petId,
    required this.petName,
    this.petImageUrl,
    this.petPhotoBase64,
  });

  final String petId;
  final String petName;
  final String? petImageUrl;
  final String? petPhotoBase64;

  @override
  State<BehaviorRecordPage> createState() => _BehaviorRecordPageState();
}

class _BehaviorRecordPageState extends State<BehaviorRecordPage> {
  static const _green = Color(0xFF1F5B46);
  static const _lightGreen = Color(0xFFE7F4E9);
  static const _orange = Color(0xFFF58A5B);
  static const _red = Color(0xFFD93645);

  final _notesController = TextEditingController();

  DateTime _recordDate = DateTime.now();
  String _mood = '平靜';
  double _activityLevel = 3;
  String _sleepStatus = '良好';
  String _appetiteChange = '正常';
  final Set<String> _abnormalBehaviors = {'無異常'};
  bool _saving = false;
  String? _reminder;

  static const _moods = ['平靜', '興奮', '焦慮', '疲倦', '警覺'];
  static const _sleepOptions = ['良好', '睡眠增加', '睡眠減少', '容易驚醒', '日夜顛倒'];
  static const _appetiteOptions = ['正常', '增加', '下降', '拒食'];
  static const _behaviorOptions = [
    '無異常',
    '吠叫不止',
    '亂吃東西',
    '攻擊性',
    '躲藏',
    '抽搐',
    '其他',
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _recordDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: '選擇紀錄日期',
      cancelText: '取消',
      confirmText: '確定',
    );
    if (selected != null) setState(() => _recordDate = selected);
  }

  void _toggleAbnormalBehavior(String value) {
    setState(() {
      if (value == '無異常') {
        _abnormalBehaviors
          ..clear()
          ..add(value);
        return;
      }

      _abnormalBehaviors.remove('無異常');
      if (!_abnormalBehaviors.add(value)) _abnormalBehaviors.remove(value);
      if (_abnormalBehaviors.isEmpty) _abnormalBehaviors.add('無異常');
    });
  }

  Future<void> _saveRecord() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage('登入已失效，請重新登入');
      return;
    }

    setState(() => _saving = true);
    try {
      final dateKey = _dateKey(_recordDate);
      await FirebaseFirestore.instance
          .collection('pets')
          .doc(widget.petId)
          .collection('behavior_records')
          .doc(dateKey)
          .set({
        'owner_uid': user.uid,
        'pet_id': widget.petId,
        'pet_name': widget.petName,
        'record_date': Timestamp.fromDate(DateTime(
          _recordDate.year,
          _recordDate.month,
          _recordDate.day,
        )),
        'date_key': dateKey,
        'mood': _mood,
        'activity_level': _activityLevel.round(),
        'sleep_status': _sleepStatus,
        'appetite_change': _appetiteChange,
        'abnormal_behaviors': _abnormalBehaviors.toList(),
        'notes': _notesController.text.trim(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() => _reminder = HealthInsights.reminder({
        'recordType': 'behavior', 'mood': _mood,
        'activity_level': _activityLevel.round(),
        'sleep_status': _sleepStatus, 'appetite_change': _appetiteChange,
        'abnormal_behaviors': _abnormalBehaviors.toList(),
      }));
      _showMessage('行為紀錄已儲存');
    } on FirebaseException catch (error) {
      if (mounted) _showMessage('儲存失敗：${error.message ?? error.code}');
    } catch (error) {
      if (mounted) _showMessage('儲存失敗：$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showHistory() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .72,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                '行為紀錄歷史',
                style: TextStyle(
                  color: _green,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('pets')
                    .doc(widget.petId)
                    .collection('behavior_records')
                    .orderBy('record_date', descending: true)
                    .limit(30)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('讀取紀錄失敗'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final records = snapshot.data!.docs;
                  if (records.isEmpty) {
                    return const Center(child: Text('目前還沒有行為紀錄'));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                    itemCount: records.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final record = records[index];
                      final data = record.data();
                      final behaviors = (data['abnormal_behaviors'] as List?)
                              ?.map((value) => value.toString())
                              .join('、') ??
                          '無異常';
                      return ListTile(
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => RecordDetailPage(reference: record.reference,
                            petId: widget.petId))),
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
                        leading: const CircleAvatar(
                          backgroundColor: _lightGreen,
                          child: Icon(Icons.pets, color: _green),
                        ),
                        title: Text(
                          data['date_key']?.toString() ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${data['mood'] ?? '-'}・活動量 ${data['activity_level'] ?? '-'}\n$behaviors',
                        ),
                        isThreeLine: true,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _green,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '行為紀錄',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: '歷史紀錄',
            onPressed: _showHistory,
            icon: const Icon(Icons.history),
          ),
          const SizedBox(width: 8),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(2),
          child: Divider(height: 2, thickness: 2, color: _orange),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 36),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PetHeader(
                    petName: widget.petName,
                    petImageUrl: widget.petImageUrl,
                    petPhotoBase64: widget.petPhotoBase64,
                    dateText: _dateKey(_recordDate),
                  ),
                  const SizedBox(height: 24),
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _SectionTitle('紀錄日期'),
                        const SizedBox(height: 18),
                        InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 13,
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_month, color: _green),
                                const SizedBox(width: 8),
                                Text(
                                  _dateKey(_recordDate),
                                  style: const TextStyle(
                                    color: _green,
                                    fontSize: 17,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        const _SectionTitle('整體情緒'),
                        const SizedBox(height: 18),
                        ..._moods.map(
                          (mood) => _ChoiceButton(
                            label: mood,
                            selected: _mood == mood,
                            onTap: () => setState(() => _mood = mood),
                          ),
                        ),
                        const SizedBox(height: 30),
                        const _SectionTitle('活動量 (1–5)'),
                        const SizedBox(height: 20),
                        Slider(
                          value: _activityLevel,
                          min: 1,
                          max: 5,
                          divisions: 4,
                          label: _activityLevel.round().toString(),
                          activeColor: _green,
                          inactiveColor: const Color(0xFFE4EEEA),
                          onChanged: (value) =>
                              setState(() => _activityLevel = value),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [Text('安靜'), Text('活躍')],
                          ),
                        ),
                        const SizedBox(height: 30),
                        const _SectionTitle('睡眠狀況'),
                        const SizedBox(height: 18),
                        _StyledDropdown(
                          value: _sleepStatus,
                          items: _sleepOptions,
                          onChanged: (value) =>
                              setState(() => _sleepStatus = value),
                        ),
                        const SizedBox(height: 30),
                        const _SectionTitle('食慾變化'),
                        const SizedBox(height: 18),
                        _StyledDropdown(
                          value: _appetiteChange,
                          items: _appetiteOptions,
                          onChanged: (value) =>
                              setState(() => _appetiteChange = value),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _SectionTitle('是否有異常行為？'),
                        const SizedBox(height: 20),
                        ..._behaviorOptions.map(
                          (behavior) => _ChoiceButton(
                            label: behavior,
                            selected: _abnormalBehaviors.contains(behavior),
                            alert: behavior != '無異常',
                            onTap: () => _toggleAbnormalBehavior(behavior),
                          ),
                        ),
                        const SizedBox(height: 30),
                        const _SectionTitle('補充說明'),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _notesController,
                          minLines: 3,
                          maxLines: 6,
                          maxLength: 300,
                          decoration: InputDecoration(
                            hintText: '請描述您觀察到的細節…',
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(bottom: 60),
                              child: Icon(Icons.notes, color: _green),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFFDCE9E3)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFFDCE9E3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: _green, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _saving ? null : _saveRecord,
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      disabledBackgroundColor: _green.withValues(alpha: .45),
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _saving ? '儲存中…' : '儲存行為紀錄',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_reminder != null) Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Card(child: Padding(padding: const EdgeInsets.all(16),
                      child: Text('健康提醒：$_reminder'))),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PetHeader extends StatelessWidget {
  const _PetHeader({
    required this.petName,
    required this.petImageUrl,
    required this.petPhotoBase64,
    required this.dateText,
  });

  final String petName;
  final String? petImageUrl;
  final String? petPhotoBase64;
  final String dateText;

  @override
  Widget build(BuildContext context) {
    ImageProvider? petImage;
    if (petImageUrl != null && petImageUrl!.trim().isNotEmpty) {
      petImage = NetworkImage(petImageUrl!);
    } else if (petPhotoBase64 != null && petPhotoBase64!.trim().isNotEmpty) {
      try {
        petImage = MemoryImage(base64Decode(petPhotoBase64!));
      } catch (_) {
        petImage = null;
      }
    }
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: _BehaviorRecordPageState._lightGreen,
            backgroundImage: petImage,
            child: petImage != null
                ? null
                : const Icon(
                    Icons.pets,
                    color: _BehaviorRecordPageState._green,
                    size: 30,
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '紀錄給 $petName',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _BehaviorRecordPageState._green,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateText,
                  style: const TextStyle(
                    color: Color(0xFF4F7B6C),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 26,
          decoration: BoxDecoration(
            color: _BehaviorRecordPageState._green,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: _BehaviorRecordPageState._green,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.alert = false,
  });

  final String label;
  final bool selected;
  final bool alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selectedColor = alert
        ? _BehaviorRecordPageState._red
        : const Color(0xFF2E8B3C);
    final selectedBackground = alert
        ? const Color(0xFFFFE7EA)
        : _BehaviorRecordPageState._lightGreen;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? selectedBackground : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
          side: BorderSide(
            color: selected ? selectedColor.withValues(alpha: .25) : const Color(0xFFDCE9E3),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (selected) ...[
                  Icon(Icons.check, size: 19, color: selectedColor),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected
                          ? selectedColor
                          : _BehaviorRecordPageState._green,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StyledDropdown extends StatelessWidget {
  const _StyledDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      icon: const Icon(Icons.keyboard_arrow_down, color: _BehaviorRecordPageState._green),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDCE9E3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDCE9E3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: _BehaviorRecordPageState._green,
            width: 2,
          ),
        ),
      ),
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}
