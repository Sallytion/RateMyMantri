# Aadhaar Backend Integration

## Overview
This integration adds secure Aadhaar verification with SHA-256 hashing to prevent duplicate Aadhaar usage while maintaining user privacy. It includes automatic verification status checking on login.

## How It Works

### 1. **Login Flow** (New Feature)
- User logs in with Google
- App calls `/me` endpoint to fetch user profile
- Checks `aadhaarVerified` status from backend
- **If verified**: Skip to main screen
- **If not verified**: Show Aadhaar verification page

### 2. **QR Code Scanning** (Existing Flow - Unchanged)
- User takes photo with camera or selects from gallery
- ML Kit scans the image for QR code
- Raw QR data is extracted

### 3. **Backend Verification** (New Feature)
- Raw QR data is hashed using SHA-256 (64-character hex string)
- Hash is sent to backend API for verification
- Backend checks if this Aadhaar has been used before
- **No personal data is stored** - only the hash
- Verification status saved locally

### 4. **Data Parsing** (Existing Flow - Unchanged)
- QR data is parsed using certificates
- User details are extracted and displayed
- Security type is determined (Secure PVC vs Unsecure XML)

## API Integration

### 1. Get User Profile (Login Check)
```
GET https://ratemymantri.sallytion.qzz.io/me
```

**Request Headers:**
```json
{
  "Authorization": "Bearer <ACCESS_TOKEN>"
}
```

**Response:**
```json
{
  "user": {
    "id": "4614a234-1faf-4e51-802e-25ddb724070b",
    "email": "jayatekwani76@gmail.com",
    "name": "Jaya Tekwani",
    "profile_image": "https://lh3.googleusercontent.com/...",
    "is_verified": false
  }
}
```

**Note**: The code checks `response.user.is_verified` to determine Aadhaar verification status.

### 2. Verify Aadhaar Hash
```
POST https://ratemymantri.sallytion.qzz.io/auth/aadhaar
```

**Request Headers:**
```json
{
  "Authorization": "Bearer <ACCESS_TOKEN>",
  "Content-Type": "application/json"
}
```

**Request Body:**
```json
{
  "aadhaarHash": "64_character_sha256_hash_here"
}
```

**Response Codes:**
- **200/201**: Verification successful
- **400**: Aadhaar already used by another user
- **401**: Authentication failed (need to re-login)
- **500**: Server error

## Local Storage

Verification status is stored locally using SharedPreferences:
- **Key**: `aadhaar_verified`
- **Type**: Boolean
- **Updated**: On login (from `/me`) and after successful verification

## Files Modified

### 1. `lib/services/auth_storage_service.dart` (Modified)
Added verification status management:
- `saveAadhaarVerificationStatus()` - Save verification status locally
- `getAadhaarVerificationStatus()` - Get verification status from local storage
- `fetchUserProfile()` - Fetch user profile from `/me` endpoint
- Added `_aadhaarVerifiedKey` constant
- Clear verification status on logout

### 2. `lib/services/aadhaar_verification_service.dart` (New)
Service for hashing and backend verification:
- `hashAadhaarData()` - Converts raw QR to SHA-256 hash
- `verifyAadhaarHash()` - Sends hash to backend API
- `processAadhaarQR()` - Complete flow: hash → verify
- `isAadhaarVerified()` - Check if user has verified Aadhaar
- Updates local storage on successful verification

### 3. `lib/pages/google_sign_in_page.dart` (Modified)
Login flow with verification check:
- Added `_navigateToMainScreen()` method
- After login, calls `fetchUserProfile()` to get verification status
- **If verified**: Navigate directly to MainScreen
- **If not verified**: Navigate to AadharVerificationPage
- Works on both manual sign-in and silent sign-in

### 4. `lib/pages/aadhar_verification_page.dart` (Modified)
Added backend integration to existing scanner:
- Imports `aadhaar_verification_service.dart`
- After QR scan, calls `processAadhaarQR(rawValue)`
- Shows warning if backend verification fails
- **Still parses and displays user details** (existing functionality)
- Passes verification status to result page

### 5. `lib/pages/aadhar_result_page.dart` (Modified)
Display backend verification status:
- Added `rawQrData` and `backendVerified` parameters
- Shows verification badge in Card Information section
- Visual indicator: ✓ green for verified, ⚠ orange for pending

### 6. `pubspec.yaml` (Modified)
Added dependency:
```yaml
crypto: ^3.0.3  # For SHA-256 hashing
```

## User Flows

### Flow 1: New User (Not Verified)
1. User logs in with Google
2. App calls `/me` endpoint
3. Backend returns `user.is_verified: false`
4. App shows Aadhaar verification page
5. User scans QR code
6. App hashes data and sends to backend
7. Backend verifies and saves hash
8. Local storage updated: `aadhaar_verified = true`
9. User proceeds to main screen

### Flow 2: Returning User (Already Verified)
1. User logs in with Google (or silent sign-in)
2. App calls `/me` endpoint
3. Backend returns `user.is_verified: true`
4. Local storage updated: `aadhaar_verified = true`
5. **Skip verification page** → Go directly to main screen

### Flow 3: Duplicate Aadhaar Attempt
1. User logs in (not verified)
2. User scans Aadhaar QR code
3. App hashes data and sends to backend
4. Backend responds: **400 - Already used**
5. App shows error: "This Aadhaar has already been verified"
6. User can retry with different Aadhaar or skip

## Security Features

1. **No Data Storage**: Raw Aadhaar data is never stored
2. **SHA-256 Hashing**: One-way cryptographic hash (cannot be reversed)
3. **Uniqueness Check**: Backend prevents duplicate Aadhaar usage
4. **Privacy Preserved**: User details are shown locally but not sent to backend

## User Flow

1. User scans Aadhaar QR code
2. App hashes the raw data (SHA-256)
3. App sends hash to backend API
4. Backend responds:
   - ✅ Success → User is verified
   - ❌ Already used → Show error, allow retry
   - ⚠️ Network error → Show warning, continue with local verification
5. App parses QR data and shows user details
6. Result page shows both:
   - Parsed user information (name, DOB, etc.)
   - Backend verification status

## Testing

### Test Cases
1. **First login (not verified)**: Should show Aadhaar verification page
2. **Returning user (verified)**: Should skip to main screen
3. **First-time scan**: Should verify successfully and save status
4. **Duplicate scan**: Same Aadhaar scanned twice (same device) → Should fail
5. **Duplicate user**: Different user scans same Aadhaar → Should fail
6. **Network error**: No internet → Shows warning, continues with local parsing
7. **Invalid token**: Expired auth → Prompts re-login
8. **Silent sign-in**: App restart with saved tokens → Should check verification status

### Debug Logs
Check console output:
```
Checking Aadhaar verification status...
User profile fetched successfully
Aadhaar verified status: true/false
# If verified:
[Navigating directly to MainScreen]
# If not verified:
[Showing Aadhaar verification page]

# During QR scan:
QR Detected! Length: XXXX
Hashing Aadhaar data...
Generated Aadhaar Hash: <64-char-hash>
✅ Aadhaar hash verified with backend
Parsed: <Name>, Secure: true/false
```

## Notes

- Existing functionality is **100% preserved**
- User details are still parsed and displayed
- Backend verification runs in parallel with parsing
- If backend fails, user can still see their details
- Only secure PVC Aadhaar QR codes enable anonymous posting
- **Verification status is checked on every login**
- **Verified users skip the Aadhaar verification page**
- Local storage keeps verification status for offline checks
- `/me` endpoint is the source of truth for verification status
