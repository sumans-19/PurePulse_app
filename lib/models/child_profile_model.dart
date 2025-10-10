import 'package:purepulse_app/models/user_model.dart';

class ChildProfile {
  final String id;
  final String parentId;
  final String name;
  final int age;
  final List<String> healthConditions;
  final String? schoolLocation;
  final String? outdoorActivities;
  final DateTime createdAt;

  ChildProfile({
    required this.id,
    required this.parentId,
    required this.name,
    required this.age,
    required this.healthConditions,
    this.schoolLocation,
    this.outdoorActivities,
    required this.createdAt,
  });

  factory ChildProfile.fromMap(Map<String, dynamic> map, String id) {
    return ChildProfile(
      id: id,
      parentId: map['parentId'] ?? '',
      name: map['name'] ?? '',
      age: map['age'] ?? 0,
      healthConditions: List<String>.from(map['healthConditions'] ?? []),
      schoolLocation: map['schoolLocation'],
      outdoorActivities: map['outdoorActivities'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'parentId': parentId,
      'name': name,
      'age': age,
      'healthConditions': healthConditions,
      'schoolLocation': schoolLocation,
      'outdoorActivities': outdoorActivities,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  RiskLevel getRiskLevel() {
    // Children are generally more vulnerable
    if (age < 5) return RiskLevel.high;
    
    final severeConditions = ['asthma', 'allergies', 'respiratory'];
    final hasSevereCondition = healthConditions.any(
      (condition) => severeConditions.contains(condition.toLowerCase())
    );
    
    return hasSevereCondition ? RiskLevel.high : RiskLevel.medium;
  }
}