// lib/frontend/screens/goal_card.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GoalCard extends StatelessWidget {
  const GoalCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final nowTs = Timestamp.now();
    final goalsStream =
        FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('goals')
            .where('startDate', isLessThanOrEqualTo: nowTs)
            .orderBy('startDate', descending: true)
            .limit(1)
            .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: goalsStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 10),
            elevation: 3,
            child: ListTile(
              leading: const Icon(Icons.flag, color: Colors.grey),
              title: const Text("Loading goals..."),
            ),
          );
        }
        if (snap.hasError) {
          debugPrint("GoalCard error: ${snap.error}");
          return const SizedBox();
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 10),
            elevation: 3,
            child: ListTile(
              leading: const Icon(Icons.flag, color: Colors.green),
              title: const Text("No active goals"),
            ),
          );
        }
        final d0 = docs.first.data();
        final endTs = d0['endDate'] as Timestamp?;
        if (endTs == null || endTs.compareTo(nowTs) < 0) {
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 10),
            elevation: 3,
            child: ListTile(
              leading: const Icon(Icons.flag, color: Colors.green),
              title: const Text("No active goals"),
            ),
          );
        }

        final title = d0['goalTitle'] as String;
        final target = d0['target'] as int;
        final current = d0['current'] as int;
        final progress = target > 0 ? current / target : 0.0;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 10),
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "🎯 Weekly Goal",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(title, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Text("✅ Progress: $current / $target"),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
