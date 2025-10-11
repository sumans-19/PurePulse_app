// TEST SCRIPT 2: FORECAST ALERT (with Error Handling and History)
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
  console.log(`[TEST 2] Running Forecast Alert check...`);
  const usersSnapshot = await db.collection('users').get();
  
  for (const userDoc of usersSnapshot.docs) {
    try {
      const user = { uid: userDoc.id, ...userDoc.data() };
      
      // Skip users who don't have activities scheduled
      if (!user.fcmToken || !user.outdoorActivities || user.outdoorActivities.length === 0) {
        continue;
      }
      
      // Simulate a bad forecast for today
      const todayStr = new Date().toISOString().slice(0, 10);
      const fakeForecast = { daily: { pm25: [{ day: todayStr, avg: 150 }] } };
      
      console.log(`-> Checking ${user.name}. Has activities: Yes. Forecast avg: ${fakeForecast.daily.pm25[0].avg}.`);
      
      if (fakeForecast.daily.pm25[0].avg > 100) {
        const message = { 
          notification: { 
            title: '✅ Forecast Alert Test', 
            body: `Hi ${user.name}, the AQI is forecasted to be poor today.` 
          }, 
          token: user.fcmToken 
        };
        
        await messaging.send(message);
        console.log(`   SUCCESS: Sent forecast alert to ${user.name}.`);

        // --- THIS IS THE ONLY ADDED CODE ---
        // Save a copy of the notification to the history subcollection
        await db.collection('users').doc(user.uid).collection('notifications').add({
            title: message.notification.title,
            body: message.notification.body,
            timestamp: admin.firestore.FieldValue.serverTimestamp()
        });
        console.log(`   -> Saved forecast alert to history for ${user.name}.`);
        // ------------------------------------

      }
    } catch (error) {
      // If an error occurs for one user, log it and continue to the next
      const userName = userDoc.data().name || userDoc.id;
      console.error(`   ERROR: Failed to process user "${userName}". Reason: ${error.message}`);
    }
  }
}

cron.schedule('*/1 * * * *', checkAqiAndSendAlerts);
console.log('✅ TEST 2 SCRIPT RUNNING...');