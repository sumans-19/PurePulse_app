import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:purepulse_app/screens/home/home_screen.dart';
import 'package:purepulse_app/services/firestore_service.dart';
import 'add_child_profile_screen.dart'; // We'll create this next

class ParentProfileSetupScreen extends StatefulWidget {
  const ParentProfileSetupScreen({super.key});

  @override
  State<ParentProfileSetupScreen> createState() =>
      _ParentProfileSetupScreenState();
}

class _ParentProfileSetupScreenState extends State<ParentProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  Position? _currentPosition;
  bool _isFetchingLocation = false;
  final TextEditingController _locationController = TextEditingController();

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  // This location logic is the same as the personal setup screen
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

  Future<void> _saveAndProceed() async {
  if (!_formKey.currentState!.validate()) return;

  final firestoreService = context.read<FirestoreService>();
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) return;

  Map<String, dynamic> parentProfileData = {
    'primaryLocation': {
      'latitude': _currentPosition!.latitude,
      'longitude': _currentPosition!.longitude,
    },
    'profileComplete': true,
  };

  try {
    await firestoreService.updateUser(user.uid, parentProfileData);
    if (mounted) {
      // --- THIS IS THE CORRECTED NAVIGATION ---
      // This is now the final step, so go to the HomeScreen.
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
                  "We need your primary location to monitor air quality for your family."),
              const SizedBox(height: 24),
              
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
              
              ElevatedButton(
                onPressed: _saveAndProceed,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Save & Add First Child'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}