import 'package:flutter/material.dart';
import 'package:timepreneur/frontend/screens/tasks_screen.dart';
import 'package:timepreneur/frontend/screens/profile_screen.dart';
import 'package:timepreneur/backend/ai/task_ranker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timepreneur/frontend/screens/smart_suggestion_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

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
                  final recommendedStart = parseToDateTime(
                    task['recommendedStartTime'],
                  );
                  final recommendedEnd = parseToDateTime(
                    task['recommendedEndTime'],
                  );

                  return ListTile(
                    title: Text(task['title']),
                    subtitle: Text(
                      'Priority: ${task['priority']} | '
                      'Deadline: ${deadline != null ? _formatDateTime(deadline) : "N/A"} | '
                      'Recommended: ${recommendedStart != null && recommendedEnd != null ? "${_formatDateTime(recommendedStart)} - ${_formatDateTime(recommendedEnd)}" : ""}',
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
      SmartSuggestionsScreen(), // ✅ New AI tab
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  String _monthName(int month) {
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
    return months[month - 1];
  }

  String _formatDateTime(DateTime dt) {
    final month = _monthName(dt.month);
    final time = TimeOfDay.fromDateTime(dt).format(context);
    return "${dt.day} $month ${dt.year}, $time";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
}
