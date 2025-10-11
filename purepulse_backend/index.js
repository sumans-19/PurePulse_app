// Import required packages
require('dotenv').config();
const admin = require('firebase-admin');
const cron = require('node-cron');
const axios = require('axios');

// Initialize Firebase
const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const messaging = admin.messaging();
const waqiToken = process.env.WAQI_TOKEN;

const NOTIFICATION_COOLDOWN_HOURS = 6;

// Helper function to send and save notifications
async function sendAndSaveNotification(user, message, type) {
  try {
    await messaging.send(message);
    console.log(`✅ Notification (${type}) sent to ${user.name}`);

    await db.collection('users').doc(user.uid).collection('notifications').add({
      title: message.notification.title,
      body: message.notification.body,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });

    const now = new Date();
    const lastTimestamps = user.lastNotificationTimestamps || {};
    await db.collection('users').doc(user.uid).set({
      lastNotificationTimestamps: { ...lastTimestamps, [type]: now }
    }, { merge: true });

  } catch (error) {
    console.error(`❌ Error sending ${type} notification to ${user.name}:`, error.message);
  }
}

// Main function to check and send alerts
const checkAqiAndSendAlerts = async () => {
  console.log(`[${new Date().toLocaleString()}] Running intelligent AQI check...`);
  
  try {
    const usersSnapshot = await db.collection('users').get();
    if (usersSnapshot.empty) return console.log('No users found.');

    for (const userDoc of usersSnapshot.docs) {
      const user = { uid: userDoc.id, ...userDoc.data() };
      const { 
        primaryLocation, fcmToken, name, userType, 
        healthConditions = [], outdoorActivities = [], lastNotificationTimestamps = {} 
      } = user;

      if (!primaryLocation || !fcmToken) continue;

      // --- NEW: Flag to track if a notification was sent for this user ---
      let notificationSent = false;

      const aqiUrl = `https://api.waqi.info/feed/geo:${primaryLocation.latitude};${primaryLocation.longitude}/?token=${waqiToken}`;
      const response = await axios.get(aqiUrl);

      if (response.data.status !== 'ok' || !response.data.data.aqi) continue;
      
      const currentAqi = response.data.data.aqi;
      console.log(`\nProcessing ${name} | Location AQI: ${currentAqi}`);
      
      const now = new Date();
      const historyRef = db.collection('users').doc(user.uid).collection('aqi_history');
      await historyRef.add({ aqi: currentAqi, timestamp: now });

      // --- PRIORITY 1: SPIKE ALERT ---
      const lastSpikeAlert = lastNotificationTimestamps.spike?.toDate() || new Date(0);
      if (now - lastSpikeAlert > NOTIFICATION_COOLDOWN_HOURS * 3600 * 1000) {
        const historySnapshot = await historyRef.orderBy('timestamp', 'desc').limit(2).get();
        if (historySnapshot.docs.length > 1) {
          const previousAqi = historySnapshot.docs[1].data().aqi;
          if (currentAqi - previousAqi >= 40) {
            const message = { notification: { title: '⚠️ Sudden AQI Spike!', body: `Hi ${name}, air quality in your area worsened rapidly to an AQI of ${currentAqi}.` }, token: fcmToken };
            await sendAndSaveNotification(user, message, 'spike');
            notificationSent = true;
          }
        }
      }
      
      if (notificationSent) continue;

      // --- PRIORITY 2: FORECAST ALERT ---
      const lastForecastAlert = lastNotificationTimestamps.forecast?.toDate() || new Date(0);
      if (outdoorActivities.length > 0 && (now - lastForecastAlert > NOTIFICATION_COOLDOWN_HOURS * 3600 * 1000)) {
        const forecast = response.data.data.forecast?.daily?.pm25;
        const todayStr = now.toISOString().slice(0, 10);
        const todayForecast = forecast?.find(day => day.day === todayStr);
        if (todayForecast && todayForecast.avg > 100) {
           const message = { notification: { title: 'Heads-up for Today!', body: `Hi ${name}, the AQI is forecasted to be poor today. You may want to reschedule outdoor activities.` }, token: fcmToken };
           await sendAndSaveNotification(user, message, 'forecast');
           notificationSent = true;
        }
      }

      if (notificationSent) continue;

      // --- PRIORITY 3: STANDARD HIGH AQI ALERT ---
      const lastStandardAlert = lastNotificationTimestamps.standard?.toDate() || new Date(0);
      if (now - lastStandardAlert > NOTIFICATION_COOLDOWN_HOURS * 3600 * 1000) {
        if (userType === 'parent') {
          const childrenSnapshot = await db.collection('users').doc(user.uid).collection('children').get();
          if (childrenSnapshot.empty) continue;
          for (const childDoc of childrenSnapshot.docs) {
            const child = childDoc.data();
            const isSensitive = child.healthConditions?.some(c => ['Asthma', 'Bronchitis', 'COPD'].includes(c));
            const childThreshold = isSensitive ? 100 : 150;
            if (currentAqi > childThreshold) {
              const description = getAqiDescription(currentAqi);
              const message = {
                notification: {
                  title: `High AQI Alert for ${child.name}`,
                  body: `The current AQI is ${currentAqi} (${description}), which is above the recommended level for ${child.name}.`
                },
                token: fcmToken
              };
              await sendAndSaveNotification(user, message, 'standard');
              notificationSent = true;
              break; 
            }
          }
        } else { // Personal user
          const isSensitive = healthConditions.some(c => ['Asthma', 'Bronchitis', 'COPD'].includes(c));
          const aqiThreshold = isSensitive ? 100 : 150;
          if (currentAqi > aqiThreshold) {
            const description = getAqiDescription(currentAqi);
            const message = { notification: { title: 'High AQI Alert', body: `Hi ${name}, the current AQI is ${currentAqi} (${description}), which is above your personalized risk level.` }, token: fcmToken };
            await sendAndSaveNotification(user, message, 'standard');
            notificationSent = true;
          }
        }
      }
      
      // --- NEW: Final check to print the log message ---
      if (!notificationSent) {
          console.log(` -> Nothing to alert for ${name}.`);
      }
    }
  } catch (error) {
    console.error('An error occurred during the AQI check process:', error);
  }
};

function getAqiDescription(aqi) {
  if (aqi > 300) return 'Hazardous';
  if (aqi > 200) return 'Very Unhealthy';
  if (aqi > 150) return 'Unhealthy';
  if (aqi > 100) return 'Unhealthy for Sensitive Groups';
  if (aqi > 50) return 'Moderate';
  return 'Good';
}

// Production schedule: Run once every hour.
cron.schedule('*/1 * * * *', checkAqiAndSendAlerts);

console.log('✅ Intelligent backend server started. Checks will run every hour.');