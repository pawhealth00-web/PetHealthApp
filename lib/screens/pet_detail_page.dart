import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'diet_record_page.dart';
import 'poop_record_page.dart';
import 'ai_analysis_page.dart';
import 'vaccine_record_page.dart';

class PetDetailPage extends StatefulWidget {
  final String petId;
  final String petName;

  const PetDetailPage({
    super.key,
    required this.petId,
    required this.petName,
  });

  @override
  State<PetDetailPage> createState() => _PetDetailPageState();
}

class _PetDetailPageState extends State<PetDetailPage> {
  // 用來追蹤目前底部導覽列選中的是哪一個分頁 (0: 飲食, 1: 排便, 2: 歷史)
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // 定義三個分頁要顯示的內容
    final List<Widget> pages = [
      // 頁籤 0：飲食紀錄
      DietRecordPage(petId: widget.petId, petName: widget.petName),

      // 頁籤 1：排便追蹤
      PoopRecordPage(petId: widget.petId, petName: widget.petName),

      // 頁籤 2：健康存摺 (包含按鈕與歷史清單)
      _buildHistoryAndToolsPage(),
    ];

    return Scaffold(
      // 頂部標題列 (顯示寵物名字的小天地)
      appBar: AppBar(
        title: Text('${widget.petName} 的專屬天地'),
        backgroundColor: Colors.brown,
      ),

      // 頁面主體：根據使用者點擊的底部標籤來切換畫面
      body: pages[_currentIndex],

      // 底部導覽列
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index; // 切換分頁
          });
        },
        selectedItemColor: Colors.brown,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant),
            label: '飲食紀錄',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.cookie),
            label: '排便追蹤',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: '健康存摺',
          ),
        ],
      ),
    );
  }

  // 第三個頁籤的專屬畫面：將所有進階功能和歷史清單放在這裡
  Widget _buildHistoryAndToolsPage() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 橫向排列的兩個快捷按鈕 (疫苗與 AI)
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VaccineRecordPage(petId: widget.petId, petName: widget.petName),
                      ),
                    );
                  },
                  icon: const Icon(Icons.vaccines, color: Colors.white, size: 18),
                  label: const Text('疫苗', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HealthAnalysisPage(petId: widget.petId, petName: widget.petName),
                      ),
                    );
                  },
                  icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                  label: const Text('AI 分析', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            '歷史紀錄',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.brown),
          ),
          const Divider(),
          // 歷史紀錄清單
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('health_records')
                  .where('petId', isEqualTo: widget.petId)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.brown));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('目前尚無紀錄'));
                }

                final records = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final data = records[index].data() as Map<String, dynamic>;
                    final recordType = data['recordType'] ?? '';
                    final note = data['note'] ?? '';

                    if (recordType == 'diet') {
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.restaurant, color: Colors.white)),
                          title: Text('🍖 餵食：${data['foodType'] ?? ''}'),
                          subtitle: Text(note.isNotEmpty ? '備註：$note' : '份量：${data['amount'] ?? ''}'),
                        ),
                      );
                    } else if (recordType == 'poop') {
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: Colors.brown.shade700, child: const Icon(Icons.cookie, color: Colors.white)),
                          title: Text('💩 便便：${data['shape'] ?? ''}'),
                          subtitle: Text(note.isNotEmpty ? '備註：$note' : '顏色：${data['color'] ?? ''}'),
                        ),
                      );
                    } else if (recordType == 'vaccine') {
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(backgroundColor: Colors.pinkAccent, child: Icon(Icons.vaccines, color: Colors.white)),
                          title: Text('💉 疫苗：${data['vaccineName'] ?? ''}'),
                          subtitle: Text(note.isNotEmpty ? '備註：$note' : ''),
                        ),
                      );
                    }
                    return const SizedBox();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}