import 'package:flutter/material.dart';
import '../../backend/google_calendar_service.dart';

class CalendarViewScreen extends StatefulWidget {
  const CalendarViewScreen({Key? key}) : super(key: key);

  @override
  _CalendarViewScreenState createState() => _CalendarViewScreenState();
}

class _CalendarViewScreenState extends State<CalendarViewScreen> {
  final GoogleCalendarService _calendarService = GoogleCalendarService();
  List<dynamic> _events = [];
  bool _loading = false;
  String? _errorMessage;

  Future<void> _handleSignInAndFetchEvents() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final token = await _calendarService.signInAndGetAuthToken();
      if (token == null) {
        setState(() {
          _errorMessage = "Sign in cancelled or failed";
          _loading = false;
        });
        return;
      }
      final events = await _calendarService.fetchCalendarEvents(token);
      setState(() {
        _events = events;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Google Calendar Events")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(child: Text(_errorMessage!))
                : _events.isNotEmpty
                ? ListView.builder(
                  itemCount: _events.length,
                  itemBuilder: (context, index) {
                    final event = _events[index];
                    final eventTitle = event['summary'] ?? 'No Title';
                    final eventStart =
                        event['start']?['dateTime'] ??
                        event['start']?['date'] ??
                        '';
                    return ListTile(
                      title: Text(eventTitle),
                      subtitle: Text(eventStart.toString()),
                    );
                  },
                )
                : Center(
                  child: const Text(
                    "No events found. Press the button to sign in and load events.",
                  ),
                ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _handleSignInAndFetchEvents,
        child: const Icon(Icons.calendar_today),
      ),
    );
  }
}
