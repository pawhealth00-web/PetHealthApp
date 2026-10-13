import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HealthAnalysisPage extends StatefulWidget {
  final String petId;
  final String petName;

  const HealthAnalysisPage({
    super.key,
    required this.petId,
    required this.petName,
  });

  @override
  State<HealthAnalysisPage> createState() => _HealthAnalysisPageState();
}

class _HealthAnalysisPageState extends State<HealthAnalysisPage> {
  final TextEditingController _questionController = TextEditingController();
  bool _isAnalyzing = false;

  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();

  // 📸 挑選或拍攝要分析的照片
  Future<void> _pickImage() async {
    // 這裡我們稍微提高一點品質，讓 AI 看得更清楚，但還是限制大小避免撐爆資料庫
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
      maxWidth: 800,
    );
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      if (!mounted) return;
      if (bytes.lengthInBytes > 650 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('照片過大，請選擇較小的圖片')));
        return;
      }
      setState(() => _imageBytes = bytes);
    }
  }

  // 🚀 將照片與問題送出到 Firebase
  Future<void> _submitForAnalysis() async {
    if (_imageBytes == null && _questionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ 請至少上傳一張照片，或輸入您想詢問的狀況喔！')),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true; // 顯示載入動畫
    });

    try {
      String? base64Image;

      // 如果有照片，轉成 Base64 準備存入資料庫
      if (_imageBytes != null) {
        base64Image = base64Encode(_imageBytes!);
      }

      // 🌟 將分析請求存入 Firestore 的 'ai_analysis_requests' 集合中
      await FirebaseFirestore.instance.collection('ai_analysis_requests').add({
        'petId': widget.petId,
        'petName': widget.petName,
        'question': _questionController.text.trim(),
        'photoBase64': base64Image,
        'status': 'pending', // 狀態設為 pending (等待 AI 處理)
        'aiReply': '',       // 預留欄位給未來的 AI 回覆
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已儲存分析請求，等待後端處理。')),
        );
        // 清空表單，準備下一次詢問
        setState(() {
          _imageBytes = null;
          _questionController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 送出失敗：$e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('✨ ${widget.petName} 的 AI 健康分析'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '可上傳照片並描述狀況；請求會先儲存，等待後端處理。',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // 📸 照片上傳區塊
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.teal.shade200, width: 2, style: BorderStyle.solid),
                ),
                child: _imageBytes != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                )
                    : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo, size: 50, color: Colors.teal.shade300),
                    const SizedBox(height: 12),
                    Text('點擊上傳便便、皮膚或狀態照片', style: TextStyle(color: Colors.teal.shade700, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 📝 狀況描述輸入框
            TextField(
              controller: _questionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: '狀況描述 (例如：這兩天大便偏軟，這樣正常嗎？)',
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.teal, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // 🚀 送出按鈕
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isAnalyzing ? null : _submitForAnalysis,
                icon: _isAnalyzing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.auto_awesome, color: Colors.white),
                label: Text(
                  _isAnalyzing ? '送出中…' : '送出分析請求',
                  style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
