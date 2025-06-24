import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:timepreneur/frontend/screens/tasks_screen.dart';
import 'package:timepreneur/frontend/screens/profile_screen.dart';
import 'package:timepreneur/backend/ai/task_ranker.dart';
import 'package:timepreneur/backend/services/goal_service.dart'; // ← New import
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timepreneur/frontend/screens/smart_suggestion_screen.dart';
import 'package:timepreneur/frontend/screens/goal_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _hasSeededGoal = false; // ← New flag

  DateTime? parseToDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      final iso = value.contains(' ') ? value.replaceFirst(' ', 'T') : value;
      return DateTime.tryParse(iso);
    }
    return null;
  }

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureDefaultGoal();
    });
    _pages = <Widget>[
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser!.uid)
                .collection('tasks')
                .snapshots(),
        builder: (
          context,
          AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
        ) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No tasks available"));
          }

          // build & rank tasks...
          List<Map<String, dynamic>> tasks =
              snapshot.data!.docs
                  .map((doc) {
                    final data = doc.data();
                    if (data['isCompleted'] == true) return null;
                    return {
                      'docId': doc.id,
                      'title': data['title'] ?? '',
                      'priority': data['priority'] ?? 1,
                      'deadline':
                          DateTime.tryParse(
                            data['deadline']?.toString() ?? '',
                          ) ??
                          DateTime.now(),
                      'recommendedStartTime':
                          data['recommendedStartTime'] is Timestamp
                              ? (data['recommendedStartTime'] as Timestamp)
                                  .toDate()
                              : null,
                      'recommendedEndTime':
                          data['recommendedEndTime'] is Timestamp
                              ? (data['recommendedEndTime'] as Timestamp)
                                  .toDate()
                              : null,
                      'duration': data['duration'] ?? 30,
                    };
                  })
                  .whereType<Map<String, dynamic>>()
                  .toList();

          final rankedTasks = TaskRanker().getTopSuggestions(tasks);

          // write back recommendations...
          for (var task in rankedTasks) {
            if (task.containsKey('docId')) {
              try {
                final start = parseToDateTime(task['recommendedStartTime']);
                final end = parseToDateTime(task['recommendedEndTime']);
                if (start != null && end != null) {
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser!.uid)
                      .collection('tasks')
                      .doc(task['docId'])
                      .update({
                        'recommendedStartTime': Timestamp.fromDate(start),
                        'recommendedEndTime': Timestamp.fromDate(end),
                      });
                }
              } catch (e) {
                debugPrint('Error parsing recommendation times: $e');
              }
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GoalCard(), // ← Show goal card
                const SizedBox(height: 12),
                const Text(
                  'Welcome to TimePreneur!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Top Smart Suggestions:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ...rankedTasks.take(3).map((task) {
                  final deadline = parseToDateTime(task['deadline']);
                  final recStart = parseToDateTime(
                    task['recommendedStartTime'],
                  );
                  final recEnd = parseToDateTime(task['recommendedEndTime']);
                  return ListTile(
                    title: Text(task['title']),
                    subtitle: Text(
                      'Priority: ${task['priority']} | '
                      'Deadline: ${deadline != null ? _formatDateTime(deadline) : "N/A"} | '
                      'Recommended: ${recStart != null && recEnd != null ? "${_formatDateTime(recStart)} - ${_formatDateTime(recEnd)}" : ""}',
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
      TasksScreen(),
      ProfileScreen(),
      SmartSuggestionsScreen(),
    ];
  }

  /// Seeds a default weekly goal if none exists
  Future<void> _ensureDefaultGoal() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    debugPrint('🔸 ensureDefaultGoal() called for uid=$uid');
    final goalsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('goals');

    final snapshot = await goalsRef.limit(1).get();
    debugPrint('🔸 existing goals count: ${snapshot.docs.length}');
    if (snapshot.docs.isEmpty && !_hasSeededGoal) {
      _hasSeededGoal = true;
      final now = DateTime.now();
      // Monday of this week:
      final startOfWeek = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1));
      // Sunday 23:59:
      final endOfWeek = startOfWeek.add(
        const Duration(days: 6, hours: 23, minutes: 59),
      );

      debugPrint('🔸 creating default goal from $startOfWeek → $endOfWeek');
      await GoalService.createGoal(
        title: 'Complete 5 tasks',
        target: 5,
        startDate: startOfWeek,
        endDate: endOfWeek,
      );
      debugPrint('✅ default goal created');
      setState(() {}); // refresh GoalCard stream subscription
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  String _monthName(int m) {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return months[m - 1];
  }

  String _formatDateTime(DateTime dt) {
    final month = _monthName(dt.month);
    final time = TimeOfDay.fromDateTime(dt).format(context);
    return "${dt.day} $month ${dt.year}, $time";
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("TimePreneur")),
    body: IndexedStack(index: _selectedIndex, children: _pages),
    bottomNavigationBar: BottomNavigationBar(
      currentIndex: _selectedIndex,
      selectedItemColor: Colors.deepPurple,
      onTap: _onItemTapped,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.task), label: 'Tasks'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        BottomNavigationBarItem(
          icon: Icon(Icons.lightbulb_outline),
          label: 'AI',
        ),
      ],
    ),
  );
}
