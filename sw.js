self.addEventListener('install', (event) => {
    event.waitUntil(self.skipWaiting());
});

self.addEventListener('activate', (event) => {
    event.waitUntil(self.clients.claim());
});

self.addEventListener('push', (event) => {
    const payload = (() => {
        if (!event.data) return {};
        try {
            return event.data.json();
        } catch (error) {
            return { body: event.data.text() };
        }
    })();

    const title = payload.title || 'One Place';
    const options = {
        body: payload.body || 'You have a new notification.',
        icon: payload.icon || 'assets/icons/icon-192.png',
        badge: payload.badge || 'assets/icons/icon-72.png',
        data: payload.data || {}
    };

    event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', (event) => {
    event.notification.close();
    const targetUrl = event.notification?.data?.url || '/';
    event.waitUntil(
        self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
            if (clientList.length > 0) {
                return clientList[0].focus();
            }
            return self.clients.openWindow(targetUrl);
        })
    );
});
