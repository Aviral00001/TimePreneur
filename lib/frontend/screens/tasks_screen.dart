import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TasksScreen extends StatelessWidget {
  TasksScreen({Key? key}) : super(key: key);

  // Reference to the "tasks" collection in Firestore
  final CollectionReference tasksCollection = FirebaseFirestore.instance
      .collection('tasks');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Tasks"),
        actions: [
          // Add clear button in AppBar actions
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              await clearSampleTasks();
              // Show a SnackBar as a confirmation
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text("Tasks cleared")));
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            tasksCollection.orderBy("timestamp", descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text("Error loading tasks"));
          }

          final tasks = snapshot.data?.docs;
          if (tasks == null || tasks.isEmpty) {
            return const Center(child: Text("No tasks found."));
          }

          return ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              var task = tasks[index];
              return ListTile(
                title: Text(task["title"] ?? "No Title"),
                subtitle: Text(task["description"] ?? ""),
                trailing: Text(
                  task["timestamp"] != null
                      ? (task["timestamp"] as Timestamp).toDate().toString()
                      : "",
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showAddTaskDialog(context),
      ),
    );
  }

  Future<void> clearSampleTasks() async {
    final snapshot = await tasksCollection.get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> _showAddTaskDialog(BuildContext context) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add New Task"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: "Title"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: "Description"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cancel
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isNotEmpty) {
                  await tasksCollection.add({
                    "title": titleController.text,
                    "description": descriptionController.text,
                    "timestamp": FieldValue.serverTimestamp(),
                  });
                }
                Navigator.of(context).pop(); // Close dialog
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }
}
