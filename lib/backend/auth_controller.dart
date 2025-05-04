// lib/backend/auth_controller.dart
import 'package:firebase_auth/firebase_auth.dart';

class AuthController {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<void> logout() async {
    await _auth.signOut();
  }
}
