import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';
import 'pet_detail_page.dart';
import 'create_pet_profile_page.dart';
import 'edit_pet_profile_page.dart'; // 🌟 引入剛剛做好的編輯頁面

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的寵物列表'),
        backgroundColor: Colors.brown,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: '登出',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('pets').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.brown));
          }

          if (snapshot.hasError) {
            return Center(child: Text('發生錯誤：${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                '目前還沒有寵物喔！\n點擊右下角 ➕ 新增一隻吧！',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final pets = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: pets.length,
            itemBuilder: (context, index) {
              final petDoc = pets[index];
              final petData = petDoc.data() as Map<String, dynamic>;

              final petName = petData['name'] ?? '未知寵物';
              final species = petData['species'];
              final gender = petData['gender'];
              final photoBase64 = petData['photoBase64'];

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  leading: Builder(
                    builder: (context) {
                      if (photoBase64 != null && photoBase64.toString().isNotEmpty) {
                        return CircleAvatar(
                          radius: 30,
                          backgroundImage: MemoryImage(base64Decode(photoBase64)),
                        );
                      } else {
                        return CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.orange.shade200,
                          child: const Icon(Icons.pets, color: Colors.white, size: 30),
                        );
                      }
                    },
                  ),
                  title: Text(
                    petName,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${species ?? '未設定種類'}  |  ${gender ?? '未設定性別'}\n點擊進入專屬天地'),
                  isThreeLine: true,

                  // 🌟 這裡把原本的純箭頭，改成了「編輯按鈕」
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_note, color: Colors.brown, size: 32),
                    tooltip: '編輯資料',
                    onPressed: () {
                      // 點擊編輯按鈕，將目前資料傳遞給編輯頁面
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditPetProfilePage(
                            petId: petDoc.id,
                            initialName: petName,
                            initialSpecies: species,
                            initialGender: gender,
                            initialPhotoBase64: photoBase64,
                          ),
                        ),
                      );
                    },
                  ),
                  onTap: () {
                    // 點擊整張卡片，仍然是進入健康存摺
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PetDetailPage(
                          petId: petDoc.id,
                          petName: petName,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreatePetProfilePage(),
            ),
          );
        },
        backgroundColor: Colors.brown,
        icon: const Icon(Icons.add),
        label: const Text('新增寵物'),
      ),
    );
  }
}