import 'package:flutter/material.dart';
import 'screens/login_page.dart'; // 引入我們剛拆分出來的登入頁面
import 'package:firebase_core/firebase_core.dart';

void main() async {
  // 1. 確保 Flutter 核心已經準備好
  WidgetsFlutterBinding.ensureInitialized();

  // 2. 喚醒並啟動 Firebase
  await Firebase.initializeApp();

  runApp(const PetApp());
}

class PetApp extends StatelessWidget {
  const PetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false, // 隱藏右上角的 DEBUG 標籤
      home: LoginPage(),
    );
  }
}