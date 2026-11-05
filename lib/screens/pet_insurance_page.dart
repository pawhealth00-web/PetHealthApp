import 'package:flutter/material.dart';
import 'medical_claim_selector_page.dart';

class PetInsurancePage extends StatefulWidget {
  final String petId;

  const PetInsurancePage({super.key, this.petId = "pet_001"});

  @override
  State<PetInsurancePage> createState() => _PetInsurancePageState();
}

class _PetInsurancePageState extends State<PetInsurancePage> {
  String company = "富邦產險 - 毛孩安心方案";
  String policyId = "INS-2026-8888";
  DateTime endDate = DateTime(2026, 12, 31);
  int clinicLimit = 10;
  int clinicUsed = 3;

  void _editPolicyDialog() {
    final companyCtrl = TextEditingController(text: company);
    final policyCtrl = TextEditingController(text: policyId);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("編輯保單資訊"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: companyCtrl,
              decoration: const InputDecoration(labelText: "保險公司與方案名稱"),
            ),
            TextField(
              controller: policyCtrl,
              decoration: const InputDecoration(labelText: "保單號碼"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("取消"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                company = companyCtrl.text;
                policyId = policyCtrl.text;
              });
              Navigator.pop(context);
            },
            child: const Text("儲存"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int remainingDays = endDate.difference(DateTime.now()).inDays;
    final double usageRatio = clinicLimit > 0 ? (clinicUsed / clinicLimit) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的寵物保單與健康存摺'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            company,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Chip(
                          label: Text(remainingDays > 0 ? "倒數 $remainingDays 天" : "已到期"),
                          backgroundColor: remainingDays > 30 ? Colors.green[100] : Colors.orange[100],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text("保單編號: $policyId", style: TextStyle(color: Colors.grey[700])),
                    const Divider(height: 24),
                    const Text("年度門診理賠額度使用狀況", style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: usageRatio.clamp(0.0, 1.0),
                      minHeight: 10,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        usageRatio > 0.8 ? Colors.redAccent : Colors.teal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("已申請 $clinicUsed 次"),
                        Text("剩餘 ${clinicLimit - clinicUsed} / $clinicLimit 次"),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.edit),
                            label: const Text("編輯保單"),
                            onPressed: _editPolicyDialog,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.receipt_long),
                            label: const Text("線上申請理賠"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MedicalClaimSelectorPage(petId: widget.petId),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}