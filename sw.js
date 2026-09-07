// Service worker — נותן לאפליקציה לעבוד גם בלי חיבור לאינטרנט.
//
// אסטרטגיה: רשת-קודם עם נפילה למטמון.
//   - כשיש רשת, תמיד מתקבלת הגרסה העדכנית מ-GitHub Pages, ולכן
//     עדכון שנדחף לריפו מגיע למשתמש לבד.
//   - כשאין רשת, מוגש מה שנשמר במטמון בביקור האחרון.
//
// המשימות עצמן נשמרות ב-localStorage ולא כאן. המטמון מחזיק רק את
// קובצי האפליקציה, ולכן מחיקתו לעולם לא מוחקת משימות.

var CACHE = 'task-manager-v1';
var ASSETS = [
  './',
  './index.html',
  './manifest.webmanifest',
  './icons/icon-192.png',
  './icons/icon-512.png'
];

self.addEventListener('install', function (e) {
  e.waitUntil(
    caches.open(CACHE)
      .then(function (c) { return c.addAll(ASSETS); })
      .then(function () { return self.skipWaiting(); })
  );
});

self.addEventListener('activate', function (e) {
  e.waitUntil(
    caches.keys()
      .then(function (keys) {
        return Promise.all(keys.filter(function (k) { return k !== CACHE; })
                               .map(function (k) { return caches.delete(k); }));
      })
      .then(function () { return self.clients.claim(); })
  );
});

self.addEventListener('fetch', function (e) {
  if (e.request.method !== 'GET') return;
  e.respondWith(
    fetch(e.request)
      .then(function (res) {
        var copy = res.clone();
        caches.open(CACHE).then(function (c) { c.put(e.request, copy); }).catch(function () {});
        return res;
      })
      .catch(function () {
        return caches.match(e.request).then(function (hit) {
          return hit || caches.match('./index.html');
        });
      })
  );
});
