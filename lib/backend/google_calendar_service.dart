import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GoogleCalendarService {
  // Specify the OAuth scopes you need.
  // For read-only access to calendar events, use:
  static final List<String> scopes = <String>[
    'email',
    'profile',
    'https://www.googleapis.com/auth/calendar.readonly',
    // If you need to manage events (create, update, delete), use:
    // 'https://www.googleapis.com/auth/calendar'
  ];

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: scopes);

  /// Initiates Google sign-in and returns the access token.
  Future<String?> signInAndGetAuthToken() async {
    try {
      // Start the sign-in process.
      final account = await _googleSignIn.signIn();
      if (account == null) {
        // User cancelled the sign-in.
        return null;
      }
      final auth = await account.authentication;
      // The accessToken can now be used to make authorized calls to the Google Calendar API.
      return auth.accessToken;
    } catch (error) {
      print("Google Sign-In Error: $error");
      return null;
    }
  }

  /// Example: Fetches calendar events using the obtained access token.
  Future<List<dynamic>> fetchCalendarEvents(String accessToken) async {
    final url = Uri.parse(
      'https://www.googleapis.com/calendar/v3/calendars/primary/events',
    );
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['items'] ?? [];
    } else {
      throw Exception('Failed to load calendar events: ${response.body}');
    }
  }
}
