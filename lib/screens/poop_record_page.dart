import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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

  final _countController = TextEditingController();
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
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photoBytes = bytes;
        _photoName = image.name;
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
    await ref.putData(_photoBytes!, metadata);
    return ref.getDownloadURL();
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
    final count = int.tryParse(_countController.text.trim());
    if (count == null || count <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入正確的排便次數')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final photoUrl = await _uploadPhoto();
      await FirebaseFirestore.instance.collection('health_records').add({
        'petId': widget.petId,
        'petName': widget.petName,
        'recordType': 'poop',
        // 保留舊版欄位名稱，健康存摺仍可讀取。
        'shape': _shape,
        'color': _color,
        'note': _noteController.text.trim(),
        // 新版欄位。
        'recordDate': Timestamp.fromDate(_recordDate),
        'count': count,
        'frequency': _frequency,
        'consistency': _consistency,
        'photoUrl': photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() => _aiAnalysis = _makeLocalAnalysis());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('排便紀錄儲存成功')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('儲存失敗：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _countController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '排便紀錄',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: _green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        _sectionTitle(Icons.event_note_rounded, '基本資訊'),
        const SizedBox(height: 16),
        _dateField(),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _textInput(
                controller: _countController,
                hint: '例如：1',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _dropDown(
                label: '排便頻率',
                value: _frequency,
                items: const ['每日多次', '每日一次', '兩日一次', '三日以上一次'],
                onChanged: (value) => setState(() => _frequency = value!),
              ),
            ),
          ],
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
        SizedBox(
          height: 62,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveRecord,
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
                : const Text(
              '儲存紀錄',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
        ),
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
