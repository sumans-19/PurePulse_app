import 'package:flutter/material.dart';
import 'package:purepulse_app/screens/onboarding/add_child_profile_screen.dart';
import 'package:purepulse_app/screens/onboarding/personal_profile_setup.dart';
import 'package:purepulse_app/screens/onboarding/parent_profile_setup.dart';
import 'package:purepulse_app/services/firestore_service.dart';
import 'package:provider/provider.dart'; // Import Provider

class UserTypeSelectionScreen extends StatelessWidget {
  // Add these final fields to accept the data
  final String uid;
  final String name;
  final String email;

  // Update the constructor
  const UserTypeSelectionScreen({
    super.key,
    required this.uid,
    required this.name,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    // Get the FirestoreService from Provider
    final firestoreService = context.read<FirestoreService>();

    Future<void> _selectUserType(String userType) async {
      try {
        // Now, create the full user document in Firestore in one go
        await firestoreService.createUserDocument(
          uid: uid,
          name: name,
          email: email,
          userType: userType,
        );

        // Navigate to the appropriate profile setup screen
        if (userType == 'personal') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
                builder: (context) => PersonalProfileSetupScreen()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
                builder: (context) =>
                    const AddChildProfileScreen(isFirstChild: true)),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save user data: $e')),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your Profile'),
        automaticallyImplyLeading: false, // Disables the back button
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "How will you be using PurePulse?",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),

              // Option 1: Personal Use
              _UserTypeCard(
                icon: Icons.person_outline,
                title: 'Personal Use',
                description:
                    'Monitor air quality for yourself and get personalized alerts.',
                onTap: () => _selectUserType('personal'),
              ),

              const SizedBox(height: 20),

              // Option 2: Parental Control
              _UserTypeCard(
                icon: Icons.family_restroom_outlined,
                title: 'Parental Control',
                description:
                    'Monitor air quality for your children and manage their profiles.',
                onTap: () => _selectUserType('parent'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// This helper widget remains the same
class _UserTypeCard extends StatelessWidget {
  // ... no changes here
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _UserTypeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Icon(icon, size: 48, color: Theme.of(context).primaryColor),
              const SizedBox(height: 12),
              Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
