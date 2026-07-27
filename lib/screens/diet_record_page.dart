import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  // 建立控制器來抓取使用者輸入的食物與份量
  final TextEditingController _foodTypeController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  bool _isSaving = false;

  Future<void> _saveRecord() async {
    // 簡單的檢查，確保有輸入食物名稱和份量
    if (_foodTypeController.text.trim().isEmpty || _amountController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ 請輸入食物種類和份量喔！')),
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
        'recordType': 'diet',
        'foodType': _foodTypeController.text.trim(),
        'amount': double.tryParse(_amountController.text.trim()) ?? 0,
        'unit': 'g', // 這裡預設單位為克，您可以之後再加入下拉選單讓使用者選
        'note': _noteController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 飲食紀錄儲存成功！可以到健康存摺查看囉！')),
        );

        // 🚨 關鍵修改：儲存後不清空整個頁面，而是清空輸入框，方便連續紀錄！
        setState(() {
          _foodTypeController.clear();
          _amountController.clear();
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
    _foodTypeController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🚨 關鍵修改：這裡直接回傳 ListView，不再使用 Scaffold 和 AppBar
    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        const Text(
          '今日飲食狀況',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
        ),
        const SizedBox(height: 16),

        // 食物種類輸入框
        TextField(
          controller: _foodTypeController,
          decoration: InputDecoration(
            labelText: '餵食了什麼？ (例如：乾飼料、罐頭)',
            prefixIcon: const Icon(Icons.restaurant_menu, color: Colors.orange),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.orange, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 份量輸入框
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: '份量 (單位：克)',
            prefixIcon: const Icon(Icons.scale, color: Colors.orange),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.orange, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 備註輸入框
        TextField(
          controller: _noteController,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: '備註 (例如：有沒有挑食？喝水多嗎？)',
            prefixIcon: const Icon(Icons.edit_note, color: Colors.orange),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.orange, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 32),

        // 儲存按鈕
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveRecord,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
            child: _isSaving
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('儲存今日飲食紀錄', style: TextStyle(fontSize: 18, color: Colors.white)),
          ),
        ),
      ],
    );
  }
}