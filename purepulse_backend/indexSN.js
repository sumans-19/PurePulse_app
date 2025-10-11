// TEST SCRIPT 1: STANDARD ALERT (with Error Handling and History)
require('dotenv').config();
const admin = require('firebase-admin');
const cron = require('node-cron');

const serviceAccount = require('./serviceAccountKey.json');
// Use this check to prevent re-initializing Firebase
if (!admin.apps.length) { 
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) }); 
}
const db = admin.firestore();
const messaging = admin.messaging();

async function checkAqiAndSendAlerts() {
  console.log(`[TEST 1] Running Standard Alert check...`);
  const usersSnapshot = await db.collection('users').get();

  for (const userDoc of usersSnapshot.docs) {
    try {
      const user = { uid: userDoc.id, ...userDoc.data() };
      if (!user.fcmToken) continue;
      
      const currentAqi = 101; // Force a value just above the sensitive threshold
      const isSensitive = user.healthConditions?.some(c => ['Asthma', 'Bronchitis', 'COPD'].includes(c));
      const aqiThreshold = isSensitive ? 100 : 150;

      console.log(`-> Checking ${user.name}. Sensitive: ${isSensitive}. Threshold: ${aqiThreshold}.`);
      if (currentAqi > aqiThreshold) {
        const message = { 
          notification: { 
            title: '✅ Standard Alert Test', 
            body: `Hi ${user.name}, the AQI of ${currentAqi} is above your risk level.` 
          }, 
          token: user.fcmToken 
        };
        await messaging.send(message);
        console.log(`   SUCCESS: Sent standard alert to ${user.name}.`);

        // --- THIS IS THE ONLY ADDED CODE ---
        // Save a copy of the notification to the history subcollection
        await db.collection('users').doc(user.uid).collection('notifications').add({
            title: message.notification.title,
            body: message.notification.body,
            timestamp: admin.firestore.FieldValue.serverTimestamp()
        });
        console.log(`   -> Saved standard alert to history for ${user.name}.`);
        // ------------------------------------

      }
    } catch (error) {
        const userName = userDoc.data().name || userDoc.id;
        console.error(`   ERROR: Failed to process user "${userName}". Reason: ${error.message}`);
    }
  }
}

cron.schedule('*/1 * * * *', checkAqiAndSendAlerts);
console.log('✅ TEST 1 SCRIPT RUNNING...');