# 🗳️ Rate My Mantri

A Flutter-based civic engagement platform that allows citizens to rate and review their political representatives (MPs, MLAs, and Councillors) across India. The app combines Google authentication, Aadhaar verification, interactive maps, and push notifications to create a transparent and accountable political feedback system.

## ✨ Features

- **🔐 Secure Authentication**: Google Sign-In with JWT-based backend authentication
- **📱 Aadhaar Verification**: Optional Aadhaar verification using QR code scanning
- **🗺️ Interactive Maps**: MapLibre-based maps showing constituency boundaries with GeoJSON data
- **⭐ Rating System**: Rate politicians on multiple criteria (Development, Corruption, Responsiveness, etc.)
- **📊 Real-time Analytics**: View aggregated ratings and reviews from verified citizens
- **🔔 Push Notifications**: Firebase Cloud Messaging for important civic updates
- **🌓 Dark Mode**: Full dark/light theme support with system integration
- **📷 Media Uploads**: Share photos and evidence with reviews (coming soon)

## 🛠️ Tech Stack

### Frontend (Flutter)
- **Framework**: Flutter 3.x
- **State Management**: Provider pattern
- **Authentication**: Google Sign-In + JWT
- **Maps**: MapLibre GL (offline-capable vector maps)
- **Barcode Scanning**: ML Kit for Aadhaar QR codes
- **Push Notifications**: Firebase Cloud Messaging (FCM)
- **HTTP Client**: http package for API communication
- **Storage**: SharedPreferences for local data persistence

### Backend
- **API**: RESTful API (details in [V2-API-docs.md](V2-API-docs.md))
- **Authentication**: JWT tokens with Google OAuth
- **Verification**: Aadhaar QR code validation
- **Database**: Stores user profiles, ratings, reviews, and politician data

### Services
- **Firebase**:
  - Firebase Cloud Messaging (push notifications)
  - Firebase Authentication integration
  - Firebase Installations Service
- **Google Cloud**:
  - Google Sign-In OAuth
  - Maps API (optional)

## 📋 Prerequisites

- **Flutter SDK**: 3.0 or higher
- **Dart SDK**: 3.0 or higher
- **Android Studio** / **VS Code** with Flutter extensions
- **Firebase Project**: For push notifications
- **Google Cloud Project**: For OAuth credentials
- **Backend API**: Running instance (see backend documentation)

## 🚀 Getting Started

### 1. Clone the Repository

```bash
git clone <your-repo-url>
cd rate_my_mantri
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Firebase Setup

#### Firebase Console Configuration:
1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Add Android app with package name: `com.example.rate_my_mantri`
3. **Add SHA-1 fingerprint**:
   ```bash
   cd android
   ./gradlew signingReport
   # Copy the SHA1 fingerprint and add it to Firebase Console
   ```
4. Enable **Firebase Cloud Messaging API**
5. Enable **Firebase Installations API** in [Google Cloud Console](https://console.cloud.google.com/apis/dashboard)
6. Download `google-services.json` → place in `android/app/`

#### Generate Firebase Options:
```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase (generates lib/firebase_options.dart)
flutterfire configure --project=your-firebase-project-id
```

⚠️ **IMPORTANT**: Never commit `google-services.json` or `firebase_options.dart` to Git!

### 4. Google Sign-In Setup

See [GOOGLE_SIGNIN_SETUP.md](GOOGLE_SIGNIN_SETUP.md) for detailed instructions.

**Quick steps**:
1. Get OAuth 2.0 credentials from [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
2. Add SHA-1 fingerprint to OAuth credentials
3. Configure backend API with Google Client ID

### 5. Backend Configuration

Update API endpoints in your code (create `lib/config/api_config.dart`):

```dart
class ApiConfig {
  static const String baseUrl = 'https://your-backend-api.com/api';
  static const String loginEndpoint = '$baseUrl/auth/google';
  static const String ratingsEndpoint = '$baseUrl/ratings';
  // Add other endpoints...
}
```

See [backend-details.md](backend-details.md) and [V2-API-docs.md](V2-API-docs.md) for API documentation.

### 6. Run the App

```bash
# Development mode
flutter run

# Release build
flutter build apk --release
flutter build ios --release
```

## 📁 Project Structure

```
lib/
├── main.dart                      # App entry point
├── firebase_options.dart          # Firebase configuration (gitignored)
├── models/                        # Data models
│   ├── politician.dart
│   ├── rating.dart
│   └── user.dart
├── pages/                         # UI screens
│   ├── google_sign_in_page.dart  # Authentication screen
│   ├── home_page.dart            # Main dashboard
│   ├── map_page.dart             # Interactive constituency map
│   └── ...
├── services/                      # Business logic
│   ├── aadhaar_verification_service.dart
│   ├── auth_storage_service.dart
│   ├── notification_service.dart
│   └── ...
├── widgets/                       # Reusable UI components
└── utils/                         # Helper functions

android/
├── app/
│   ├── google-services.json      # Firebase config (gitignored)
│   └── src/main/AndroidManifest.xml
└── build.gradle.kts

assets/
├── india.geojson                  # Indian constituency boundaries
└── logo/                          # App branding assets
```

## 🔑 Environment Variables & Secrets

**Files that contain sensitive data** (already added to `.gitignore`):
- `android/app/google-services.json` - Firebase Android configuration
- `ios/Runner/GoogleService-Info.plist` - Firebase iOS configuration  
- `lib/firebase_options.dart` - Generated Firebase options
- `send_notification.ps1` - FCM server scripts with OAuth tokens

**API Keys Present** (restricted in Google Cloud Console):
- Firebase API keys (restricted to Firebase services only)
- Google OAuth client IDs (restricted to authorized origins)
- MapLibre style URLs (no sensitive data)

✅ **Security Status**: All sensitive files are gitignored and NOT committed.

## 📱 Features Documentation

### Authentication Flow
1. User clicks "Sign in with Google"
2. Google OAuth consent screen
3. Backend validates Google token → returns JWT
4. JWT stored locally for API requests
5. Optional: Aadhaar verification for verified badge

See: [GOOGLE_SIGNIN_SETUP.md](GOOGLE_SIGNIN_SETUP.md), [AADHAAR_BACKEND_INTEGRATION.md](AADHAAR_BACKEND_INTEGRATION.md)

### Rating System
- Rate politicians on 8 criteria (1-5 stars each)
- Add text reviews
- Upload supporting media (photos/documents)
- View aggregated community ratings

See: [RATINGS-API.md](RATINGS-API.md)

### Push Notifications
- Topic-based broadcasting (all users subscribed to "general")
- Foreground/background message handling
- Send notifications via Firebase Console or server script

See: [lib/services/notification_service.dart](lib/services/notification_service.dart)

### Map Integration
- MapLibre GL for vector maps
- GeoJSON overlays for constituencies
- Click constituency → view politician details
- Offline map support

See: [flutter_map_integration.md](flutter_map_integration.md)

## 🐛 Troubleshooting

### Firebase Messaging Issues
If you get `FIS_AUTH_ERROR`:
1. Verify SHA-1 fingerprint is added to Firebase Console
2. Check that **Firebase Installations API** is enabled in Google Cloud Console
3. Verify API key restrictions allow Firebase APIs:
   - Go to Google Cloud Console → APIs & Services → Credentials
   - Find your Android API key
   - Ensure "Firebase Installations API" is in allowed APIs list
4. Download fresh `google-services.json` and run `flutterfire configure`

See: [JWT_VERIFICATION_ISSUE.md](JWT_VERIFICATION_ISSUE.md)

### Build Errors
```bash
# Clean and rebuild
flutter clean
flutter pub get
cd android && ./gradlew clean
cd ..
flutter run
```

### Google Sign-In Not Working
- Verify SHA-1 is added to both Firebase AND Google Cloud OAuth credentials
- Check package name matches: `com.example.rate_my_mantri`
- Ensure Google Sign-In is enabled in Firebase Console

## 🔄 CI/CD & Deployment

### GitHub Actions (recommended setup)
```yaml
# .github/workflows/flutter.yml
name: Flutter CI

on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test
      - run: flutter build apk --release
```

**Note**: Store `google-services.json` as GitHub Secrets, not in repo.

## 📄 API Documentation

- **V2 API**: [V2-API-docs.md](V2-API-docs.md)
- **Ratings API**: [RATINGS-API.md](RATINGS-API.md)
- **Aadhaar Integration**: [AADHAAR_BACKEND_INTEGRATION.md](AADHAAR_BACKEND_INTEGRATION.md)
- **Technical Details**: [TECHNICAL_DETAILS.md](TECHNICAL_DETAILS.md)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'Add amazing feature'`
4. Push to branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

**Important**: Never commit API keys, tokens, or `google-services.json`!

## 📝 License

[Add your license here]

## 👥 Authors

[Add your name/team here]

## 🙏 Acknowledgments

- Maps data: GeoJSON India constituency boundaries
- Icons: Flutter launcher icons
- Backend API: [Add backend team credits]

## 📞 Support

For issues and questions:
- Open a GitHub Issue
- Email: [your-support-email]
- Documentation: See `/docs` folder

---

**Made with ❤️ for transparent democracy in India** 🇮🇳
