import 'package:intl/intl.dart';

class TaskRanker {
  /// Calculates a score for each task based on priority and deadline proximity.
  /// Lower deadline (i.e., sooner) and higher priority increases the score.
  double calculateTaskScore({
    required int priority, // 1 (low) to 3 (high)
    required DateTime deadline,
  }) {
    final now = DateTime.now();
    final timeLeft = deadline.difference(now).inHours;

    // Normalize time left: less time = higher score boost
    double urgencyFactor = timeLeft <= 0 ? 1.5 : 1 / (timeLeft / 24 + 1);

    // Priority multiplier
    double priorityFactor = priority.toDouble();

    return urgencyFactor * priorityFactor;
  }

  /// Returns a list of top task suggestions sorted by highest score.
  /// Each task includes a recommended time window based on its priority.
  List<Map<String, dynamic>> getTopSuggestions(
    List<Map<String, dynamic>> tasks, {
    int topN = 5,
  }) {
    final formatter = DateFormat.jm(); // e.g. "5:08 PM"

    List<Map<String, dynamic>> scoredTasks =
        tasks.map((task) {
          final priority = task['priority'] ?? 1;
          final deadline =
              task['deadline'] ?? DateTime.now().add(Duration(days: 1));
          final score = calculateTaskScore(
            priority: priority,
            deadline: deadline,
          );

          // Calculate recommended time range based on priority
          final int hoursBefore = (6 - priority).clamp(1, 5).toInt();
          final recommendedStartTime = deadline.subtract(
            Duration(hours: hoursBefore),
          );
          final recommendedEndTime = recommendedStartTime.add(
            const Duration(hours: 1),
          );

          return {
            ...task,
            'score': score,
            'recommendedStartTime': formatter.format(recommendedStartTime),
            'recommendedEndTime': formatter.format(recommendedEndTime),
          };
        }).toList();

    scoredTasks.sort((a, b) => b['score'].compareTo(a['score']));

    return scoredTasks.take(topN).toList();
  }
}
