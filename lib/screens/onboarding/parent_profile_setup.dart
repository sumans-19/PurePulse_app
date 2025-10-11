import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:purepulse_app/screens/home/home_screen.dart';
import 'package:purepulse_app/services/firestore_service.dart';

class ParentProfileSetupScreen extends StatefulWidget {
  const ParentProfileSetupScreen({super.key});

  @override
  State<ParentProfileSetupScreen> createState() =>
      _ParentProfileSetupScreenState();
}

class _ParentProfileSetupScreenState extends State<ParentProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // --- NEW: Storing coordinates directly for flexibility ---
  double? _latitude;
  double? _longitude;
  
  bool _isFetchingLocation = false;
  final TextEditingController _locationController = TextEditingController();

  // --- NEW: Predefined locations with Bangalore as the first ---
  final Map<String, Map<String, double>> _predefinedLocations = {
    'Bangalore': {'lat': 12.9716, 'lon': 77.5946},
    'Hyderabad': {'lat': 17.3850, 'lon': 78.4867},
    'Delhi': {'lat': 28.7041, 'lon': 77.1025},
    'Mumbai': {'lat': 19.0760, 'lon': 72.8777},
    'Chennai': {'lat': 13.0827, 'lon': 80.2707},
  };
  
  String? _selectedCity;

  @override
  void initState() {
    super.initState();
    // --- NEW: Set Bangalore as the default selection ---
    _updateLocationFromCity('Bangalore');
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  // --- NEW: Helper function to update state from the dropdown ---
  void _updateLocationFromCity(String cityName) {
    final location = _predefinedLocations[cityName]!;
    setState(() {
      _selectedCity = cityName;
      _latitude = location['lat'];
      _longitude = location['lon'];
      _locationController.text = 'Selected: $cityName';
    });
  }

  // --- UPDATED: _getCurrentLocation now updates lat/lon directly ---
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
        // Clear city selection if GPS is used
        _selectedCity = null;
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationController.text =
            'Lat: ${position.latitude.toStringAsFixed(2)}, Lon: ${position.longitude.toStringAsFixed(2)}';
      });
    } catch (e) {
      // ... (error handling)
    } finally {
      setState(() => _isFetchingLocation = false);
    }
  }

  // --- UPDATED: _saveAndProceed now uses lat/lon directly ---
  Future<void> _saveAndProceed() async {
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

    Map<String, dynamic> parentProfileData = {
      'primaryLocation': {
        'latitude': _latitude,
        'longitude': _longitude,
      },
      'profileComplete': true,
    };

    try {
      await firestoreService.updateUser(user.uid, parentProfileData);
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      // ... (error handling)
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Parent Profile Setup"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("Confirm Your Location",
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text(
                  "Select a city or use your device's GPS to monitor local air quality."),
              const SizedBox(height: 24),
              
              // --- NEW: Dropdown to select a city ---
              DropdownButtonFormField<String>(
                value: _selectedCity,
                decoration: const InputDecoration(
                  labelText: 'Select a City',
                  border: OutlineInputBorder(),
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
                validator: (value) => value == null && _latitude == null
                    ? 'Please select a city or use GPS'
                    : null,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Center(child: Text('OR')),
              ),

              // Button to get current location
              ElevatedButton.icon(
                onPressed: _isFetchingLocation ? null : _getCurrentLocation,
                icon: _isFetchingLocation
                    ? const SizedBox(
                        width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location),
                label: Text(
                    _isFetchingLocation ? 'Fetching...' : 'Use My Current Location'),
              ),
              const SizedBox(height: 24),

              // Read-only field to show the result
              TextFormField(
                controller: _locationController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: "Selected Location",
                  border: InputBorder.none,
                ),
              ),
              const SizedBox(height: 16),
              
              ElevatedButton(
                onPressed: _saveAndProceed,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Save & Finish Setup'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}