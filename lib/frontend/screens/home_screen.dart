import 'package:flutter/material.dart';
import 'package:timepreneur/frontend/screens/tasks_screen.dart';
import 'package:timepreneur/frontend/screens/profile_screen.dart';
import 'package:timepreneur/backend/ai/task_ranker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _pages = <Widget>[
    StreamBuilder(
      stream:
          FirebaseFirestore.instance
              .collection('users')
              .doc(FirebaseAuth.instance.currentUser!.uid)
              .collection('tasks')
              .snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No tasks available"));
        }

        List<Map<String, dynamic>> tasks =
            snapshot.data!.docs
                .map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  if (data['isCompleted'] == true) return null;
                  return {
                    'title': data['title'] ?? '',
                    'priority': data['priority'] ?? 1,
                    'deadline':
                        (data['deadline'] is Timestamp)
                            ? (data['deadline'] as Timestamp).toDate()
                            : DateTime.now(),
                  };
                })
                .whereType<Map<String, dynamic>>()
                .toList();

        final rankedTasks = TaskRanker().getTopSuggestions(tasks);

        return Padding(
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
              ...rankedTasks
                  .take(3)
                  .map(
                    (task) => ListTile(
                      title: Text(task['title']),
                      subtitle: Text(
                        'Priority: ${task['priority']} | Deadline: ${task['deadline']}',
                      ),
                    ),
                  ),
            ],
          ),
        );
      },
    ),
    TasksScreen(), // Tasks page
    ProfileScreen(), // Profile page
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("TimePreneur")),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.deepPurple,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.task), label: 'Tasks'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
