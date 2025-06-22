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

    final workStartHour = 8;
    final workEndHour = 20;

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

    // Sort by score descending
    scoredTasks.sort((a, b) => b['score'].compareTo(a['score']));

    // Track occupied time windows to avoid overlaps
    List<Map<String, DateTime>> scheduledWindows = [];

    for (var task in scoredTasks) {
      DateTime start = task['recommendedStartTime'];
      DateTime end = task['recommendedEndTime'];
      final int duration = (task['duration'] ?? 1).toInt();

      // Shift time if it overlaps with existing tasks or is outside work hours
      while (scheduledWindows.any(
            (window) =>
                start.isBefore(window['end']!) && end.isAfter(window['start']!),
          ) ||
          start.hour < workStartHour ||
          end.hour > workEndHour) {
        start = start.add(Duration(hours: 1));
        end = start.add(Duration(hours: duration));
      }

      // Update the task's time window
      task['recommendedStartTime'] = start;
      task['recommendedEndTime'] = end;

      scheduledWindows.add({'start': start, 'end': end});
    }

    return scoredTasks.take(topN).toList();
  }
}
