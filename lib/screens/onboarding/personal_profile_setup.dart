import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:purepulse_app/services/firestore_service.dart';
import 'package:purepulse_app/screens/home/home_screen.dart';
import 'package:provider/provider.dart';

class PersonalProfileSetupScreen extends StatefulWidget {
  final Map<String, dynamic>? profileData;

  const PersonalProfileSetupScreen({super.key, this.profileData});

  @override
  State<PersonalProfileSetupScreen> createState() =>
      _PersonalProfileSetupScreenState();
}

class _PersonalProfileSetupScreenState
    extends State<PersonalProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  DateTime? _dateOfBirth;
  double? _latitude;
  double? _longitude;
  bool _isFetchingLocation = false;

  final List<String> _commonConditions = [
    'Asthma',
    'Allergies',
    'Bronchitis',
    'COPD',
    'Hay Fever',
    'Sinusitis'
  ];
  final List<String> _selectedConditions = [];
  final TextEditingController _conditionController = TextEditingController();

  final List<Map<String, dynamic>> _activities = [];

  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  String? _selectedCity;
  final Map<String, Map<String, double>> _predefinedLocations = {
    'Hyderabad': {'lat': 17.3850, 'lon': 78.4867},
    'Bangalore': {'lat': 12.9716, 'lon': 77.5946},
    'Delhi': {'lat': 28.7041, 'lon': 77.1025},
    'Mumbai': {'lat': 19.0760, 'lon': 72.8777},
    'Chennai': {'lat': 13.0827, 'lon': 80.2707},
  };

  @override
  void initState() {
    super.initState();
    if (widget.profileData != null) {
      final data = widget.profileData!;
      _dateOfBirth = (data['dateOfBirth'] as Timestamp?)?.toDate();
      if (_dateOfBirth != null) {
        _dobController.text = DateFormat('MMMM d, y').format(_dateOfBirth!);
      }
      _selectedConditions
          .addAll(List<String>.from(data['healthConditions'] ?? []));
      _activities.addAll(
          List<Map<String, dynamic>>.from(data['outdoorActivities'] ?? []));

      final location = data['primaryLocation'];
      if (location != null) {
        _latitude = location['latitude'];
        _longitude = location['longitude'];
        _locationController.text =
            'Lat: ${_latitude?.toStringAsFixed(2)}, Lon: ${_longitude?.toStringAsFixed(2)}';
      }
    } else {
      _updateLocationFromCity('Hyderabad');
    }
  }

  @override
  void dispose() {
    _dobController.dispose();
    _locationController.dispose();
    _conditionController.dispose();
    super.dispose();
  }

  void _updateLocationFromCity(String cityName) {
    final location = _predefinedLocations[cityName]!;
    setState(() {
      _selectedCity = cityName;
      _latitude = location['lat'];
      _longitude = location['lon'];
      _locationController.text = 'Selected: $cityName';
    });
  }

  void _addCustomCondition(String condition) {
    final trimmedCondition = condition.trim();
    if (trimmedCondition.isNotEmpty &&
        !_selectedConditions.contains(trimmedCondition)) {
      setState(() {
        _selectedConditions.add(trimmedCondition);
      });
      _conditionController.clear();
    }
  }

  void _showAddActivityDialog() {
    final formKey = GlobalKey<FormState>();
    String? activityName;
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    final startTimeController = TextEditingController();
    final endTimeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.directions_walk, color: Colors.green),
              SizedBox(width: 12),
              Text('Add Outdoor Activity'),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Activity Name',
                    hintText: 'e.g., Running, Walking',
                    prefixIcon: const Icon(Icons.fitness_center),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter a name'
                      : null,
                  onSaved: (value) => activityName = value,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: startTimeController,
                  decoration: InputDecoration(
                    labelText: 'Start Time',
                    prefixIcon: const Icon(Icons.access_time),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  readOnly: true,
                  onTap: () async {
                    startTime = await showTimePicker(
                        context: context, initialTime: TimeOfDay.now());
                    if (startTime != null) {
                      startTimeController.text = startTime!.format(context);
                    }
                  },
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please select a time'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: endTimeController,
                  decoration: InputDecoration(
                    labelText: 'End Time',
                    prefixIcon: const Icon(Icons.access_time),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  readOnly: true,
                  onTap: () async {
                    endTime = await showTimePicker(
                        context: context, initialTime: TimeOfDay.now());
                    if (endTime != null) {
                      endTimeController.text = endTime!.format(context);
                    }
                  },
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please select a time'
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();
                  setState(() {
                    _activities.add({
                      'name': activityName,
                      'startTime': startTime!.format(context),
                      'endTime': endTime!.format(context),
                    });
                  });
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Add Activity'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime.now(),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.indigo.shade600,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _dateOfBirth) {
      setState(() {
        _dateOfBirth = picked;
        _dobController.text = DateFormat('MMMM d, y').format(picked);
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')),
          );
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _selectedCity = null;
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationController.text =
            'Lat: ${position.latitude.toStringAsFixed(2)}, Lon: ${position.longitude.toStringAsFixed(2)}';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get location: $e')),
      );
    } finally {
      setState(() => _isFetchingLocation = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location.')),
      );
      return;
    }

    final firestoreService = context.read<FirestoreService>();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    Map<String, dynamic> profileData = {
      'dateOfBirth': _dateOfBirth,
      'healthConditions': _selectedConditions,
      'outdoorActivities': _activities,
      'primaryLocation': {
        'latitude': _latitude,
        'longitude': _longitude,
      },
      'profileComplete': true,
    };

    try {
      await firestoreService.updateUser(user.uid, profileData);
      if (mounted) {
        if (widget.profileData != null) {
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save profile: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.indigo.shade600,
        title: Text(
          widget.profileData != null ? "Edit Profile" : "Complete Your Profile",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigo.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.3],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.indigo.shade100,
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.person_outline,
                          size: 48, color: Colors.indigo.shade600),
                      const SizedBox(height: 12),
                      Text(
                        "Tell us about yourself",
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "This helps us provide personalized air quality alerts",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Date of Birth Section
                _SectionCard(
                  icon: Icons.cake,
                  title: 'Date of Birth',
                  color: Colors.blue,
                  child: TextFormField(
                    controller: _dobController,
                    decoration: InputDecoration(
                      hintText: 'Select your date of birth',
                      prefixIcon: const Icon(Icons.calendar_today),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    readOnly: true,
                    onTap: _selectDate,
                    validator: (value) => value == null || value.isEmpty
                        ? 'Please select your date of birth'
                        : null,
                  ),
                ),

                const SizedBox(height: 20),

                // Health Conditions Section
                _SectionCard(
                  icon: Icons.health_and_safety,
                  title: 'Health Conditions',
                  color: Colors.pink,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Select common conditions:",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: _commonConditions.map((condition) {
                          final isSelected =
                              _selectedConditions.contains(condition);
                          return FilterChip(
                            label: Text(condition),
                            selected: isSelected,
                            selectedColor: Colors.pink.shade100,
                            checkmarkColor: Colors.pink.shade700,
                            onSelected: (bool selected) {
                              setState(() {
                                if (selected) {
                                  _selectedConditions.add(condition);
                                } else {
                                  _selectedConditions.remove(condition);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _conditionController,
                        decoration: InputDecoration(
                          hintText: 'Add custom condition',
                          prefixIcon: const Icon(Icons.add_circle_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        onSubmitted: _addCustomCondition,
                      ),
                      if (_selectedConditions.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          "Your selected conditions:",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: _selectedConditions.map((condition) {
                            return Chip(
                              label: Text(condition),
                              deleteIcon:
                                  const Icon(Icons.close, size: 18),
                              onDeleted: () {
                                setState(() {
                                  _selectedConditions.remove(condition);
                                });
                              },
                              backgroundColor: Colors.pink.shade50,
                              side: BorderSide(color: Colors.pink.shade200),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Activities Section
                _SectionCard(
                  icon: Icons.directions_walk,
                  title: 'Outdoor Activities',
                  color: Colors.green,
                  child: Column(
                    children: [
                      if (_activities.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              'No activities added yet',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _activities.length,
                          itemBuilder: (context, index) {
                            final activity = _activities[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade600,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.directions_walk,
                                      color: Colors.white, size: 20),
                                ),
                                title: Text(
                                  activity['name'],
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  '${activity['startTime']} - ${activity['endTime']}',
                                  style: TextStyle(color: Colors.green.shade900),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      _activities.removeAt(index);
                                    });
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Add Activity'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green.shade700,
                            side: BorderSide(color: Colors.green.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _showAddActivityDialog,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Location Section
                _SectionCard(
                  icon: Icons.location_on,
                  title: 'Primary Location',
                  color: Colors.orange,
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedCity,
                        decoration: InputDecoration(
                          labelText: 'Select a City',
                          prefixIcon: const Icon(Icons.location_city),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        items: _predefinedLocations.keys.map((String city) {
                          return DropdownMenuItem<String>(
                            value: city,
                            child: Text(city),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            _updateLocationFromCity(newValue);
                          }
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Row(
                          children: [
                            Expanded(child: Divider(color: Colors.grey.shade300)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'OR',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ),
                            Expanded(child: Divider(color: Colors.grey.shade300)),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              _isFetchingLocation ? null : _getCurrentLocation,
                          icon: _isFetchingLocation
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.my_location, color: Colors.white),
                          label: Text(
                            _isFetchingLocation
                                ? 'Fetching...'
                                : 'Use Current Location',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_locationController.text.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle,
                                  color: Colors.orange.shade700, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _locationController.text,
                                  style: TextStyle(
                                    color: Colors.orange.shade900,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.indigo.shade500, Colors.indigo.shade700],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.indigo.shade300.withOpacity(0.5),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _saveProfile,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          alignment: Alignment.center,
                          child: Text(
                            widget.profileData != null
                                ? 'Save Changes'
                                : 'Save Profile & Continue',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 22, color: color),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}