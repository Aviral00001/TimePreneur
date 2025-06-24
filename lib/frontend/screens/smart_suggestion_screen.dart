import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timepreneur/backend/ai/gpt_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SmartSuggestionsScreen extends StatefulWidget {
  @override
  _SmartSuggestionsScreenState createState() => _SmartSuggestionsScreenState();
}

class _SmartSuggestionsScreenState extends State<SmartSuggestionsScreen> {
  String? aiResponse;
  String? _cachedResponse;
  bool isLoading = false;
  final ScrollController _scrollController = ScrollController();
  bool _disposed = false;
  DateTime? _lastRetryTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFromCache();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('ai_response_cache');
    if (cached != null && !_disposed) {
      setState(() {
        aiResponse = cached;
        _cachedResponse = cached;
        isLoading = false;
      });
    } else {
      _fetchAndAskGPT();
    }
  }

  Future<void> _fetchAndAskGPT() async {
    if (_disposed) return;

    setState(() {
      isLoading = true;
      aiResponse = null;
    });

    List<Map<String, dynamic>> tasks = [];

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('tasks')
              .where('isCompleted', isEqualTo: false)
              .get();

      tasks =
          snapshot.docs.take(8).map((doc) {
            final data = doc.data();
            return {
              "title": data['title'] ?? '',
              "priority": data['priority'] ?? 3,
              "duration": data['duration'] ?? 1.0,
              "deadline":
                  data['deadline']?.toDate().toIso8601String() ?? 'unspecified',
            };
          }).toList();
    } catch (e) {
      if (_disposed) return;
      setState(() {
        aiResponse = "❌ Failed to fetch tasks from Firebase.\n$e";
        isLoading = false;
      });
      return;
    }

    try {
      final result = await GPTService.getSmartSuggestions(
        tasks,
      ).timeout(const Duration(seconds: 12));
      if (_disposed) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ai_response_cache', result);

      _cachedResponse = result;
      setState(() => aiResponse = result);
    } catch (e) {
      if (_disposed) return;
      setState(() => aiResponse = "❌ Failed to fetch suggestions.\n$e");
    } finally {
      if (_disposed) return;
      setState(() => isLoading = false);
    }
  }

  void _retry() {
    final now = DateTime.now();
    if (_lastRetryTime == null ||
        now.difference(_lastRetryTime!) > Duration(seconds: 5)) {
      _lastRetryTime = now;
      _fetchAndAskGPT();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⏳ Please wait before retrying...")),
      );
    }
  }

  Future<void> _clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ai_response_cache');
    setState(() {
      _cachedResponse = null;
      aiResponse = null;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("🧹 Cache cleared.")));
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
                ? Column(
                  children: [
                    Expanded(
                      child: Scrollbar(
                        thumbVisibility: true,
                        controller: _scrollController,
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            aiResponse!,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _fetchAndAskGPT,
                          icon: Icon(Icons.refresh),
                          label: Text("Refresh Suggestions"),
                        ),
                        ElevatedButton.icon(
                          onPressed: _clearCache,
                          icon: Icon(Icons.delete_forever),
                          label: Text("Clear Cache"),
                        ),
                      ],
                    ),
                  ],
                )
                : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("No suggestions available."),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _retry,
                      child: const Text("Retry"),
                    ),
                    ElevatedButton(
                      onPressed: _clearCache,
                      child: const Text("Clear Cache"),
                    ),
                  ],
                ),
      ),
    );
  }
}
