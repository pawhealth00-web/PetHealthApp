import 'package:flutter/material.dart';

class HistoryRecordPage extends StatefulWidget {
  const HistoryRecordPage({super.key});
  @override
  State<HistoryRecordPage> createState() => _HistoryRecordPageState();
}

class _HistoryRecordPageState extends State<HistoryRecordPage> {
  // 1. 健康存摺模擬資料庫
  final List<Map<String, dynamic>> _healthRecords = [
    {"date": "2026-07-10", "type": "疫苗", "title": "狂犬病與十合一疫苗", "clinic": "安心動物醫院", "note": "打完有點想睡覺，需觀察食慾"},
    {"date": "2026-06-15", "type": "看診", "title": "年度健康檢查", "clinic": "快樂獸醫院", "note": "體重過重，醫生建議減少零食並增加運動量"},
    {"date": "2026-05-01", "type": "驅蟲", "title": "心絲蟲與跳蚤預防", "clinic": "居家點藥", "note": "全能狗S (下個月記得再吃)"},
  ];

  // 2. 新增：寵物日常模擬資料庫 (包含飲食與排便)
  final List<Map<String, dynamic>> _dailyRecords = [
    {
      "date": "2026-07-20",
      "type": "飲食",
      "status": "正常進食",
      "water": "正常喝水",
      "note": "今天食慾很好，吃了一整碗乾糧！"
    },
    {
      "date": "2026-07-20",
      "type": "排便",
      "status": "形狀漂亮(條狀)",
      "note": "早上去公園散步時上的，非常健康。"
    },
    {
      "date": "2026-07-19",
      "type": "排便",
      "status": "軟便或拉肚子",
      "note": "可能昨天的零食吃太多了，明天要減少給予。"
    },
    {
      "date": "2026-07-19",
      "type": "飲食",
      "status": "挑食或食慾不佳",
      "water": "喝水量偏少",
      "note": "天氣太熱不想吃飯，加了肉泥才願意吃。"
    },
  ];

  // 呼叫底部彈出視窗的函式 (針對健康存摺)
  void _showAddRecordBottomSheet() {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return Container(
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: _AddMedicalRecordForm(
              onSave: (newRecord) {
                setState(() => _healthRecords.insert(0, newRecord));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已成功新增醫療紀錄！'), backgroundColor: Colors.teal));
              },
            ),
          );
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
            title: const Text("歷史紀錄"),
            backgroundColor: Colors.teal,
            bottom: const TabBar(
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(icon: Icon(Icons.medical_information), text: "健康存摺"),
                  Tab(icon: Icon(Icons.calendar_month), text: "寵物日常")
                ]
            )
        ),
        body: TabBarView(
            children: [
              _healthRecords.isEmpty ? _buildEmptyState(Icons.medical_services, "尚無健康存摺紀錄", "這裡未來可以紀錄疫苗、看診等醫療資訊") : _buildHealthRecordList(),
              _dailyRecords.isEmpty ? _buildEmptyState(Icons.restaurant_menu, "尚無日常紀錄", "前往「飲食紀錄」或「排便追蹤」\n頁面開始紀錄") : _buildDailyRecordList(),
            ]
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showAddRecordBottomSheet,
          backgroundColor: Colors.teal,
          elevation: 4,
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 100, color: Colors.teal.withValues(alpha: 0.3)), const SizedBox(height: 24), Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)), const SizedBox(height: 12), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.grey, height: 1.5))]));
  }

  Widget _buildHealthRecordList() {
    return ListView.builder(
        padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 80),
        itemCount: _healthRecords.length,
        itemBuilder: (context, index) {
          final record = _healthRecords[index];
          IconData iconData = Icons.bug_report;
          Color iconColor = Colors.purple;
          if (record['type'] == '疫苗') { iconData = Icons.vaccines; iconColor = Colors.green; }
          else if (record['type'] == '看診') { iconData = Icons.local_hospital; iconColor = Colors.redAccent; }

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(iconData, color: iconColor, size: 28)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text(record['title'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)), Text(record['date'], style: const TextStyle(color: Colors.grey, fontSize: 14))]),
                        const SizedBox(height: 8),
                        Row(children: [const Icon(Icons.location_on, size: 16, color: Colors.grey), const SizedBox(width: 4), Text(record['clinic'], style: const TextStyle(color: Colors.black87))]),
                        const SizedBox(height: 8),
                        Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(6)), child: Text(record['note'], style: const TextStyle(color: Colors.black54, fontSize: 14, height: 1.4)))
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }
    );
  }

  // 3. 升級：打造精緻的「寵物日常」卡片列表
  Widget _buildDailyRecordList() {
    return ListView.builder(
        padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 80),
        itemCount: _dailyRecords.length,
        itemBuilder: (context, index) {
          final record = _dailyRecords[index];
          bool isDiet = record['type'] == '飲食';

          // 根據類型決定圖示與顏色
          IconData iconData = isDiet ? Icons.restaurant : Icons.pets;
          Color iconColor = isDiet ? Colors.orange : Colors.brown;

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: iconColor.withValues(alpha: 0.3), width: 1)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左側圓形 Icon 區塊
                  Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: Icon(iconData, color: iconColor, size: 28)
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 頂部：類型標籤與日期
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("${record['type']}紀錄", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: iconColor)),
                              Text(record['date'], style: const TextStyle(color: Colors.grey, fontSize: 14))
                            ]
                        ),
                        const SizedBox(height: 12),

                        // 中間：詳細狀態內容
                        if (isDiet) ...[
                          Text("🍽️ 飲食狀況：${record['status']}", style: const TextStyle(fontSize: 15, color: Colors.black87)),
                          const SizedBox(height: 6),
                          Text("💧 喝水狀況：${record['water']}", style: const TextStyle(fontSize: 15, color: Colors.black87)),
                        ] else ...[
                          Text("💩 糞便狀態：${record['status']}", style: const TextStyle(fontSize: 15, color: Colors.black87)),
                        ],

                        // 底部：備註區塊 (如果有填寫的話)
                        if (record['note'] != null && record['note'].isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade200)),
                              child: Text("備註：${record['note']}", style: const TextStyle(color: Colors.black54, fontSize: 14, height: 1.4))
                          )
                        ]
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }
    );
  }
}

// 獨立元件：新增醫療紀錄專用表單
class _AddMedicalRecordForm extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;
  const _AddMedicalRecordForm({required this.onSave});
  @override
  State<_AddMedicalRecordForm> createState() => _AddMedicalRecordFormState();
}

class _AddMedicalRecordFormState extends State<_AddMedicalRecordForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _clinicController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String _selectedType = '看診';
  DateTime _selectedDate = DateTime.now();

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final newRecord = {"date": "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}", "type": _selectedType, "title": _titleController.text, "clinic": _clinicController.text.isEmpty ? "未提供地點" : _clinicController.text, "note": _noteController.text.isEmpty ? "無備註" : _noteController.text};
      widget.onSave(newRecord);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("新增醫療紀錄", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: InkWell(onTap: _pickDate, child: InputDecorator(decoration: const InputDecoration(labelText: "日期", border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today, size: 20)), child: Text("${_selectedDate.year}/${_selectedDate.month}/${_selectedDate.day}")))),
                const SizedBox(width: 16),
                Expanded(child: DropdownButtonFormField<String>(value: _selectedType, decoration: const InputDecoration(labelText: "類型", border: OutlineInputBorder(), prefixIcon: Icon(Icons.category, size: 20)), items: ['看診', '疫苗', '驅蟲', '其他'].map((String value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(), onChanged: (newValue) => setState(() => _selectedType = newValue!))),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(controller: _titleController, decoration: const InputDecoration(labelText: "項目名稱 (必填，如：年度健檢)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.edit)), validator: (value) => (value == null || value.isEmpty) ? '請填寫項目名稱' : null),
            const SizedBox(height: 16),
            TextFormField(controller: _clinicController, decoration: const InputDecoration(labelText: "醫院名稱 (選填)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.local_hospital))),
            const SizedBox(height: 16),
            TextFormField(controller: _noteController, maxLines: 3, decoration: const InputDecoration(labelText: "醫生備註 / 觀察事項 (選填)", border: OutlineInputBorder(), alignLabelWithHint: true)),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _submit, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.teal, foregroundColor: Colors.white), child: const Text("儲存紀錄", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          ],
        ),
      ),
    );
  }
}