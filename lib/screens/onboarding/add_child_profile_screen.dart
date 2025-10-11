import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:purepulse_app/services/firestore_service.dart';
import 'package:purepulse_app/screens/home/home_screen.dart';
import 'package:purepulse_app/screens/onboarding/parent_profile_setup.dart';

class AddChildProfileScreen extends StatefulWidget {
  final bool isFirstChild;
  final DocumentSnapshot? childDoc;
  const AddChildProfileScreen(
      {super.key, this.isFirstChild = true, this.childDoc});

  @override
  State<AddChildProfileScreen> createState() => _AddChildProfileScreenState();
}

class _AddChildProfileScreenState extends State<AddChildProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  DateTime? _dateOfBirth;

  final List<String> _commonConditions = [
    'Asthma',
    'Allergies',
    'Bronchitis',
    'Eczema',
    'Hay Fever',
    'Sinusitis'
  ];
  final List<String> _selectedConditions = [];
  final TextEditingController _conditionController = TextEditingController();
  final List<Map<String, dynamic>> _activities = [];

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _conditionController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.childDoc != null) {
      final data = widget.childDoc!.data() as Map<String, dynamic>;
      _nameController.text = data['name'] ?? '';
      _dateOfBirth = (data['dateOfBirth'] as Timestamp?)?.toDate();
      if (_dateOfBirth != null) {
        _dobController.text = DateFormat('MMMM d, y').format(_dateOfBirth!);
      }
      _selectedConditions
          .addAll(List<String>.from(data['healthConditions'] ?? []));
      _activities.addAll(
          List<Map<String, dynamic>>.from(data['outdoorActivities'] ?? []));
    }
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

      if (widget.childDoc != null) {
        await firestoreService.updateChildProfile(
            parentId, widget.childDoc!.id, childData);
        Navigator.of(context).pop();
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        await firestoreService.addChildProfile(parentId, childData);
        Navigator.of(context).pop();

        if (mounted) {
          if (widget.isFirstChild) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => _buildSuccessDialog(),
            );
          } else {
            Navigator.of(context).pop();
          }
        }
      }
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save child profile: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Widget _buildSuccessDialog() {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle, color: Colors.green.shade600, size: 48),
            ),
            const SizedBox(height: 20),
            const Text(
              'Child Added Successfully!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Would you like to add another child?',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _resetForm();
                    },
                    child: const Text('Add Another'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.blue.shade600,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                            builder: (context) =>
                                const ParentProfileSetupScreen()),
                      );
                    },
                    child: const Text('Finish Setup'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Add Activity",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Activity Name',
                      hintText: 'e.g., Playground, Sports',
                      prefixIcon: const Icon(Icons.sports_soccer),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    readOnly: true,
                    onTap: () async {
                      startTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
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
                      prefixIcon: const Icon(Icons.access_time_filled),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    readOnly: true,
                    onTap: () async {
                      endTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (endTime != null) {
                        endTimeController.text = endTime!.format(context);
                      }
                    },
                    validator: (value) => value == null || value.isEmpty
                        ? 'Please select a time'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
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
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Colors.blue.shade600,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Add'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Child's Profile"),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        automaticallyImplyLeading: !widget.isFirstChild,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic Information Section
              _buildSectionTitle('Basic Information', Icons.person_outline),
              const SizedBox(height: 16),
              _buildCard(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: "Child's Name",
                        hintText: 'Enter full name',
                        prefixIcon: const Icon(Icons.child_care),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? "Please enter the child's name"
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _dobController,
                      decoration: InputDecoration(
                        labelText: "Date of Birth",
                        hintText: 'Select date',
                        prefixIcon: const Icon(Icons.calendar_today),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      readOnly: true,
                      onTap: _selectDate,
                      validator: (value) => value == null || value.isEmpty
                          ? "Please select a date of birth"
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Health Conditions Section
              _buildSectionTitle('Health Conditions', Icons.health_and_safety_outlined),
              const SizedBox(height: 8),
              Text(
                'Select any applicable conditions',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
              const SizedBox(height: 12),
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
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
                          selectedColor: Colors.blue.shade50,
                          checkmarkColor: Colors.blue.shade700,
                          backgroundColor: Colors.white,
                          side: BorderSide(
                            color: isSelected ? Colors.blue.shade600 : Colors.grey.shade300,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
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
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      onSubmitted: _addCustomCondition,
                    ),
                    if (_selectedConditions.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      Text(
                        'Selected:',
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
                            deleteIcon: const Icon(Icons.close, size: 18),
                            onDeleted: () {
                              setState(() {
                                _selectedConditions.remove(condition);
                              });
                            },
                            backgroundColor: Colors.blue.shade50,
                            side: BorderSide.none,
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Outdoor Activities Section
              _buildSectionTitle('Outdoor Activities', Icons.park_outlined),
              const SizedBox(height: 8),
              Text(
                'Track times when your child is outdoors',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
              const SizedBox(height: 12),
              _buildCard(
                child: Column(
                  children: [
                    if (_activities.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          children: [
                            Icon(Icons.directions_run, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              'No activities added yet',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _activities.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final activity = _activities[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: Colors.green.shade50,
                              child: Icon(Icons.sports_soccer, color: Colors.green.shade700, size: 20),
                            ),
                            title: Text(
                              activity['name'],
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${activity['startTime']} - ${activity['endTime']}',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                              onPressed: () {
                                setState(() {
                                  _activities.removeAt(index);
                                });
                              },
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add Activity'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _showAddActivityDialog,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveChildProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue.shade600,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    widget.isFirstChild ? 'Save Child Profile' : 'Save Changes',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 24, color: Colors.blue.shade700),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}