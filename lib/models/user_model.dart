class UserModel {
  final String uid;
  final String email;
  final String name;
  final UserType userType;
  final DateTime createdAt;
  
  // Personal user fields
  final int? age;
  final List<String>? healthConditions;
  final String? outdoorRoutine;
  final String? location;
  
  // Parent user fields
  final List<String>? childrenIds;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.userType,
    required this.createdAt,
    this.age,
    this.healthConditions,
    this.outdoorRoutine,
    this.location,
    this.childrenIds,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      userType: UserType.values.firstWhere(
        (e) => e.toString() == 'UserType.${map['userType']}',
        orElse: () => UserType.personal,
      ),
      createdAt: DateTime.parse(map['createdAt']),
      age: map['age'],
      healthConditions: map['healthConditions'] != null 
          ? List<String>.from(map['healthConditions']) 
          : null,
      outdoorRoutine: map['outdoorRoutine'],
      location: map['location'],
      childrenIds: map['childrenIds'] != null 
          ? List<String>.from(map['childrenIds']) 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'userType': userType.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'age': age,
      'healthConditions': healthConditions,
      'outdoorRoutine': outdoorRoutine,
      'location': location,
      'childrenIds': childrenIds,
    };
  }

  // Risk calculation based on health conditions
  RiskLevel getRiskLevel() {
    if (healthConditions == null || healthConditions!.isEmpty) {
      return age != null && age! < 12 || age! > 65 
          ? RiskLevel.medium 
          : RiskLevel.low;
    }
    
    final severeConditions = ['asthma', 'copd', 'cardiovascular', 'heart_disease'];
    final hasSevereCondition = healthConditions!.any(
      (condition) => severeConditions.contains(condition.toLowerCase())
    );
    
    return hasSevereCondition ? RiskLevel.high : RiskLevel.medium;
  }
}

enum UserType { personal, parent }

enum RiskLevel { low, medium, high }