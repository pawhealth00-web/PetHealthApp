import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class EditPetProfilePage extends StatefulWidget {
  final String petId;
  final String initialName;
  final String? initialSpecies;
  final String? initialGender;
  final String? initialPhotoBase64;

  const EditPetProfilePage({
    super.key,
    required this.petId,
    required this.initialName,
    this.initialSpecies,
    this.initialGender,
    this.initialPhotoBase64,
  });

  @override
  State<EditPetProfilePage> createState() => _EditPetProfilePageState();
}

class _EditPetProfilePageState extends State<EditPetProfilePage> {
  late TextEditingController _nameController;
  String? _selectedSpecies;
  String? _selectedGender;
  String _selectedNeutered = '未知';
  bool _loadingPet = true;

  bool _isSaving = false;
  Uint8List? _newImageBytes;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // 進入頁面時，先把舊的名字填入輸入框
    _nameController = TextEditingController(text: widget.initialName);

    // 安全檢查：確保傳進來的舊種類存在於選項中，否則不預選
    final speciesList = ['狗 (Dog)', '貓 (Cat)', '兔 (Rabbit)', '鳥 (Bird)', '其他 (Other)'];
    if (speciesList.contains(widget.initialSpecies)) {
      _selectedSpecies = widget.initialSpecies;
    }

    // 安全檢查：確保傳進來的舊性別存在於選項中
    final genderList = ['男生 ♂', '女生 ♀', '未知'];
    if (genderList.contains(widget.initialGender)) {
      _selectedGender = widget.initialGender;
    }
    _loadNeutered();
  }

  Future<void> _loadNeutered() async {
    try {
      final pet = await FirebaseFirestore.instance.collection('pets').doc(widget.petId).get();
      final value = pet.data()?['neutered']?.toString();
      if (mounted) setState(() {
        if (['已結紮', '未結紮', '未知'].contains(value)) _selectedNeutered = value!;
        _loadingPet = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPet = false);
    }
  }

  // 📸 挑選新照片
  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 30,
      maxWidth: 400,
    );
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      if (!mounted) return;
      if (bytes.lengthInBytes > 650 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('照片過大，請選擇較小的圖片')));
        return;
      }
      setState(() => _newImageBytes = bytes);
    }
  }

  // 💾 更新資料到 Firebase
  Future<void> _updateProfile() async {
    final petName = _nameController.text.trim();

    if (petName.isEmpty || _selectedSpecies == null || _selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ 請完整填寫寵物名字、種類與性別喔！')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // 準備要更新的資料包
      Map<String, dynamic> updateData = {
        'name': petName,
        'species': _selectedSpecies,
        'gender': _selectedGender,
        'neutered': _selectedNeutered,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // 🌟 如果使用者有選「新照片」，才更新照片文字編碼；沒選就保留原本的
      if (_newImageBytes != null) {
        updateData['photoBase64'] = base64Encode(_newImageBytes!);
      }

      // 🌟 關鍵：使用 .doc(petId).update() 針對這隻寵物進行修改
      await FirebaseFirestore.instance.collection('pets').doc(widget.petId).update(updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎉 寵物資料更新成功！')),
        );
        Navigator.pop(context); // 修改完畢，回到首頁
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 更新失敗：$e')),
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
        title: const Text('編輯寵物資料'),
        backgroundColor: Colors.brown,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          // 📸 圓形大頭貼區塊 (會判斷要顯示新照片、舊照片、還是預設圖示)
          Center(
            child: GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: _newImageBytes != null
                    ? MemoryImage(_newImageBytes!)
                    : (widget.initialPhotoBase64 != null && widget.initialPhotoBase64!.isNotEmpty
                    ? MemoryImage(base64Decode(widget.initialPhotoBase64!)) // 否則顯示舊的雲端照片
                    : null),
                child: _newImageBytes == null && (widget.initialPhotoBase64 == null || widget.initialPhotoBase64!.isEmpty)
                    ? Icon(Icons.camera_alt, size: 40, color: Colors.grey.shade600)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Center(child: Text('點擊更換大頭貼', style: TextStyle(color: Colors.grey))),
          const SizedBox(height: 32),

          // 寵物名字輸入框
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '寵物名字',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.badge, color: Colors.brown),
            ),
          ),
          const SizedBox(height: 20),

          // 種類選單
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: '寵物種類',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.pets, color: Colors.brown),
            ),
            value: _selectedSpecies,
            items: ['狗 (Dog)', '貓 (Cat)', '兔 (Rabbit)', '鳥 (Bird)', '其他 (Other)']
                .map((species) => DropdownMenuItem(value: species, child: Text(species)))
                .toList(),
            onChanged: (value) => setState(() => _selectedSpecies = value),
          ),
          const SizedBox(height: 20),

          // 性別選單
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: '性別',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.transgender, color: Colors.brown),
            ),
            value: _selectedGender,
            items: ['男生 ♂', '女生 ♀', '未知']
                .map((gender) => DropdownMenuItem(value: gender, child: Text(gender)))
                .toList(),
            onChanged: (value) => setState(() => _selectedGender = value),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _selectedNeutered,
            decoration: const InputDecoration(
              labelText: '是否結紮', border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.health_and_safety_outlined, color: Colors.brown),
            ),
            items: ['已結紮', '未結紮', '未知']
                .map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
            onChanged: (value) => setState(() => _selectedNeutered = value ?? '未知'),
          ),
          const SizedBox(height: 32),

          // 儲存修改按鈕
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSaving || _loadingPet ? null : _updateProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('儲存修改', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
