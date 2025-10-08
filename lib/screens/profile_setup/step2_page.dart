// lib/screens/profile_setup/step2_page.dart
import 'package:flutter/material.dart';
import 'package:purepulse_app/utils/colors.dart';

class Step2Page extends StatefulWidget {
  final VoidCallback onPrevious;
  final Function(Map<String, dynamic>) onFinish;
  final bool isLoading;
  const Step2Page({super.key, required this.onPrevious, required this.onFinish, required this.isLoading});

  @override
  State<Step2Page> createState() => _Step2PageState();
}

class _Step2PageState extends State<Step2Page> {
  String _healthCondition = 'None';
  bool _hasMorningWalk = false;

  void _submit() {
    widget.onFinish({
      'healthCondition': _healthCondition,
      'morningWalk': _hasMorningWalk,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Step 2 of 2: Health & Habits'), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onPrevious)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: _healthCondition,
              decoration: const InputDecoration(labelText: 'Pre-existing Health Conditions'),
              items: ['None', 'Asthma', 'Allergies', 'COPD']
                  .map((label) => DropdownMenuItem(child: Text(label), value: label))
                  .toList(),
              onChanged: (value) => setState(() => _healthCondition = value!),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Do you go for a morning walk?'),
              value: _hasMorningWalk,
              onChanged: (value) => setState(() => _hasMorningWalk = value),
              activeColor: primaryColor,
            ),
            const SizedBox(height: 32),
            widget.isLoading
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: primaryColor, padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text('FINISH SETUP', style: TextStyle(color: Colors.white)),
                ),
          ],
        ),
      ),
    );
  }
}