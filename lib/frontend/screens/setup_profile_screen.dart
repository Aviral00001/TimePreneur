import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';

class SetupProfileScreen extends StatefulWidget {
  const SetupProfileScreen({super.key});

  @override
  State<SetupProfileScreen> createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends State<SetupProfileScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final User? user = FirebaseAuth.instance.currentUser;
  bool isLoading = false;

  Future<void> _submitProfile() async {
    final username = _usernameController.text.trim();
    final company = _companyController.text.trim();

    if (username.isEmpty || company.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // Update Firebase Auth display name
      await user?.updateDisplayName(username);

      // Store in Firestore
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'username': username,
        'company': company,
        'email': user!.email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await user?.reload();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Set up your profile")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: "Username"),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _companyController,
              decoration: const InputDecoration(labelText: "Company Name"),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: isLoading ? null : _submitProfile,
              child:
                  isLoading
                      ? const CircularProgressIndicator()
                      : const Text("Continue"),
            ),
          ],
        ),
      ),
    );
  }
}
