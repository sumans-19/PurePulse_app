// Import required packages
require('dotenv').config(); // Loads environment variables from .env file
const admin = require('firebase-admin');
const cron = require('node-cron');
const axios = require('axios');

// Load your service account key
const serviceAccount = require('./serviceAccountKey.json');

// Initialize the Firebase Admin SDK
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const messaging = admin.messaging();
const openWeatherApiKey = process.env.OPENWEATHER_API_KEY;

/**
 * The core function that efficiently checks AQI and sends alerts.
 */
const checkAqiAndSendAlerts = async () => {
  console.log(`[${new Date().toLocaleString()}] Running scheduled AQI check...`);
  
  try {
    const usersSnapshot = await db.collection('users').get();
    if (usersSnapshot.empty) {
      console.log('No users found.');
      return;
    }

    // --- OPTIMIZATION LOGIC START ---

    // 1. Group all users by their location.
    // We create a "map" where each key is a unique location (rounded to ~1km)
    // and the value is an array of users at that location.
    const locationsMap = new Map();
    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      const { primaryLocation, fcmToken } = userData;

      if (!primaryLocation || !fcmToken) {
        continue; // Skip users with incomplete data
      }

      // Round lat/lon to 2 decimal places to group nearby users.
      const lat = primaryLocation.latitude.toFixed(2);
      const lon = primaryLocation.longitude.toFixed(2);
      const locationKey = `${lat},${lon}`;
      
      if (!locationsMap.has(locationKey)) {
        locationsMap.set(locationKey, []);
      }
      locationsMap.get(locationKey).push(userData);
    }

    console.log(`Found ${locationsMap.size} unique locations to check.`);

    // 2. Now, loop over the UNIQUE locations, making one API call per location.
    for (const [locationKey, users] of locationsMap.entries()) {
      const [lat, lon] = locationKey.split(',');
      
      const aqiUrl = `http://api.openweathermap.org/data/2.5/air_pollution?lat=${lat}&lon=${lon}&appid=${openWeatherApiKey}`;
      const response = await axios.get(aqiUrl);
      const aqi = response.data.list[0].main.aqi;

      console.log(`AQI for location ${locationKey} is ${aqi}.`);

      // --- THIS IS THE CORRECTED PART ---
      
      // Keep this 'if' statement commented out for the test
      // if (aqi >= 3) {

        // ✅ UNCOMMENT THIS LOOP. It is required.
        for (const user of users) {
          
          // We define the variable as 'message' here...
          const message = {
            notification: {
              title: '✅ Test Notification',
              body: `Hi ${user.name}, your PurePulse alerts are working!`
            },
            token: user.fcmToken
          };

          console.log(`Sending notification to ${user.name}...`);
          
          // ...so we must use the same variable name, 'message', here.
          messaging.send(message).catch(error => {
            console.error('Failed to send notification to', user.name, error);
          });
        }// ✅ Also UNCOMMENT this closing bracket.

      // Keep this 'if' statement's closing bracket commented out
      // }
    }
    // --- OPTIMIZATION LOGIC END ---

  } catch (error) {
    console.error('An error occurred during the AQI check process:', error);
  }
};

/**
 * Helper function to describe the AQI value.
 */
function getAqiDescription(aqi) {
  switch (aqi) {
    case 1: return 'Good';
    case 2: return 'Fair';
    case 3: return 'Moderate';
    case 4: return 'Poor';
    case 5: return 'Very Poor';
    default: return 'Unknown';
  }
}

// Schedule the task to run once every hour at the start of the hour.
cron.schedule('*/1 * * * *', checkAqiAndSendAlerts);

console.log('✅ Backend server started. Optimized AQI checks will run every hour.');