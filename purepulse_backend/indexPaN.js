// TEST SCRIPT 4: PARENT/CHILD ALERT (with Error Handling and History)
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
      
      // Skip any user who is not a parent or doesn't have a token
      if (!user.fcmToken || user.userType !== 'parent') continue;
      
      console.log(`-> Found parent: ${user.name}. Checking children...`);

      const childrenSnapshot = await db.collection('users').doc(user.uid).collection('children').get();
      if (childrenSnapshot.empty) continue;

      const currentAqi = 101; // Force a high AQI for sensitive children

      for (const childDoc of childrenSnapshot.docs) {
        const child = childDoc.data();
        const isSensitive = child.healthConditions?.some(c => ['Asthma', 'Bronchitis', 'COPD'].includes(c));
        const childThreshold = isSensitive ? 100 : 150;

        console.log(`  - Checking child: ${child.name}. Sensitive: ${isSensitive}. Threshold: ${childThreshold}.`);

        if (currentAqi > childThreshold) {
          console.log(`    ALERT: AQI is above threshold for ${child.name}.`);
          const message = {
            notification: {
              title: `✅ High AQI Alert for ${child.name}`,
              body: `Hi ${user.name}, the AQI is ${currentAqi}, which is above the risk level for ${child.name}.`
            },
            token: user.fcmToken
          };
          await messaging.send(message);
          console.log(`    SUCCESS: Sent parent alert for ${child.name}.`);

          // --- THIS IS THE ADDED CODE ---
          // Save a copy of the notification to the history subcollection
          await db.collection('users').doc(user.uid).collection('notifications').add({
              title: message.notification.title,
              body: message.notification.body,
              timestamp: admin.firestore.FieldValue.serverTimestamp()
          });
          console.log(`    -> Saved parent alert to history for ${user.name}.`);
          // ------------------------------------
          
          break; 
        }
      }
    } catch (error) {
      const userName = userDoc.data().name || userDoc.id;
      console.error(`   ERROR: Failed to process parent "${userName}". Reason: ${error.message}`);
    }
  }
}

cron.schedule('*/1 * * * *', checkAqiAndSendAlerts);
console.log('✅ TEST 4 SCRIPT RUNNING...');