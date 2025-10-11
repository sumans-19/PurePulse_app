// TEST SCRIPT 3: SPIKE ALERT (with Error Handling and History)
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
  console.log(`[TEST 3] Running Spike Alert check...`);
  const usersSnapshot = await db.collection('users').get();

  for (const userDoc of usersSnapshot.docs) {
    try {
      const user = { uid: userDoc.id, ...userDoc.data() };
      if (!user.fcmToken) continue; 

      // Simulate a big jump in AQI
      const currentAqi = 150;
      const previousAqi = 50;
      const difference = currentAqi - previousAqi;
      
      console.log(`-> Checking ${user.name}. Current: ${currentAqi}, Previous: ${previousAqi}, Difference: ${difference}.`);

      if (difference >= 40) {
        
        // --- THIS IS THE ONLY CHANGED PART ---
        const message = { 
          notification: { 
            title: '⚠️ Sudden Spike Alert!', 
            body: `Hi ${user.name}, the AQI has rapidly worsened to ${currentAqi}. It's recommended to close windows and avoid outdoor activity for the next hour.` 
          }, 
          token: user.fcmToken 
        };
        // ------------------------------------

        await messaging.send(message);
        console.log(`   SUCCESS: Sent spike alert to ${user.name}.`);

        await db.collection('users').doc(user.uid).collection('notifications').add({
            title: message.notification.title,
            body: message.notification.body,
            timestamp: admin.firestore.FieldValue.serverTimestamp()
        });
        console.log(`   -> Saved spike alert to history for ${user.name}.`);
      }
    } catch (error) {
      const userName = userDoc.data().name || userDoc.id;
      console.error(`   ERROR: Failed to process user "${userName}". Reason: ${error.message}`);
    }
  }
}

cron.schedule('*/1 * * * *', checkAqiAndSendAlerts);
console.log('✅ TEST 3 SCRIPT RUNNING...');