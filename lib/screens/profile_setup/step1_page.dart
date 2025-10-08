// lib/screens/profile_setup/step1_page.dart
import 'package:flutter/material.dart';
import 'package:purepulse_app/utils/colors.dart';

class Step1Page extends StatefulWidget {
  final Function(Map<String, dynamic>) onNext;
  const Step1Page({super.key, required this.onNext});

  @override
  State<Step1Page> createState() => _Step1PageState();
}

class _Step1PageState extends State<Step1Page> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _cityController = TextEditingController();

  void _submit() {
    if (_formKey.currentState!.validate()) {
      widget.onNext({
        'name': _nameController.text.trim(),
        'age': int.tryParse(_ageController.text.trim()) ?? 0,
        'city': _cityController.text.trim(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Step 1 of 2: Personal Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (value) => value!.isEmpty ? 'Please enter your name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ageController,
                decoration: const InputDecoration(labelText: 'Age'),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? 'Please enter your age' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(labelText: 'Your City'),
                validator: (value) => value!.isEmpty ? 'Please enter your city' : null,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('NEXT', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}