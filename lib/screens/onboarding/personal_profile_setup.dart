import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../home/home_screen.dart';

class PersonalProfileSetup extends StatefulWidget {
  final String uid;
  final String name;
  final String email;

  const PersonalProfileSetup({
    Key? key,
    required this.uid,
    required this.name,
    required this.email,
  }) : super(key: key);

  @override
  State<PersonalProfileSetup> createState() => _PersonalProfileSetupState();
}

class _PersonalProfileSetupState extends State<PersonalProfileSetup> {
  final _formKey = GlobalKey<FormState>();
  final _ageController = TextEditingController();
  final _locationController = TextEditingController();
  
  final List<String> _availableHealthConditions = [
    'Asthma',
    'COPD',
    'Cardiovascular Disease',
    'Allergies',
    'Respiratory Issues',
    'Heart Disease',
    'None',
  ];
  
  final List<String> _selectedHealthConditions = [];
  String? _outdoorRoutine;

  @override
  void dispose() {
    _ageController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _completeSetup() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedHealthConditions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one health condition (or None)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    if (_outdoorRoutine == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your outdoor routine'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final userModel = UserModel(
      uid: widget.uid,
      email: widget.email,
      name: widget.name,
      userType: UserType.personal,
      createdAt: DateTime.now(),
      age: int.parse(_ageController.text),
      healthConditions: _selectedHealthConditions.contains('None') 
          ? [] 
          : _selectedHealthConditions,
      outdoorRoutine: _outdoorRoutine,
      location: _locationController.text.trim(),
    );

    final authService = context.read<AuthService>();
    final success = await authService.createUserProfile(userModel);

    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to create profile. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Profile Setup'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Tell us about yourself',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This helps us provide personalized air quality alerts',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 32),

                // Age field
                TextFormField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Age',
                    prefixIcon: Icon(Icons.cake_outlined),
                    border: OutlineInputBorder(),
                    helperText: 'Your age helps us assess air quality risk',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your age';
                    }
                    final age = int.tryParse(value);
                    if (age == null || age < 1 || age > 120) {
                      return 'Please enter a valid age';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Location field
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location (City)',
                    prefixIcon: Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(),
                    helperText: 'We\'ll monitor air quality in your area',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your location';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Health Conditions
                Text(
                  'Health Conditions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select all that apply (this helps us customize alerts)',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableHealthConditions.map((condition) {
                    final isSelected = _selectedHealthConditions.contains(condition);
                    return FilterChip(
                      label: Text(condition),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (condition == 'None') {
                            // If None is selected, clear all others
                            _selectedHealthConditions.clear();
                            if (selected) {
                              _selectedHealthConditions.add(condition);
                            }
                          } else {
                            // If any other condition is selected, remove None
                            _selectedHealthConditions.remove('None');
                            if (selected) {
                              _selectedHealthConditions.add(condition);
                            } else {
                              _selectedHealthConditions.remove(condition);
                            }
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Outdoor Routine
                Text(
                  'Outdoor Routine',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                _OutdoorRoutineOption(
                  title: 'Minimal (Indoor most of the time)',
                  value: 'minimal',
                  groupValue: _outdoorRoutine,
                  onChanged: (value) {
                    setState(() {
                      _outdoorRoutine = value;
                    });
                  },
                ),
                _OutdoorRoutineOption(
                  title: 'Moderate (Regular commute, occasional outdoor activity)',
                  value: 'moderate',
                  groupValue: _outdoorRoutine,
                  onChanged: (value) {
                    setState(() {
                      _outdoorRoutine = value;
                    });
                  },
                ),
                _OutdoorRoutineOption(
                  title: 'Active (Daily outdoor exercise or work)',
                  value: 'active',
                  groupValue: _outdoorRoutine,
                  onChanged: (value) {
                    setState(() {
                      _outdoorRoutine = value;
                    });
                  },
                ),
                const SizedBox(height: 32),

                // Complete button
                ElevatedButton(
                  onPressed: _completeSetup,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Complete Setup',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OutdoorRoutineOption extends StatelessWidget {
  final String title;
  final String value;
  final String? groupValue;
  final ValueChanged<String?> onChanged;

  const _OutdoorRoutineOption({
    required this.title,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RadioListTile<String>(
      title: Text(title),
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }
}
