import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MedicalClaimSelectorPage extends StatefulWidget {
  final String petId;
  const MedicalClaimSelectorPage({super.key, required this.petId});

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
      final recordId = doc.reference.path;
      if (_selectedRecordsMap[recordId] == true) {
        selectedRecords.add({
          "record_id": doc.id,
          "visit_date": _dateText(data['recordDate'] ?? data['visitDate'] ?? data['date'] ?? data['timestamp']),
          "diagnosis": (data['diagnosis'] ?? data['title'] ?? data['note'] ?? data['symptom'] ?? '一般醫療診察').toString(),
          // 舊 API 要求數字；未填費用用 0，畫面明確標示未填。
          "cost": double.tryParse('${data['cost'] ?? ''}') ?? 0.0,
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
          _aiPrecheckNote = '${data['review_note'] ?? '已整理 ${selectedRecords.length} 筆就醫紀錄。請補齊未填的收據與費用，並依保單條款向保險公司確認是否可申請。'}';
        });
      } else {
        setState(() {
          _aiPrecheckNote = '已選 ${selectedRecords.length} 筆紀錄，但伺服器回應 ${response.statusCode}；請稍後重試。';
        });
      }
    } catch (e) {
      setState(() {
        _aiPrecheckNote = '已選 ${selectedRecords.length} 筆紀錄，但目前無法連線整理：$e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _dateText(Object? value) {
    final date = value is Timestamp ? value.toDate()
        : DateTime.tryParse('${value ?? ''}');
    return date == null ? '未填日期' :
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('整理理賠資料'),
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
              if (healthSnapshot.hasError || subSnapshot.hasError) {
                return const Center(child: Text('就醫紀錄讀取失敗，請稍後重試'));
              }
              if (!healthSnapshot.hasData || !subSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              // 收集既有兩種資料路徑，只選就醫紀錄供理賠資料整理。
              final List<QueryDocumentSnapshot<Map<String, dynamic>>> allDocs = [];

              if (healthSnapshot.hasData) {
                for (var doc in healthSnapshot.data!.docs) {
                  final type = (doc.data()['recordType'] ?? doc.data()['type'] ?? '').toString();
                  if (type == 'medical' || type == '看診' || type == '醫療') {
                    allDocs.add(doc);
                  }
                }
              }

              for (final doc in subSnapshot.data!.docs) {
                final type = '${doc.data()['recordType'] ?? doc.data()['type'] ?? ''}';
                if (type == 'medical' || type == '看診' || type == '醫療' ||
                    type == '結紮' || type == '驅蟲' ||
                    (type.isEmpty && doc.data().containsKey('diagnosis'))) {
                  allDocs.add(doc);
                }
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
                          '請先至寵物總覽的「醫療紀錄」新增看診資料，再回來勾選。',
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
                        final recordId = doc.reference.path;

                        final diagnosis = (data['diagnosis'] ?? data['title'] ?? data['note'] ?? data['symptom'] ?? '一般醫療診察').toString();
                        final visitDate = _dateText(data['recordDate'] ?? data['visitDate'] ?? data['date'] ?? data['timestamp']);
                        final cost = data['cost'];

                        final isSelected = _selectedRecordsMap[recordId] ?? false;

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: CheckboxListTile(
                            activeColor: Colors.teal,
                            title: Text(
                              diagnosis,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text('看診日期：$visitDate  |  費用：${cost == null ? '未填' : 'NT\$ $cost'}'),
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
                          _isLoading ? '整理中…' : '整理已選的就醫紀錄',
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
