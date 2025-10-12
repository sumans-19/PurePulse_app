// TEST SCRIPT 1: STANDARD ALERT (with Moderate AQI)
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
  if (aqi > 50) return 'Moderate';
  return 'Good';
}

async function checkAqiAndSendAlerts() {
  console.log(`[TEST 1] Running Standard Alert check...`);
  const usersSnapshot = await db.collection('users').get();

  for (const userDoc of usersSnapshot.docs) {
    try {
      const user = { uid: userDoc.id, ...userDoc.data() };
      if (!user.fcmToken) continue;
      
      // --- CHANGE 1: Use a "Moderate" AQI value ---
      const currentAqi = 75; 
      
      const isSensitive = user.healthConditions?.some(c => ['Asthma', 'Bronchitis', 'COPD'].includes(c));
      
      // --- CHANGE 2: Lower the threshold for sensitive users ---
      const aqiThreshold = isSensitive ? 50 : 100; // Was 100 : 150

      console.log(`-> Checking ${user.name}. Sensitive: ${isSensitive}. Threshold: ${aqiThreshold}.`);
      if (currentAqi > aqiThreshold) {
        
        // --- CHANGE 3: Updated notification message for moderate risk ---
        const description = getAqiDescription(currentAqi);
        const message = { 
          notification: { 
            title: `Moderate AQI Alert - ${description}`, 
            body: `Hi ${user.name}, the AQI is ${currentAqi} (${description}). Sensitive individuals should consider reducing outdoor exertion.`
          }, 
          token: user.fcmToken 
        };
        // -----------------------------------------------------------------

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
        // console.error(`   ERROR: Failed to process user "${userName}". Reason: ${error.message}`);
    }
  }
}

cron.schedule('*/1 * * * *', checkAqiAndSendAlerts);
console.log('✅ TEST 1 SCRIPT RUNNING...');