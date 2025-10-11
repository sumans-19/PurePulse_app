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
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading air quality data...',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
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
            automaticallyImplyLeading: false,
            elevation: 0,
            backgroundColor: Colors.transparent,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade600, Colors.blue.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            title: Text(
              _selectedIndex == 0
                  ? 'Dashboard'
                  : _selectedIndex == 1
                      ? 'Notifications'
                      : 'Profile',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            actions: [
              if (_selectedIndex == 1)
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white),
                  tooltip: 'Clear All Notifications',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext dialogContext) {
                        return AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          title: const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.orange),
                              SizedBox(width: 12),
                              Text('Clear History?'),
                            ],
                          ),
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
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text('Clear All'),
                              onPressed: () {
                                final userId = FirebaseAuth.instance.currentUser!.uid;
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
                  icon: const Icon(Icons.edit_outlined, color: Colors.white),
                  tooltip: 'Edit Profile',
                  onPressed: () {
                    if (userType == 'parent') {
                      Navigator.of(context)
                          .push(MaterialPageRoute(
                            builder: (context) => const ParentProfileSetupScreen(),
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
            ],
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade50,
                  Colors.white,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.3],
              ),
            ),
            child: IndexedStack(
              index: _selectedIndex,
              children: pages,
            ),
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: BottomNavigationBar(
              elevation: 0,
              selectedItemColor: Colors.blue.shade600,
              unselectedItemColor: Colors.grey.shade400,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              items: const <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_outlined),
                  activeIcon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.notifications_outlined),
                  activeIcon: Icon(Icons.notifications),
                  label: 'Notifications',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          ),
          floatingActionButton: (_selectedIndex == 0 && userType == 'parent')
              ? FloatingActionButton.extended(
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) =>
                            const AddChildProfileScreen(isFirstChild: false)));
                    setState(() {});
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Child'),
                  backgroundColor: Colors.blue.shade600,
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

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello,',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        '${user['name']}!',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.blue.shade600],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade300.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.air,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.blue.shade600),
                const SizedBox(width: 4),
                Text(
                  stationName,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _AqiDisplayCard(aqiData: aqi),
            const SizedBox(height: 16),
            _HealthRiskCard(user: user, aqi: aqiValue),
            const SizedBox(height: 20),
            _PollutantsGrid(aqiData: aqi),
            const SizedBox(height: 20),
            _WeatherInfoCard(aqiData: aqi),
            const SizedBox(height: 16),
            _LastUpdatedCard(aqiData: aqi),
          ],
        ),
      ),
    );
  }

  Widget _buildParentDashboard(Map<String, dynamic> user,
      Map<String, dynamic> aqi, List<DocumentSnapshot> children) {
    final int aqiValue = (aqi['aqi'] is int)
        ? aqi['aqi']
        : int.tryParse(aqi['aqi'].toString()) ?? 0;
    final String stationName = aqi['city']?['name'] ?? 'Unknown Station';

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello,',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              '${user['name']}!',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.green.shade400, Colors.green.shade600],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.shade300.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.family_restroom,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _AqiDisplayCard(aqiData: aqi),
                  const SizedBox(height: 8),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on,
                            size: 14, color: Colors.blue.shade600),
                        const SizedBox(width: 4),
                        Text(
                          stationName,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _PollutantsGrid(aqiData: aqi),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.child_care,
                          color: Colors.blue.shade600,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "Your Children's Profiles",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 6.0),
                  child: Card(
                    elevation: 3,
                    shadowColor: riskColor.withOpacity(0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: riskColor.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          colors: [
                            riskColor.withOpacity(0.05),
                            Colors.white,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                riskColor.withOpacity(0.8),
                                riskColor,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: riskColor.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.child_care,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        title: Text(
                          child['name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text(
                            (child['healthConditions'] as List?)?.join(', ') ??
                                'No conditions listed',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [riskColor.withOpacity(0.8), riskColor],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: riskColor.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
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
                  ),
                );
              },
              childCount: children.length,
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
        ],
      ),
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

  IconData _getAqiIcon(int aqi) {
    if (aqi > 200) return Icons.dangerous;
    if (aqi > 150) return Icons.warning_amber_rounded;
    if (aqi > 100) return Icons.info_outline;
    if (aqi > 50) return Icons.check_circle_outline;
    return Icons.check_circle;
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
          colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.4), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_getAqiIcon(finalAqi), color: color, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Live Air Quality Index',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              finalAqi.toString(),
              style: TextStyle(
                fontSize: 64,
                color: color,
                fontWeight: FontWeight.bold,
                height: 1,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.8), color],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                _getAqiText(finalAqi),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
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
      {'key': 'no2', 'name': 'NO₂', 'icon': Icons.local_shipping, 'unit': 'ppb'},
      {'key': 'so2', 'name': 'SO₂', 'icon': Icons.factory, 'unit': 'ppb'},
      {'key': 'co', 'name': 'CO', 'icon': Icons.smoke_free, 'unit': 'ppm'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.shade400, Colors.purple.shade600],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.analytics_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Pollutant Levels',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
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
        gradient: LinearGradient(
          colors: [Colors.white, Colors.blue.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade100.withOpacity(0.5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade600],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
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
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade400, Colors.orange.shade600],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.wb_sunny_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Weather Conditions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade50, Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orange.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.shade100.withOpacity(0.5),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              if (temp != null)
                _WeatherItem(
                  icon: Icons.thermostat,
                  label: 'Temp',
                  value: '${temp}°C',
                  color: Colors.red,
                ),
              if (humidity != null)
                _WeatherItem(
                  icon: Icons.water_drop,
                  label: 'Humidity',
                  value: '$humidity%',
                  color: Colors.blue,
                ),
              if (pressure != null)
                _WeatherItem(
                  icon: Icons.speed,
                  label: 'Pressure',
                  value: '$pressure',
                  color: Colors.purple,
                ),
              if (wind != null)
                _WeatherItem(
                  icon: Icons.air,
                  label: 'Wind',
                  value: '$wind m/s',
                  color: Colors.teal,
                ),
            ],
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
  final Color color;

  const _WeatherItem({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.8), color],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
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

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.blue.shade100],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade100.withOpacity(0.5),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.blue.shade600],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.update,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Last Updated',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  timestamp,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: riskColor.withOpacity(0.4), width: 2),
        boxShadow: [
          BoxShadow(
            color: riskColor.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [riskColor.withOpacity(0.8), riskColor],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: riskColor.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(riskIcon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Personalized Risk',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Based on current AQI & your health data',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [riskColor.withOpacity(0.8), riskColor],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: riskColor.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              risk,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}