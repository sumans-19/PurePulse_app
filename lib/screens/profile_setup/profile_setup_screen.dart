// lib/screens/profile_setup/profile_setup_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:purepulse_app/screens/profile_setup/step1_page.dart';
import 'package:purepulse_app/screens/profile_setup/step2_page.dart';
import 'package:purepulse_app/utils/colors.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final PageController _pageController = PageController();
  final Map<String, dynamic> _formData = {};
  bool _isLoading = false;

  void _nextPage(Map<String, dynamic> stepData) {
    setState(() {
      _formData.addAll(stepData);
    });
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _saveProfile(Map<String, dynamic> stepData) async {
    setState(() {
      _formData.addAll(stepData);
      _isLoading = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        ..._formData,
        'email': user.email,
        'profileComplete': true,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      // Navigation will be handled by the AuthGate
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save profile: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // Disable swiping
        children: [
          Step1Page(onNext: _nextPage),
          Step2Page(onPrevious: _previousPage, onFinish: _saveProfile, isLoading: _isLoading),
        ],
      ),
    );
  }
}