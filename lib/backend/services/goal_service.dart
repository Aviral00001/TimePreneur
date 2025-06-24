// lib/backend/services/goal_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GoalService {
  // Reference to /users/{uid}/goals
  static CollectionReference<Map<String, dynamic>> get _goalsRef {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('goals');
  }

  /// Returns all goals where startDate <= now AND endDate >= now.
  static Future<List<Map<String, dynamic>>> getActiveGoals() async {
    final nowTs = Timestamp.now();

    // Only filter on startDate (<= now) at the server
    final snapshot =
        await _goalsRef.where('startDate', isLessThanOrEqualTo: nowTs).get();

    // Now filter endDate (>= now) in client code
    final activeDocs = snapshot.docs.where((doc) {
      final data = doc.data();
      final endTs = data['endDate'] as Timestamp?;
      return endTs != null && endTs.compareTo(nowTs) >= 0;
    });

    // Map to simple model
    return activeDocs.map((doc) {
      final d = doc.data();
      return {
        'id': doc.id,
        'goalTitle': d['goalTitle'] as String? ?? '',
        'target': d['target'] as int? ?? 0,
        'current': d['current'] as int? ?? 0,
      };
    }).toList();
  }

  /// (Optional) Create a new goal
  static Future<void> createGoal({
    required String title,
    required int target,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return _goalsRef.add({
      'goalTitle': title,
      'target': target,
      'current': 0,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
    });
  }
}
