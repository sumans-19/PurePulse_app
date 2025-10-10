import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:purepulse_app/services/aqi_service.dart';
import 'package:purepulse_app/services/firestore_service.dart';
import 'package:purepulse_app/screens/auth/login_screen.dart';
import 'package:purepulse_app/screens/onboarding/add_child_profile_screen.dart';
import 'package:purepulse_app/screens/home/notification_history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _setupFCM();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<Map<String, dynamic>> _loadData() async {
    // This function is now only called by the FutureBuilder
    final firestoreService = context.read<FirestoreService>();
    final aqiService = context.read<AqiService>();
    final user = FirebaseAuth.instance.currentUser!;

    final userDoc = await firestoreService.getUser(user.uid);
    final userData = userDoc.data() as Map<String, dynamic>;

    if (userData['primaryLocation'] == null) {
      throw Exception('User location has not been set up.');
    }
    final aqiData = await aqiService.getAqiData(
        userData['primaryLocation']['latitude'], userData['primaryLocation']['longitude']);
    
    print('RAW AQI DATA FROM API: $aqiData');

    if (userData['userType'] == 'parent') {
      final childrenSnapshot = await firestoreService.getChildren(user.uid);
      return {
        'user': userData,
        'aqi': aqiData,
        'children': childrenSnapshot.docs,
      };
    }

    return {'user': userData, 'aqi': aqiData};
  }

  void _setupFCM() async {
    final firestoreService = context.read<FirestoreService>();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseMessaging.instance.requestPermission();
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      await firestoreService.saveUserToken(user.uid, fcmToken);
      print('FCM Token saved to Firestore: $fcmToken');
    }
  }

  @override
  Widget build(BuildContext context) {
    // This is the new, cleaner structure.
    // The FutureBuilder is at the top level.
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadData(),
      builder: (context, snapshot) {
        // Handle loading and error states first
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('Error: ${snapshot.error}')));
        }
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: Text('No data found.')));
        }

        // Once data is loaded, build the real UI
        final data = snapshot.data!;
        final userType = data['user']['userType'];

        final List<Widget> pages = [
          userType == 'personal'
              ? _buildPersonalDashboard(data['user'], data['aqi'])
              : _buildParentDashboard(data['user'], data['aqi'], data['children']),
          const NotificationHistoryScreen(),
        ];

        return Scaffold(
          appBar: AppBar(
            title: Text(_selectedIndex == 0 ? 'Dashboard' : 'Notification History'),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
              ),
            ],
          ),
          body: IndexedStack(
            index: _selectedIndex,
            children: pages,
          ),
          bottomNavigationBar: BottomNavigationBar(
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
              BottomNavigationBarItem(icon: Icon(Icons.history_outlined), label: 'History'),
            ],
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
          ),
          floatingActionButton: (_selectedIndex == 0 && userType == 'parent')
              ? FloatingActionButton(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const AddChildProfileScreen(isFirstChild: false),
                      ),
                    );
                    setState(() {}); // Rebuild to refresh the dashboard future
                  },
                  child: const Icon(Icons.add),
                  tooltip: 'Add Child',
                )
              : null,
        );
      },
    );
  }

  String _calculateRisk(List<dynamic> conditions, int aqi) {
    bool isSensitive = conditions.any((c) => 
      ['Asthma', 'Bronchitis', 'COPD', 'Allergies', 'Hay Fever'].contains(c)
    );
    if (isSensitive) {
      if (aqi > 100) return 'High Risk';
      if (aqi > 50) return 'Moderate Risk';
      return 'Low Risk';
    } else {
      if (aqi > 150) return 'High Risk';
      if (aqi > 100) return 'Moderate Risk';
      return 'Low Risk';
    }
  }

  Widget _buildPersonalDashboard(Map<String, dynamic> user, Map<String, dynamic> aqi) {
    final int aqiValue = (aqi['aqi'] is int) ? aqi['aqi'] : int.tryParse(aqi['aqi'].toString()) ?? 0;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hello, ${user['name']}!', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          _AqiDisplayCard(aqiData: aqi),
          const SizedBox(height: 16),
          _HealthRiskCard(user: user, aqi: aqiValue),
        ],
      ),
    );
  }

  Widget _buildParentDashboard(Map<String, dynamic> user, Map<String, dynamic> aqi, List<DocumentSnapshot> children) {
    final int aqiValue = (aqi['aqi'] is int) ? aqi['aqi'] : int.tryParse(aqi['aqi'].toString()) ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: _AqiDisplayCard(aqiData: aqi),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text("Your Children's Profiles", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: children.length,
            itemBuilder: (context, index) {
              final child = children[index].data() as Map<String, dynamic>;
              final risk = _calculateRisk(child['healthConditions'] as List? ?? [], aqiValue);
              Color riskColor = Colors.green;
              if (risk == 'High Risk') riskColor = Colors.red;
              if (risk == 'Moderate Risk') riskColor = Colors.orange;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: riskColor.withOpacity(0.15),
                    child: Icon(Icons.child_care, color: riskColor),
                  ),
                  title: Text(child['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text((child['healthConditions'] as List?)?.join(', ') ?? 'No conditions listed'),
                  trailing: Chip(
                    label: Text(risk, style: const TextStyle(color: Colors.white)),
                    backgroundColor: riskColor,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AqiDisplayCard extends StatelessWidget {
  final Map<String, dynamic> aqiData;
  const _AqiDisplayCard({super.key, required this.aqiData});

  Color _getAqiColor(int aqi) {
    if (aqi > 200) return Colors.purple;
    if (aqi > 150) return Colors.red;
    if (aqi > 100) return Colors.orange;
    if (aqi > 50) return Colors.yellow.shade700;
    return Colors.green;
  }

  String _getAqiText(int aqi) {
    if (aqi > 200) return 'Very Unhealthy';
    if (aqi > 150) return 'Unhealthy';
    if (aqi > 100) return 'Unhealthy for Sensitive';
    if (aqi > 50) return 'Moderate';
    return 'Good';
  }

  @override
  Widget build(BuildContext context) {
    final aqiValue = aqiData['aqi'];
    final int finalAqi = (aqiValue is int) ? aqiValue : int.tryParse(aqiValue.toString()) ?? 0;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text('Live Air Quality Index', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Text(finalAqi.toString(), style: TextStyle(fontSize: 48, color: _getAqiColor(finalAqi), fontWeight: FontWeight.bold)),
            Text(_getAqiText(finalAqi), style: TextStyle(color: _getAqiColor(finalAqi), fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
      ),
    );
  }
}

class _HealthRiskCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final int aqi;

  const _HealthRiskCard({super.key, required this.user, required this.aqi});

  String _calculateRisk(List<dynamic> conditions, int aqiValue) {
    bool isSensitive = conditions.any((c) => 
      ['Asthma', 'Bronchitis', 'COPD', 'Allergies', 'Hay Fever'].contains(c)
    );
    if (isSensitive) {
      if (aqiValue > 100) return 'High Risk';
      if (aqiValue > 50) return 'Moderate Risk';
      return 'Low Risk';
    } else {
      if (aqiValue > 150) return 'High Risk';
      if (aqiValue > 100) return 'Moderate Risk';
      return 'Low Risk';
    }
  }

  @override
  Widget build(BuildContext context) {
    final risk = _calculateRisk(user['healthConditions'] as List? ?? [], aqi);
    Color riskColor = Colors.green;
    if (risk == 'High Risk') riskColor = Colors.red;
    if (risk == 'Moderate Risk') riskColor = Colors.orange;

    return Card(
      elevation: 2,
      child: ListTile(
        title: const Text('Your Personalized Risk'),
        subtitle: Text('Based on current AQI & your health data'),
        trailing: Chip(
          label: Text(risk, style: const TextStyle(color: Colors.white)),
          backgroundColor: riskColor,
        ),
      ),
    );
  }
}