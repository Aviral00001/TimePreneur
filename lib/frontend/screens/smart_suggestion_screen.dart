import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timepreneur/backend/ai/gpt_service.dart'; // ✅ Adjust path if needed

class SmartSuggestionsScreen extends StatefulWidget {
  @override
  _SmartSuggestionsScreenState createState() => _SmartSuggestionsScreenState();
}

class _SmartSuggestionsScreenState extends State<SmartSuggestionsScreen> {
  String? aiResponse;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchAndAskGPT();
  }

  Future<void> _fetchAndAskGPT() async {
    setState(() => isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('tasks')
              .where('isCompleted', isEqualTo: false)
              .get();

      final tasks =
          snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              "title": data['title'] ?? '',
              "priority": data['priority'] ?? 3,
              "duration": data['duration'] ?? 1.0,
              "deadline":
                  data['deadline']?.toDate().toIso8601String() ?? 'unspecified',
            };
          }).toList();

      final result = await GPTService.getSmartSuggestions(tasks);
      setState(() => aiResponse = result);
    } catch (e) {
      setState(() => aiResponse = "❌ Failed to fetch suggestions.\n$e");
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Smart Suggestions")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child:
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : aiResponse != null
                ? Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      aiResponse!,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                )
                : const Center(child: Text("No suggestions available.")),
      ),
    );
  }
}
