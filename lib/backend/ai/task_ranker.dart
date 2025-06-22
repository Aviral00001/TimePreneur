import 'package:intl/intl.dart';

class TaskRanker {
  /// Calculates a score for each task based on priority and deadline proximity.
  /// Lower deadline (i.e., sooner) and higher priority increases the score.
  double calculateTaskScore({
    required int priority, // 1 (low) to 3 (high)
    required DateTime deadline,
    int? duration,
  }) {
    final now = DateTime.now();
    final timeLeft = deadline.difference(now).inHours;

    // Normalize time left: less time = higher score boost
    double urgencyFactor = timeLeft <= 0 ? 1.5 : 1 / (timeLeft / 24 + 1);

    // Priority multiplier
    double priorityFactor = priority.toDouble();

    // Duration factor: shorter tasks get a small boost
    double durationFactor = duration != null ? (1 / (duration + 1)) : 1;

    return urgencyFactor * priorityFactor * durationFactor;
  }

  /// Returns a list of top task suggestions sorted by highest score.
  /// Each task includes a recommended time window based on its priority.
  List<Map<String, dynamic>> getTopSuggestions(
    List<Map<String, dynamic>> tasks, {
    int topN = 5,
  }) {
    final formatter = DateFormat(
      'd MMM yyyy, h:mm a',
    ); // e.g. "22 Jun 2025, 7:05 PM"

    List<Map<String, dynamic>> scoredTasks =
        tasks.map((task) {
          final priority = task['priority'] ?? 1;
          final rawDeadline = task['deadline'];
          final duration = (task['duration'] ?? 1).toInt();
          final deadline =
              rawDeadline is DateTime
                  ? rawDeadline
                  : DateTime.tryParse(rawDeadline.toString()) ??
                      DateTime.now().add(Duration(days: 1));
          final score = calculateTaskScore(
            priority: priority,
            deadline: deadline,
            duration: duration,
          );

          // Calculate recommended time range based on priority and duration
          final int hoursBefore = (6 - priority).clamp(1, 5).toInt();
          final recommendedStartTime = deadline.subtract(
            Duration(hours: hoursBefore),
          );
          final recommendedEndTime = recommendedStartTime.add(
            Duration(hours: duration),
          );

          return {
            ...task,
            'score': score,
            'recommendedStartTime': recommendedStartTime,
            'recommendedEndTime': recommendedEndTime,
          };
        }).toList();

    scoredTasks.sort((a, b) => b['score'].compareTo(a['score']));

    return scoredTasks.take(topN).toList();
  }
}
