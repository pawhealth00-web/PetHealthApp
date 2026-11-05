import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'health_insights.dart';
import 'record_detail_page.dart';
import 'record_presentation.dart';

class CategoryHistoryPage extends StatelessWidget {
  const CategoryHistoryPage({super.key, required this.petId, required this.category});

  final String petId;
  final String category;

  String get _title => const {
    'diet': '飲食', 'poop': '排便', 'behavior': '行為', 'medical': '醫療',
  }[category] ?? '健康';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$_title紀錄歷史'),
          backgroundColor: const Color(0xFF2E7D5B), foregroundColor: Colors.white),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('health_records')
            .where('petId', isEqualTo: petId).snapshots(),
        builder: (context, health) {
          if (health.hasError) return Center(child: Text('讀取失敗：${health.error}'));
          if (!health.hasData) return const Center(child: CircularProgressIndicator());
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('pets').doc(petId)
                .collection('behavior_records').snapshots(),
            builder: (context, behavior) {
              if (behavior.hasError) return Center(child: Text('讀取失敗：${behavior.error}'));
              if (!behavior.hasData) return const Center(child: CircularProgressIndicator());
              final all = [...health.data!.docs, ...behavior.data!.docs];
              final docs = all.where((doc) {
                final type = HealthInsights.type(doc.data());
                return category == 'medical'
                    ? type == 'medical' || type == 'vaccine' : type == category;
              }).toList()..sort((a, b) => HealthInsights.date(b.data())
                  .compareTo(HealthInsights.date(a.data())));
              if (docs.isEmpty) return Center(child: Text('目前沒有$_title紀錄'));
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final date = HealthInsights.date(doc.data());
                  return ListTile(
                    title: Text(RecordPresentation.title(doc.data())),
                    subtitle: Text('${date.year}/${date.month}/${date.day} · '
                        '${RecordPresentation.subtitle(doc.data())}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => RecordDetailPage(reference: doc.reference, petId: petId))),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
