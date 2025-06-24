import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class TasksScreen extends StatefulWidget {
  TasksScreen({Key? key}) : super(key: key);

  @override
  _TasksScreenState createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  Set<String> selectedTaskIds = {};

  @override
  Widget build(BuildContext context) {
    final isSelectionMode = selectedTaskIds.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Tasks"),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'delete_selected') {
                await _deleteSelectedTasks();
              } else if (value == 'delete_all') {
                await clearSampleTasks();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("All tasks cleared")),
                );
              }
            },
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    value: 'delete_selected',
                    enabled: selectedTaskIds.isNotEmpty,
                    child: const Text("Delete Selected Tasks"),
                  ),
                  const PopupMenuItem(
                    value: 'delete_all',
                    child: Text("Delete All Tasks"),
                  ),
                ],
            icon: const Icon(Icons.delete),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser!.uid)
                .collection('tasks')
                .orderBy("timestamp", descending: true)
                .snapshots(),
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

          final incompleteTasks =
              tasks.where((t) {
                final data = t.data() as Map<String, dynamic>?;
                return data?['isCompleted'] != true;
              }).toList();

          final completedTasks =
              tasks.where((t) {
                final data = t.data() as Map<String, dynamic>?;
                return data?['isCompleted'] == true;
              }).toList();

          // ... your sorting logic for incompleteTasks & completedTasks ...

          return ListView(
            children: [
              // Incomplete Tasks
              ...incompleteTasks.map((task) {
                final data = task.data() as Map<String, dynamic>?;
                final isSelected = selectedTaskIds.contains(task.id);
                final title = data?['title'] ?? 'No Title';
                final priority = data?['priority'] ?? 'N/A';
                final deadline =
                    data?['deadline'] is Timestamp
                        ? DateFormat(
                          'yyyy MMM d, h:mm a',
                        ).format((data!['deadline'] as Timestamp).toDate())
                        : data?['deadline']?.toString() ?? '';
                final isCompleted = data?['isCompleted'] == true;

                return ListTile(
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: isCompleted,
                        onChanged: (checked) async {
                          final uid = FirebaseAuth.instance.currentUser!.uid;
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(uid)
                              .collection('tasks')
                              .doc(task.id)
                              .update({'isCompleted': checked});

                          if (checked == true) {
                            // --- Analytics update (your existing code) ---
                            final now = DateTime.now();
                            final dateKey =
                                "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
                            final analyticsRef = FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid)
                                .collection('analytics')
                                .doc(dateKey);
                            final doc = await analyticsRef.get();
                            if (doc.exists) {
                              analyticsRef.update({
                                'completedTasks': FieldValue.increment(1),
                                'totalTasks': FieldValue.increment(0),
                              });
                            } else {
                              analyticsRef.set({
                                'completedTasks': 1,
                                'totalTasks': 0,
                              });
                            }

                            // --- Update active weekly goals ---
                            try {
                              final goalsRef = FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(uid)
                                  .collection('goals');
                              final querySnapshot =
                                  await goalsRef
                                      .where(
                                        'startDate',
                                        isLessThanOrEqualTo: Timestamp.now(),
                                      )
                                      .get();
                              final nowTs = Timestamp.now();
                              for (var goalDoc in querySnapshot.docs) {
                                final data = goalDoc.data();
                                final endTs = data['endDate'] as Timestamp?;
                                if (endTs != null &&
                                    endTs.compareTo(nowTs) >= 0) {
                                  await goalsRef.doc(goalDoc.id).update({
                                    'current': FieldValue.increment(1),
                                  });
                                }
                              }
                            } catch (e) {
                              print("Failed to update goal progress: $e");
                            }
                          }
                        },
                      ),
                      if (isSelectionMode)
                        Checkbox(
                          value: isSelected,
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                selectedTaskIds.add(task.id);
                              } else {
                                selectedTaskIds.remove(task.id);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                  title: Text(title),
                  subtitle: Text('Priority: $priority\nDeadline: $deadline'),
                  trailing:
                      isSelectionMode
                          ? null
                          : PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'edit') {
                                _showTaskDialog(context, task);
                              } else {
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(FirebaseAuth.instance.currentUser!.uid)
                                    .collection('tasks')
                                    .doc(task.id)
                                    .delete();
                              }
                            },
                            itemBuilder:
                                (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                          ),
                  onLongPress: () {
                    setState(() {
                      if (isSelected) {
                        selectedTaskIds.remove(task.id);
                      } else {
                        selectedTaskIds.add(task.id);
                      }
                    });
                  },
                );
              }),

              // Divider before completed tasks
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  "Completed Tasks",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),

              // Completed Tasks
              ...completedTasks.map((task) {
                final data = task.data() as Map<String, dynamic>?;
                final isSelected = selectedTaskIds.contains(task.id);
                final title = data?['title'] ?? 'No Title';
                final priority = data?['priority'] ?? 'N/A';
                final deadline =
                    data?['deadline'] is Timestamp
                        ? DateFormat(
                          'yyyy MMM d, h:mm a',
                        ).format((data!['deadline'] as Timestamp).toDate())
                        : data?['deadline']?.toString() ?? '';
                final isCompleted = data?['isCompleted'] == true;

                return ListTile(
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: isCompleted,
                        onChanged: (checked) async {
                          final uid = FirebaseAuth.instance.currentUser!.uid;
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(uid)
                              .collection('tasks')
                              .doc(task.id)
                              .update({'isCompleted': checked});

                          if (checked == true) {
                            // --- Analytics update ---
                            final now = DateTime.now();
                            final dateKey =
                                "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
                            final analyticsRef = FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid)
                                .collection('analytics')
                                .doc(dateKey);
                            final doc = await analyticsRef.get();
                            if (doc.exists) {
                              analyticsRef.update({
                                'completedTasks': FieldValue.increment(1),
                                'totalTasks': FieldValue.increment(0),
                              });
                            } else {
                              analyticsRef.set({
                                'completedTasks': 1,
                                'totalTasks': 0,
                              });
                            }

                            // --- Update active weekly goals ---
                            try {
                              final goalsRef = FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(uid)
                                  .collection('goals');
                              final querySnapshot =
                                  await goalsRef
                                      .where(
                                        'startDate',
                                        isLessThanOrEqualTo: Timestamp.now(),
                                      )
                                      .get();
                              final nowTs = Timestamp.now();
                              for (var goalDoc in querySnapshot.docs) {
                                final data = goalDoc.data();
                                final endTs = data['endDate'] as Timestamp?;
                                if (endTs != null &&
                                    endTs.compareTo(nowTs) >= 0) {
                                  await goalsRef.doc(goalDoc.id).update({
                                    'current': FieldValue.increment(1),
                                  });
                                }
                              }
                            } catch (e) {
                              print("Failed to update goal progress: $e");
                            }
                          }
                        },
                      ),
                      if (isSelectionMode)
                        Checkbox(
                          value: isSelected,
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                selectedTaskIds.add(task.id);
                              } else {
                                selectedTaskIds.remove(task.id);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                  title: Text(
                    title,
                    style: const TextStyle(
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  subtitle: Text('Priority: $priority\nDeadline: $deadline'),
                  trailing:
                      isSelectionMode
                          ? null
                          : PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'edit') {
                                _showTaskDialog(context, task);
                              } else {
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(FirebaseAuth.instance.currentUser!.uid)
                                    .collection('tasks')
                                    .doc(task.id)
                                    .delete();
                              }
                            },
                            itemBuilder:
                                (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                          ),
                  onLongPress: () {
                    setState(() {
                      if (isSelected) {
                        selectedTaskIds.remove(task.id);
                      } else {
                        selectedTaskIds.add(task.id);
                      }
                    });
                  },
                );
              }),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showTaskDialog(context, null),
      ),
    );
  }

  Future<void> _deleteSelectedTasks() async {
    if (selectedTaskIds.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final tasksCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('tasks');
    final batch = FirebaseFirestore.instance.batch();
    for (final taskId in selectedTaskIds) {
      final docRef = tasksCollection.doc(taskId);
      batch.delete(docRef);
    }
    await batch.commit();
    setState(() {
      selectedTaskIds.clear();
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Selected tasks deleted")));
  }

  Future<void> clearSampleTasks() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final tasksCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('tasks');
    final snapshot = await tasksCollection.get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    setState(() {
      selectedTaskIds.clear();
    });
  }

  Future<void> _showTaskDialog(
    BuildContext context,
    DocumentSnapshot? task,
  ) async {
    final taskData = task?.data() as Map<String, dynamic>? ?? {};
    final titleController = TextEditingController(
      text: taskData.containsKey('title') ? taskData['title'] : '',
    );
    final descriptionController = TextEditingController(
      text: taskData.containsKey('description') ? taskData['description'] : '',
    );
    final deadlineController = TextEditingController(
      text:
          taskData.containsKey('deadline')
              ? (taskData['deadline'] is Timestamp
                  ? (taskData['deadline'] as Timestamp).toDate().toString()
                  : taskData['deadline'].toString())
              : '',
    );
    final durationController = TextEditingController(
      text:
          taskData.containsKey('duration')
              ? taskData['duration'].toString()
              : '',
    );

    int priorityValue =
        taskData.containsKey('priority') ? taskData['priority'] : 3;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(task == null ? "Add New Task" : "Edit Task"),
              content: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: "Title"),
                      autofocus: true,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: "Description",
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: deadlineController,
                      readOnly: true,
                      decoration: const InputDecoration(labelText: "Deadline"),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (date != null) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (time != null) {
                            final dateTime = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            );
                            setStateDialog(() {
                              deadlineController.text = dateTime.toString();
                            });
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Priority: ${priorityValue} (${_priorityLabel(priorityValue)})",
                        ),
                        Slider(
                          value: priorityValue.toDouble(),
                          min: 1,
                          max: 5,
                          divisions: 4,
                          label: priorityValue.toString(),
                          onChanged: (value) {
                            setStateDialog(() {
                              priorityValue = value.round();
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Duration: ${durationController.text.isEmpty ? '1.0' : durationController.text} hrs",
                        ),
                        Slider(
                          value:
                              double.tryParse(durationController.text) ?? 1.0,
                          min: 0.5,
                          max: 12.0,
                          divisions: 23,
                          label:
                              "${double.tryParse(durationController.text) ?? 1.0} hrs",
                          onChanged: (value) {
                            setStateDialog(() {
                              durationController.text = value.toStringAsFixed(
                                1,
                              );
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
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
                      final uid = FirebaseAuth.instance.currentUser!.uid;
                      final tasksCollection = FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .collection('tasks');
                      if (task == null) {
                        await tasksCollection.add({
                          "title": titleController.text,
                          "description": descriptionController.text,
                          "deadline":
                              deadlineController.text.isNotEmpty
                                  ? Timestamp.fromDate(
                                    DateTime.parse(deadlineController.text),
                                  )
                                  : "",
                          "priority": priorityValue,
                          "duration":
                              double.tryParse(durationController.text) ?? 1.0,
                          "isCompleted": false,
                          "timestamp": FieldValue.serverTimestamp(),
                          "recommendedStartTime": "",
                          "recommendedEndTime": "",
                        });
                        // Log the task creation for adaptive scheduling
                        try {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(uid)
                              .collection('adaptiveLogs')
                              .add({
                                'taskTitle': titleController.text,
                                'priority': priorityValue,
                                'timestamp': FieldValue.serverTimestamp(),
                                'completedInMinutes':
                                    null, // placeholder to be updated later
                              });
                        } catch (e) {
                          print('Failed to log to adaptiveLogs: $e');
                        }
                      } else {
                        await tasksCollection.doc(task.id).update({
                          "title": titleController.text,
                          "description": descriptionController.text,
                          "deadline":
                              deadlineController.text.isNotEmpty
                                  ? Timestamp.fromDate(
                                    DateTime.parse(deadlineController.text),
                                  )
                                  : "",
                          "priority": priorityValue,
                          "duration":
                              double.tryParse(durationController.text) ?? 1.0,
                        });
                        // Optionally, you could update the adaptive log if you want to track updates
                      }
                      Navigator.of(context).pop(); // Close dialog
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Cannot add/edit task. Title is required.',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: Text(task == null ? "Add" : "Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _priorityLabel(int p) {
    if (p <= 2) return "Low";
    if (p == 3) return "Medium";
    return "High";
  }
}
