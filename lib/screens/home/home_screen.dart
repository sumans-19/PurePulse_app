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
import 'package:purepulse_app/screens/home/profile_screen.dart';
import 'package:purepulse_app/screens/onboarding/parent_profile_setup.dart';
import 'package:purepulse_app/screens/onboarding/personal_profile_setup.dart';

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
    final firestoreService = context.read<FirestoreService>();
    final aqiService = context.read<AqiService>();
    final user = FirebaseAuth.instance.currentUser!;

    final userDoc = await firestoreService.getUser(user.uid);
    final userData = userDoc.data() as Map<String, dynamic>;

    if (userData['primaryLocation'] == null) {
      throw Exception('User location has not been set up.');
    }
    final aqiData = await aqiService.getAqiData(
        userData['primaryLocation']['latitude'],
        userData['primaryLocation']['longitude']);

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
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(
              body: Center(child: Text('Error: ${snapshot.error}')));
        }
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: Text('No data found.')));
        }

        final data = snapshot.data!;
        final userType = data['user']['userType'];

        final List<Widget> pages = [
          userType == 'personal'
              ? _buildPersonalDashboard(data['user'], data['aqi'])
              : _buildParentDashboard(
                  data['user'], data['aqi'], data['children']),
          const NotificationHistoryScreen(),
          ProfileScreen(
            userData: data['user'],
            children: (userType == 'parent') ? data['children'] : null,
          ),
        ];

        return Scaffold(
          appBar: AppBar(
            title: Text(_selectedIndex == 0
                ? 'Dashboard'
                : _selectedIndex == 1
                    ? 'Notifications'
                    : 'Profile'),
            automaticallyImplyLeading: false,
            actions: [
              if (_selectedIndex == 1)
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined),
                  tooltip: 'Clear All Notifications',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext dialogContext) {
                        return AlertDialog(
                          title: const Text('Clear History?'),
                          content: const Text(
                            'Are you sure you want to delete all notifications? This cannot be undone.',
                          ),
                          actions: <Widget>[
                            TextButton(
                              child: const Text('Cancel'),
                              onPressed: () => Navigator.of(dialogContext).pop(),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              child: const Text('Clear All'),
                              onPressed: () {
                                final userId =
                                    FirebaseAuth.instance.currentUser!.uid;
                                context
                                    .read<FirestoreService>()
                                    .clearAllNotifications(userId);
                                Navigator.of(dialogContext).pop();
                              },
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              if (_selectedIndex == 2)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit Profile',
                  onPressed: () {
                    if (userType == 'parent') {
                      Navigator.of(context)
                          .push(MaterialPageRoute(
                            builder: (context) =>
                                const ParentProfileSetupScreen(),
                          ))
                          .then((_) => setState(() {}));
                    } else {
                      Navigator.of(context)
                          .push(MaterialPageRoute(
                            builder: (context) => PersonalProfileSetupScreen(
                                profileData: data['user']),
                          ))
                          .then((_) => setState(() {}));
                    }
                  },
                ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (context) => const LoginScreen()),
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
              BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.notifications_outlined),
                  label: 'Notifications'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline), label: 'Profile'),
            ],
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
          ),
          floatingActionButton: (_selectedIndex == 0 && userType == 'parent')
              ? FloatingActionButton(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            const AddChildProfileScreen(isFirstChild: false),
                      ),
                    );
                    setState(() {});
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
        ['Asthma', 'Bronchitis', 'COPD', 'Allergies', 'Hay Fever'].contains(c));
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

  Widget _buildPersonalDashboard(
      Map<String, dynamic> user, Map<String, dynamic> aqi) {
    final int aqiValue = (aqi['aqi'] is int)
        ? aqi['aqi']
        : int.tryParse(aqi['aqi'].toString()) ?? 0;
    final String stationName = aqi['city']?['name'] ?? 'Unknown Station';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hello, ${user['name']}!',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                stationName,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _AqiDisplayCard(aqiData: aqi),
          const SizedBox(height: 16),
          _HealthRiskCard(user: user, aqi: aqiValue),
          const SizedBox(height: 16),
          _PollutantsGrid(aqiData: aqi),
          const SizedBox(height: 16),
          _WeatherInfoCard(aqiData: aqi),
          const SizedBox(height: 16),
          _LastUpdatedCard(aqiData: aqi),
        ],
      ),
    );
  }

  Widget _buildParentDashboard(Map<String, dynamic> user,
      Map<String, dynamic> aqi, List<DocumentSnapshot> children) {
    final int aqiValue = (aqi['aqi'] is int)
        ? aqi['aqi']
        : int.tryParse(aqi['aqi'].toString()) ?? 0;
    final String stationName = aqi['city']?['name'] ?? 'Unknown Station';

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hello, ${user['name']}!',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                _AqiDisplayCard(aqiData: aqi),
                const SizedBox(height: 8),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on,
                          size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        stationName,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _PollutantsGrid(aqiData: aqi),
                const SizedBox(height: 24),
                const Text(
                  "Your Children's Profiles",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final child = children[index].data() as Map<String, dynamic>;
              final risk = _calculateRisk(
                  child['healthConditions'] as List? ?? [], aqiValue);
              Color riskColor = Colors.green;
              if (risk == 'High Risk') riskColor = Colors.red;
              if (risk == 'Moderate Risk') riskColor = Colors.orange;

              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: riskColor.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.child_care, color: riskColor, size: 24),
                    ),
                    title: Text(
                      child['name'],
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        (child['healthConditions'] as List?)?.join(', ') ??
                            'No conditions listed',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade700),
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: riskColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        risk,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
            childCount: children.length,
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
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
    final int finalAqi =
        (aqiValue is int) ? aqiValue : int.tryParse(aqiValue.toString()) ?? 0;
    final color = _getAqiColor(finalAqi);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text('Live Air Quality Index',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 16),
            Text(finalAqi.toString(),
                style: TextStyle(
                    fontSize: 56, color: color, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(_getAqiText(finalAqi),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PollutantsGrid extends StatelessWidget {
  final Map<String, dynamic> aqiData;
  const _PollutantsGrid({super.key, required this.aqiData});

  @override
  Widget build(BuildContext context) {
    final iaqi = aqiData['iaqi'] as Map<String, dynamic>?;
    if (iaqi == null) return const SizedBox.shrink();

    final pollutants = [
      {'key': 'pm25', 'name': 'PM2.5', 'icon': Icons.blur_on, 'unit': 'μg/m³'},
      {'key': 'pm10', 'name': 'PM10', 'icon': Icons.grain, 'unit': 'μg/m³'},
      {'key': 'o3', 'name': 'Ozone', 'icon': Icons.cloud, 'unit': 'ppb'},
      {
        'key': 'no2',
        'name': 'NO₂',
        'icon': Icons.local_shipping,
        'unit': 'ppb'
      },
      {'key': 'so2', 'name': 'SO₂', 'icon': Icons.factory, 'unit': 'ppb'},
      {'key': 'co', 'name': 'CO', 'icon': Icons.smoke_free, 'unit': 'ppm'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Pollutant Levels',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: pollutants.length,
          itemBuilder: (context, index) {
            final pollutant = pollutants[index];
            final value = iaqi[pollutant['key']]?['v'];

            if (value == null) return const SizedBox.shrink();

            return _PollutantCard(
              name: pollutant['name'] as String,
              value: value.toString(),
              unit: pollutant['unit'] as String,
              icon: pollutant['icon'] as IconData,
            );
          },
        ),
      ],
    );
  }
}

class _PollutantCard extends StatelessWidget {
  final String name;
  final String value;
  final String unit;
  final IconData icon;

  const _PollutantCard({
    super.key,
    required this.name,
    required this.value,
    required this.unit,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900)),
              Text(unit,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeatherInfoCard extends StatelessWidget {
  final Map<String, dynamic> aqiData;
  const _WeatherInfoCard({super.key, required this.aqiData});

  @override
  Widget build(BuildContext context) {
    final iaqi = aqiData['iaqi'] as Map<String, dynamic>?;
    if (iaqi == null) return const SizedBox.shrink();

    final temp = iaqi['t']?['v'];
    final humidity = iaqi['h']?['v'];
    final pressure = iaqi['p']?['v'];
    final wind = iaqi['w']?['v'];

    if (temp == null && humidity == null && pressure == null && wind == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Weather Conditions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (temp != null)
                  _WeatherItem(
                      icon: Icons.thermostat,
                      label: 'Temp',
                      value: '${temp}°C'),
                if (humidity != null)
                  _WeatherItem(
                      icon: Icons.water_drop,
                      label: 'Humidity',
                      value: '$humidity%'),
                if (pressure != null)
                  _WeatherItem(
                      icon: Icons.speed,
                      label: 'Pressure',
                      value: '$pressure hPa'),
                if (wind != null)
                  _WeatherItem(
                      icon: Icons.air, label: 'Wind', value: '$wind m/s'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WeatherItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _WeatherItem({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue.shade700),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}

class _LastUpdatedCard extends StatelessWidget {
  final Map<String, dynamic> aqiData;
  const _LastUpdatedCard({super.key, required this.aqiData});

  @override
  Widget build(BuildContext context) {
    final time = aqiData['time'];
    if (time == null) return const SizedBox.shrink();

    final timestamp = time['s'] ?? 'Unknown';

    return Card(
      elevation: 1,
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(Icons.update, size: 18, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            Text('Last updated: $timestamp',
                style: TextStyle(fontSize: 12, color: Colors.blue.shade900)),
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
        ['Asthma', 'Bronchitis', 'COPD', 'Allergies', 'Hay Fever'].contains(c));
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
    IconData riskIcon = Icons.check_circle;

    if (risk == 'High Risk') {
      riskColor = Colors.red;
      riskIcon = Icons.warning;
    } else if (risk == 'Moderate Risk') {
      riskColor = Colors.orange;
      riskIcon = Icons.info;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [riskColor.withOpacity(0.15), riskColor.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: riskColor.withOpacity(0.3), width: 2),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: riskColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(riskIcon, color: riskColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your Personalized Risk',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text('Based on current AQI & your health data',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: riskColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(risk,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}