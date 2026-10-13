import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'record_detail_page.dart';
import 'record_presentation.dart';

class DietRecordPage extends StatefulWidget {
  final String petId;
  final String petName;

  const DietRecordPage({
    super.key,
    required this.petId,
    required this.petName,
  });

  @override
  State<DietRecordPage> createState() => _DietRecordPageState();
}

class _DietRecordPageState extends State<DietRecordPage> {
  static const Color _green = Color(0xFF1F5B46);
  static const Color _buttonGreen = Color(0xFF2F765A);
  static const Color _border = Color(0xFFE1EBE6);
  static const Color _hint = Color(0xFFA5B8B0);

  final _brandController = TextEditingController();
  final _foodNameController = TextEditingController();
  final _amountController = TextEditingController();
  final _supplementController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime _recordDate = DateTime.now();
  TimeOfDay _mealTime = TimeOfDay.now();
  String _mealType = '正餐';
  String _unit = '公克 (g)';
  String _appetite = '正常';
  String _waterStatus = '正常';
  double _finishedRatio = 75;
  bool _changedFood = false;
  bool _vomited = false;
  bool _isSaving = false;
  String? _aiAnalysis;

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _recordDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected != null) setState(() => _recordDate = selected);
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _mealTime,
    );
    if (selected != null) setState(() => _mealTime = selected);
  }

  String get _dateText =>
      '${_recordDate.year}-${_recordDate.month.toString().padLeft(2, '0')}-${_recordDate.day.toString().padLeft(2, '0')}';

  String _makeLocalAnalysis() {
    final warnings = <String>[];
    if (_appetite == '不佳') warnings.add('食慾不佳');
    if (_waterStatus == '不足') warnings.add('飲水量不足');
    if (_finishedRatio < 40) warnings.add('進食完成比例偏低');
    if (_changedFood) warnings.add('本次有更換食物');
    if (_vomited) warnings.add('進食後出現嘔吐');

    if (warnings.isEmpty) {
      return '根據本次紀錄，${widget.petName}的進食與飲水狀況大致正常。建議持續維持固定餵食時間，並觀察食慾與精神狀態。';
    }
    return '根據本次紀錄，發現${warnings.join('、')}。建議先補充飲水並持續觀察；若嘔吐、拒食或精神不佳持續超過 24 小時，請諮詢獸醫。';
  }

  Future<void> _saveRecord() async {
    final rawAmount = _amountController.text.trim();
    final amount = rawAmount.isEmpty ? null : double.tryParse(rawAmount);
    if (rawAmount.isNotEmpty && (amount == null || amount <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('若填寫份量，請輸入大於 0 的數字')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final recordDateTime = DateTime(
        _recordDate.year,
        _recordDate.month,
        _recordDate.day,
        _mealTime.hour,
        _mealTime.minute,
      );

      await FirebaseFirestore.instance.collection('health_records').add({
        'petId': widget.petId,
        'petName': widget.petName,
        'recordType': 'diet',
        // 保留舊欄位，避免健康存摺原本的讀取程式失效。
        'foodType': _foodNameController.text.trim(),
        'amount': amount,
        'unit': _unit,
        'note': _noteController.text.trim(),
        // 新版飲食紀錄欄位。
        'recordDate': Timestamp.fromDate(recordDateTime),
        'mealType': _mealType,
        'brand': _brandController.text.trim(),
        'foodName': _foodNameController.text.trim(),
        'supplement': _supplementController.text.trim(),
        'appetite': _appetite,
        'waterStatus': _waterStatus,
        'finishedRatio': _finishedRatio.round(),
        'changedFood': _changedFood,
        'vomited': _vomited,
        'createdAt': FieldValue.serverTimestamp(),
        'owner_uid': FirebaseAuth.instance.currentUser?.uid,
      });

      if (!mounted) return;
      setState(() => _aiAnalysis = _makeLocalAnalysis());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('飲食紀錄儲存成功')),
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

  void _showHistory() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .68,
        child: Column(
          children: [
            const Text('飲食紀錄歷史',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _green)),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('health_records')
                    .where('petId', isEqualTo: widget.petId)
                    .where('recordType', isEqualTo: 'diet')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('讀取紀錄失敗'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs.toList()
                    ..sort((a, b) {
                      final aDate = (a.data()['recordDate'] ?? a.data()['createdAt']) as Timestamp?;
                      final bDate = (b.data()['recordDate'] ?? b.data()['createdAt']) as Timestamp?;
                      return (bDate?.millisecondsSinceEpoch ?? 0)
                          .compareTo(aDate?.millisecondsSinceEpoch ?? 0);
                    });
                  if (docs.isEmpty) return const Center(child: Text('目前沒有飲食紀錄'));
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final doc = docs[index];
                      final data = doc.data();
                      final timestamp = (data['recordDate'] ?? data['createdAt']) as Timestamp?;
                      final date = timestamp?.toDate();
                      final dateText = date == null
                          ? '日期未記錄'
                          : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                      return ListTile(
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => RecordDetailPage(reference: doc.reference,
                            petId: widget.petId))),
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFEAF4EC),
                          child: Icon(Icons.restaurant, color: _green),
                        ),
                        title: Text(RecordPresentation.title(data)),
                        subtitle: Text('$dateText ・ ${RecordPresentation.subtitle(data)}'),
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
  void dispose() {
    _brandController.dispose();
    _foodNameController.dispose();
    _amountController.dispose();
    _supplementController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('飲食紀錄',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _green)),
            ),
            IconButton(
              tooltip: '歷史紀錄',
              onPressed: _showHistory,
              icon: const Icon(Icons.history, color: _green, size: 30),
            ),
          ],
        ),
        const SizedBox(height: 28),
        _label('紀錄日期'),
        _tapField(_dateText, Icons.calendar_month_outlined, _pickDate),
        const SizedBox(height: 24),
        _label('進食時間'),
        _tapField(_mealTime.format(context), Icons.keyboard_arrow_down, _pickTime),
        const SizedBox(height: 24),
        Center(
          child: SizedBox(
            width: 300,
            child: _dropDown(
              label: '餐點類型',
              value: _mealType,
              items: const ['早餐', '正餐', '點心', '宵夜'],
              onChanged: (value) => setState(() => _mealType = value!),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _input('食物品牌', _brandController, '例如：皇家')),
            const SizedBox(width: 16),
            Expanded(child: _input('食物名稱', _foodNameController, '例如：犬糧A')),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _input('份量', _amountController, '0',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _dropDown(
                label: '單位',
                value: _unit,
                items: const ['公克 (g)', '毫升 (ml)', '罐', '包', '份'],
                onChanged: (value) => setState(() => _unit = value!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _input('補充品', _supplementController, '例如：魚油、化毛膏'),
        const SizedBox(height: 28),
        _label('食慾與飲水'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _dropDown(
                label: '食慾',
                value: _appetite,
                items: const ['良好', '正常', '不佳'],
                onChanged: (value) => setState(() => _appetite = value!),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _dropDown(
                label: '飲水狀況',
                value: _waterStatus,
                items: const ['充足', '正常', '不足'],
                onChanged: (value) => setState(() => _waterStatus = value!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        _label('吃完比例'),
        Container(
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
          decoration: _cardDecoration(),
          child: Column(
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: _buttonGreen,
                  inactiveTrackColor: _border,
                  thumbColor: _buttonGreen,
                  overlayColor: _buttonGreen.withOpacity(.12),
                  trackHeight: 6,
                ),
                child: Slider(
                  value: _finishedRatio,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  label: '${_finishedRatio.round()}%',
                  onChanged: (value) => setState(() => _finishedRatio = value),
                ),
              ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text('幾乎沒吃', style: TextStyle(color: _green)), Text('全部吃完', style: TextStyle(color: _green))],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _switchCard('是否更換食物', '本次飲食與上次品牌或類型不同', _changedFood,
                (value) => setState(() => _changedFood = value)),
        const SizedBox(height: 20),
        _switchCard('是否有嘔吐', '進食後是否有異常', _vomited,
                (value) => setState(() => _vomited = value)),
        const SizedBox(height: 28),
        _input('補充說明', _noteController, '記錄任何關於飲食的細節...', maxLines: 3),
        const SizedBox(height: 28),
        SizedBox(
          height: 62,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveRecord,
            style: ElevatedButton.styleFrom(
              backgroundColor: _buttonGreen,
              disabledBackgroundColor: _buttonGreen.withOpacity(.55),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
            child: _isSaving
                ? const SizedBox(width: 25, height: 25, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                : const Text('儲存紀錄', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          ),
        ),
        if (_aiAnalysis != null) ...[
          const SizedBox(height: 36),
          Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F8E9),
              border: Border.all(color: const Color(0xFFD2E8B9)),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: _buttonGreen,
                      foregroundColor: Colors.white,
                      child: Icon(Icons.auto_awesome),
                    ),
                    SizedBox(width: 12),
                    Text('AI 營養分析', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: _buttonGreen)),
                  ],
                ),
                const SizedBox(height: 20),
                Text(_aiAnalysis!, style: const TextStyle(fontSize: 16, height: 1.75, color: _green)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _green)),
  );

  Widget _tapField(String text, IconData icon, VoidCallback onTap) => InkWell(
    borderRadius: BorderRadius.circular(28),
    onTap: onTap,
    child: Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: _fieldDecoration(28),
      child: Row(
        children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 18, color: _green))),
          Icon(icon, color: _buttonGreen),
        ],
      ),
    ),
  );

  Widget _input(String label, TextEditingController controller, String hint,
      {TextInputType? keyboardType, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        TextField(
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
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _buttonGreen, width: 1.8)),
          ),
        ),
      ],
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
        _label(label),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: _buttonGreen),
          items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: const BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: const BorderSide(color: _buttonGreen, width: 1.8)),
          ),
        ),
      ],
    );
  }

  Widget _switchCard(String title, String subtitle, bool value, ValueChanged<bool> onChanged) => Container(
    padding: const EdgeInsets.fromLTRB(20, 22, 12, 22),
    decoration: _cardDecoration(),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, color: _green)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 13, color: _buttonGreen)),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged, activeColor: Colors.white, activeTrackColor: _buttonGreen, inactiveTrackColor: _border),
      ],
    ),
  );

  BoxDecoration _fieldDecoration(double radius) => BoxDecoration(
    color: Colors.white,
    border: Border.all(color: _border),
    borderRadius: BorderRadius.circular(radius),
  );

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    border: Border.all(color: _border),
    borderRadius: BorderRadius.circular(28),
  );
}
