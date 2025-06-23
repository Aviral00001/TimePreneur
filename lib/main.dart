import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'frontend/screens/home_screen.dart';
import 'frontend/screens/login_screen.dart';
import 'frontend/screens/setup_profile_screen.dart';
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(); // ⬅️ Load .env file
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TimePreneur',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final user = snapshot.data;
          if (user == null) {
            return const LoginScreen();
          } else if (user.displayName == null || user.displayName!.isEmpty) {
            return const SetupProfileScreen();
          } else {
            return const HomeScreen();
          }
        },
      ),
    );
  }
}
