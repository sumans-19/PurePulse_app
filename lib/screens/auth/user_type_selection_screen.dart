import 'package:flutter/material.dart';
import 'package:purepulse_app/screens/onboarding/add_child_profile_screen.dart';
import 'package:purepulse_app/screens/onboarding/personal_profile_setup.dart';
import 'package:purepulse_app/screens/onboarding/parent_profile_setup.dart';
import 'package:purepulse_app/services/firestore_service.dart';
import 'package:provider/provider.dart';

class UserTypeSelectionScreen extends StatefulWidget {
  final String uid;
  final String name;
  final String email;

  const UserTypeSelectionScreen({
    super.key,
    required this.uid,
    required this.name,
    required this.email,
  });

  @override
  State<UserTypeSelectionScreen> createState() => _UserTypeSelectionScreenState();
}

class _UserTypeSelectionScreenState extends State<UserTypeSelectionScreen> {
  String? _selectedType;
  bool _isLoading = false;

  Future<void> _selectUserType(String userType) async {
    setState(() {
      _selectedType = userType;
      _isLoading = true;
    });

    final firestoreService = context.read<FirestoreService>();

    try {
      await firestoreService.createUserDocument(
        uid: widget.uid,
        name: widget.name,
        email: widget.email,
        userType: userType,
      );

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      if (userType == 'personal') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => PersonalProfileSetupScreen(),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const AddChildProfileScreen(isFirstChild: true),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _selectedType = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save user data: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFAF5F0),
              const Color(0xFFF0F9FA),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: IntrinsicHeight(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 16),

                              // Welcome section
                              Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF06b6d4),
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF06b6d4).withAlpha(50),
                                          blurRadius: 12,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.air,
                                      size: 40,
                                      color: Color(0xFF06b6d4),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  const Text(
                                    'Welcome to PurePulse!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF06b6d4),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'How will you be using the app?',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 32),

                              // Personal Use Option
                              Expanded(
                                child: _EnhancedUserTypeCard(
                                  icon: Icons.person_outline,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      const Color(0xFF06b6d4),
                                      const Color(0xFF0891b2),
                                    ],
                                  ),
                                  title: 'Personal Use',
                                  description: 'Monitor air quality and get personalized alerts.',
                                  features: const [
                                    'Personalized monitoring',
                                    'Custom health alerts',
                                    'Location tracking',
                                  ],
                                  isSelected: _selectedType == 'personal',
                                  isLoading: _isLoading && _selectedType == 'personal',
                                  onTap: _isLoading ? null : () => _selectUserType('personal'),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Parental Control Option
                              Expanded(
                                child: _EnhancedUserTypeCard(
                                  icon: Icons.family_restroom_outlined,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      const Color(0xFF06b6d4),
                                      const Color(0xFF0891b2),
                                    ],
                                  ),
                                  title: 'Parental Control',
                                  description: 'Monitor air quality for children and manage profiles.',
                                  features: const [
                                    'Multiple child profiles',
                                    'Individual tracking',
                                    'Family dashboard',
                                  ],
                                  isSelected: _selectedType == 'parent',
                                  isLoading: _isLoading && _selectedType == 'parent',
                                  onTap: _isLoading ? null : () => _selectUserType('parent'),
                                ),
                              ),

                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Loading overlay
              if (_isLoading)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(
                    child: Card(
                      margin: EdgeInsets.all(32),
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF06b6d4),
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Setting up your profile...',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF06b6d4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnhancedUserTypeCard extends StatelessWidget {
  final IconData icon;
  final Gradient gradient;
  final String title;
  final String description;
  final List<String> features;
  final bool isSelected;
  final bool isLoading;
  final VoidCallback? onTap;

  const _EnhancedUserTypeCard({
    required this.icon,
    required this.gradient,
    required this.title,
    required this.description,
    required this.features,
    required this.isSelected,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      transform: Matrix4.identity()..scale(isSelected ? 0.98 : 1.0),
      child: Card(
        elevation: isSelected ? 8 : 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected ? const Color(0xFF06b6d4) : Colors.transparent,
            width: 2,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon with gradient background
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: gradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF06b6d4).withAlpha(100),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Title
                  Text(
                    title,
                    style:  TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade900,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Description
                  Flexible(
                    child: Text(
                      description,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        height: 1.3,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Features list
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF5F0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: features.map((feature) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  gradient: gradient,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  size: 10,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  feature,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[800],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Loading or Select button
                  if (isLoading)
                    const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF06b6d4),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: gradient,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF06b6d4).withAlpha(150),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isSelected ? 'Selected' : 'Select',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: 16,
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}