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

  /// Returns a list of top task suggestions sorted by highest score
  List<Map<String, dynamic>> getTopSuggestions(
    List<Map<String, dynamic>> tasks, {
    int topN = 5,
  }) {
    List<Map<String, dynamic>> scoredTasks =
        tasks.map((task) {
          final score = calculateTaskScore(
            priority: task['priority'] ?? 1,
            deadline: task['deadline'] ?? DateTime.now().add(Duration(days: 1)),
          );
          return {...task, 'score': score};
        }).toList();

    scoredTasks.sort((a, b) => b['score'].compareTo(a['score']));

    return scoredTasks.take(topN).toList();
  }
}
