import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:timepreneur/backend/auth_controller.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? profileImageUrl;
  bool isUploading = false;

  @override
  void initState() {
    super.initState();
    _displayNameController.text = user?.displayName ?? '';
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    try {
      final ref = FirebaseStorage.instance.ref().child(
        'profile_images/${user!.uid}.jpg',
      );

      // Try downloading; this alone will throw if the object doesn't exist
      final url = await ref.getDownloadURL();
      setState(() {
        profileImageUrl = url;
      });
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') {
        // This means no image was uploaded yet — silently ignore
        debugPrint('No profile image found for user.');
      } else {
        debugPrint('Firebase error while loading profile image: ${e.message}');
      }
    } catch (e) {
      debugPrint('Unexpected error: $e');
    }
  }

  Future<void> _uploadProfilePicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      // Validate file type
      final path = pickedFile.path.toLowerCase();
      if (!(path.endsWith('.jpg') ||
          path.endsWith('.jpeg') ||
          path.endsWith('.png'))) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Only JPG or PNG files are allowed.')),
        );
        return;
      }

      try {
        setState(() => isUploading = true);

        final ref = FirebaseStorage.instance.ref().child(
          'profile_images/${user!.uid}.jpg',
        );

        final metadata = SettableMetadata(contentType: 'image/jpeg');

        await ref.putFile(File(pickedFile.path), metadata);
        final url = await ref.getDownloadURL();

        if (!mounted) return;
        setState(() {
          profileImageUrl = url;
          isUploading = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() => isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Upload failed: ${e.toString()}")),
        );
      }
    }
  }

  Future<void> _updateDisplayName() async {
    await user?.updateDisplayName(_displayNameController.text.trim());
    await user?.reload();
    setState(() {});
  }

  Future<void> _changePassword() async {
    final newPassword = _passwordController.text.trim();
    if (newPassword.length >= 6) {
      await user?.updatePassword(newPassword);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Password updated")));
      _passwordController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password must be at least 6 characters")),
      );
    }
  }

  void _logout(BuildContext context) async {
    await AuthController.logout();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (profileImageUrl != null)
              CircleAvatar(
                radius: 50,
                backgroundImage: NetworkImage(profileImageUrl!),
              )
            else
              const CircleAvatar(
                radius: 50,
                child: Icon(Icons.person, size: 40),
              ),
            TextButton(
              onPressed: isUploading ? null : _uploadProfilePicture,
              child:
                  isUploading
                      ? const CircularProgressIndicator()
                      : const Text("Upload Profile Picture"),
            ),
            const SizedBox(height: 20),
            Text(
              "Email: ${user?.email ?? 'N/A'}",
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _displayNameController,
              decoration: const InputDecoration(labelText: "Display Name"),
            ),
            ElevatedButton(
              onPressed: _updateDisplayName,
              child: const Text("Update Name"),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "New Password"),
            ),
            ElevatedButton(
              onPressed: _changePassword,
              child: const Text("Change Password"),
            ),
          ],
        ),
      ),
    );
  }
}
