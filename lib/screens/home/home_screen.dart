import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:purepulse_app/services/aqi_service.dart';
import 'package:purepulse_app/services/firestore_service.dart';
import 'package:purepulse_app/screens/auth/login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<Map<String, dynamic>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
    _setupFCM();
  }

  Future<Map<String, dynamic>> _loadData() async {
    final firestoreService = context.read<FirestoreService>();
    final aqiService = context.read<AqiService>(); // Assuming you provide this
    final user = FirebaseAuth.instance.currentUser!;

    // Fetch user document
    final userDoc = await firestoreService.getUser(user.uid);
    final userData = userDoc.data() as Map<String, dynamic>;

    // Fetch AQI data using user's location
    final location = userData['primaryLocation'];
    final aqiData = await aqiService.getAqiData(
        location['latitude'], location['longitude']);

    // If parent, fetch children data as well
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

    // Request permission for notifications (important for iOS)
    await FirebaseMessaging.instance.requestPermission();

    // Get the token
    final fcmToken = await FirebaseMessaging.instance.getToken();

    // Save the token to Firestore
    if (fcmToken != null) {
      await firestoreService.saveUserToken(user.uid, fcmToken);
      print('FCM Token saved to Firestore: $fcmToken');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PurePulse Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // 1. Sign the user out
              await FirebaseAuth.instance.signOut();

              // 2. Navigate to the LoginScreen and remove all previous screens
              if (mounted) {
                // Checks if the widget is still in the tree
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false, // This predicate removes all routes.
                );
              }
            },
          )
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('No data found.'));
          }

          final data = snapshot.data!;
          final userType = data['user']['userType'];

          if (userType == 'personal') {
            return _buildPersonalDashboard(data['user'], data['aqi']);
          } else {
            return _buildParentDashboard(
                data['user'], data['aqi'], data['children']);
          }
        },
      ),
    );
  }

  // UI for Personal Users
  Widget _buildPersonalDashboard(
      Map<String, dynamic> user, Map<String, dynamic> aqi) {
    final aqiValue =
        aqi['main']['aqi']; // AQI is a value from 1 (Good) to 5 (Very Poor)
    // You can build out a full UI here. This is a simple example.
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hello, ${user['name']}!',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          _AqiDisplayCard(aqiValue: aqiValue),
          const SizedBox(height: 16),
          _HealthRiskCard(user: user, aqi: aqiValue),
        ],
      ),
    );
  }

  // UI for Parent Users
  Widget _buildParentDashboard(Map<String, dynamic> user,
      Map<String, dynamic> aqi, List<DocumentSnapshot> children) {
    final aqiValue = aqi['main']['aqi'];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: _AqiDisplayCard(aqiValue: aqiValue),
        ),
        const Divider(),
        Expanded(
          child: ListView.builder(
            itemCount: children.length,
            itemBuilder: (context, index) {
              final child = children[index].data() as Map<String, dynamic>;
              return ListTile(
                title: Text(child['name']),
                subtitle: Text(
                    'Risk: High'), // TODO: Calculate risk based on child's health
                leading: const Icon(Icons.child_care),
              );
            },
          ),
        ),
      ],
    );
  }
}

// Reusable card for displaying AQI
class _AqiDisplayCard extends StatelessWidget {
  final int aqiValue;
  const _AqiDisplayCard({required this.aqiValue});

  String _getAqiText(int value) {
    switch (value) {
      case 1:
        return 'Good';
      case 2:
        return 'Fair';
      case 3:
        return 'Moderate';
      case 4:
        return 'Poor';
      case 5:
        return 'Very Poor';
      default:
        return 'Unknown';
    }
  }

  Color _getAqiColor(int value) {
    switch (value) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.yellow.shade700;
      case 3:
        return Colors.orange;
      case 4:
        return Colors.red;
      case 5:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('Current Air Quality',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              _getAqiText(aqiValue),
              style: TextStyle(
                  fontSize: 28,
                  color: _getAqiColor(aqiValue),
                  fontWeight: FontWeight.bold),
            ),
            Text('AQI: $aqiValue'),
          ],
        ),
      ),
    );
  }
}

// Reusable card for displaying health risk
class _HealthRiskCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final int aqi;

  const _HealthRiskCard({required this.user, required this.aqi});

  // TODO: Implement a real risk calculation algorithm
  String _calculateRisk() {
    final conditions = user['healthConditions'] as List;
    if (conditions.isNotEmpty && aqi > 2) {
      return 'High Risk';
    }
    if (aqi > 3) {
      return 'Moderate Risk';
    }
    return 'Low Risk';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: ListTile(
        title: const Text('Your Personalized Risk'),
        subtitle: Text('Based on your health data and current AQI'),
        trailing: Text(
          _calculateRisk(),
          style: TextStyle(
            color: _calculateRisk() == 'High Risk' ? Colors.red : Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
