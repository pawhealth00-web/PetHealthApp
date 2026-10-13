import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'main_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isProcessing = false;
  bool _isTestingBackend = false;
  bool _obscurePassword = true;

  // 顯示下方提示訊息
  void _showMessage(
      String message, {
        Color backgroundColor = Colors.red,
      }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // 檢查 Email 格式
  bool _isValidEmail(String email) {
    return RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(email);
  }

  // 檢查登入及註冊欄位
  bool _validateInput() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty && password.isEmpty) {
      _showMessage('請輸入電子郵件和密碼');
      return false;
    }

    if (email.isEmpty) {
      _showMessage('請輸入電子郵件');
      return false;
    }

    if (!_isValidEmail(email)) {
      _showMessage('請輸入正確的電子郵件格式');
      return false;
    }

    if (password.isEmpty) {
      _showMessage('請輸入密碼');
      return false;
    }

    if (password.length < 6) {
      _showMessage('密碼至少需要 6 個字元');
      return false;
    }

    return true;
  }

  // 註冊功能
  Future<void> _register() async {
    if (!_validateInput()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _isProcessing = true;
    });

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 註冊成功後 Firebase 會自動登入
      // 這裡先登出，讓使用者重新按登入
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      _showMessage(
        '🎉 註冊成功！請按登入進入系統',
        backgroundColor: Colors.green,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'email-already-in-use':
          message = '這個電子郵件已經註冊過，請直接登入';
          break;

        case 'invalid-email':
          message = '電子郵件格式不正確';
          break;

        case 'weak-password':
          message = '密碼強度不足，請至少輸入 6 個字元';
          break;

        case 'operation-not-allowed':
          message = 'Firebase 尚未開啟電子郵件註冊功能';
          break;

        case 'network-request-failed':
          message = '網路連線失敗，請檢查網路後再試一次';
          break;

        case 'too-many-requests':
          message = '操作次數過多，請稍後再試';
          break;

        default:
          message = '註冊失敗：${e.message ?? e.code}';
      }

      _showMessage('❌ $message');
    } catch (e) {
      if (!mounted) return;

      _showMessage('❌ 註冊失敗，請稍後再試');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // 登入功能
  Future<void> _login() async {
    if (!_validateInput()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _isProcessing = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      _showMessage(
        '✅ 登入成功！',
        backgroundColor: Colors.green,
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const MainScreen(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          message = '電子郵件或密碼錯誤';
          break;

        case 'invalid-email':
          message = '電子郵件格式不正確';
          break;

        case 'user-disabled':
          message = '此帳號已被停用';
          break;

        case 'too-many-requests':
          message = '嘗試次數過多，請稍後再試';
          break;

        case 'network-request-failed':
          message = '網路連線失敗，請檢查網路';
          break;

        default:
          message = '登入失敗：${e.message ?? e.code}';
      }

      _showMessage('❌ $message');
    } catch (e) {
      if (!mounted) return;

      _showMessage('❌ 登入失敗，請稍後再試');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // 忘記密碼
  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showMessage('請先輸入註冊時使用的電子郵件');
      return;
    }

    if (!_isValidEmail(email)) {
      _showMessage('請輸入正確的電子郵件格式');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
      );

      if (!mounted) return;

      _showMessage(
        '📧 密碼重設信已寄出，請前往電子郵件信箱查看',
        backgroundColor: Colors.green,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'invalid-email':
          message = '電子郵件格式不正確';
          break;

        case 'user-not-found':
          message = '找不到此電子郵件的註冊帳號';
          break;

        case 'too-many-requests':
          message = '操作次數過多，請稍後再試';
          break;

        case 'network-request-failed':
          message = '網路連線失敗，請檢查網路';
          break;

        default:
          message = '無法寄送密碼重設信：${e.message ?? e.code}';
      }

      _showMessage('❌ $message');
    } catch (e) {
      if (!mounted) return;

      _showMessage('❌ 無法寄送密碼重設信，請稍後再試');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // 測試 Render 後端連線
  Future<void> _testBackend() async {
    setState(() {
      _isTestingBackend = true;
    });

    try {
      final response = await http
          .get(
        Uri.parse('https://pethealth-backend.onrender.com'),
      )
          .timeout(const Duration(seconds: 60));

      if (!mounted) return;

      if (response.statusCode == 200) {
        _showMessage(
          '✅ PawHealth 後端連線成功！',
          backgroundColor: Colors.green,
        );
      } else {
        _showMessage(
          '❌ 後端回應異常：${response.statusCode}',
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showMessage('❌ 後端連線失敗：$e');
    } finally {
      if (mounted) {
        setState(() {
          _isTestingBackend = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF6D4C41);
    const greenColor = Color(0xFF2F7154);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '寵物健康存摺 - 會員登入',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 50),

            const Icon(
              Icons.pets,
              size: 80,
              color: primaryColor,
            ),

            const SizedBox(height: 16),

            const Text(
              'PawHealth',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              '寵物健康照護系統',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 40),

            const Text(
              '電子郵件',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),

            const SizedBox(height: 8),

            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              decoration: const InputDecoration(
                hintText: '例如：pawhealth@gmail.com',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),

            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '密碼',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                TextButton(
                  onPressed:
                  _isProcessing ? null : _forgotPassword,
                  child: const Text(
                    '忘記密碼？',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: greenColor,
                    ),
                  ),
                ),
              ],
            ),

            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!_isProcessing) {
                  _login();
                }
              },
              decoration: InputDecoration(
                hintText: '請輸入至少 6 個字元',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? '顯示密碼' : '隱藏密碼',
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                  primaryColor.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isProcessing
                    ? const SizedBox(
                  width: 23,
                  height: 23,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Text(
                  '登入',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            TextButton(
              onPressed: _isProcessing ? null : _register,
              child: const Text(
                '還沒有帳號嗎？點此註冊',
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed:
              _isTestingBackend ? null : _testBackend,
              icon: _isTestingBackend
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
                  : const Icon(Icons.cloud_done),
              label: Text(
                _isTestingBackend
                    ? '正在連接後端……'
                    : '測試後端連線',
              ),
            ),
          ],
        ),
      ),
    );
  }
}