import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'create_pet_profile_page.dart';
import 'edit_pet_profile_page.dart';
import 'login_page.dart';
import 'pet_detail_page.dart';
import 'history_record_page.dart';
import 'user_profile_page.dart';
import 'ai_analysis_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const primaryColor = Color(0xFF174D3A);
  static const secondaryColor = Color(0xFF4F7D63);
  static const backgroundColor = Color(0xFFF5F8F6);
  static const lightGreenColor = Color(0xFFE5F0EA);

  final PageController _petPageController =
  PageController(viewportFraction: 0.88);
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _petsStream;
  int _selectedPetIndex = 0;
  String? _selectedPetId;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _latestPets = [];

  @override
  void initState() {
    super.initState();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    _petsStream = userId == null
        ? const Stream<QuerySnapshot<Map<String, dynamic>>>.empty()
        : FirebaseFirestore.instance
        .collection('pets')
        .where('owner_uid', isEqualTo: userId)
        .snapshots();
  }

  Future<void> _goToPetPage(int index, int petCount) async {
    if (petCount <= 1 || index < 0 || index >= petCount) return;
    await _petPageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('確定要登出嗎？'),
        content: const Text('登出後需要重新輸入電子郵件和密碼。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('確定登出'),
          ),
        ],
      ),
    );
    if (shouldLogout != true) return;
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
    );
  }

  Future<void> _openCreatePetPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreatePetProfilePage()),
    );
    // StreamBuilder 會自動收到 Firestore 更新，不需要 setState 重新查詢。
  }

  void _openPetDetail({required String petId, required String petName}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PetDetailPage(petId: petId, petName: petName),
      ),
    );
  }

  void _openHistory() => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const HistoryRecordPage()));

  void _openProfile() => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const UserProfilePage()));

  void _openSelectedAnalysis(List<QueryDocumentSnapshot<Map<String, dynamic>>> pets) {
    if (pets.isEmpty) return;
    final pet = pets[_selectedPetIndex];
    Navigator.push(context, MaterialPageRoute(builder: (_) => HealthAnalysisPage(
      petId: pet.id, petName: pet.data()['name']?.toString() ?? '寵物')));
  }

  void _openEditPetPage({
    required String petId,
    required String petName,
    dynamic species,
    dynamic gender,
    dynamic photoBase64,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditPetProfilePage(
          petId: petId,
          initialName: petName,
          initialSpecies: species,
          initialGender: gender,
          initialPhotoBase64: photoBase64,
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '早安，主人';
    if (hour < 18) return '午安，主人';
    return '晚安，主人';
  }

  Widget _buildPetPhoto(dynamic photoBase64, {double radius = 43}) {
    if (photoBase64 != null && photoBase64.toString().trim().isNotEmpty) {
      try {
        return CircleAvatar(
          radius: radius,
          backgroundColor: lightGreenColor,
          backgroundImage: MemoryImage(base64Decode(photoBase64.toString())),
        );
      } catch (_) {}
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: lightGreenColor,
      child: Icon(Icons.pets, size: radius, color: primaryColor),
    );
  }

  Widget _buildEmptyPets() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0x12000000), blurRadius: 15, offset: Offset(0, 6)),
        ],
      ),
      child: const Column(
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: lightGreenColor,
            child: Icon(Icons.pets, size: 48, color: primaryColor),
          ),
          SizedBox(height: 18),
          Text(
            '目前還沒有寵物',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: primaryColor),
          ),
          SizedBox(height: 8),
          Text(
            '點擊上方「新增」建立寵物資料，開始記錄每日健康狀況。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.5, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildPetCard(QueryDocumentSnapshot<Map<String, dynamic>> petDoc) {
    final data = petDoc.data();
    final name = data['name']?.toString().trim().isNotEmpty == true
        ? data['name'].toString()
        : '未知寵物';
    final species = data['species'];
    final gender = data['gender'];
    final photo = data['photoBase64'];
    final speciesText = species?.toString().trim().isNotEmpty == true
        ? species.toString()
        : '未設定種類';
    final genderText = gender?.toString().trim().isNotEmpty == true
        ? gender.toString()
        : '未設定性別';

    return Container(
      margin: const EdgeInsets.fromLTRB(4, 10, 4, 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF28624D), primaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x32174D3A), blurRadius: 15, offset: Offset(0, 7)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildPetPhoto(photo),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '$speciesText  ·  $genderText',
                      style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.86)),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '編輯寵物資料',
                onPressed: () => _openEditPetPage(
                  petId: petDoc.id,
                  petName: name,
                  species: species,
                  gender: gender,
                  photoBase64: photo,
                ),
                icon: const Icon(Icons.edit_outlined, color: Colors.white),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openPetDetail(petId: petDoc.id, petName: name),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withOpacity(0.65)),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.favorite_outline),
              label: const Text('查看健康存摺', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(int count) {
    if (count <= 1) return const SizedBox(height: 6);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final selected = index == _selectedPetIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: selected ? 22 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: selected ? primaryColor : primaryColor.withOpacity(0.22),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }

  Widget _petArrowButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.white.withOpacity(0.94),
      shape: const CircleBorder(),
      elevation: 5,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: primaryColor, size: 30),
      ),
    );
  }

  Widget _featureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withOpacity(0.14)),
          ),
          child: Row(
            children: [
              Container(
                width: 49,
                height: 49,
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF24372F))),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _petPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = _currentUser?.uid;
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: backgroundColor,
        foregroundColor: primaryColor,
        automaticallyImplyLeading: false,
        title: const Row(
          children: [
            Icon(Icons.pets, color: primaryColor),
            SizedBox(width: 9),
            Text('PawHealth', style: TextStyle(color: primaryColor, fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(tooltip: '使用者資料', onPressed: _openProfile,
            icon: const Icon(Icons.account_circle_outlined)),
          IconButton(tooltip: '登出', onPressed: _logout,
            icon: const Icon(Icons.logout)),
          const SizedBox(width: 6),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index == 1) {
            final pets = _latestPets;
            if (pets.isNotEmpty) {
              final pet = pets[_selectedPetIndex.clamp(0, pets.length - 1).toInt()];
              _openPetDetail(petId: pet.id,
                petName: pet.data()['name']?.toString() ?? '寵物');
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('請先新增寵物')));
            }
          } else if (index == 2) {
            _openHistory();
          } else if (index == 3) {
            _openProfile();
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: '首頁'),
          NavigationDestination(icon: Icon(Icons.edit_note), label: '紀錄'),
          NavigationDestination(icon: Icon(Icons.history), label: '健康存摺'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: '我的'),
        ],
      ),
      body: userId == null
          ? const Center(child: Text('尚未登入，請重新登入'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _petsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: primaryColor));
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('讀取寵物資料時發生錯誤：\n${snapshot.error}', textAlign: TextAlign.center),
              ),
            );
          }
          final pets = snapshot.data?.docs ?? [];
          _latestPets = pets;
          if (pets.isNotEmpty) {
            final rememberedIndex = _selectedPetId == null
                ? -1
                : pets.indexWhere((pet) => pet.id == _selectedPetId);

            if (rememberedIndex >= 0) {
              _selectedPetIndex = rememberedIndex;
            } else if (_selectedPetIndex >= pets.length) {
              _selectedPetIndex = pets.length - 1;
            }

            _selectedPetId = pets[_selectedPetIndex].id;

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || !_petPageController.hasClients) return;
              final currentPage = _petPageController.page?.round();
              if (currentPage != _selectedPetIndex) {
                _petPageController.jumpToPage(_selectedPetIndex);
              }
            });
          } else {
            _selectedPetIndex = 0;
            _selectedPetId = null;
          }

          void openSelectedPet() {
            if (pets.isEmpty) return;
            final pet = pets[_selectedPetIndex];
            _openPetDetail(
              petId: pet.id,
              petName: pet.data()['name']?.toString() ?? '未知寵物',
            );
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_getGreeting(), style: const TextStyle(fontSize: 27, fontWeight: FontWeight.bold, color: Color(0xFF24372F))),
                  const SizedBox(height: 6),
                  const Text('今天也一起守護毛孩的健康吧！', style: TextStyle(fontSize: 15, color: Colors.grey)),
                  const SizedBox(height: 25),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('我的寵物', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF24372F))),
                      TextButton.icon(
                        onPressed: _openCreatePetPage,
                        icon: const Icon(Icons.add, size: 19),
                        label: const Text('新增'),
                        style: TextButton.styleFrom(foregroundColor: primaryColor),
                      ),
                    ],
                  ),
                  if (pets.isEmpty)
                    _buildEmptyPets()
                  else ...[
                    SizedBox(
                      height: 230,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          ScrollConfiguration(
                            behavior: ScrollConfiguration.of(context).copyWith(
                              dragDevices: const {
                                PointerDeviceKind.touch,
                                PointerDeviceKind.mouse,
                                PointerDeviceKind.trackpad,
                                PointerDeviceKind.stylus,
                              },
                            ),
                            child: PageView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const PageScrollPhysics(),
                              controller: _petPageController,
                              itemCount: pets.length,
                              onPageChanged: (index) {
                                if (index < 0 || index >= pets.length) {
                                  return;
                                }
                                setState(() {
                                  _selectedPetIndex = index;
                                  _selectedPetId = pets[index].id;
                                });
                              },
                              itemBuilder: (_, index) =>
                                  _buildPetCard(pets[index]),
                            ),
                          ),
                          if (pets.length > 1 && _selectedPetIndex > 0)
                            Positioned(
                              left: 10,
                              child: _petArrowButton(
                                icon: Icons.chevron_left,
                                tooltip: '上一隻寵物',
                                onPressed: () => _goToPetPage(
                                  _selectedPetIndex - 1,
                                  pets.length,
                                ),
                              ),
                            ),
                          if (pets.length > 1 &&
                              _selectedPetIndex < pets.length - 1)
                            Positioned(
                              right: 10,
                              child: _petArrowButton(
                                icon: Icons.chevron_right,
                                tooltip: '下一隻寵物',
                                onPressed: () => _goToPetPage(
                                  _selectedPetIndex + 1,
                                  pets.length,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    _buildPageIndicator(pets.length),
                    const SizedBox(height: 24),
                    const Text('健康管理', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF24372F))),
                    const SizedBox(height: 14),
                    _featureCard(
                      icon: Icons.restaurant_outlined,
                      title: '每日健康紀錄',
                      subtitle: '記錄飲食、排便與行為狀況',
                      color: const Color(0xFFE28B57),
                      onTap: openSelectedPet,
                    ),
                    const SizedBox(height: 12),
                    _featureCard(
                      icon: Icons.calendar_month_outlined,
                      title: '最近七天紀錄',
                      subtitle: '查看毛孩近期的健康變化',
                      color: secondaryColor,
                      onTap: _openHistory,
                    ),
                    const SizedBox(height: 12),
                    _featureCard(
                      icon: Icons.auto_awesome,
                      title: 'AI 健康分析',
                      subtitle: '根據近期紀錄提供健康提醒',
                      color: primaryColor,
                      onTap: () => _openSelectedAnalysis(pets),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
