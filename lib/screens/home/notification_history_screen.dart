import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:purepulse_app/services/firestore_service.dart';

class NotificationHistoryScreen extends StatelessWidget {
  const NotificationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text("You are not logged in.")));
    }

    return Scaffold(
      // --- NEW: This screen now has its own AppBar ---
      appBar: AppBar(
        title: const Text('Notification History'),
        automaticallyImplyLeading: false, // No back button
        actions: [
          // --- NEW: "Clear All" button ---
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear All Notifications',
            onPressed: () {
              // Show a confirmation dialog before deleting
              showDialog(
                context: context,
                builder: (BuildContext dialogContext) {
                  return AlertDialog(
                    title: const Text('Clear History?'),
                    content: const Text('Are you sure you want to delete all notifications? This cannot be undone.'),
                    actions: <Widget>[
                      TextButton(
                        child: const Text('Cancel'),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                      TextButton(
                        child: const Text('Clear All', style: TextStyle(color: Colors.red)),
                        onPressed: () {
                          // Call the service to delete all notifications
                          context.read<FirestoreService>().clearAllNotifications(user.uid);
                          Navigator.of(dialogContext).pop();
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    "You have no notifications yet.",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data!.docs;

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notificationDoc = notifications[index];
              final notification = notificationDoc.data() as Map<String, dynamic>;
              final timestamp = (notification['timestamp'] as Timestamp?)?.toDate();
              
              return Dismissible(
                key: Key(notificationDoc.id),
                direction: DismissDirection.endToStart,
                onDismissed: (direction) {
                  context.read<FirestoreService>().deleteNotification(user.uid, notificationDoc.id);
                },
                background: Container(
                  color: Colors.redAccent,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                  child: ListTile(
                    leading: const Icon(Icons.notifications_active_outlined, color: Colors.blue),
                    title: Text(notification['title'] ?? 'No Title', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(notification['body'] ?? 'No body'),
                    trailing: Text(
                      timestamp != null ? DateFormat('MMM d, hh:mm a').format(timestamp) : '',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}