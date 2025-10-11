import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:purepulse_app/screens/auth/login_screen.dart';
import 'package:purepulse_app/screens/onboarding/add_child_profile_screen.dart';
import 'package:purepulse_app/screens/onboarding/parent_profile_setup.dart';
import 'package:purepulse_app/screens/onboarding/personal_profile_setup.dart';

class ProfileScreen extends StatelessWidget {
  final Map<String, dynamic> userData;
  final List<DocumentSnapshot>? children;

  const ProfileScreen({
    super.key,
    required this.userData,
    this.children,
  });

  @override
  Widget build(BuildContext context) {
    final String name = userData['name'] ?? 'No Name';
    final String email = userData['email'] ?? 'No Email';
    final String userType = userData['userType'] ?? 'personal';
    final List<dynamic> healthConditions = userData['healthConditions'] ?? [];
    final List<dynamic> activities = userData['outdoorActivities'] ?? [];

    return ListView(
      padding: const EdgeInsets.all(20.0),
      children: [
        // User Info Card - Clean and Simple
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: const Color(0xFF06b6d4).withOpacity(0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF06b6d4).withOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFF06b6d4).withOpacity(0.1),
                    child: Icon(
                      userType == 'parent' ? Icons.family_restroom : Icons.person,
                      size: 50,
                      color: const Color(0xFF0891b2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0e7490),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06b6d4).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    userType == 'parent' ? 'Parent Account' : 'Personal Account',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0891b2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // PERSONAL USER SECTION
        if (userType == 'personal') ...[
          const SizedBox(height: 28),
          _SectionTitle(title: 'Health Conditions'),
          const SizedBox(height: 12),
          if (healthConditions.isEmpty)
            _EmptyState(message: 'No health conditions listed')
          else
            Card(
              elevation: 1,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: const Color(0xFF06b6d4).withOpacity(0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: healthConditions.map((condition) {
                    return Chip(
                      label: Text(condition.toString()),
                      backgroundColor: const Color(0xFF06b6d4).withOpacity(0.1),
                      side: const BorderSide(color: Color(0xFF06b6d4)),
                      labelStyle: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF0e7490),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

          const SizedBox(height: 28),
          _SectionTitle(title: 'Outdoor Activities'),
          const SizedBox(height: 12),
          if (activities.isEmpty)
            _EmptyState(message: 'No activities scheduled')
          else
            ...activities.map((activity) {
              return Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 8),
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: const Color(0xFF06b6d4).withOpacity(0.2)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06b6d4).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.directions_walk,
                      color: Color(0xFF0891b2),
                    ),
                  ),
                  title: Text(
                    activity['name'] ?? 'Unnamed Activity',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    '${activity['startTime']} - ${activity['endTime']}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              );
            }),
        ],

        // PARENT USER SECTION
        if (userType == 'parent') ...[
          const SizedBox(height: 28),
          _SectionTitle(title: "Children's Profiles"),
          const SizedBox(height: 12),
          if (children == null || children!.isEmpty)
            _EmptyState(message: 'No children profiles added yet')
          else
            ...children!.map((childDoc) {
              final childData = childDoc.data() as Map<String, dynamic>;
              final childConditions = childData['healthConditions'] as List? ?? [];

              return Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 12),
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: const Color(0xFF06b6d4).withOpacity(0.2)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06b6d4).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.child_care,
                      color: Color(0xFF0891b2),
                    ),
                  ),
                  title: Text(
                    childData['name'] ?? 'Unnamed Child',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text(
                      childConditions.isEmpty
                          ? 'No conditions listed'
                          : childConditions.join(', '),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.edit, color: const Color(0xFF0891b2)),
                    onPressed: () {
                      Navigator.of(context)
                          .push(MaterialPageRoute(
                            builder: (context) => AddChildProfileScreen(
                              isFirstChild: false,
                              childDoc: childDoc,
                            ),
                          ))
                          .then((_) {});
                    },
                  ),
                ),
              );
            }),
        ],

        const SizedBox(height: 32),
        
        // Logout Button - Simple and Clean
        SizedBox(
          height: 50,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text(
              'Log Out',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade700,
              side: BorderSide(color: Colors.red.shade300, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder: (BuildContext dialogContext) {
                  return AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Text('Confirm Logout'),
                    content: const Text('Are you sure you want to log out?'),
                    actions: <Widget>[
                      TextButton(
                        child: const Text('Cancel'),
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Log Out'),
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                      ),
                    ],
                  );
                },
              );

              if (shouldLogout == true) {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                }
              }
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF0e7490),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: const Color(0xFF06b6d4).withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }
}