// TEST SCRIPT 4: PARENT/CHILD ALERT (with Moderate AQI)
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
  console.log(`[TEST 4] Running Parent/Child Alert check...`);
  const usersSnapshot = await db.collection('users').get();
  
  for (const userDoc of usersSnapshot.docs) {
    try {
      const user = { uid: userDoc.id, ...userDoc.data() };
      
      if (!user.fcmToken || user.userType !== 'parent') continue;
      
      console.log(`-> Found parent: ${user.name}. Checking children...`);

      const childrenSnapshot = await db.collection('users').doc(user.uid).collection('children').get();
      if (childrenSnapshot.empty) continue;

      // --- CHANGE 1: Use a "Moderate" AQI value ---
      const currentAqi = 75; 

      for (const childDoc of childrenSnapshot.docs) {
        const child = childDoc.data();
        const isSensitive = child.healthConditions?.some(c => ['Asthma', 'Bronchitis', 'COPD'].includes(c));

        // --- CHANGE 2: Lower the threshold for sensitive children ---
        const childThreshold = isSensitive ? 50 : 100; // Triggers if sensitive

        console.log(`  - Checking child: ${child.name}. Sensitive: ${isSensitive}. Threshold: ${childThreshold}.`);

        if (currentAqi > childThreshold) {
          console.log(`    ALERT: AQI is above threshold for ${child.name}.`);

          // --- CHANGE 3: Updated notification message for moderate risk ---
          const message = {
            notification: {
              title: `Moderate AQI Alert for ${child.name}`,
              body: `Hi ${user.name}, the AQI is ${currentAqi} (Moderate), which may affect sensitive individuals like ${child.name}. Consider shorter outdoor playtime today.`
            },
            token: user.fcmToken
          };
          // -----------------------------------------------------------------

          await messaging.send(message);
          console.log(`    SUCCESS: Sent parent alert for ${child.name}.`);

          await db.collection('users').doc(user.uid).collection('notifications').add({
              title: message.notification.title,
              body: message.notification.body,
              timestamp: admin.firestore.FieldValue.serverTimestamp()
          });
          console.log(`    -> Saved parent alert to history for ${user.name}.`);
          
          break; 
        }
      }
    } catch (error) {
      const userName = userDoc.data().name || userDoc.id;
    }
  }
}

cron.schedule('*/1 * * * *', checkAqiAndSendAlerts);
console.log('✅ TEST 4 SCRIPT RUNNING...');