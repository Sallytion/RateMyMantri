# Google Sign-In Setup for Rate My Mantri

## Prerequisites
- Google Cloud Console account
- SHA-1 certificate fingerprint from your app

## Step 1: Get SHA-1 Certificate

Run this command in the `android` directory:

```bash
cd android
./gradlew signingReport
```

Copy the SHA-1 fingerprint under the "debug" variant.

**Alternative (Windows):**
```bash
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

## Step 2: Google Cloud Console Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Navigate to **APIs & Services** > **Credentials**
4. Click **+ CREATE CREDENTIALS** > **OAuth client ID**
5. Select **Android** as application type
6. Enter:
   - Package name: `com.example.rate_my_mantri` (check your `android/app/build.gradle.kts`)
   - SHA-1 certificate fingerprint: (paste from Step 1)
7. Click **Create**

## Step 3: Enable APIs

In Google Cloud Console:
1. Go to **APIs & Services** > **Library**
2. Search for and enable:
   - Google Sign-In API
   - People API (optional, if you want contacts)

## Step 4: OAuth Consent Screen

1. Go to **APIs & Services** > **OAuth consent screen**
2. Select **External** (or Internal for organization)
3. Fill in required fields:
   - App name: Rate My Mantri
   - User support email: your email
   - Developer contact: your email
4. Add scopes: `email`, `profile`
5. Save and continue

## Step 5: Run the App

```bash
flutter run
```

## Troubleshooting

### "Sign in failed" error
- Verify SHA-1 is correctly added to Google Cloud Console
- Make sure package name matches exactly
- Clear app data and try again

### "Developer Error" / Error 10
- SHA-1 fingerprint is incorrect or missing
- Run `./gradlew signingReport` again and verify

### No Google accounts shown
- Make sure you have a Google account on the device
- Check if Google Play Services is updated

## Production Release

For release builds, you need to add your **release keystore's SHA-1** to Google Cloud Console:

```bash
keytool -list -v -keystore your-release-key.keystore -alias your-key-alias
```

Add this SHA-1 as another OAuth client in Google Cloud Console.
