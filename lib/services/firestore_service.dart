import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ... your other methods like updateUser might be here ...

  // ADD THIS METHOD
  Future<void> createUserDocument({
    required String uid,
    required String name,
    required String email,
    required String userType,
  }) async {
    try {
      await _db.collection('users').doc(uid).set({
        'uid': uid,
        'name': name,
        'email': email,
        'userType': userType,
        'createdAt': FieldValue.serverTimestamp(),
        // You can add any other default fields here
      });
    } catch (e) {
      // It's good practice to re-throw the error to be caught in the UI
      print("Error creating user document: $e");
      throw e;
    }
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      await _db.collection('users').doc(uid).update(data);
    } catch (e) {
      print("Error updating user: $e");
      throw e;
    }
  }

  Future<void> addChildProfile(String parentId, Map<String, dynamic> childData) async {
    try {
      // This creates a 'children' subcollection under the parent's document
      await _db
          .collection('users')
          .doc(parentId)
          .collection('children')
          .add(childData);
    } catch (e) {
      print("Error adding child profile: $e");
      throw e;
    }
  }

  // GET a single user's document
  Future<DocumentSnapshot> getUser(String uid) {
    return _db.collection('users').doc(uid).get();
  }

  // GET all children from the subcollection for a parent
  Future<QuerySnapshot> getChildren(String parentId) {
    return _db.collection('users').doc(parentId).collection('children').get();
  }
  
   Future<void> saveUserToken(String uid, String token) async {
    try {
      await _db.collection('users').doc(uid).update({'fcmToken': token});
    } catch (e) {
      print("Error saving user token: $e");
    }
  }

  // Add this new method to your FirestoreService class

Future<void> deleteNotification(String userId, String notificationId) async {
  try {
    await _db
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .delete();
  } catch (e) {
    print("Error deleting notification: $e");
    // Optionally re-throw or handle the error
  }
}
}