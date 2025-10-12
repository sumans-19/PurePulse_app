// TEST SCRIPT 2: FORECAST ALERT (with Lower Threshold)
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
      
      // --- CHANGE 1: Temporarily removed the activity check for testing ---
      if (!user.fcmToken) {
        continue;
      }
      
      // --- CHANGE 2: Simulate a "Moderate" forecast ---
      const todayStr = new Date().toISOString().slice(0, 10);
      const fakeForecast = { daily: { pm25: [{ day: todayStr, avg: 75 }] } };
      const forecastAqi = fakeForecast.daily.pm25[0].avg;
      
      console.log(`-> Checking ${user.name}. Forecast: ${forecastAqi}.`);
      
      // --- CHANGE 3: Lower the trigger threshold ---
      if (forecastAqi > 50) { // Now triggers on "Moderate"
        
        // --- CHANGE 4: Updated notification text for a "Moderate" forecast ---
        const message = { 
          notification: { 
            title: '✅ Forecast Alert Test (Moderate)', 
            body: `Hi ${user.name}, today's AQI forecast is Moderate at ${forecastAqi}. Consider taking precautions during your outdoor activities. Tap for more details.`
          }, 
          token: user.fcmToken 
        };
        
        await messaging.send(message);
        console.log(`   SUCCESS: Sent forecast alert to ${user.name}.`);

        await db.collection('users').doc(user.uid).collection('notifications').add({
            title: message.notification.title,
            body: message.notification.body,
            timestamp: admin.firestore.FieldValue.serverTimestamp()
        });
        console.log(`   -> Saved forecast alert to history for ${user.name}.`);
      }
    } catch (error) {
      const userName = userDoc.data().name || userDoc.id;
      console.error(`   ERROR: Failed to process user "${userName}". Reason: ${error.message}`);
    }
  }
}

cron.schedule('*/1 * * * *', checkAqiAndSendAlerts);
console.log('✅ TEST 2 SCRIPT RUNNING...');