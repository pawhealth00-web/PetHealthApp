import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CreatePetProfilePage extends StatefulWidget {
  const CreatePetProfilePage({super.key});

  @override
  State<CreatePetProfilePage> createState() => _CreatePetProfilePageState();
}

class _CreatePetProfilePageState extends State<CreatePetProfilePage> {
  static const primaryColor = Color(0xFF174D3A);
  static const backgroundColor = Color(0xFFF5F8F6);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _weightController = TextEditingController();
  final _picker = ImagePicker();

  String? _selectedSpecies;
  String? _selectedGender;
  String? _selectedNeutered;
  DateTime? _birthday;
  Uint8List? _imageBytes;
  bool _isSaving = false;

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 35,
      maxWidth: 600,
    );
    if (pickedFile == null) return;
    final bytes = await pickedFile.readAsBytes();
    if (!mounted) return;
    if (bytes.lengthInBytes > 650 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('照片過大，請選擇較小的圖片')));
      return;
    }
    setState(() => _imageBytes = bytes);
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _birthday ?? now,
      firstDate: DateTime(1990),
      lastDate: now,
    );
    if (date != null) setState(() => _birthday = date);
  }

  String _dateText(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedSpecies == null ||
        _selectedGender == null ||
        _selectedNeutered == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請選擇寵物種類、性別與結紮狀態')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('登入狀態已失效，請重新登入')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final weight = _weightController.text.trim().isEmpty
          ? null
          : double.tryParse(_weightController.text.trim());

      await FirebaseFirestore.instance.collection('pets').add({
        'owner_uid': user.uid,
        'name': _nameController.text.trim(),
        'species': _selectedSpecies,
        'breed': _breedController.text.trim(),
        'gender': _selectedGender,
        'birthday': _birthday == null ? null : Timestamp.fromDate(_birthday!),
        'weight': weight,
        'neutered': _selectedNeutered,
        'photoBase64': _imageBytes == null ? null : base64Encode(_imageBytes!),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('寵物資料建立成功！')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('儲存失敗：$error')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: primaryColor),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD8E4DD)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primaryColor, width: 1.6),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('新增寵物', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 40),
            children: [
              InkWell(
                onTap: _pickImage,
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  height: 210,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFD8E4DD), width: 1.4),
                    image: _imageBytes == null
                        ? null
                        : DecorationImage(image: MemoryImage(_imageBytes!), fit: BoxFit.cover),
                  ),
                  child: _imageBytes == null
                      ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined, size: 48, color: primaryColor),
                      SizedBox(height: 12),
                      Text('點擊上傳寵物照片', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                      SizedBox(height: 5),
                      Text('照片為選填', style: TextStyle(color: Colors.grey)),
                    ],
                  )
                      : Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(9),
                      decoration: const BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                      child: const Icon(Icons.edit, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: _decoration('寵物名稱 *', Icons.badge_outlined),
                validator: (value) => value == null || value.trim().isEmpty ? '請輸入寵物名稱' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedSpecies,
                decoration: _decoration('寵物種類 *', Icons.pets_outlined),
                items: ['狗 (Dog)', '貓 (Cat)', '兔 (Rabbit)', '鳥 (Bird)', '其他 (Other)']
                    .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                    .toList(),
                onChanged: (value) => setState(() => _selectedSpecies = value),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _breedController,
                decoration: _decoration('品種（選填）', Icons.category_outlined),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: _decoration('性別 *', Icons.transgender),
                items: ['男生 ♂', '女生 ♀', '未知']
                    .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                    .toList(),
                onChanged: (value) => setState(() => _selectedGender = value),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickBirthday,
                child: InputDecorator(
                  decoration: _decoration('生日（選填）', Icons.cake_outlined),
                  child: Text(_birthday == null ? '請選擇日期' : _dateText(_birthday!)),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _decoration('體重 kg（選填）', Icons.monitor_weight_outlined),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  final number = double.tryParse(value.trim());
                  if (number == null || number <= 0) return '請輸入正確的體重';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedNeutered,
                decoration: _decoration('是否結紮 *', Icons.health_and_safety_outlined),
                items: ['已結紮', '未結紮', '未知']
                    .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                    .toList(),
                onChanged: (value) => setState(() => _selectedNeutered = value),
              ),
              const SizedBox(height: 30),
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4))
                      : const Icon(Icons.save_outlined),
                  label: Text(_isSaving ? '儲存中...' : '儲存寵物資料', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
