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

const NOTIFICATION_COOLDOWN_HOURS = 0; // Set to 0 for immediate notifications (testing)

const checkAqiAndSendAlerts = async () => {
  console.log(`[${new Date().toLocaleString()}] Running intelligent AQI check...`);
  
  try {
    const usersSnapshot = await db.collection('users').get();
    if (usersSnapshot.empty) return console.log('No users found.');

    for (const userDoc of usersSnapshot.docs) {
      const user = { uid: userDoc.id, ...userDoc.data() };
      const { 
        primaryLocation, 
        fcmToken, 
        name, 
        healthConditions = [], 
        outdoorActivities = [],
        lastNotificationTimestamps = {} 
      } = user;

      console.log(`\n📋 Processing user: ${name}`);
      console.log(`   FCM Token exists: ${!!fcmToken}`);
      console.log(`   Primary Location exists: ${!!primaryLocation}`);

      if (!primaryLocation) {
        console.log(`   ⏭️ Skipping: No primary location set`);
        continue;
      }

      if (!fcmToken) {
        console.log(`   ⏭️ Skipping: No FCM token`);
        continue;
      }

      try {
        // 1. Fetch live AQI data from the real API
        console.log(`   🌍 Fetching AQI data for coordinates: ${primaryLocation.latitude}, ${primaryLocation.longitude}`);
        const aqiUrl = `https://api.waqi.info/feed/geo:${primaryLocation.latitude};${primaryLocation.longitude}/?token=${waqiToken}`;
        const response = await axios.get(aqiUrl);

        if (response.data.status !== 'ok') {
          console.log(`   ❌ API returned status: ${response.data.status}`);
          continue;
        }

        if (!response.data.data.aqi) {
          console.log(`   ❌ No AQI data in response`);
          continue;
        }

        const currentAqi = response.data.data.aqi; // Use real AQI instead of hardcoding 125
        console.log(`   ✅ Current AQI: ${currentAqi}`);
        
        const now = new Date();

        // 2. Save current AQI to history
        const historyRef = db.collection('users').doc(user.uid).collection('aqi_history');
        await historyRef.add({ aqi: currentAqi, timestamp: now });
        console.log(`   📊 AQI saved to history`);

        // 3. CHECK FOR SUDDEN SPIKE
        const lastSpikeAlert = lastNotificationTimestamps.spike?.toDate() || new Date(0);
        const spikeAlertDue = now - lastSpikeAlert > NOTIFICATION_COOLDOWN_HOURS * 3600 * 1000;
        
        if (spikeAlertDue) {""
          const historySnapshot = await historyRef.orderBy('timestamp', 'desc').limit(2).get();
          if (historySnapshot.docs.length > 1) {
            const previousAqi = historySnapshot.docs[1].data().aqi;
            const aqiDifference = currentAqi - previousAqi;
            console.log(`   📈 Previous AQI: ${previousAqi}, Difference: ${aqiDifference}`);
            
            if (aqiDifference >= 40) {
              console.log(`   🚨 SPIKE DETECTED! Sending alert...`);
              const message = { 
                notification: { 
                  title: '⚠️ Sudden AQI Spike!', 
                  body: `Hi ${name}, air quality worsened rapidly to an AQI of ${currentAqi}.` 
                }, 
                token: fcmToken 
              };
              await messaging.send(message);
              await userDoc.ref.set({ lastNotificationTimestamps: { ...lastNotificationTimestamps, spike: now } }, { merge: true });
              console.log(`   ✅ Spike alert sent to ${name}`);
              continue; 
            }
          }
        }
        
        // 4. PROACTIVE FORECAST CHECK
        const lastForecastAlert = lastNotificationTimestamps.forecast?.toDate() || new Date(0);
        const forecastAlertDue = now - lastForecastAlert > NOTIFICATION_COOLDOWN_HOURS * 3600 * 1000;
        
        if (outdoorActivities.length > 0 && forecastAlertDue) {
          console.log(`   🏃 User has outdoor activities: ${outdoorActivities.join(', ')}`);
          const forecast = response.data.data.forecast?.daily?.pm25;
          
          if (forecast && forecast.length > 0) {
            const todayStr = now.toISOString().slice(0, 10);
            const todayForecast = forecast.find(day => day.day === todayStr);
            
            if (todayForecast) {
              console.log(`   📅 Today's forecast avg: ${todayForecast.avg}`);
              if (todayForecast.avg > 100) {
                console.log(`   📢 FORECAST ALERT! Sending alert...`);
                const message = { 
                  notification: { 
                    title: 'Heads-up for Today!', 
                    body: `Hi ${name}, the AQI is forecasted to be poor today. You may want to reschedule your outdoor activities.` 
                  }, 
                  token: fcmToken 
                };
                await messaging.send(message);
                await userDoc.ref.set({ lastNotificationTimestamps: { ...lastNotificationTimestamps, forecast: now } }, { merge: true });
                console.log(`   ✅ Forecast alert sent to ${name}`);
                continue;
              }
            }
          }
        }

        // 5. STANDARD HIGH AQI CHECK
        const lastStandardAlert = lastNotificationTimestamps.standard?.toDate() || new Date(0);
        const standardAlertDue = now - lastStandardAlert > NOTIFICATION_COOLDOWN_HOURS * 3600 * 1000;
        
        const isSensitive = healthConditions.some(c => ['Asthma', 'Bronchitis', 'COPD'].includes(c));
        const aqiThreshold = isSensitive ? 100 : 150;
        
        console.log(`   💓 Health conditions: ${healthConditions.length > 0 ? healthConditions.join(', ') : 'None'}`);
        console.log(`   ⚠️ AQI Threshold: ${aqiThreshold} (${isSensitive ? 'Sensitive' : 'Standard'})`);
        console.log(`   🕐 Standard alert due: ${standardAlertDue}`);

        if (currentAqi > aqiThreshold && standardAlertDue) {
          const description = getAqiDescription(currentAqi);
          console.log(`   🔴 HIGH AQI DETECTED! Level: ${description}`);
          const message = { 
            notification: { 
              title: 'High AQI Alert', 
              body: `Hi ${name}, the current AQI is ${currentAqi} (${description}), which is above your personalized risk level.` 
            }, 
            token: fcmToken 
          };
          await messaging.send(message);
          await userDoc.ref.set({ lastNotificationTimestamps: { ...lastNotificationTimestamps, standard: now } }, { merge: true });
          console.log(`   ✅ High AQI alert sent to ${name}`);
        } else if (currentAqi <= aqiThreshold) {
          console.log(`   ✅ AQI is within safe limits (${currentAqi} ≤ ${aqiThreshold})`);
        } else {
          console.log(`   ⏰ Standard alert on cooldown`);
        }
      } catch (userError) {
        console.error(`   ❌ Error processing user ${name}:`, userError.message);
      }
    }
  } catch (error) {
    console.error('❌ An error occurred during the AQI check process:', error);
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

// Test schedule: Run every minute for testing
cron.schedule('*/1 * * * *', checkAqiAndSendAlerts);

console.log('✅ Intelligent backend server started. Checks will run every minute.');