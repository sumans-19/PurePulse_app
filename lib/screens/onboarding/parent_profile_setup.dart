import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../models/child_profile_model.dart';
import '../../services/auth_service.dart';
import '../home/home_screen.dart';

class ParentProfileSetup extends StatefulWidget {
  final String uid;
  final String name;
  final String email;

  const ParentProfileSetup({
    Key? key,
    required this.uid,
    required this.name,
    required this.email,
  }) : super(key: key);

  @override
  State<ParentProfileSetup> createState() => _ParentProfileSetupState();
}

class _ParentProfileSetupState extends State<ParentProfileSetup> {
  final List<ChildData> _children = [];
  bool _isLoading = false;

  void _addChild() {
    setState(() {
      _children.add(ChildData());
    });
  }

  void _removeChild(int index) {
    setState(() {
      _children.removeAt(index);
    });
  }

  Future<void> _completeSetup() async {
    // Validate all children data
    for (var i = 0; i < _children.length; i++) {
      if (!_children[i].validate()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please complete all fields for Child ${i + 1}'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    if (_children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one child profile'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      // Create child profiles and collect IDs
      final childrenIds = <String>[];

      for (var childData in _children) {
        final docRef = firestore.collection('children').doc();
        childrenIds.add(docRef.id);

        final childProfile = ChildProfile(
          id: docRef.id,
          parentId: widget.uid,
          name: childData.nameController.text.trim(),
          age: int.parse(childData.ageController.text),
          healthConditions: childData.selectedHealthConditions.contains('None')
              ? []
              : childData.selectedHealthConditions,
          schoolLocation: childData.schoolLocationController.text.trim(),
          outdoorActivities: childData.outdoorActivities,
          createdAt: DateTime.now(),
        );

        batch.set(docRef, childProfile.toMap());
      }

      // Create parent user profile
      final userModel = UserModel(
        uid: widget.uid,
        email: widget.email,
        name: widget.name,
        userType: UserType.parent,
        createdAt: DateTime.now(),
        childrenIds: childrenIds,
      );

      batch.set(
        firestore.collection('users').doc(widget.uid),
        userModel.toMap(),
      );

      await batch.commit();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent Profile Setup'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Add Your Children',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We\'ll monitor air quality and send you alerts to keep them safe',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: 24),

                    // Children forms
                    ..._children.asMap().entries.map((entry) {
                      final index = entry.key;
                      final child = entry.value;
                      return _ChildForm(
                        childNumber: index + 1,
                        childData: child,
                        onRemove: () => _removeChild(index),
                      );
                    }).toList(),

                    // Add child button
                    OutlinedButton.icon(
                      onPressed: _addChild,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Another Child'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Complete button (fixed at bottom)
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _completeSetup,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Complete Setup',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChildData {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController schoolLocationController = TextEditingController();
  
  final List<String> availableHealthConditions = [
    'Asthma',
    'Allergies',
    'Respiratory Issues',
    'None',
  ];
  
  final List<String> selectedHealthConditions = [];
  String? outdoorActivities;

  bool validate() {
    return nameController.text.isNotEmpty &&
        ageController.text.isNotEmpty &&
        int.tryParse(ageController.text) != null &&
        schoolLocationController.text.isNotEmpty &&
        selectedHealthConditions.isNotEmpty &&
        outdoorActivities != null;
  }

  void dispose() {
    nameController.dispose();
    ageController.dispose();
    schoolLocationController.dispose();
  }
}

class _ChildForm extends StatefulWidget {
  final int childNumber;
  final ChildData childData;
  final VoidCallback onRemove;

  const _ChildForm({
    required this.childNumber,
    required this.childData,
    required this.onRemove,
  });

  @override
  State<_ChildForm> createState() => _ChildFormState();
}

class _ChildFormState extends State<_ChildForm> {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Child ${widget.childNumber}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: widget.onRemove,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Name
            TextFormField(
              controller: widget.childData.nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Age
            TextFormField(
              controller: widget.childData.ageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Age',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // School Location
            TextFormField(
              controller: widget.childData.schoolLocationController,
              decoration: const InputDecoration(
                labelText: 'School/Daycare Location',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Health Conditions
            Text(
              'Health Conditions',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.childData.availableHealthConditions.map((condition) {
                final isSelected = widget.childData.selectedHealthConditions.contains(condition);
                return FilterChip(
                  label: Text(condition),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (condition == 'None') {
                        widget.childData.selectedHealthConditions.clear();
                        if (selected) {
                          widget.childData.selectedHealthConditions.add(condition);
                        }
                      } else {
                        widget.childData.selectedHealthConditions.remove('None');
                        if (selected) {
                          widget.childData.selectedHealthConditions.add(condition);
                        } else {
                          widget.childData.selectedHealthConditions.remove(condition);
                        }
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Outdoor Activities
            Text(
              'Outdoor Activities',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ...['Minimal', 'Moderate (Sports/Play)', 'Very Active'].map((activity) {
              return RadioListTile<String>(
                title: Text(activity),
                value: activity.toLowerCase(),
                groupValue: widget.childData.outdoorActivities,
                onChanged: (value) {
                  setState(() {
                    widget.childData.outdoorActivities = value;
                  });
                },
                contentPadding: EdgeInsets.zero,
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}