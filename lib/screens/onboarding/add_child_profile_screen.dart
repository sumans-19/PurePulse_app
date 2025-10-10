import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:purepulse_app/services/firestore_service.dart';
import 'package:purepulse_app/screens/home/home_screen.dart';

class AddChildProfileScreen extends StatefulWidget {
  const AddChildProfileScreen({super.key});

  @override
  State<AddChildProfileScreen> createState() => _AddChildProfileScreenState();
}

class _AddChildProfileScreenState extends State<AddChildProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  DateTime? _dateOfBirth;

  Map<String, bool> healthConditions = {
    'Asthma': false,
    'Allergies': false,
    'Bronchitis': false,
    'Other Respiratory Issues': false,
  };

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime.now(),
      firstDate: DateTime(2000), // Adjust range for children
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _dateOfBirth) {
      setState(() {
        _dateOfBirth = picked;
        _dobController.text = DateFormat('MMMM d, y').format(picked);
      });
    }
  }

  Future<void> _saveChildProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    final firestoreService = context.read<FirestoreService>();
    final parentId = FirebaseAuth.instance.currentUser?.uid;

    print('Attempting to save child profile for parent UID: $parentId');
    if (parentId == null) return;

    final selectedConditions = healthConditions.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
    
    final Map<String, dynamic> childData = {
      'name': _nameController.text.trim(),
      'dateOfBirth': _dateOfBirth,
      'healthConditions': selectedConditions,
    };

    try {
      await firestoreService.addChildProfile(parentId, childData);
      if (mounted) {
        // After adding the first child, go to the main home screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch(e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save child profile: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Child's Profile"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("Child's Information", style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 24),
              
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Child's Name"),
                validator: (value) => value == null || value.isEmpty ? "Please enter the child's name" : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _dobController,
                decoration: const InputDecoration(labelText: "Date of Birth"),
                readOnly: true,
                onTap: _selectDate,
                validator: (value) => value == null || value.isEmpty ? "Please select a date of birth" : null,
              ),
              const SizedBox(height: 24),
              
              Text("Health Conditions (if any)", style: Theme.of(context).textTheme.titleMedium),
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
              const SizedBox(height: 32),
              
              ElevatedButton(
                onPressed: _saveChildProfile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Save Child and Finish Setup'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}