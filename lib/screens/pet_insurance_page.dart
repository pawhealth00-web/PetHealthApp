import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'medical_claim_selector_page.dart';

class PetInsurancePage extends StatefulWidget {
  final String petId;
  const PetInsurancePage({super.key, required this.petId});

  @override
  State<PetInsurancePage> createState() => _PetInsurancePageState();
}

class _PetInsurancePageState extends State<PetInsurancePage> {
  static const green = Color(0xFF2E7D5B);

  Future<void> _edit(Map<String, dynamic> existing) async {
    final company = TextEditingController(text: '${existing['company'] ?? ''}');
    final plan = TextEditingController(text: '${existing['plan'] ?? ''}');
    final number = TextEditingController(text: '${existing['policyNumber'] ?? ''}');
    final note = TextEditingController(text: '${existing['note'] ?? ''}');
    DateTime? expiry = DateTime.tryParse('${existing['expiryDate'] ?? ''}');
    var saving = false;
    try {
      await showDialog<void>(context: context, builder: (dialogContext) =>
        StatefulBuilder(builder: (dialogContext, update) => AlertDialog(
          title: const Text('保單資料'),
          content: SizedBox(width: 440, child: SingleChildScrollView(child:
            Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: company,
                decoration: const InputDecoration(labelText: '保險公司')),
              TextField(controller: plan,
                decoration: const InputDecoration(labelText: '方案名稱')),
              TextField(controller: number,
                decoration: const InputDecoration(labelText: '保單號碼（選填）')),
              ListTile(contentPadding: EdgeInsets.zero,
                title: Text(expiry == null ? '到期日（選填）' :
                  '到期日：${expiry!.year}/${expiry!.month}/${expiry!.day}'),
                trailing: const Icon(Icons.calendar_month),
                onTap: saving ? null : () async {
                  final chosen = await showDatePicker(context: dialogContext,
                    initialDate: expiry ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 3650)));
                  if (chosen != null) update(() => expiry = chosen);
                }),
              TextField(controller: note, maxLines: 2,
                decoration: const InputDecoration(labelText: '保障備註（選填）')),
            ]))),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('取消')),
            FilledButton(onPressed: saving ? null : () async {
              if (company.text.trim().isEmpty || plan.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('請填寫保險公司與方案名稱')));
                return;
              }
              update(() => saving = true);
              try {
                final uid = FirebaseAuth.instance.currentUser?.uid;
                if (uid == null) throw StateError('請先登入');
                final ref = FirebaseFirestore.instance.collection('pets').doc(widget.petId);
                await FirebaseFirestore.instance.runTransaction((tx) async {
                  final pet = await tx.get(ref);
                  if (pet.data()?['owner_uid'] != uid) throw StateError('沒有保單修改權限');
                  tx.update(ref, {'insurancePolicy': {
                    'company': company.text.trim(), 'plan': plan.text.trim(),
                    'policyNumber': number.text.trim(),
                    'expiryDate': expiry == null ? '' :
                      '${expiry!.year.toString().padLeft(4, '0')}-${expiry!.month.toString().padLeft(2, '0')}-${expiry!.day.toString().padLeft(2, '0')}',
                    'note': note.text.trim(),
                  }, 'updatedAt': FieldValue.serverTimestamp()});
                });
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (error) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('保單儲存失敗：$error')));
                if (dialogContext.mounted) update(() => saving = false);
              }
            }, child: Text(saving ? '儲存中…' : '儲存')),
          ],
        )));
    } finally {
      company.dispose(); plan.dispose(); number.dispose(); note.dispose();
    }
  }

  Widget _offers(String species) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance.collection('insurance_offers').snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) return const Card(child: ListTile(
        title: Text('暫時無法讀取合作方案'), subtitle: Text('保單與理賠資料仍可使用。')));
      if (!snapshot.hasData) return const LinearProgressIndicator();
      final offers = snapshot.data!.docs.where((doc) {
        final info = doc.data();
        final kinds = (info['species'] as List?)?.map((value) => '$value').toList() ?? [];
        return info['active'] == true &&
          (kinds.isEmpty || kinds.any((kind) => species.contains(kind)));
      }).toList();
      if (offers.isEmpty) return const Card(child: ListTile(
        leading: Icon(Icons.campaign_outlined), title: Text('目前沒有上架的合作方案'),
        subtitle: Text('有正式方案資訊後才會顯示廣告。')));
      return Column(children: [for (final offer in offers)
        Card(child: ListTile(
          leading: const Icon(Icons.campaign_outlined, color: green),
          title: Text('${offer.data()['title'] ?? '方案資訊'}'),
          subtitle: Text('廣告／合作資訊 · ${offer.data()['summary'] ?? ''}',
              maxLines: 3, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            final info = offer.data();
            final url = '${info['url'] ?? ''}';
            showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
              title: Text('${info['title'] ?? '方案資訊'}'),
              content: SingleChildScrollView(child: Text(
                '廣告／合作資訊\n\n${info['summary'] ?? ''}\n\n${info['terms'] ?? ''}\n\n保障與費用以保險公司正式條款為準。')),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('關閉')),
                if (url.startsWith('https://')) TextButton(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: url));
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已複製連結，可貼到瀏覽器查看')));
                  }, child: const Text('複製方案連結')),
              ],
            ));
          },
        )),
      ]);
    },
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('寵物保險'),
      backgroundColor: green, foregroundColor: Colors.white),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('pets').doc(widget.petId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('保單讀取失敗：${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final pet = snapshot.data!.data();
        if (pet == null) return const Center(child: Text('找不到寵物資料'));
        final policy = (pet['insurancePolicy'] as Map?)?.cast<String, dynamic>() ?? {};
        final company = '${policy['company'] ?? ''}'.trim();
        final policyNumber = '${policy['policyNumber'] ?? ''}'.trim();
        final expiry = DateTime.tryParse('${policy['expiryDate'] ?? ''}');
        return ListView(padding: const EdgeInsets.all(16), children: [
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('我的保單', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(company.isEmpty ? '尚未新增保單' : '$company · ${policy['plan'] ?? ''}'),
              if (company.isNotEmpty) ...[
                Text('保單號碼：${policyNumber.isEmpty ? '未填' : policyNumber}'),
                Text(expiry == null ? '到期日未填' :
                  expiry.isBefore(DateTime.now()) ? '可能已到期' :
                  '到期日：${policy['expiryDate']}'),
                if ('${policy['note'] ?? ''}'.isNotEmpty) Text('${policy['note']}'),
              ],
              const SizedBox(height: 10),
              OutlinedButton.icon(onPressed: () => _edit(policy),
                icon: const Icon(Icons.edit_outlined),
                label: Text(company.isEmpty ? '新增保單' : '修改保單')),
            ]))),
          const SizedBox(height: 10),
          Card(child: ListTile(
            leading: const Icon(Icons.receipt_long, color: green),
            title: const Text('整理理賠資料'),
            subtitle: const Text('從已存看診紀錄挑選，供申請前核對'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => MedicalClaimSelectorPage(petId: widget.petId))),
          )),
          const SizedBox(height: 22),
          const Text('保險方案資訊', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          const Text('合作推薦會標明廣告；比較時請看等待期、除外責任、額度與續保條件。'),
          _offers('${pet['species'] ?? ''}'),
        ]);
      },
    ),
  );
}
