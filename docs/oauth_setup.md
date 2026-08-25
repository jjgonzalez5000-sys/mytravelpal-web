# OAuth setup — Google, Facebook, Apple

The mobile app has full sign-in flows wired for Google, Facebook, Apple
and a demo backdoor. The backend has matching verifiers. Neither talks
to the real providers until you register OAuth apps and drop the
identifiers into the right places. This doc walks through each.

Until you finish setup:

- The app's **Continue with … buttons don't crash** — they show a
  SnackBar with the underlying error ("Google returned no id token",
  "Facebook login cancelled or failed", etc.) so users can fall back to
  **Continue as demo**.
- The backend's `POST /v1/auth/session` returns `401` with
  `oauth_verification_failed` if the client id / app secret env var is
  missing.

## 1. Google Sign-In

### 1.1 Register the app in Google Cloud

1. Open <https://console.cloud.google.com/apis/credentials> and create a
   new project (or pick one you own).
2. **OAuth consent screen** → configure as "External", app name
   *MyTravelPal*, support email = yours, developer email = yours. Scopes:
   `openid`, `email`, `profile`.
3. **Credentials → Create OAuth client ID** — you need one per platform:
   - **Android**: package name `com.mytravelpal.app`, SHA-1 fingerprint
     from your debug keystore. Get it with:

     ```bash
     keytool -list -v -keystore ~/.android/debug.keystore \
         -alias androiddebugkey -storepass android -keypass android \
         | grep SHA1
     ```

     For release builds, generate a proper keystore and register that
     SHA-1 too.
   - **iOS**: bundle ID `com.mytravelpal.app`. Copy the *iOS URL scheme*
     Google gives you back.
   - **Web** (only if you ship the Chrome build): authorised origin =
     your Fly URL (`https://mytravelpal-api.fly.dev`) + redirect URI
     `https://mytravelpal-api.fly.dev`.

### 1.2 Android — drop `google-services.json`

1. In the Google Cloud project add an Android app via *Firebase*
   (Firebase re-uses the same OAuth client). Download the generated
   `google-services.json`.
2. Put it at `mobile/android/app/google-services.json`.
3. Add the plugin to
   `mobile/android/app/build.gradle.kts`:

   ```kotlin
   plugins {
       // …existing…
       id("com.google.gms.google-services")
   }
   ```

   And to `mobile/android/settings.gradle.kts`:

   ```kotlin
   plugins {
       // …existing…
       id("com.google.gms.google-services") version "4.4.2" apply false
   }
   ```

### 1.3 iOS (when the platform folder exists)

1. Add the *reversed client ID* from your iOS OAuth credential as a URL
   scheme in `ios/Runner/Info.plist` under `CFBundleURLTypes`.
2. Under `ios/Runner/Info.plist` also add
   `GIDClientID = <your iOS OAuth client ID>`.

### 1.4 Backend — verify tokens

`GoogleOAuthProvider` uses the `google-auth` package (already in
`backend/pyproject.toml`). Set the env var on the API host:

```bash
fly secrets set GOOGLE_CLIENT_ID='<your Android/iOS/Web client ID>'
```

For local dev put it in `backend/.env` or export before uvicorn.

## 2. Facebook Login

### 2.1 Register the app

1. Open <https://developers.facebook.com/apps/> → *Create App* → *Consumer*.
2. On the app dashboard grab **App ID** and **App Secret**.
3. *Add product → Facebook Login → Set up*.

### 2.2 Android

1. Under *Facebook Login → Quickstart → Android*, register
   `com.mytravelpal.app` and paste the debug key hash. Generate it with:

   ```bash
   keytool -exportcert -alias androiddebugkey \
       -keystore ~/.android/debug.keystore -storepass android -keypass android \
       | openssl sha1 -binary | openssl base64
   ```

2. Add the app id and client token to
   `mobile/android/app/src/main/res/values/strings.xml`:

   ```xml
   <string name="facebook_app_id">1234567890</string>
   <string name="fb_login_protocol_scheme">fb1234567890</string>
   <string name="facebook_client_token">abcd…</string>
   ```

3. Add the meta tags + Facebook activity to `AndroidManifest.xml`
   (see `flutter_facebook_auth` README — three lines under `<application>`).

### 2.3 iOS

1. Under *Quickstart → iOS*, register the bundle id.
2. Add the app id, client token, display name and URL scheme to
   `ios/Runner/Info.plist` as documented in `flutter_facebook_auth`.

### 2.4 Backend — verify tokens

`FacebookOAuthProvider` uses Graph API to debug the access token. Set:

```bash
fly secrets set FACEBOOK_APP_SECRET='<your app secret>'
```

## 3. Apple Sign-In

### 3.1 Configure the App ID

1. In <https://developer.apple.com/account/resources/identifiers/> add
   `com.mytravelpal.app` and enable **Sign In with Apple**.
2. In Xcode enable the *Sign In with Apple* capability on the Runner
   target (this generates the entitlement).

### 3.2 Backend — verify id_tokens

The backend already has `AppleOAuthProvider` that validates via Apple's
public JWKS. Set the audience so the check is strict:

```bash
fly secrets set APPLE_APP_ID='com.mytravelpal.app'
```

No app secret needed — Apple's tokens are asymmetrically signed.

## 4. Local development

For local iterate-fast work without OAuth apps configured:

- **Backend**: set no env vars. `GoogleOAuthProvider.verify` and
  `FacebookOAuthProvider.verify` short-circuit with a clear
  `OAuthVerificationError`.
- **Mobile**: skip the real buttons, hit **Continue as demo** which
  posts `provider=demo, id_token=demo-token`. Backend accepts unconditionally
  and mints a demo JWT.

## 5. Verify end-to-end

Once configured:

```bash
# Backend health
curl https://mytravelpal-api.fly.dev/health

# Round-trip a demo login (works without any OAuth configuration)
curl -X POST https://mytravelpal-api.fly.dev/v1/auth/session \
    -H "Content-Type: application/json" \
    -d '{"provider":"demo","id_token":"x","demo_email":"a@b","demo_name":"A"}'
```

For Google/Facebook: run the mobile app, tap the button, watch the API
logs for `POST /v1/auth/session` returning `200`.
