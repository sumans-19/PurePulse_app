import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../onboarding/personal_profile_setup.dart';
import '../onboarding/parent_profile_setup.dart';
import '../auth/login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UserModel? _userModel;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final authService = context.read<AuthService>();
    if (authService.currentUser != null) {
      final userModel = await authService.getUserProfile(authService.currentUser!.uid);
      if (mounted) {
        setState(() {
          _userModel = userModel;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    final authService = context.read<AuthService>();
    await authService.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PurePlus Dashboard'),
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: Consumer<AuthService>(
        builder: (context, authService, child) {
          if (authService.isLoading || _isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (authService.currentUser == null) {
            return const Center(
              child: Text('No user logged in'),
            );
          }

          final user = _userModel;
          final userName = user?.name.isNotEmpty == true ? user!.name : 'User';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Greeting
                Text(
                  'Welcome back, $userName!',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Monitor air quality and protect your health',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),

                // Profile completion check
                if (user == null || (user.userType == UserType.personal && (user.age == null || user.healthConditions == null)))
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.info_outline, color: Colors.orange),
                      title: const Text('Complete your profile'),
                      subtitle: const Text('Set up your health information for personalized recommendations'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        final currentUser = authService.currentUser!;
                        final userName = user?.name ?? 'User';
                        if (user?.userType == UserType.personal || user == null) {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => PersonalProfileSetup(
                              uid: currentUser.uid,
                              email: currentUser.email!,
                              name: userName,
                            )),
                          );
                        } else {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => ParentProfileSetup(
                              uid: currentUser.uid,
                              email: currentUser.email!,
                              name: userName,
                            )),
                          );
                        }
                      },
                    ),
                  ),

                const SizedBox(height: 16),

                // User Type Specific Content
                if (user?.userType == UserType.personal) ...[
                  // Personal Health Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.person,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Personal Health',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Your Risk Level: ${user?.getRiskLevel().name.toUpperCase()}'),
                          if (user?.healthConditions != null && user!.healthConditions!.isNotEmpty)
                            Text('Conditions: ${user!.healthConditions!.join(', ')}'),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () {
                              // Navigate to air quality map or health tips
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Navigate to Air Quality Map')),
                              );
                            },
                            child: const Text('Check Air Quality'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else if (user?.userType == UserType.parent) ...[
                  // Parent Children Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.child_care,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Family Health',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (user?.childrenIds != null && user!.childrenIds!.isNotEmpty)
                            Text('Children: ${user!.childrenIds!.length}')
                          else
                            const Text('No children profiles set up'),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () {
                              // Navigate to add child or view children
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Navigate to Child Profiles')),
                              );
                            },
                            child: const Text('Manage Children'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // General Features
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.map),
                        title: const Text('Air Quality Map'),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Open Air Quality Map')),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.info),
                        title: const Text('Health Tips'),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('View Health Tips')),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.settings),
                        title: const Text('Settings'),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Open Settings')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: 0,
        onTap: (index) {
          // Handle navigation
          if (index == 1) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Navigate to Map')),
            );
          } else if (index == 2) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Navigate to Profile')),
            );
          }
        },
      ),
    );
  }
}
