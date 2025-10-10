import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:purepulse_app/services/firestore_service.dart';
import 'package:purepulse_app/screens/home/home_screen.dart';
import 'package:purepulse_app/screens/onboarding/parent_profile_setup.dart';

class AddChildProfileScreen extends StatefulWidget {
  // CORRECTED: The constructor now handles 'isFirstChild' correctly.
  final bool isFirstChild;
  const AddChildProfileScreen({super.key, this.isFirstChild = true});

  @override
  State<AddChildProfileScreen> createState() => _AddChildProfileScreenState();
}

class _AddChildProfileScreenState extends State<AddChildProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // State Variables
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  DateTime? _dateOfBirth;

  // Hybrid system for health conditions
  final List<String> _commonConditions = [
    'Asthma', 'Allergies', 'Bronchitis', 'Eczema', 'Hay Fever', 'Sinusitis'
  ];
  final List<String> _selectedConditions = [];
  final TextEditingController _conditionController = TextEditingController();

  // List for multiple outdoor activities
  final List<Map<String, dynamic>> _activities = [];

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _conditionController.dispose();
    super.dispose();
  }
  
  void _resetForm() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _dobController.clear();
    _conditionController.clear();
    setState(() {
      _dateOfBirth = null;
      _selectedConditions.clear();
      _activities.clear();
    });
  }

  // CORRECTED: This is the full save logic with the "Add Another?" dialog.
  Future<void> _saveChildProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    final firestoreService = context.read<FirestoreService>();
    final parentId = FirebaseAuth.instance.currentUser?.uid;
    if (parentId == null) return;
    
    final Map<String, dynamic> childData = {
      'name': _nameController.text.trim(),
      'dateOfBirth': _dateOfBirth,
      'healthConditions': _selectedConditions,
      'outdoorActivities': _activities,
    };

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      
      await firestoreService.addChildProfile(parentId, childData);
      
      Navigator.of(context).pop(); // Dismiss loading indicator

      if (mounted) {
        if (widget.isFirstChild) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Child Added Successfully!'),
              content: const Text('Would you like to add another child?'),
              actions: [
                TextButton(
                  child: const Text('Add Another'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _resetForm();
                  },
                ),
                ElevatedButton(
                  child: const Text('Finish Setup'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => const ParentProfileSetupScreen()),
                    );
                  },
                ),
              ],
            ),
          );
        } else {
          Navigator.of(context).pop();
        }
      }
    } catch(e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save child profile: $e')),
      );
    }
  }
  
  void _addCustomCondition(String condition) {
    final trimmedCondition = condition.trim();
    if (trimmedCondition.isNotEmpty && !_selectedConditions.contains(trimmedCondition)) {
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
          title: const Text("Add Child's Activity"),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Activity Name (e.g., Playground)'),
                  validator: (value) => value == null || value.isEmpty ? 'Please enter a name' : null,
                  onSaved: (value) => activityName = value,
                ),
                TextFormField(
                  controller: startTimeController,
                  decoration: const InputDecoration(labelText: 'Start Time'),
                  readOnly: true,
                  onTap: () async {
                    startTime = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                    if (startTime != null) {
                      startTimeController.text = startTime!.format(context);
                    }
                  },
                   validator: (value) => value == null || value.isEmpty ? 'Please select a time' : null,
                ),
                TextFormField(
                  controller: endTimeController,
                  decoration: const InputDecoration(labelText: 'End Time'),
                  readOnly: true,
                  onTap: () async {
                    endTime = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                    if (endTime != null) {
                      endTimeController.text = endTime!.format(context);
                    }
                  },
                   validator: (value) => value == null || value.isEmpty ? 'Please select a time' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
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

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _dateOfBirth) {
      setState(() {
        _dateOfBirth = picked;
        _dobController.text = DateFormat('MMMM d, y').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Child's Profile"),
        automaticallyImplyLeading: !widget.isFirstChild, // No back button during onboarding
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
              const SizedBox(height: 8),
              const Text("Select from common conditions:", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0, runSpacing: 4.0,
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
              TextField(
                controller: _conditionController,
                decoration: const InputDecoration(
                  hintText: 'Or add a custom condition and press Enter',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: _addCustomCondition,
              ),
              if (_selectedConditions.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text("Selected conditions:", style: TextStyle(fontWeight: FontWeight.bold)),
                Wrap(
                  spacing: 8.0, runSpacing: 4.0,
                  children: _selectedConditions.map((condition) {
                    return Chip(
                      label: Text(condition),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        setState(() { _selectedConditions.remove(condition); });
                      },
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 24),
              Text("Child's Outdoor Activities", style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (_activities.isEmpty)
                const Center(child: Text('No activities added yet.', style: TextStyle(color: Colors.grey))),
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
                      subtitle: Text('${activity['startTime']} - ${activity['endTime']}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () { setState(() { _activities.removeAt(index); }); },
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
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saveChildProfile,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: Text(widget.isFirstChild ? 'Save Child' : 'Save and Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}