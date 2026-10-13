import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'record_detail_page.dart';

class PoopRecordPage extends StatefulWidget {
  final String petId;
  final String petName;

  const PoopRecordPage({
    super.key,
    required this.petId,
    required this.petName,
  });

  @override
  State<PoopRecordPage> createState() => _PoopRecordPageState();
}

class _PoopRecordPageState extends State<PoopRecordPage> {
  static const Color _green = Color(0xFF1F5B46);
  static const Color _buttonGreen = Color(0xFF2F765A);
  static const Color _lightGreen = Color(0xFFEAF4EC);
  static const Color _border = Color(0xFFE1EBE6);
  static const Color _hint = Color(0xFFA5B8B0);

  final _noteController = TextEditingController();
  final _picker = ImagePicker();

  DateTime _recordDate = DateTime.now();
  String _frequency = '每日一次';
  String _shape = '成條';
  String _color = '深褐色';
  String _consistency = '適中';
  Uint8List? _photoBytes;
  String? _photoName;
  bool _isSaving = false;
  bool _photoUploaded = false;
  DocumentReference<Map<String, dynamic>>? _savedRecord;
  String? _saveStatus;
  double? _uploadProgress;
  String? _aiAnalysis;

  String get _dateText =>
      '${_recordDate.year}-${_recordDate.month.toString().padLeft(2, '0')}-${_recordDate.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _recordDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected != null) setState(() => _recordDate = selected);
  }

  Future<void> _pickPhoto() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 65,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes().timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (bytes.lengthInBytes > 2 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('照片超過 2 MB，請選擇較小的照片')));
        return;
      }
      setState(() {
        _photoBytes = bytes;
        _photoName = image.name;
        _photoUploaded = false;
        _uploadProgress = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('照片選擇失敗：$e')),
        );
      }
    }
  }

  Future<String?> _uploadPhoto() async {
    if (_photoBytes == null) return null;
    final extension = (_photoName ?? '').toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    final ref = FirebaseStorage.instance.ref().child(
      'poop_records/${widget.petId}/${DateTime.now().millisecondsSinceEpoch}.$extension',
    );
    final metadata = SettableMetadata(
      contentType: extension == 'png' ? 'image/png' : 'image/jpeg',
    );
    final task = ref.putData(_photoBytes!, metadata);
    final subscription = task.snapshotEvents.listen((snapshot) {
      if (!mounted || snapshot.totalBytes == 0) return;
      setState(() => _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes);
    });
    try {
      await task.timeout(const Duration(seconds: 25));
      return await ref.getDownloadURL().timeout(const Duration(seconds: 10));
    } catch (_) {
      unawaited(task.cancel().then((_) {}).catchError((Object _) {}));
      rethrow;
    } finally {
      await subscription.cancel();
    }
  }

  String _makeLocalAnalysis() {
    final warning = <String>[];
    if (_shape == '糊狀') warning.add('糞便呈糊狀');
    if (_consistency == '乾硬') warning.add('糞便偏乾硬');
    if (_consistency == '偏軟') warning.add('糞便偏軟');
    if (_color == '紅色／帶血') warning.add('糞便可能帶血');
    if (_color == '黑色') warning.add('糞便顏色偏黑');
    if (_color == '灰白色') warning.add('糞便顏色偏灰白');

    if (warning.isEmpty) {
      return '根據紀錄，${widget.petName}的糞便形狀、顏色與軟硬程度目前在一般範圍。建議持續觀察排便頻率並維持充足飲水。';
    }
    if (_color == '紅色／帶血' || _color == '黑色') {
      return '本次紀錄顯示${warning.join('、')}。請保留照片並密切觀察；若持續出現、排便困難、嘔吐或精神不佳，建議儘快諮詢獸醫。';
    }
    return '本次紀錄顯示${warning.join('、')}。建議補充飲水、避免突然更換食物並觀察 24 小時；若情況持續或惡化，請諮詢獸醫。';
  }

  Future<void> _saveRecord() async {
    setState(() {
      _isSaving = true;
      _saveStatus = _savedRecord == null ? '正在儲存紀錄…' : '正在重試上傳照片…';
      _uploadProgress = null;
    });
    try {
      if (_savedRecord == null) {
        final record = await FirebaseFirestore.instance.collection('health_records').add({
        'petId': widget.petId,
        'petName': widget.petName,
        'recordType': 'poop',
        // 保留舊版欄位名稱，健康存摺仍可讀取。
        'shape': _shape,
        'color': _color,
        'note': _noteController.text.trim(),
        // 新版欄位。
        'recordDate': Timestamp.fromDate(_recordDate),
        'frequency': _frequency,
        'consistency': _consistency,
        'createdAt': FieldValue.serverTimestamp(),
        'owner_uid': FirebaseAuth.instance.currentUser?.uid,
        });
        _savedRecord = record;
      }

      if (!mounted) return;
      setState(() => _aiAnalysis = _makeLocalAnalysis());
      if (_photoBytes != null && !_photoUploaded) {
        setState(() => _saveStatus = '紀錄已儲存，照片上傳中…');
        try {
          final photoUrl = await _uploadPhoto();
          if (photoUrl != null) await _savedRecord!.update({'photoUrl': photoUrl});
          _photoUploaded = true;
        } catch (error) {
          if (!mounted) return;
          final reason = error is TimeoutException ? '連線逾時' :
              error is FirebaseException ? (error.message ?? error.code) : '$error';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            duration: const Duration(seconds: 8),
            content: Text('文字紀錄已儲存，照片未上傳（$reason）。請檢查網路或 Firebase Storage 權限，再按「重試照片上傳」。'),
          ));
          return;
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_photoBytes == null ? '排便紀錄儲存成功' : '排便紀錄與照片儲存成功')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_savedRecord == null ? '儲存失敗：$e' : '文字紀錄已儲存，但照片連結更新失敗：$e')),
        );
      }
    } finally {
      if (mounted) setState(() { _isSaving = false; _saveStatus = null; });
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _showHistory() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * .68,
        child: Column(children: [
          const Text('排便紀錄歷史',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _green)),
          const SizedBox(height: 12),
          Expanded(child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('health_records')
                .where('petId', isEqualTo: widget.petId)
                .where('recordType', isEqualTo: 'poop').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text('讀取紀錄失敗'));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs.toList()..sort((a, b) {
                final aTime = (a.data()['recordDate'] ?? a.data()['createdAt']) as Timestamp?;
                final bTime = (b.data()['recordDate'] ?? b.data()['createdAt']) as Timestamp?;
                return (bTime?.millisecondsSinceEpoch ?? 0)
                    .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
              });
              if (docs.isEmpty) return const Center(child: Text('目前沒有排便紀錄'));
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data();
                  final timestamp = (data['recordDate'] ?? data['createdAt']) as Timestamp?;
                  final date = timestamp?.toDate();
                  final dateText = date == null ? '日期未記錄' :
                      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                  return ListTile(
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => RecordDetailPage(reference: doc.reference,
                          petId: widget.petId))),
                    leading: const CircleAvatar(backgroundColor: _lightGreen,
                        child: Icon(Icons.pets, color: _green)),
                    title: Text(dateText),
                    subtitle: Text('${data['frequency'] ?? '未填頻率'} ・ ${data['shape'] ?? '未填形狀'} ・ ${data['color'] ?? '未填顏色'}'),
                    trailing: const Icon(Icons.chevron_right),
                  );
                },
              );
            },
          )),
        ]),
      ),
    );
  }

  void _startNewRecord() {
    _noteController.clear();
    setState(() {
      _recordDate = DateTime.now();
      _frequency = '每日一次';
      _shape = '成條';
      _color = '深褐色';
      _consistency = '適中';
      _photoBytes = null;
      _photoName = null;
      _photoUploaded = false;
      _uploadProgress = null;
      _savedRecord = null;
      _aiAnalysis = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      children: [
        Row(
          children: [
            const Expanded(child: Text(
              '排便紀錄', textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: _green,
              ),
            )),
            IconButton(
              tooltip: '歷史紀錄',
              onPressed: _showHistory,
              icon: const Icon(Icons.history, color: _green, size: 30),
            ),
          ],
        ),
        const SizedBox(height: 28),
        _sectionTitle(Icons.event_note_rounded, '基本資訊'),
        const SizedBox(height: 16),
        _dateField(),
        const SizedBox(height: 24),
        _dropDown(
          label: '排便頻率',
          value: _frequency,
          items: const ['每日多次', '每日一次', '兩日一次', '三日以上一次'],
          onChanged: (value) => setState(() => _frequency = value!),
        ),
        const SizedBox(height: 34),
        _sectionTitle(Icons.visibility_rounded, '糞便特徵'),
        const SizedBox(height: 20),
        _fieldLabel('糞便形狀'),
        _choiceRow(
          values: const ['成條', '圓形', '糊狀'],
          selected: _shape,
          onSelected: (value) => setState(() => _shape = value),
        ),
        const SizedBox(height: 22),
        _dropDown(
          label: '糞便顏色',
          value: _color,
          items: const ['深褐色', '淺褐色', '黃色', '綠色', '黑色', '灰白色', '紅色／帶血'],
          onChanged: (value) => setState(() => _color = value!),
        ),
        const SizedBox(height: 22),
        _fieldLabel('軟硬程度'),
        _choiceRow(
          values: const ['乾硬', '適中', '偏軟'],
          selected: _consistency,
          onSelected: (value) => setState(() => _consistency = value),
        ),
        const SizedBox(height: 34),
        _sectionTitle(Icons.add_a_photo_rounded, '補充資料'),
        const SizedBox(height: 18),
        _photoPicker(),
        const SizedBox(height: 22),
        _textInput(
          controller: _noteController,
          hint: '輸入關於排便的補充說明...',
          maxLines: 3,
        ),
        if (_aiAnalysis != null) ...[
          const SizedBox(height: 30),
          _analysisCard(),
        ],
        const SizedBox(height: 34),
        if (_saveStatus != null) ...[
          Text(_saveStatus!, textAlign: TextAlign.center,
              style: const TextStyle(color: _green)),
          if (_uploadProgress != null) LinearProgressIndicator(value: _uploadProgress),
          const SizedBox(height: 12),
        ],
        SizedBox(
          height: 62,
          child: ElevatedButton(
            onPressed: _isSaving || (_savedRecord != null &&
                (_photoBytes == null || _photoUploaded)) ? null : _saveRecord,
            style: ElevatedButton.styleFrom(
              backgroundColor: _buttonGreen,
              disabledBackgroundColor: _buttonGreen.withOpacity(.55),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
              width: 25,
              height: 25,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            )
                : Text(
              _savedRecord == null ? '儲存紀錄' :
                  _photoUploaded || _photoBytes == null ? '已儲存' : '重試照片上傳',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        if (_savedRecord != null) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _isSaving ? null : _startNewRecord,
            icon: const Icon(Icons.add),
            label: const Text('新增下一筆紀錄'),
          ),
        ],
      ],
    );
  }

  Widget _sectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: _buttonGreen, size: 26),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: _green,
          ),
        ),
      ],
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: _buttonGreen,
        ),
      ),
    );
  }

  Widget _dateField() {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: _fieldDecoration(12),
        child: Row(
          children: [
            const Icon(Icons.calendar_month, color: _green),
            const SizedBox(width: 10),
            Text(_dateText, style: const TextStyle(fontSize: 18, color: _green)),
          ],
        ),
      ),
    );
  }

  Widget _textInput({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _hint),
        prefixIcon: const Icon(Icons.edit_note_rounded, color: _green),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _buttonGreen, width: 1.8),
        ),
      ),
    );
  }

  Widget _dropDown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: _buttonGreen),
          items: items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _buttonGreen, width: 1.8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _choiceRow({
    required List<String> values,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return Row(
      children: [
        for (var i = 0; i < values.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () => onSelected(values[i]),
              borderRadius: BorderRadius.circular(18),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected == values[i] ? _lightGreen : Colors.white,
                  border: Border.all(
                    color: selected == values[i] ? _buttonGreen : _border,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  selected == values[i] ? '✓  ${values[i]}' : values[i],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _green,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _photoPicker() {
    return InkWell(
      onTap: _pickPhoto,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: 220,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(28),
        ),
        child: _photoBytes == null
            ? const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_upload_rounded, color: _buttonGreen, size: 48),
            SizedBox(height: 12),
            Text(
              '上傳照片選填',
              style: TextStyle(fontSize: 17, color: _buttonGreen),
            ),
          ],
        )
            : Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(_photoBytes!, fit: BoxFit.cover),
            Positioned(
              right: 10,
              top: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  tooltip: '移除照片',
                  onPressed: () => setState(() {
                    _photoBytes = null;
                    _photoName = null;
                  }),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _analysisCard() {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7F3),
        border: Border.all(color: const Color(0xFFB9DCCB)),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: _buttonGreen, size: 30),
              SizedBox(width: 12),
              Text(
                'AI 分析結果',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: _buttonGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            _aiAnalysis!,
            style: const TextStyle(fontSize: 16, height: 1.75, color: _green),
          ),
        ],
      ),
    );
  }

  BoxDecoration _fieldDecoration(double radius) {
    return BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(radius),
    );
  }
}
