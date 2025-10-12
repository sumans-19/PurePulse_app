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
import 'package:purepulse_app/screens/chat/chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _pulseController;
  late AnimationController _slideController;

  @override
  void initState() {
    super.initState();
    _setupFCM();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
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
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      ScaleTransition(
                        scale: Tween<double>(begin: 1.0, end: 1.3).animate(
                          CurvedAnimation(
                            parent: _pulseController,
                            curve: Curves.easeInOut,
                          ),
                        ),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF06b6d4).withOpacity(0.2),
                          ),
                        ),
                      ),
                      const CircularProgressIndicator(
                        color: Color(0xFF06b6d4),
                        strokeWidth: 3,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Loading air quality data...',
                    style: TextStyle(
                      color: Color(0xFF0e7490),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
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
            elevation: 0,
            backgroundColor: const Color(0xFF0891b2),
            title: Text(
              _selectedIndex == 0
                  ? 'Dashboard'
                  : _selectedIndex == 1
                      ? 'Notifications'
                      : 'Profile',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            automaticallyImplyLeading: false,
            actions: [
              if (_selectedIndex == 0 && userType == 'parent')
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Add Child',
                  onPressed: () {
                    Navigator.of(context)
                        .push(MaterialPageRoute(
                          builder: (context) =>
                              const AddChildProfileScreen(isFirstChild: false),
                        ))
                        .then((_) => setState(() {}));
                  },
                ),
              if (_selectedIndex == 1)
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined),
                  tooltip: 'Clear All Notifications',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext dialogContext) {
                        return AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: const Text('Clear History?'),
                          content: const Text(
                            'Are you sure you want to delete all notifications? This cannot be undone.',
                          ),
                          actions: <Widget>[
                            TextButton(
                              child: const Text('Cancel'),
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
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
            ],
          ),
          body: IndexedStack(
            index: _selectedIndex,
            children: pages,
          ),
          bottomNavigationBar: BottomNavigationBar(
            selectedItemColor: const Color(0xFF0891b2),
            unselectedItemColor: Colors.grey,
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
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ChatScreen()),
              );
            },
            child: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Ask PurePulse Assist',
          ),
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
          _buildHeaderSection(user['name'], stationName),
          const SizedBox(height: 24),
          _AqiDisplayCard(aqiData: aqi, pulseController: _pulseController),
          const SizedBox(height: 20),
          _HealthRiskCard(user: user, aqi: aqiValue),
          const SizedBox(height: 24),
          _QuickStatsRow(aqiData: aqi),
          const SizedBox(height: 20),
          _PollutantsGrid(aqiData: aqi),
          const SizedBox(height: 20),
          _WeatherInfoCard(aqiData: aqi),
          const SizedBox(height: 20),
          _LastUpdatedCard(aqiData: aqi),
          const SizedBox(height: 16),
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
                _buildHeaderSection(user['name'], stationName),
                const SizedBox(height: 24),
                _AqiDisplayCard(
                    aqiData: aqi, pulseController: _pulseController),
                const SizedBox(height: 20),
                _QuickStatsRow(aqiData: aqi),
                const SizedBox(height: 20),
                _PollutantsGrid(aqiData: aqi),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF06b6d4).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.family_restroom,
                          color: Color(0xFF0891b2), size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Your Children's Profiles",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0e7490),
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

              return _ChildProfileCard(
                child: child,
                risk: risk,
                riskColor: riskColor,
                index: index,
              );
            },
            childCount: children.length,
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
      ],
    );
  }

  Widget _buildHeaderSection(String name, String location) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0891b2).withOpacity(0.1),
            const Color(0xFF06b6d4).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF06b6d4).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF06b6d4).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wb_sunny_outlined,
                color: Color(0xFF0891b2), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, $name!',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0e7490),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        size: 14, color: Color(0xFF0891b2)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF0891b2),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickStatsRow extends StatelessWidget {
  final Map<String, dynamic> aqiData;
  const _QuickStatsRow({required this.aqiData});

  @override
  Widget build(BuildContext context) {
    final iaqi = aqiData['iaqi'] as Map<String, dynamic>?;
    if (iaqi == null || iaqi.isEmpty) return const SizedBox.shrink();

    final pm25 = iaqi['pm25']?['v'];
    final temp = iaqi['t']?['v'];
    final humidity = iaqi['h']?['v'];

    return Row(
      children: [
        if (pm25 != null)
          Expanded(
            child: _QuickStatCard(
              icon: Icons.blur_on,
              label: 'PM2.5',
              value: '$pm25',
              unit: 'μg/m³',
            ),
          ),
        if (pm25 != null && temp != null) const SizedBox(width: 12),
        if (temp != null)
          Expanded(
            child: _QuickStatCard(
              icon: Icons.thermostat,
              label: 'Temp',
              value: '$temp',
              unit: '°C',
            ),
          ),
        if ((pm25 != null || temp != null) && humidity != null)
          const SizedBox(width: 12),
        if (humidity != null)
          Expanded(
            child: _QuickStatCard(
              icon: Icons.water_drop,
              label: 'Humidity',
              value: '$humidity',
              unit: '%',
            ),
          ),
      ],
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;

  const _QuickStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF06b6d4).withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF06b6d4).withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF0891b2), size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0e7490),
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 10,
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

class _ChildProfileCard extends StatefulWidget {
  final Map<String, dynamic> child;
  final String risk;
  final Color riskColor;
  final int index;

  const _ChildProfileCard({
    required this.child,
    required this.risk,
    required this.riskColor,
    required this.index,
  });

  @override
  State<_ChildProfileCard> createState() => _ChildProfileCardState();
}

class _ChildProfileCardState extends State<_ChildProfileCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 300 + (widget.index * 100)),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.3, 0),
          end: Offset.zero,
        ).animate(_animation),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: widget.riskColor.withOpacity(0.3), width: 2),
              boxShadow: [
                BoxShadow(
                  color: widget.riskColor.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              widget.riskColor.withOpacity(0.2),
                              widget.riskColor.withOpacity(0.1),
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.child_care,
                            color: widget.riskColor, size: 30),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: widget.riskColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.favorite,
                              color: Colors.white, size: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.child['name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: Color(0xFF0e7490),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF06b6d4).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            (widget.child['healthConditions'] as List?)
                                    ?.join(', ') ??
                                'No conditions',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF0891b2),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: widget.riskColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: widget.riskColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          widget.risk,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
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

class _AqiDisplayCard extends StatelessWidget {
  final Map<String, dynamic> aqiData;
  final AnimationController pulseController;

  const _AqiDisplayCard({
    required this.aqiData,
    required this.pulseController,
  });

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
    if (aqi > 150) return Icons.warning_amber;
    if (aqi > 100) return Icons.error_outline;
    if (aqi > 50) return Icons.info_outline;
    return Icons.check_circle_outline;
  }

  @override
  Widget build(BuildContext context) {
    final aqiValue = aqiData['aqi'];
    final int finalAqi =
        (aqiValue is int) ? aqiValue : int.tryParse(aqiValue.toString()) ?? 0;
    final color = _getAqiColor(finalAqi);

    return Stack(
      children: [
        ScaleTransition(
          scale: Tween<double>(begin: 1.0, end: 1.05).animate(
            CurvedAnimation(
              parent: pulseController,
              curve: Curves.easeInOut,
            ),
          ),
          child: Container(
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
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(_getAqiIcon(finalAqi),
                                color: color, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Live Air Quality',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Color(0xFF0e7490),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'LIVE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0e7490),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: color.withOpacity(0.3), width: 8),
                          gradient: RadialGradient(
                            colors: [
                              color.withOpacity(0.1),
                              color.withOpacity(0.05),
                            ],
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            finalAqi.toString(),
                            style: TextStyle(
                              fontSize: 72,
                              color: color,
                              fontWeight: FontWeight.bold,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'AQI',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0891b2),
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 10),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      _getAqiText(finalAqi),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PollutantsGrid extends StatelessWidget {
  final Map<String, dynamic> aqiData;
  const _PollutantsGrid({required this.aqiData});

  @override
  Widget build(BuildContext context) {
    final iaqi = aqiData['iaqi'] as Map<String, dynamic>?;
    if (iaqi == null || iaqi.isEmpty) return const SizedBox.shrink();

    final allPollutants = [
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

    final pollutants = allPollutants.where((pollutant) {
      return iaqi[pollutant['key']]?['v'] != null;
    }).toList();

    if (pollutants.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF06b6d4).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.analytics_outlined,
                  color: Color(0xFF0891b2), size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Pollutant Levels',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0e7490),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.35,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: pollutants.length,
          itemBuilder: (context, index) {
            final pollutant = pollutants[index];
            final value = iaqi[pollutant['key']]?['v'];

            return _PollutantCard(
              name: pollutant['name'] as String,
              value: value.toString(),
              unit: pollutant['unit'] as String,
              icon: pollutant['icon'] as IconData,
              index: index,
            );
          },
        ),
      ],
    );
  }
}

class _PollutantCard extends StatefulWidget {
  final String name;
  final String value;
  final String unit;
  final IconData icon;
  final int index;

  const _PollutantCard({
    required this.name,
    required this.value,
    required this.unit,
    required this.icon,
    required this.index,
  });

  @override
  State<_PollutantCard> createState() => _PollutantCardState();
}

class _PollutantCardState extends State<_PollutantCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getPollutantRecommendation(String pollutant, double value) {
    switch (pollutant) {
      case 'PM2.5':
        if (value > 100)
          return 'Avoid outdoor activities. Fine particulates are extremely harmful. Stay indoors and use air purifiers if available.';
        if (value > 50)
          return 'Reduce outdoor exposure. Wear N95 masks if you must go outside.';
        return 'Air quality is acceptable. You can safely enjoy outdoor activities.';
      case 'PM10':
        if (value > 150)
          return 'Limit outdoor activities. Coarse dust particles are affecting air quality significantly.';
        if (value > 75)
          return 'Reduce strenuous outdoor activities. Consider wearing masks outdoors.';
        return 'PM10 levels are safe for outdoor activities.';
      case 'Ozone':
        if (value > 100)
          return 'High ozone levels detected. Avoid outdoor exercise and stay indoors if possible.';
        if (value > 60)
          return 'Ozone levels are elevated. Limit strenuous activities outdoors.';
        return 'Ozone levels are healthy. Safe to exercise outdoors.';
      case 'NO₂':
        if (value > 200)
          return 'Very high NO₂ levels (vehicle emissions). Avoid busy traffic areas and stay indoors.';
        if (value > 100)
          return 'High NO₂ levels. Reduce exposure, especially near traffic congestion.';
        return 'NO₂ levels are acceptable for normal outdoor activities.';
      case 'SO₂':
        if (value > 125)
          return 'Elevated SO₂ levels (industrial emissions). Limit outdoor exposure and use masks.';
        if (value > 50)
          return 'SO₂ levels are moderate. Sensitive groups should limit outdoor time.';
        return 'SO₂ levels are healthy and safe.';
      case 'CO':
        if (value > 1000)
          return 'Very high CO levels detected. Avoid outdoor activities and ensure good ventilation indoors.';
        if (value > 500)
          return 'High CO levels present. Limit time outdoors, especially during peak hours.';
        return 'CO levels are safe for normal activities.';
      default:
        return 'Monitor this pollutant level for any changes.';
    }
  }

  void _showPollutantDialog() {
    final recommendation =
        _getPollutantRecommendation(widget.name, double.parse(widget.value));

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF06b6d4).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    Icon(widget.icon, color: const Color(0xFF0891b2), size: 20),
              ),
              const SizedBox(width: 12),
              Text(widget.name),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF06b6d4).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text(
                      widget.value,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0e7490),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.unit,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Recommendation:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF0e7490),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                recommendation,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Close',
                style: TextStyle(color: Color(0xFF0891b2)),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _controller.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _controller.reverse();
        _showPollutantDialog();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isPressed
                  ? const Color(0xFF06b6d4).withOpacity(0.5)
                  : const Color(0xFF06b6d4).withOpacity(0.2),
              width: _isPressed ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF06b6d4)
                    .withOpacity(_isPressed ? 0.15 : 0.08),
                blurRadius: _isPressed ? 12 : 8,
                offset: Offset(0, _isPressed ? 6 : 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF0891b2).withOpacity(0.15),
                          const Color(0xFF06b6d4).withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(widget.icon,
                        size: 20, color: const Color(0xFF0891b2)),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06b6d4).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: Color(0xFF0891b2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        widget.value,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0e7490),
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.unit,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 3,
                    width: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0891b2), Color(0xFF06b6d4)],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeatherInfoCard extends StatelessWidget {
  final Map<String, dynamic> aqiData;
  const _WeatherInfoCard({required this.aqiData});

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
                color: const Color(0xFF06b6d4).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.wb_cloudy_outlined,
                  color: Color(0xFF0891b2), size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Weather Conditions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0e7490),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF06b6d4).withOpacity(0.05),
                const Color(0xFF0891b2).withOpacity(0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF06b6d4).withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF06b6d4).withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (temp != null)
                  Expanded(
                    child: _WeatherItem(
                      icon: Icons.thermostat,
                      label: 'Temperature',
                      value: '$temp°C',
                    ),
                  ),
                if (humidity != null) ...[
                  if (temp != null) _VerticalDivider(),
                  Expanded(
                    child: _WeatherItem(
                      icon: Icons.water_drop,
                      label: 'Humidity',
                      value: '$humidity%',
                    ),
                  ),
                ],
                if (pressure != null) ...[
                  if (temp != null || humidity != null) _VerticalDivider(),
                  Expanded(
                    child: _WeatherItem(
                      icon: Icons.speed,
                      label: 'Pressure',
                      value: '$pressure hPa',
                    ),
                  ),
                ],
                if (wind != null) ...[
                  if (temp != null || humidity != null || pressure != null)
                    _VerticalDivider(),
                  Expanded(
                    child: _WeatherItem(
                      icon: Icons.air,
                      label: 'Wind Speed',
                      value: '$wind m/s',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _VerticalDivider() {
    return Container(
      width: 1,
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF06b6d4).withOpacity(0),
            const Color(0xFF06b6d4).withOpacity(0.3),
            const Color(0xFF06b6d4).withOpacity(0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }
}

class _WeatherItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _WeatherItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF0891b2).withOpacity(0.15),
                const Color(0xFF06b6d4).withOpacity(0.1),
              ],
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF0891b2), size: 24),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Color(0xFF0e7490),
          ),
        ),
      ],
    );
  }
}

class _LastUpdatedCard extends StatelessWidget {
  final Map<String, dynamic> aqiData;
  const _LastUpdatedCard({required this.aqiData});

  @override
  Widget build(BuildContext context) {
    final time = aqiData['time'];
    if (time == null) return const SizedBox.shrink();

    final timestamp = time['s'] ?? 'Unknown';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF06b6d4).withOpacity(0.1),
            const Color(0xFF0891b2).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF06b6d4).withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF06b6d4).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  const Icon(Icons.update, size: 20, color: Color(0xFF0891b2)),
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
                      color: Color(0xFF0891b2),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timestamp,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF0e7490),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 16, color: Colors.green),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthRiskCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final int aqi;

  const _HealthRiskCard({required this.user, required this.aqi});

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

  String _getRiskAdvice(String risk) {
    if (risk == 'High Risk') return 'Avoid outdoor activities';
    if (risk == 'Moderate Risk') return 'Limit outdoor exposure';
    return 'Safe for outdoor activities';
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
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      riskColor.withOpacity(0.3),
                      riskColor.withOpacity(0.2),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: riskColor.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(riskIcon, color: riskColor, size: 32),
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
                        fontSize: 17,
                        color: Color(0xFF0e7490),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Based on current AQI & health profile',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: riskColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: riskColor.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  risk,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: riskColor.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: riskColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _getRiskAdvice(risk),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.w600,
                    ),
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
