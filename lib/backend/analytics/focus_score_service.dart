// focus_score_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class FocusScoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> recordFocusScore({
    required String userId,
    required DateTime date,
    required int completedTasks,
    required int plannedTasks,
  }) async {
    final formattedDate =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final double score =
        plannedTasks > 0 ? (completedTasks / plannedTasks) * 100 : 0;

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('analytics')
        .doc(formattedDate)
        .set({
          'date': formattedDate,
          'focusScore': score,
          'tasksCompleted': completedTasks,
          'tasksPlanned': plannedTasks,
          'timestamp': FieldValue.serverTimestamp(),
        });
  }

  Future<Map<String, dynamic>?> getFocusScoreForDate({
    required String userId,
    required DateTime date,
  }) async {
    final formattedDate =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final doc =
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('analytics')
            .doc(formattedDate)
            .get();

    return doc.exists ? doc.data() : null;
  }
}
