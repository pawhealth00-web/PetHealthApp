import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class CreatePetProfilePage extends StatefulWidget {
  const CreatePetProfilePage({super.key});

  @override
  State<CreatePetProfilePage> createState() => _CreatePetProfilePageState();
}

class _CreatePetProfilePageState extends State<CreatePetProfilePage> {
  final TextEditingController _nameController = TextEditingController();

  // 🌟 新增：用來記錄使用者選擇的種類與性別
  String? _selectedSpecies;
  String? _selectedGender;

  bool _isSaving = false;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  // 📸 從相簿挑選照片
  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 30, // 壓縮圖片
      maxWidth: 400,
    );
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  // 💾 儲存資料
  Future<void> _saveProfile() async {
    final petName = _nameController.text.trim();

    // 檢查欄位是否有填寫
    if (petName.isEmpty || _selectedSpecies == null || _selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ 請輸入名字，並選擇寵物種類與性別喔！')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      String? base64Image;

      // 如果有照片，轉成 Base64 文字編碼
      if (_imageFile != null) {
        final bytes = await _imageFile!.readAsBytes();
        base64Image = base64Encode(bytes);
      }

      // 🌟 將包含「種類」與「性別」的完整資料存入資料庫
      await FirebaseFirestore.instance.collection('pets').add({
        'name': petName,
        'species': _selectedSpecies, // 存入種類
        'gender': _selectedGender,   // 存入性別
        'photoBase64': base64Image,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎉 寵物資料建立成功！')),
        );
        Navigator.pop(context);
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
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('建立寵物檔案'),
        backgroundColor: Colors.brown,
      ),
      // 改用 ListView 讓畫面如果太長可以滑動
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          // 📸 圓形大頭貼點擊區
          Center(
            child: GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                child: _imageFile == null
                    ? Icon(Icons.camera_alt, size: 40, color: Colors.grey.shade600)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Center(child: Text('點擊上傳大頭貼', style: TextStyle(color: Colors.grey))),
          const SizedBox(height: 32),

          // 1️⃣ 寵物名字輸入框
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '寵物名字',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.badge, color: Colors.brown),
            ),
          ),
          const SizedBox(height: 20),

          // 2️⃣ 寵物種類下拉選單
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: '寵物種類',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.pets, color: Colors.brown),
            ),
            value: _selectedSpecies,
            items: ['狗 (Dog)', '貓 (Cat)', '兔 (Rabbit)', '鳥 (Bird)', '其他 (Other)']
                .map((species) => DropdownMenuItem(
              value: species,
              child: Text(species),
            ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedSpecies = value;
              });
            },
          ),
          const SizedBox(height: 20),

          // 3️⃣ 寵物性別下拉選單
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: '性別',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.transgender, color: Colors.brown),
            ),
            value: _selectedGender,
            items: ['男生 ♂', '女生 ♀', '未知']
                .map((gender) => DropdownMenuItem(
              value: gender,
              child: Text(gender),
            ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedGender = value;
              });
            },
          ),
          const SizedBox(height: 32),

          // 儲存按鈕
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('儲存寵物資料', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}