// lib/main.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:purepulse_app/firebase_options.dart';
import 'package:purepulse_app/screens/dashboard_screen.dart';
import 'package:purepulse_app/screens/login_screen.dart';
import 'package:purepulse_app/screens/profile_setup/profile_setup_screen.dart';
import 'package:purepulse_app/utils/colors.dart';

// Placeholder for the main app screen after login
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: ElevatedButton(
          child: const Text('Sign Out'),
          onPressed: () => FirebaseAuth.instance.signOut(),
        ),
      ),
    );
  }
}

void main() async {
  // Ensure Flutter bindings are initialized before running the app.
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase with platform-specific options.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PurePulse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.cyan,
        scaffoldBackgroundColor: secondaryColor,
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme)
            .apply(bodyColor: textColor),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const LoginScreen();
        }
        // User is logged in, now check for profile
        return ProfileCheck(user: snapshot.data!);
      },
    );
  }
}

// New widget to check if the user profile is complete
class ProfileCheck extends StatelessWidget {
  final User user;
  const ProfileCheck({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // You can create a beautiful loading screen here
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('Error: ${snapshot.error}')));
        }

        // Check if the document exists and if 'profileComplete' is true
        if (snapshot.hasData && snapshot.data!.exists && snapshot.data!.data()!['profileComplete'] == true) {
          return const DashboardScreen();
        } else {
          return const ProfileSetupScreen();
        }
      },
    );
  }
}