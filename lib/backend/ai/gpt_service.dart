import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GPTService {
  static final _apiKey = dotenv.env['OPENAI_API_KEY'];
  static const _endpoint = "https://api.openai.com/v1/chat/completions";

  static Future<String> getSmartSuggestions(
    List<Map<String, dynamic>> tasks,
  ) async {
    final prompt = _buildPrompt(tasks);
    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "model": "gpt-4o",
        "messages": [
          {"role": "system", "content": "You are a productivity assistant."},
          {"role": "user", "content": prompt},
        ],
        "max_tokens": 230,
        "temperature": 0.7,
      }),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return decoded['choices'][0]['message']['content'];
    } else {
      print("❌ OpenAI API Error: ${response.statusCode}, ${response.body}");
      return "Failed to get suggestions.";
    }
  }

  static String _buildPrompt(List<Map<String, dynamic>> tasks) {
    final buffer = StringBuffer(
      "You are a helpful productivity assistant. The user has the following uncompleted tasks. For each task, the details include title, priority, and deadline:\n\n",
    );
    for (final task in tasks) {
      final title = task['title'] ?? 'No Title';
      final priority = task['priority']?.toString() ?? 'N/A';
      final deadline = task['deadline']?.toString() ?? 'N/A';
      buffer.writeln("- $title (Priority: $priority, Deadline: $deadline)");
    }
    buffer.writeln(
      "\nBriefly help the user decide how to approach completing these tasks efficiently, including suggestions on what to prioritize and when to take a break.",
    );
    return buffer.toString();
  }
}
