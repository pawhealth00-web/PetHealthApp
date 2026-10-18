import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MedicalClaimSelectorPage extends StatefulWidget {
  final String petId;
  const MedicalClaimSelectorPage({super.key, this.petId = "pet_001"});

  @override
  State<MedicalClaimSelectorPage> createState() => _MedicalClaimSelectorPageState();
}

class _MedicalClaimSelectorPageState extends State<MedicalClaimSelectorPage> {
  bool _isLoading = false;
  String? _aiPrecheckNote;
  final Map<String, bool> _selectedRecordsMap = {};

  Future<void> _exportAndPreCheckClaim(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    final selectedRecords = <Map<String, dynamic>>[];

    for (var doc in docs) {
      final data = doc.data();
      final recordId = doc.id;
      if (_selectedRecordsMap[recordId] == true) {
        selectedRecords.add({
          "record_id": recordId,
          "visit_date": (data['visitDate'] ?? data['date'] ?? data['timestamp'] ?? '2026-10-18').toString(),
          "diagnosis": (data['diagnosis'] ?? data['title'] ?? data['note'] ?? data['symptom'] ?? '一般醫療診察').toString(),
          "cost": double.tryParse((data['cost'] ?? data['amount'] ?? 1000).toString()) ?? 1000.0,
          "receipt_url": (data['receiptUrl'] ?? '').toString(),
        });
      }
    }

    if (selectedRecords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請至少勾選一筆就醫紀錄')),
      );
      return;
    }

    final claimPayload = {
      "pet_id": widget.petId,
      "claim_items": selectedRecords,
    };

    setState(() {
      _isLoading = true;
      _aiPrecheckNote = null;
    });

    try {
      final response = await http.post(
        Uri.parse('https://pethealth-backend.onrender.com/insurance/pre-check'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(claimPayload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _aiPrecheckNote = data['ai_precheck_note'];
        });
      } else {
        setState(() {
          _aiPrecheckNote = "已打包 ${selectedRecords.length} 筆資料（伺服器預審回應碼：${response.statusCode}）";
        });
      }
    } catch (e) {
      setState(() {
        _aiPrecheckNote = "已完成本地理賠資料打包！（目前無法連線至雲端預審：$e）";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('勾選就醫紀錄申請理賠'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      // 同時監聽 pets/{petId}/medical_records 以及全域的 health_records 兩種可能路徑
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('health_records')
            .where('petId', isEqualTo: widget.petId)
            .snapshots(),
        builder: (context, healthSnapshot) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('pets')
                .doc(widget.petId)
                .collection('medical_records')
                .snapshots(),
            builder: (context, subSnapshot) {

              // 收集並合併兩種路徑的所有文件，同時過濾出屬於醫療/疫苗的紀錄
              final List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs = [];

              if (healthSnapshot.hasData) {
                for (var doc in healthSnapshot.data!.docs) {
                  final type = (doc.data()['recordType'] ?? doc.data()['type'] ?? '').toString();
                  if (type == 'medical' || type == 'vaccine' || type.isEmpty) {
                    allDocs.add(doc);
                  }
                }
              }

              if (subSnapshot.hasData) {
                allDocs.addAll(subSnapshot.data!.docs);
              }

              if (allDocs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.medical_services_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          '目前尚無真實就醫紀錄',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '請先至「健康存摺 -> 醫療紀錄」新增看診資料，即可在此勾選申請保險理賠！',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: allDocs.length,
                      itemBuilder: (context, index) {
                        final doc = allDocs[index];
                        final data = doc.data();
                        final recordId = doc.id;

                        final diagnosis = (data['diagnosis'] ?? data['title'] ?? data['note'] ?? data['symptom'] ?? '一般醫療診察').toString();
                        final visitDate = (data['visitDate'] ?? data['date'] ?? data['timestamp'] ?? '未填寫日期').toString();
                        final cost = data['cost'] ?? data['amount'] ?? 1000;

                        final isSelected = _selectedRecordsMap[recordId] ?? false;

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: CheckboxListTile(
                            activeColor: Colors.teal,
                            title: Text(
                              diagnosis,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text("看診日期：$visitDate  |  費用：NT\$ $cost"),
                            value: isSelected,
                            onChanged: (bool? val) {
                              setState(() {
                                _selectedRecordsMap[recordId] = val ?? false;
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  if (_aiPrecheckNote != null)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.teal.shade300),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.verified_user, color: Colors.teal),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _aiPrecheckNote!,
                              style: const TextStyle(fontSize: 14, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: _isLoading
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                            : const Icon(Icons.send_and_archive),
                        label: Text(
                          _isLoading ? 'AI 預審與打包中...' : '勾選並產生理賠資料包 (AI 預審)',
                          style: const TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _isLoading ? null : () => _exportAndPreCheckClaim(allDocs),
                      ),
                    ),
                  )
                ],
              );
            },
          );
        },
      ),
    );
  }
}