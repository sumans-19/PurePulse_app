import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:purepulse_app/services/firestore_service.dart';
import 'package:purepulse_app/screens/home/home_screen.dart';
import 'package:provider/provider.dart';

class PersonalProfileSetupScreen extends StatefulWidget {
  const PersonalProfileSetupScreen({super.key});

  @override
  State<PersonalProfileSetupScreen> createState() =>
      _PersonalProfileSetupScreenState();
}

class _PersonalProfileSetupScreenState
    extends State<PersonalProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  // --- NEW & UPDATED STATE VARIABLES ---
  DateTime? _dateOfBirth;
  Position? _currentPosition;
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

  // New list for multiple outdoor activities (replaces start/end time)
  final List<Map<String, dynamic>> _activities = [];

  // Controllers for form fields
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  @override
  void dispose() {
    _dobController.dispose();
    _locationController.dispose();
    _conditionController.dispose();
    super.dispose();
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

  // --- NEW: Function to show a dialog for adding an activity ---
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
          title: const Text('Add Outdoor Activity'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  decoration: const InputDecoration(
                      labelText: 'Activity Name (e.g., Running)'),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter a name'
                      : null,
                  onSaved: (value) => activityName = value,
                ),
                TextFormField(
                  controller: startTimeController,
                  decoration: const InputDecoration(labelText: 'Start Time'),
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
                TextFormField(
                  controller: endTimeController,
                  decoration: const InputDecoration(labelText: 'End Time'),
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
                child: const Text('Cancel')),
            ElevatedButton(
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
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  // --- UPDATED: Save profile logic with new data structures ---
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your primary location')),
      );
      return;
    }

    final firestoreService = context.read<FirestoreService>();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    Map<String, dynamic> profileData = {
      'dateOfBirth': _dateOfBirth,
      'healthConditions': _selectedConditions, // Save the new dynamic list
      'outdoorActivities': _activities, // Save the new activity list
      'primaryLocation': {
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude,
      },
      'profileComplete': true,
    };

    try {
      await firestoreService.updateUser(user.uid, profileData);
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save profile: $e')),
      );
    }
  }

  // --- Unchanged helper functions ---
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime.now(),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
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
        _currentPosition = position;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Complete Your Profile"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("Tell us about yourself",
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text(
                  "This information helps us provide personalized air quality alerts."),
              const SizedBox(height: 24),

              // Date of Birth (UI is unchanged)
              TextFormField(
                controller: _dobController,
                decoration: const InputDecoration(labelText: "Date of Birth"),
                readOnly: true,
                onTap: _selectDate,
                validator: (value) => value == null || value.isEmpty
                    ? 'Please select your date of birth'
                    : null,
              ),
              const SizedBox(height: 24),

              // --- NEW: Health Conditions Input Section ---
              Text("Health Conditions (if any)",
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text("Select from common conditions:",
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: _commonConditions.map((condition) {
                  final isSelected = _selectedConditions.contains(condition);
                  return FilterChip(
                    label: Text(condition),
                    selected: isSelected,
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

              // Custom condition input
              TextField(
                controller: _conditionController,
                decoration: const InputDecoration(
                  hintText: 'Or add a custom condition and press Enter',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: _addCustomCondition,
              ),
              const SizedBox(height: 16),

              // Display all selected conditions
              if (_selectedConditions.isNotEmpty)
                const Text("Your selected conditions:", style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: _selectedConditions.map((condition) {
                  return Chip(
                    label: Text(condition),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () {
                      setState(() {
                        _selectedConditions.remove(condition);
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // --- NEW: Outdoor Routine Section ---
              Text("Your Outdoor Activities",
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (_activities.isEmpty)
                const Center(
                    child: Text('No activities added yet.',
                        style: TextStyle(color: Colors.grey))),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _activities.length,
                itemBuilder: (context, index) {
                  final activity = _activities[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    child: ListTile(
                      title: Text(activity['name']),
                      subtitle: Text(
                          '${activity['startTime']} - ${activity['endTime']}'),
                      trailing: IconButton(
                        icon:
                            const Icon(Icons.delete_outline, color: Colors.red),
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
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Activity'),
                onPressed: _showAddActivityDialog,
              ),
              const SizedBox(height: 24),

              // Location (UI is unchanged)
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: "Primary Location",
                  hintText: "Click the button to fetch",
                ),
                readOnly: true,
                validator: (value) => value == null || value.isEmpty
                    ? 'Please fetch your location'
                    : null,
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _getCurrentLocation,
                icon: _isFetchingLocation
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location),
                label: Text(_isFetchingLocation
                    ? 'Fetching...'
                    : 'Get Current Location'),
              ),
              const SizedBox(height: 32),

              // Save Button (UI is unchanged)
              ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('Save Profile & Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
