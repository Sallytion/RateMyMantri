# Aadhar QR Code Technical Implementation

## QR Code Format Detection

### Secure V2 Format (Official PVC Aadhar)
- **Format**: Dense numeric QR code
- **Identification**: Contains only digits (0-9)
- **Processing**:
  1. Convert numeric string to BigInt
  2. Convert BigInt to byte array
  3. Decompress using GZIP
  4. Split data (last 256 bytes = signature, rest = data)
  5. Parse data fields separated by 0xFF delimiter

**Example Structure:**
```
Field 0: Email hash
Field 1: Reference ID (Last4Digits + YYYYMMDD + Random)
Field 2: Name
Field 3: DOB
Field 4: Gender (M/F/T)
Field 5: Care Of
Field 10: Pincode
Field 11: District
Field 12: State
Field 13: Street
```

### DigiLocker/XML Format (Unsecure)
- **Format**: Text-based XML QR code
- **Identification**: Starts with "<?xml" or contains "<PrintLetterBarcodeData"
- **Processing**: Direct XML parsing

**Example Structure:**
```xml
<PrintLetterBarcodeData 
    name="JOHN DOE"
    uid="123456789012"
    dob="01-01-1990"
    gender="M"
    co="S/O FATHER NAME"
    house="123"
    street="MAIN STREET"
    loc="LOCALITY"
    vtc="VILLAGE/TOWN/CITY"
    po="POST OFFICE"
    dist="DISTRICT"
    state="STATE"
    pc="123456"
/>
```

## Security Classification

### ✅ SECURE (Verified User)
**Criteria:**
- QR is dense numeric format
- Successfully decompressed from GZIP
- Contains structured data fields

**User Benefits:**
- Can use anonymous mode
- Verified user badge
- Full app access

**Detection Logic:**
```dart
bool _isNumeric(String str) {
  return RegExp(r'^[0-9]+$').hasMatch(str);
}
```

### ⚠️ UNSECURE (Unverified User)
**Criteria:**
- QR is XML/text format
- From DigiLocker or shop print
- No compression

**User Limitations:**
- Cannot use anonymous mode
- Unverified user badge
- Must reveal identity when rating

**User Message:**
> "This QR is from DigiLocker or shop print. Please scan the dense QR code from your official PVC Aadhar card (not shop printed)."

## Data Privacy

### What We Extract:
- ✅ Name
- ✅ Date of Birth
- ✅ Gender
- ✅ Address
- ✅ Last 4 digits of Aadhar (masked)
- ✅ Card generation date

### What We DON'T Extract:
- ❌ Full Aadhar number
- ❌ Biometric data
- ❌ Photo
- ❌ QR code content itself

### Masking Example:
```
Original UID: 1234 5678 9012
Displayed: xxxx xxxx 9012
```

## No Signature Verification (As Requested)

The integration does NOT verify digital signatures because:
1. You specifically requested to skip fake detection
2. Focus is on QR format (dense vs text) not authenticity
3. Simpler implementation without certificate management

### What This Means:
- **Pros**: Simpler, faster, no certificate updates needed
- **Cons**: Cannot detect fake official-looking QR codes
- **Approach**: Trust the QR format as indicator of authenticity

## User Type Logic

```dart
enum UserType {
  verified,      // Secure QR → Can be anonymous
  unverified     // Unsecure QR → Cannot be anonymous
}

UserType get userType {
  return isSecure ? UserType.verified : UserType.unverified;
}
```

## Anonymous Mode Implementation

### Profile Page Switch:
```dart
Switch(
  value: _isAnonymous,
  onChanged: widget.isVerified 
      ? (value) { setState(() { _isAnonymous = value; }); }
      : null, // Disabled for unverified users
)
```

### Display Logic:
- **Verified + Anonymous ON**: Shows as "Verified Citizen"
- **Verified + Anonymous OFF**: Shows user's real name
- **Unverified**: Always shows real name (no toggle)

## Error Handling

### Common Errors:
1. **Unknown QR Format**: Neither numeric nor XML
2. **Decompression Failed**: Invalid numeric QR
3. **XML Parse Failed**: Malformed XML
4. **Data Too Short**: Incomplete QR scan

### Error Display:
```dart
if (data.errorMessage != null) {
  return AadharData.error('Parsing failed: $e');
}
```

## Camera Permissions

### Android (AndroidManifest.xml):
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" />
<uses-feature android:name="android.hardware.camera.autofocus" />
```

### iOS (Info.plist):
```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required to scan Aadhar QR codes</string>
```

### Runtime Permission:
```dart
final status = await Permission.camera.request();
if (!status.isGranted) {
  // Show error and navigate back
}
```

## Testing Checklist

- [ ] Scan official PVC Aadhar (dense QR) → Should show SECURE
- [ ] Scan DigiLocker Aadhar → Should show UNSECURE  
- [ ] Scan shop-printed Aadhar → Should show UNSECURE
- [ ] Try anonymous mode as verified user → Should work
- [ ] Try anonymous mode as unverified user → Should be disabled
- [ ] Check camera permission prompt
- [ ] Verify masked UID display
- [ ] Test error handling with invalid QR

## Code Structure

```
lib/
├── models/
│   └── aadhar_data.dart          # Data model with UserType enum
├── services/
│   └── aadhar_qr_parser.dart     # QR parsing logic
├── pages/
│   ├── aadhar_verification_page.dart   # Scanner UI
│   ├── aadhar_result_page.dart         # Result display
│   ├── otp_page.dart                   # Updated to navigate to scanner
│   ├── main_screen.dart                # Updated to pass verification status
│   ├── profile_page.dart               # Shows verification badge
│   └── rate_page.dart                  # Shows anonymous capability
```

## Performance Considerations

- QR parsing is async (doesn't block UI)
- GZIP decompression is fast (~50-100ms)
- XML parsing is lightweight
- Camera runs in separate thread
- No network calls required

## Future Enhancements (Optional)

1. **Add Signature Verification**:
   - Load UIDAI certificates
   - Verify RSA signature
   - Detect fake QR codes

2. **Store Verification Status**:
   - Save to local database
   - Don't require re-scan each time
   - Update periodically

3. **Multiple Verification Methods**:
   - Aadhar QR (current)
   - Voter ID
   - Driving License
   - Passport

4. **Analytics**:
   - Track verification success rate
   - Monitor QR type distribution
   - User verification preferences
