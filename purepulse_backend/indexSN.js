// TEST SCRIPT 1: STANDARD ALERT (with Enhanced Notification)
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

// Helper function to get the risk level description
function getAqiDescription(aqi) {
  if (aqi > 100) return 'Unhealthy for Sensitive Groups';
  return 'Good';
}

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
        
        // --- THIS IS THE ONLY CHANGED PART ---
        const description = getAqiDescription(currentAqi);
        const message = { 
          notification: { 
            title: `⚠️ High AQI Alert - ${description}`, 
            body: `Hi ${user.name}, the AQI is now ${currentAqi}, which poses a risk due to your health conditions. It's recommended to limit prolonged outdoor exertion today.`
          }, 
          token: user.fcmToken 
        };
        // ------------------------------------

        await messaging.send(message);
        console.log(`   SUCCESS: Sent standard alert to ${user.name}.`);

        await db.collection('users').doc(user.uid).collection('notifications').add({
            title: message.notification.title,
            body: message.notification.body,
            timestamp: admin.firestore.FieldValue.serverTimestamp()
        });
        console.log(`   -> Saved standard alert to history for ${user.name}.`);

      }
    } catch (error) {
        const userName = userDoc.data().name || userDoc.id;
        console.error(`   ERROR: Failed to process user "${userName}". Reason: ${error.message}`);
    }
  }
}

cron.schedule('*/1 * * * *', checkAqiAndSendAlerts);
console.log('✅ TEST 1 SCRIPT RUNNING...');