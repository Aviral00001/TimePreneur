import 'package:cloud_firestore/cloud_firestore.dart';

class SmartSuggestionEngine {
  final CollectionReference tasksRef = FirebaseFirestore.instance.collection(
    'tasks',
  );

  Future<List<Map<String, dynamic>>> getSuggestedTasks() async {
    final snapshot =
        await tasksRef.orderBy('timestamp', descending: true).limit(20).get();

    final tasks =
        snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

    // Suggest tasks with high priority or approaching deadlines
    final now = DateTime.now();
    final suggestions =
        tasks.where((task) {
          final deadline = (task['deadline'] as Timestamp?)?.toDate();
          final priority = task['priority'];
          return (priority == 'High' ||
              (deadline != null && deadline.difference(now).inHours < 24));
        }).toList();

    return suggestions;
  }
}
