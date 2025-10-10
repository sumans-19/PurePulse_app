import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:purepulse_app/services/firestore_service.dart';
import 'package:purepulse_app/screens/home/home_screen.dart'; // We will create this later
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

  // State variables for form fields
  DateTime? _dateOfBirth;
  TimeOfDay? _routineStartTime;
  TimeOfDay? _routineEndTime;
  Position? _currentPosition;
  bool _isFetchingLocation = false;

  Map<String, bool> healthConditions = {
    'Asthma': false,
    'Allergies': false,
    'Bronchitis': false,
    'Other Respiratory Issues': false,
  };

  // Controllers
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  @override
  void dispose() {
    _dobController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _locationController.dispose();
    super.dispose();
  }

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

  Future<void> _selectTime(bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _routineStartTime = picked;
          _startTimeController.text = picked.format(context);
        } else {
          _routineEndTime = picked;
          _endTimeController.text = picked.format(context);
        }
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

    final selectedConditions = healthConditions.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    Map<String, dynamic> profileData = {
      'dateOfBirth': _dateOfBirth,
      'healthConditions': selectedConditions,
      'outdoorRoutine': {
        'start': _routineStartTime?.format(context),
        'end': _routineEndTime?.format(context),
      },
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

              // Date of Birth
              TextFormField(
                controller: _dobController,
                decoration:
                    const InputDecoration(labelText: "Date of Birth"),
                readOnly: true,
                onTap: _selectDate,
                validator: (value) =>
                    value == null || value.isEmpty ? 'Please select your date of birth' : null,
              ),
              const SizedBox(height: 16),

              // Health Conditions
              Text("Pre-existing Health Conditions",
                  style: Theme.of(context).textTheme.titleMedium),
              ...healthConditions.keys.map((String key) {
                return CheckboxListTile(
                  title: Text(key),
                  value: healthConditions[key],
                  onChanged: (bool? value) {
                    setState(() {
                      healthConditions[key] = value!;
                    });
                  },
                );
              }).toList(),
              const SizedBox(height: 16),

              // Outdoor Routine
              Text("Typical Outdoor Routine",
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _startTimeController,
                      decoration: const InputDecoration(labelText: "From"),
                      readOnly: true,
                      onTap: () => _selectTime(true),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _endTimeController,
                      decoration: const InputDecoration(labelText: "To"),
                      readOnly: true,
                      onTap: () => _selectTime(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Location
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: "Primary Location",
                  hintText: "Click the button to fetch",
                ),
                readOnly: true,
                validator: (value) =>
                    value == null || value.isEmpty ? 'Please fetch your location' : null,
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _getCurrentLocation,
                icon: _isFetchingLocation
                    ? const SizedBox(
                        width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location),
                label: Text(
                    _isFetchingLocation ? 'Fetching...' : 'Get Current Location'),
              ),
              const SizedBox(height: 32),

              // Save Button
              ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Save Profile & Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}