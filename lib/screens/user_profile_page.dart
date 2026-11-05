import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'login_page.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});
  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _saving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save(String uid) async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'displayName': _name.text.trim(),
        'phone': _phone.text.trim(),
        'email': FirebaseAuth.instance.currentUser?.email,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('使用者資料已儲存')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('儲存失敗：$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(context: context,
      builder: (context) => AlertDialog(title: const Text('確定登出？'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('登出'))]));
    if (confirmed != true) return;
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('請先登入')));
    return Scaffold(appBar: AppBar(title: const Text('使用者資料'),
      backgroundColor: const Color(0xFF174D3A), foregroundColor: Colors.white),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('資料讀取失敗：${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (!_initialized) {
            _name.text = (snapshot.data!.data()?['displayName'] ?? user.displayName ?? '').toString();
            _phone.text = (snapshot.data!.data()?['phone'] ?? '').toString();
            _initialized = true;
          }
          return ListView(padding: const EdgeInsets.all(20), children: [
            const Icon(Icons.account_circle, size: 82, color: Color(0xFF174D3A)),
            const SizedBox(height: 16),
            TextField(controller: _name, decoration: const InputDecoration(
              labelText: '稱呼', border: OutlineInputBorder())),
            const SizedBox(height: 14),
            TextField(controller: _phone, keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: '電話（選填）',
                border: OutlineInputBorder())),
            const SizedBox(height: 14),
            ListTile(title: const Text('登入 Email'), subtitle: Text(user.email ?? '未設定')),
            const SizedBox(height: 16),
            FilledButton(onPressed: _saving ? null : () => _save(user.uid),
              child: Text(_saving ? '儲存中…' : '儲存資料')),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: _logout,
              icon: const Icon(Icons.logout), label: const Text('登出')),
          ]);
        },
      ),
    );
  }
}
