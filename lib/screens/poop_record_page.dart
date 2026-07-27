import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  // 記錄使用者選擇了哪一個便便狀態
  String? _selectedShape;
  final TextEditingController _noteController = TextEditingController();
  bool _isSaving = false;

  // 定義與您截圖相符的便便選項
  final List<String> _poopOptions = [
    '形狀漂亮 (條狀)',
    '軟便或拉肚子',
    '乾硬 (像羊便便)',
    '帶血或黏液'
  ];

  Future<void> _saveRecord() async {
    if (_selectedShape == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ 請先選擇今日糞便狀態喔！')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // 寫入 Firebase
      await FirebaseFirestore.instance.collection('health_records').add({
        'petId': widget.petId,
        'recordType': 'poop',
        'shape': _selectedShape,
        'color': '依形狀判斷', // 您可以未來再加入顏色選項，目前先給預設值
        'note': _noteController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 排便紀錄儲存成功！可以到健康存摺查看囉！')),
        );

        // 🚨 關鍵修改：因為現在是分頁，儲存後「不可以」呼叫 Navigator.pop！
        // 我們改為「清空表單」，讓使用者可以繼續停留在這個畫面
        setState(() {
          _selectedShape = null;
          _noteController.clear();
        });
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
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🚨 關鍵修改：移除了 Scaffold 和 AppBar，直接回傳 ListView，解決雙重標題列問題！
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const Text(
          '糞便狀態',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.brown),
        ),
        const SizedBox(height: 8),
        const Text('請選擇今日糞便狀態：', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 16),

        // 產生便便選項卡片
        ..._poopOptions.map((shape) => _buildOptionCard(shape)).toList(),

        const SizedBox(height: 24),

        // 備註欄位
        TextField(
          controller: _noteController,
          decoration: InputDecoration(
            labelText: '備註 (選填)',
            prefixIcon: const Icon(Icons.edit_note, color: Colors.brown),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          maxLines: 2,
        ),

        const SizedBox(height: 32),

        // 儲存按鈕
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveRecord,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.brown,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSaving
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('儲存今日排便紀錄', style: TextStyle(fontSize: 18, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  // 打造可點擊的選項卡片 UI
  Widget _buildOptionCard(String shapeName) {
    final isSelected = _selectedShape == shapeName;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedShape = shapeName;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected ? Colors.brown.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.brown : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: [
            if (!isSelected)
              BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected ? Colors.brown : Colors.grey,
            ),
            const SizedBox(width: 16),
            Text(
              shapeName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.brown.shade800 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}