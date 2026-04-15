# Firebase Cloud Messaging — handoff for backend

This app uses **Firebase Cloud Messaging (FCM)** for push notifications on **Android** and **iOS**. The Flutter client is wired in `lib/main.dart`, `lib/core/notification_service/notification_service.dart`, and stores every received message locally for the in-app **Notifications** screen (`lib/services/push_inbox_service.dart`).

## What to share with backend

1. **Firebase project**
   - Project ID and name (as used in Firebase Console).
2. **Server keys / FCM API**
   - Prefer **HTTP v1** with a **service account** JSON (Google Cloud). Legacy server key is deprecated.
3. **Android**
   - Package name / application id must match the build the user installs (see `android/app/build.gradle` → `applicationId` and `google-services.json`).
4. **iOS**
   - **APNs** auth key or certificates uploaded in Firebase Console → Project settings → Cloud Messaging.
   - **Bundle ID** must match Xcode / `GoogleService-Info.plist`.

> **Security:** Do not commit service account JSON or server secrets to the app repo. Backend keeps credentials on the server only.

## Device token on the LMS API

After login, the app sends an **FCM registration token** to your API where applicable (e.g. Google sign-in flow uses `fcm_token` in the social login body — see `lib/services/auth_service.dart`).

Backend should:

- Store **one or more tokens per user/device** (token refresh can invalidate old values).
- Expect **token refresh** — subscribe to updates or re-read token on each login if you add a dedicated `POST /users/fcm-token` endpoint later.

## Payload recommendations

### Best for this app (reliable tray + foreground + inbox)

Send a **notification** block **and** a **data** block. Example JSON (FCM v1 `message` body):

```json
{
  "message": {
    "token": "<DEVICE_FCM_TOKEN>",
    "notification": {
      "title": "New assignment",
      "body": "You have a new task in Biology 101."
    },
    "data": {
      "title": "New assignment",
      "body": "You have a new task in Biology 101.",
      "type": "assignment",
      "action_value": "/courses/bio-101/assignments/42"
    },
    "android": {
      "priority": "HIGH",
      "notification": {
        "channel_id": "high_importance_channel",
        "sound": "default"
      }
    },
    "apns": {
      "headers": {
        "apns-priority": "10"
      },
      "payload": {
        "aps": {
          "sound": "default",
          "badge": 1
        }
      }
    }
  }
}
```

**Android channel:** the app declares default channel id `high_importance_channel` in `AndroidManifest.xml` (`com.google.firebase.messaging.default_notification_channel_id`).

### Data-only messages

If you send **only** `data` (no `notification`):

- **Android:** the background handler can run and the app shows a **local** notification + saves to inbox.
- **iOS:** behaviour depends on APNs / delivery; prefer including `notification` for user-visible alerts unless you have a specific silent-push design.

**Data values** should be **strings** (FCM requirement for `data` map).

### Title/body fallbacks

If `notification.title` / `notification.body` are missing, the client falls back to `data['title']`, `data['subject']`, `data['body']`, `data['message']`, `data['content']`.

## Client behaviour (summary)

| App state        | Typical behaviour |
|-----------------|-------------------|
| **Foreground**  | `onMessage` → local notification + **inbox** |
| **Background**  | Data / combined messages: background isolate may run → local notification + **inbox**. Notification-only may be shown by OS; inbox entry when user opens from tap (`getInitialMessage` / `onMessageOpenedApp`) or when handler runs. |
| **Terminated**  | `FirebaseMessaging.onBackgroundMessage` registered in `main()` before `runApp`. Tap to open → `getInitialMessage` → **inbox**. |

The **Notifications** screen merges **LMS API** notifications (`GET /notifications`) with **local FCM inbox** items (`source: fcm_local`).

## iOS notes

- `UIBackgroundModes` includes `remote-notification` in `ios/Runner/Info.plist`.
- `AppDelegate` calls `FirebaseApp.configure()`.

## Android notes

- `POST_NOTIFICATIONS` permission for Android 13+.
- `google-services` Gradle plugin applied on the app module used for release builds (see Groovy `android/app/build.gradle` in this repo).

## Testing checklist for backend

1. Send test message from Firebase Console to a single FCM token.
2. Verify **foreground** (app open): alert + row in Notifications.
3. Verify **background**: tray notification; open app → row present.
4. Verify **force-stop / killed**: tray notification; tap → app opens → row present.
5. Confirm LMS list still loads when API returns empty (local rows only).
