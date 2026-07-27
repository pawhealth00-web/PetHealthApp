import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VaccineRecordPage extends StatefulWidget {
  final String petId;
  final String petName;

  const VaccineRecordPage({
    super.key,
    required this.petId,
    required this.petName,
  });

  @override
  State<VaccineRecordPage> createState() => _VaccineRecordPageState();
}

class _VaccineRecordPageState extends State<VaccineRecordPage> {
  final TextEditingController _vaccineNameController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  DateTime? _nextDate;
  bool _isSaving = false;

  // 呼叫內建月曆來選擇日期
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)), // 預設為一年後
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null && picked != _nextDate) {
      setState(() {
        _nextDate = picked;
      });
    }
  }

  // 儲存紀錄到 Firebase
  Future<void> _saveRecord() async {
    if (_vaccineNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ 請輸入疫苗名稱 (例如：狂犬病)')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // 將選好的時間轉換成 YYYY-MM-DD 的字串格式
      String nextDateString = _nextDate != null
          ? "${_nextDate!.year}-${_nextDate!.month.toString().padLeft(2, '0')}-${_nextDate!.day.toString().padLeft(2, '0')}"
          : '';

      await FirebaseFirestore.instance.collection('health_records').add({
        'petId': widget.petId,
        'recordType': 'vaccine', // 標記這是一筆疫苗紀錄
        'vaccineName': _vaccineNameController.text.trim(),
        'nextDate': nextDateString,
        'note': _noteController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 疫苗紀錄新增成功！')),
        );
        Navigator.pop(context); // 儲存完畢後自動回到上一頁
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 儲存失敗：$e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _vaccineNameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('新增 ${widget.petName} 的疫苗紀錄'),
        backgroundColor: Colors.pinkAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // 疫苗名稱輸入框
            TextField(
              controller: _vaccineNameController,
              decoration: const InputDecoration(
                labelText: '疫苗名稱 (必填，如：狂犬病、十合一)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.vaccines, color: Colors.pinkAccent),
              ),
            ),
            const SizedBox(height: 16),

            // 下次施打日期 (點擊跳出月曆)
            ListTile(
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              leading: const Icon(Icons.calendar_month, color: Colors.pinkAccent),
              title: Text(
                _nextDate == null
                    ? '設定下次施打日期 (點此展開月曆)'
                    : '下次補打：${_nextDate!.year}-${_nextDate!.month.toString().padLeft(2, '0')}-${_nextDate!.day.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.edit),
              onTap: () => _selectDate(context),
            ),
            const SizedBox(height: 16),

            // 備註輸入框
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '備註 (選填，如：施打醫院、副作用觀察)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
            ),
            const SizedBox(height: 24),

            // 儲存按鈕
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveRecord,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('儲存紀錄', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}