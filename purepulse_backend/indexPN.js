// TEST SCRIPT 2: ENHANCED FORECAST ALERT (with Recommendations and History)
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

// Helper function to get risk level description
function getRiskLevel(aqi) {
  if (aqi > 300) return 'Hazardous';
  if (aqi > 200) return 'Very Unhealthy';
  if (aqi > 150) return 'Unhealthy';
  if (aqi > 100) return 'Unhealthy for Sensitive Groups';
  if (aqi > 50) return 'Moderate';
  return 'Good';
}

// Helper function to get time-based greeting
function getTimeBasedGreeting() {
  const hour = new Date().getHours();
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

// Helper function to generate forecast-specific recommendations
function getForecastRecommendations(forecastAqi, activities, isSensitive, healthConditions) {
  const recommendations = [];
  
  // Activity-specific recommendations
  if (activities && activities.length > 0) {
    recommendations.push('📅 Today\'s scheduled activities detected');
    
    if (forecastAqi > 150) {
      recommendations.push('❌ Consider rescheduling outdoor activities');
      recommendations.push('🏠 Plan indoor alternatives instead');
    } else if (forecastAqi > 100) {
      recommendations.push('⚠️ Reschedule activities to early morning if possible');
      recommendations.push('⏱️ Keep outdoor time short (< 30 minutes)');
      recommendations.push('😷 Wear a mask during outdoor activities');
    } else if (forecastAqi > 50 && isSensitive) {
      recommendations.push('⏰ Best time: Early morning or late evening');
      recommendations.push('🚶 Take frequent breaks during activities');
    }
  }
  
  // Preparation recommendations
  if (forecastAqi > 150) {
    recommendations.push('🛒 Stock up on essentials to avoid going out');
    recommendations.push('💊 Prepare medications in advance');
    recommendations.push('🪟 Keep windows and doors closed all day');
  } else if (forecastAqi > 100) {
    recommendations.push('🗓️ Plan to stay indoors during peak hours (10AM-4PM)');
    recommendations.push('💨 Use air purifiers at home');
    if (isSensitive) {
      recommendations.push('💊 Have rescue medications ready');
    }
  } else if (forecastAqi > 50) {
    recommendations.push('👀 Check AQI updates throughout the day');
    recommendations.push('📱 Enable real-time AQI notifications');
  }
  
  // Health condition-specific recommendations
  if (healthConditions) {
    if (healthConditions.includes('Asthma') && forecastAqi > 100) {
      recommendations.push('🫁 Use preventive inhaler as prescribed');
      recommendations.push('☎️ Keep doctor\'s contact handy');
    }
    if (healthConditions.includes('COPD') || healthConditions.includes('Bronchitis')) {
      recommendations.push('🏥 Monitor oxygen levels if available');
      recommendations.push('💧 Increase fluid intake');
    }
    if (healthConditions.includes('Heart Disease') && forecastAqi > 100) {
      recommendations.push('❤️ Avoid any physical exertion');
      recommendations.push('🩺 Monitor blood pressure regularly');
    }
  }
  
  // General preparation tips
  if (forecastAqi > 100) {
    recommendations.push('🚗 Avoid driving during peak traffic hours');
    recommendations.push('🏢 Work from home if possible');
    recommendations.push('👨‍👩‍👧 Keep children indoors');
  }
  
  return recommendations;
}

// Helper function to format activities list
function formatActivities(activities) {
  if (!activities || activities.length === 0) return '';
  
  const activityList = activities.slice(0, 3).map(a => {
    const time = a.time || 'Time not set';
    const name = a.name || 'Activity';
    return `   • ${name} at ${time}`;
  }).join('\n');
  
  return activities.length > 3 
    ? `${activityList}\n   • ...and ${activities.length - 3} more`
    : activityList;
}

// Helper function to create detailed forecast notification
// In your index.js file, replace this entire function

function createForecastNotification(userName, forecastAqi, activities, isSensitive, healthConditions) {
  const riskLevel = getRiskLevel(forecastAqi);
  const greeting = getTimeBasedGreeting();
  // We still generate the full recommendations to save them in the history
  const recommendations = getForecastRecommendations(forecastAqi, activities, isSensitive, healthConditions); 
  
  const title = `🔮 Heads-up: High AQI Forecast`;
  
  // --- THIS IS THE NEW, MORE DETAILED NOTIFICATION BODY ---
  let body = `${greeting} ${userName}! The AQI forecast for today is high at ${forecastAqi} (${riskLevel}).`;
  
  // Add activity-specific advice if activities are scheduled
  if (activities && activities.length > 0) {
      const firstActivityName = activities[0].name || 'outdoor activity';
      body += ` This may affect your scheduled '${firstActivityName}'.`;
  }
  
  // Add the rescheduling suggestion
  body += ` Consider rescheduling to early morning or after sunset when air quality is typically better.`;
  // --------------------------------------------------
  
  // The function still returns the full list of recommendations for saving to history
  return { title, body, recommendations }; 
}

async function checkAqiAndSendAlerts() {
  console.log(`[ENHANCED FORECAST] Running forecast alert check with recommendations...`);
  const usersSnapshot = await db.collection('users').get();
  
  for (const userDoc of usersSnapshot.docs) {
    try {
      const user = { uid: userDoc.id, ...userDoc.data() };
      
      // Skip users who don't have FCM token or activities
      if (!user.fcmToken || !user.outdoorActivities || user.outdoorActivities.length === 0) {
        continue;
      }
      
      // Simulate a bad forecast for today
      const todayStr = new Date().toISOString().slice(0, 10);
      const fakeForecast = { daily: { pm25: [{ day: todayStr, avg: 150 }] } };
      const forecastAqi = fakeForecast.daily.pm25[0].avg;
      
      const isSensitive = user.healthConditions?.some(c => 
        ['Asthma', 'Bronchitis', 'COPD', 'Allergies', 'Hay Fever', 'Heart Disease'].includes(c)
      );
      
      console.log(`-> Checking ${user.name}. Activities: ${user.outdoorActivities.length}. Forecast: ${forecastAqi}. Sensitive: ${isSensitive}`);
      
      if (forecastAqi > 100) {
        // Generate personalized forecast notification
        const notification = createForecastNotification(
          user.name,
          forecastAqi,
          user.outdoorActivities,
          isSensitive,
          user.healthConditions
        );
        
        const message = { 
          notification: { 
            title: notification.title, 
            body: notification.body
          },
          data: {
            type: 'forecast',
            forecastAqi: forecastAqi.toString(),
            riskLevel: getRiskLevel(forecastAqi),
            forecastDate: todayStr,
            hasActivities: 'true',
            activityCount: user.outdoorActivities.length.toString()
          },
          token: user.fcmToken,
          android: {
            priority: 'high',
            notification: {
              sound: 'default',
              channelId: 'forecast_alerts',
              priority: 'high',
              color: '#FF9800'
            }
          },
          apns: {
            payload: {
              aps: {
                sound: 'default',
                badge: 1,
                category: 'FORECAST_ALERT'
              }
            }
          }
        };
        
        await messaging.send(message);
        console.log(`   ✅ SUCCESS: Sent enhanced forecast alert to ${user.name}.`);
        
        // Save to notification history with full details
        await db.collection('users').doc(user.uid).collection('notifications').add({
          title: notification.title,
          body: notification.body,
          type: 'forecast',
          forecastAqi: forecastAqi,
          forecastDate: todayStr,
          riskLevel: getRiskLevel(forecastAqi),
          recommendations: notification.recommendations,
          activities: user.outdoorActivities,
          isSensitive: isSensitive,
          healthConditions: user.healthConditions || [],
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          read: false
        });
        console.log(`   📝 Saved enhanced forecast alert to history for ${user.name}.`);
        
        // Log recommendations and activities
        console.log(`   📅 Activities affected: ${user.outdoorActivities.length}`);
        user.outdoorActivities.slice(0, 3).forEach(activity => {
          console.log(`      - ${activity.name || 'Activity'} at ${activity.time || 'Time not set'}`);
        });
        console.log(`   💡 Recommendations sent:`);
        notification.recommendations.slice(0, 5).forEach(rec => console.log(`      - ${rec}`));
      }
    } catch (error) {
      const userName = userDoc.data().name || userDoc.id;
      console.error(`   ❌ ERROR: Failed to process user "${userName}". Reason: ${error.message}`);
    }
  }
}

// Run every minute for testing
cron.schedule('*/1 * * * *', checkAqiAndSendAlerts);
console.log('✅ ENHANCED FORECAST ALERT SCRIPT RUNNING...');
console.log('🔮 Forecast notifications will include:');
console.log('   - Predicted AQI levels');
console.log('   - Scheduled activity analysis');
console.log('   - Personalized planning recommendations');
console.log('   - Time-specific advice');
console.log('   - Health condition considerations');