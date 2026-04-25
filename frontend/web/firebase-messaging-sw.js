// firebase-messaging-sw.js - Firebase Cloud Messaging Service Worker
importScripts('https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.22.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyDq-J6ibZjRFyGErOB981P6vu-IyD8TY',
  authDomain: 'emlakdefter.firebaseapp.com',
  projectId: 'emlakdefter',
  messagingSenderId: '304007762415',
  appId: '1:304007762415:web:d0441c0ee6217c1b64e61a',
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Background message received:', payload);
  const notificationTitle = payload.notification?.title || 'Emlakdefter';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data,
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});