# Aadhaar QR Code Verification - Flutter Integration Guide

## 📋 Overview
This guide will help you implement Aadhaar QR code scanning and verification in your Flutter app, supporting both:
- **Old XML Format** (Text QR - DigiLocker/Printed)
- **Secure V2 Format** (Numeric with Digital Signature)

---

## 🎯 Features You'll Implement

1. **QR Code Scanning** - Camera-based scanning
2. **XML QR Parsing** - Extract details from old format cards
3. **Secure QR Decoding** - Decompress and parse V2 format
4. **Digital Signature Verification** - Verify authenticity using UIDAI certificates
5. **Beautiful UI** - Display verification results with status indicators

---

## 📦 Step 1: Add Dependencies

Add these packages to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # QR Code Scanning
  mobile_scanner: ^5.1.1
  
  # XML Parsing
  xml: ^6.5.0
  
  # Cryptography for signature verification
  pointycastle: ^3.9.1
  asn1lib: ^1.5.3
  
  # Compression (zlib/gzip)
  archive: ^3.6.1
  
  # Permissions
  permission_handler: ^11.3.1
  
  # UI Components
  google_fonts: ^6.2.1
  flutter_svg: ^2.0.10

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.1
```

Run: `flutter pub get`

---

## 🔧 Step 2: Configure Permissions

### Android (`android/app/src/main/AndroidManifest.xml`)

Add camera permission inside `<manifest>` tag:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" />
<uses-feature android:name="android.hardware.camera.autofocus" />
```

### iOS (`ios/Runner/Info.plist`)

Add camera usage description inside `<dict>` tag:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required to scan Aadhaar QR codes</string>
```

---

## 📁 Step 3: Project Structure

Create this folder structure in your `lib` directory:

```
lib/
├── main.dart
├── models/
│   └── aadhaar_data.dart
├── services/
│   ├── qr_parser_service.dart
│   └── signature_verifier.dart
├── screens/
│   ├── scanner_screen.dart
│   └── result_screen.dart
└── assets/
    └── certificates/
        └── (place your .cer files here)
```

---

## 🗂️ Step 4: Add UIDAI Certificates

1. Create `assets/certificates/` folder in your project root
2. Copy your `.cer` certificate files (PEM format) into this folder
3. Update `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/certificates/
```

---

## 💾 Step 5: Create Data Model

**File: `lib/models/aadhaar_data.dart`**

```dart
enum QRType {
  secureV2,
  digilockerXML,
  unknown
}

enum VerificationStatus {
  official,        // Signature verified
  unofficial,      // Data readable but signature failed
  digilocker,      // Text QR without signature
  error
}

class AadhaarData {
  final QRType type;
  final VerificationStatus status;
  final String name;
  final String dob;
  final String gender;
  final String? careOf;
  final String address;
  final String cardGenDate;
  final String uidLast4;
  final String? verifiedByCertificate;
  final String? errorMessage;

  AadhaarData({
    required this.type,
    required this.status,
    required this.name,
    required this.dob,
    required this.gender,
    this.careOf,
    required this.address,
    required this.cardGenDate,
    required this.uidLast4,
    this.verifiedByCertificate,
    this.errorMessage,
  });

  factory AadhaarData.error(String message) {
    return AadhaarData(
      type: QRType.unknown,
      status: VerificationStatus.error,
      name: '',
      dob: '',
      gender: '',
      address: '',
      cardGenDate: '',
      uidLast4: '',
      errorMessage: message,
    );
  }

  String get statusLabel {
    switch (status) {
      case VerificationStatus.official:
        return '✅ OFFICIAL AADHAAR (VERIFIED)';
      case VerificationStatus.unofficial:
        return '⚠️ UNOFFICIAL / SHOP PRINT';
      case VerificationStatus.digilocker:
        return '⚠️ DIGILOCKER / TEXT QR';
      case VerificationStatus.error:
        return '❌ ERROR';
    }
  }

  String get statusDescription {
    switch (status) {
      case VerificationStatus.official:
        return 'Signed by UIDAI via $verifiedByCertificate';
      case VerificationStatus.unofficial:
        return 'Data is readable, but Digital Signature is FAKE/INVALID';
      case VerificationStatus.digilocker:
        return 'Valid Data, but No Cryptographic Security';
      case VerificationStatus.error:
        return errorMessage ?? 'Unknown error occurred';
    }
  }
}
```

---

## 🔐 Step 6: Create Signature Verifier

**File: `lib/services/signature_verifier.dart`**

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pointycastle/export.dart';
import 'package:asn1lib/asn1lib.dart';

class SignatureVerifier {
  final List<MapEntry<String, RSAPublicKey>> _publicKeys = [];

  Future<void> loadCertificates() async {
    _publicKeys.clear();
    
    // Load certificates from assets
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = json.decode(manifestContent);
    
    final certPaths = manifestMap.keys
        .where((String key) => key.startsWith('assets/certificates/'))
        .where((String key) => key.endsWith('.cer'))
        .toList();

    for (final certPath in certPaths) {
      try {
        final certPem = await rootBundle.loadString(certPath);
        final publicKey = _parsePublicKeyFromPem(certPem);
        final fileName = certPath.split('/').last;
        _publicKeys.add(MapEntry(fileName, publicKey));
        print('✅ Loaded certificate: $fileName');
      } catch (e) {
        print('⚠️ Failed to load $certPath: $e');
      }
    }
    
    print('📦 Total certificates loaded: ${_publicKeys.length}');
  }

  RSAPublicKey _parsePublicKeyFromPem(String pem) {
    // Remove PEM headers and decode
    final lines = pem
        .replaceAll('-----BEGIN CERTIFICATE-----', '')
        .replaceAll('-----END CERTIFICATE-----', '')
        .replaceAll('\n', '')
        .replaceAll('\r', '');
    
    final bytes = base64.decode(lines);
    
    // Parse X.509 certificate
    final asn1Parser = ASN1Parser(bytes);
    final topLevelSeq = asn1Parser.nextObject() as ASN1Sequence;
    
    // Certificate structure: [tbsCertificate, signatureAlgorithm, signature]
    final tbsCertificate = topLevelSeq.elements[0] as ASN1Sequence;
    
    // Extract subject public key info (index may vary, typically 6)
    ASN1Sequence? subjectPublicKeyInfo;
    for (final element in tbsCertificate.elements) {
      if (element is ASN1Sequence && element.elements.length >= 2) {
        final firstElement = element.elements[0];
        if (firstElement is ASN1Sequence) {
          // This is likely the subjectPublicKeyInfo
          subjectPublicKeyInfo = element;
          break;
        }
      }
    }
    
    if (subjectPublicKeyInfo == null) {
      throw Exception('Could not find subject public key info');
    }
    
    // Extract the bit string containing the public key
    final publicKeyBitString = subjectPublicKeyInfo.elements[1] as ASN1BitString;
    final publicKeyBytes = publicKeyBitString.valueBytes;
    
    // Parse RSA public key
    final publicKeyAsn = ASN1Parser(publicKeyBytes!);
    final publicKeySeq = publicKeyAsn.nextObject() as ASN1Sequence;
    
    final modulus = (publicKeySeq.elements[0] as ASN1Integer).valueAsBigInteger;
    final exponent = (publicKeySeq.elements[1] as ASN1Integer).valueAsBigInteger;
    
    return RSAPublicKey(modulus!, exponent!);
  }

  /// Verify signature using PKCS1v15 with SHA-256
  Future<MapEntry<bool, String?>> verifySignature(
    Uint8List dataBody,
    Uint8List signature,
  ) async {
    for (final entry in _publicKeys) {
      try {
        final verifier = Signer('SHA-256/RSA');
        verifier.init(
          false,
          PublicKeyParameter<RSAPublicKey>(entry.value),
        );
        
        final sig = RSASignature(signature);
        final isValid = verifier.verifySignature(dataBody, sig);
        
        if (isValid) {
          return MapEntry(true, entry.key);
        }
      } catch (e) {
        continue; // Try next certificate
      }
    }
    
    return const MapEntry(false, null);
  }

  int get certificateCount => _publicKeys.length;
}
```

---

## 🔍 Step 7: Create QR Parser Service

**File: `lib/services/qr_parser_service.dart`**

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import '../models/aadhaar_data.dart';
import 'signature_verifier.dart';

class QRParserService {
  final SignatureVerifier _verifier = SignatureVerifier();

  Future<void> initialize() async {
    await _verifier.loadCertificates();
  }

  Future<AadhaarData> parseQRCode(String rawData) async {
    try {
      // Detect QR Type
      if (rawData.trim().startsWith('<?xml') || 
          rawData.contains('<PrintLetterBarcodeData')) {
        return _parseXmlQR(rawData);
      } else if (_isNumeric(rawData)) {
        return await _parseSecureQR(rawData);
      } else {
        return AadhaarData.error('Unknown QR Format');
      }
    } catch (e) {
      return AadhaarData.error('Parsing failed: $e');
    }
  }

  bool _isNumeric(String str) {
    return RegExp(r'^[0-9]+$').hasMatch(str);
  }

  /// Parse Old XML Format (DigiLocker/Text QR)
  AadhaarData _parseXmlQR(String rawData) {
    try {
      final startIndex = rawData.indexOf('<');
      final cleanXml = rawData.substring(startIndex);
      final document = XmlDocument.parse(cleanXml);
      final root = document.rootElement;

      // Extract attributes
      final name = root.getAttribute('name') ?? 'Unknown';
      final uid = root.getAttribute('uid') ?? '';
      final dob = root.getAttribute('dob') ?? 
                 root.getAttribute('yob') ?? 'Unknown';
      final gender = root.getAttribute('gender') ?? 'Unknown';

      // Build address
      final addressParts = [
        root.getAttribute('house'),
        root.getAttribute('street'),
        root.getAttribute('loc'),
        root.getAttribute('vtc'),
        root.getAttribute('po'),
        root.getAttribute('dist'),
        root.getAttribute('subdist'),
        root.getAttribute('state'),
        root.getAttribute('pc'),
      ].where((e) => e != null && e.isNotEmpty).toList();
      
      final address = addressParts.join(', ');
      
      // Mask UID
      final maskedUid = uid.length >= 4 
          ? 'xxxx xxxx ${uid.substring(uid.length - 4)}' 
          : 'Unknown';

      return AadhaarData(
        type: QRType.digilockerXML,
        status: VerificationStatus.digilocker,
        name: name,
        dob: dob,
        gender: gender,
        address: address,
        cardGenDate: 'N/A',
        uidLast4: maskedUid,
      );
    } catch (e) {
      return AadhaarData.error('XML Parse Failed: $e');
    }
  }

  /// Parse Secure QR V2.0 (Numeric with Signature)
  Future<AadhaarData> _parseSecureQR(String rawData) async {
    try {
      // 1. Convert BigInt String to Bytes
      final bigInt = BigInt.parse(rawData);
      final byteLength = (bigInt.bitLength + 7) ~/ 8;
      final byteArray = _bigIntToBytes(bigInt, byteLength);

      // 2. Decompress using Gzip
      final decompressed = GZipDecoder().decodeBytes(byteArray);
      
      if (decompressed.length <= 256) {
        return AadhaarData.error('Data too short for signature');
      }

      // 3. Split Data and Signature
      final dataBody = Uint8List.fromList(
        decompressed.sublist(0, decompressed.length - 256)
      );
      final signature = Uint8List.fromList(
        decompressed.sublist(decompressed.length - 256)
      );

      // 4. Verify Signature
      final verificationResult = await _verifier.verifySignature(
        dataBody,
        signature,
      );
      final isValid = verificationResult.key;
      final certName = verificationResult.value;

      // 5. Parse Data Fields
      final parsedData = _parseSecureQRData(dataBody);

      // 6. Set Status
      final status = isValid 
          ? VerificationStatus.official 
          : VerificationStatus.unofficial;

      return AadhaarData(
        type: QRType.secureV2,
        status: status,
        name: parsedData['name'] ?? 'Unknown',
        dob: parsedData['dob'] ?? 'Unknown',
        gender: parsedData['gender'] ?? 'Unknown',
        careOf: parsedData['co'],
        address: _buildAddress(parsedData),
        cardGenDate: parsedData['cardGenDate'] ?? 'Unknown',
        uidLast4: parsedData['uidLast4'] ?? 'Unknown',
        verifiedByCertificate: certName,
      );
    } catch (e) {
      return AadhaarData.error('Secure QR Processing Failed: $e');
    }
  }

  Uint8List _bigIntToBytes(BigInt number, int length) {
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[length - 1 - i] = (number & BigInt.from(0xff)).toInt();
      number = number >> 8;
    }
    return bytes;
  }

  Map<String, String> _parseSecureQRData(Uint8List dataBody) {
    // Split by delimiter 0xFF
    final fields = <String>[];
    final buffer = <int>[];
    
    for (final byte in dataBody) {
      if (byte == 0xFF) {
        if (buffer.isNotEmpty) {
          fields.add(String.fromCharCodes(buffer));
          buffer.clear();
        }
      } else {
        buffer.add(byte);
      }
    }
    if (buffer.isNotEmpty) {
      fields.add(String.fromCharCodes(buffer));
    }

    String getField(int index) {
      return index < fields.length ? fields[index].trim() : '';
    }

    // Field 1: Reference ID (Last4Digits + YYYYMMDD + Random)
    final refId = getField(1);
    String uidLast4 = 'Unknown';
    String cardGenDate = 'Unknown';
    
    if (refId.length >= 4) {
      uidLast4 = 'xxxx xxxx ${refId.substring(0, 4)}';
    }
    
    if (refId.length >= 12) {
      final datePart = refId.substring(4, 12);
      cardGenDate = '${datePart.substring(0, 4)}-'
                   '${datePart.substring(4, 6)}-'
                   '${datePart.substring(6, 8)}';
    }

    return {
      'name': getField(2),
      'dob': getField(3),
      'gender': getField(4),
      'co': getField(5),
      'pincode': getField(10),
      'state': getField(12),
      'district': getField(11),
      'street': getField(13),
      'cardGenDate': cardGenDate,
      'uidLast4': uidLast4,
    };
  }

  String _buildAddress(Map<String, String> data) {
    final parts = [
      data['street'],
      data['district'],
      data['state'],
      data['pincode'],
    ].where((e) => e != null && e.isNotEmpty).toList();
    
    return parts.join(', ');
  }
}
```

---

## 📱 Step 8: Create Scanner Screen

**File: `lib/screens/scanner_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/qr_parser_service.dart';
import 'result_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final QRParserService _parserService = QRParserService();
  bool _isProcessing = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Request camera permission
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission is required')),
        );
        Navigator.pop(context);
      }
      return;
    }

    // Initialize parser service
    await _parserService.initialize();
    
    setState(() {
      _isInitialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Aadhaar QR Code'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: !_isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _handleQRDetection,
                ),
                Positioned(
                  top: 20,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Align the QR code within the frame',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                if (_isProcessing)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 16),
                          Text(
                            'Processing...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  void _handleQRDetection(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await _parserService.parseQRCode(barcode.rawValue!);
      
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResultScreen(data: result),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

---

## 🎨 Step 9: Create Result Screen

**File: `lib/screens/result_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/aadhaar_data.dart';

class ResultScreen extends StatelessWidget {
  final AadhaarData data;

  const ResultScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification Result'),
        backgroundColor: _getStatusColor(),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 20),
            _buildDetailsCard(),
            const SizedBox(height: 20),
            _buildMetadataCard(),
            const SizedBox(height: 20),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      color: _getStatusColor().withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              _getStatusIcon(),
              size: 64,
              color: _getStatusColor(),
            ),
            const SizedBox(height: 12),
            Text(
              data.statusLabel,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _getStatusColor(),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              data.statusDescription,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Personal Details',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            _buildDetailRow('👤 Name', data.name),
            _buildDetailRow('🎂 Date of Birth', data.dob),
            _buildDetailRow('⚥ Gender', data.gender),
            if (data.careOf != null && data.careOf!.isNotEmpty)
              _buildDetailRow('👪 Care Of', data.careOf!),
            _buildDetailRow('🏠 Address', data.address),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Card Information',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            _buildDetailRow('📅 Card Generated', data.cardGenDate),
            _buildDetailRow('💳 UID (Last 4)', data.uidLast4),
            _buildDetailRow('🔍 QR Type', _getQRTypeName()),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan Another'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            icon: const Icon(Icons.home),
            label: const Text('Back to Home'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor() {
    switch (data.status) {
      case VerificationStatus.official:
        return Colors.green;
      case VerificationStatus.digilocker:
        return Colors.orange;
      case VerificationStatus.unofficial:
      case VerificationStatus.error:
        return Colors.red;
    }
  }

  IconData _getStatusIcon() {
    switch (data.status) {
      case VerificationStatus.official:
        return Icons.verified;
      case VerificationStatus.digilocker:
        return Icons.warning_amber;
      case VerificationStatus.unofficial:
      case VerificationStatus.error:
        return Icons.error;
    }
  }

  String _getQRTypeName() {
    switch (data.type) {
      case QRType.secureV2:
        return 'Secure V2.0 (Signed)';
      case QRType.digilockerXML:
        return 'DigiLocker/Text (XML)';
      case QRType.unknown:
        return 'Unknown';
    }
  }
}
```

---

## 🏠 Step 10: Update Main App

**File: `lib/main.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/scanner_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aadhaar QR Verifier',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        textTheme: GoogleFonts.poppinsTextTheme(),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.deepPurple.shade400,
              Colors.deepPurple.shade800,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.qr_code_scanner,
                    size: 120,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Aadhaar QR Verifier',
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Scan and verify Aadhaar QR codes\nwith digital signature validation',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ScannerScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.camera_alt, size: 28),
                    label: const Text(
                      'Start Scanning',
                      style: TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.deepPurple,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  _buildFeatureItem(
                    Icons.security,
                    'Digital Signature Verification',
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureItem(
                    Icons.verified_user,
                    'Supports Secure V2.0 QR',
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureItem(
                    Icons.description,
                    'DigiLocker XML Format',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
```

---

## 🚀 Step 11: Testing Instructions

### Test with Different QR Types:

1. **Old XML Format (DigiLocker)**
   - Should extract data successfully
   - Status: "DIGILOCKER / TEXT QR"
   - Warning: No cryptographic security

2. **Secure V2 Format (Official)**
   - Should decompress and verify signature
   - Status: "OFFICIAL AADHAAR (VERIFIED)" if signature matches
   - Status: "UNOFFICIAL / SHOP PRINT" if signature fails

### Debugging Tips:

```dart
// Add debug prints in qr_parser_service.dart:

print('🔍 Raw QR Data: ${rawData.substring(0, 50)}...');
print('📦 Decompressed size: ${decompressed.length}');
print('✅ Signature verified: $isValid');
```

---

## 🔒 Security Best Practices

1. **Never store Aadhaar UID** - Only show last 4 digits
2. **Don't log sensitive data** - Remove debug prints in production
3. **Validate certificates** - Ensure UIDAI certificates are up-to-date
4. **Handle errors gracefully** - Show user-friendly messages
5. **Offline mode** - Works without internet after initial setup

---

## 📊 Expected Behavior

### Official Card (Secure QR):
```
✅ OFFICIAL AADHAAR (VERIFIED)
Signed by UIDAI via certificate_name.cer
Name: John Doe
UID: xxxx xxxx 1234
Card Generated: 2023-07-13
```

### Shop Print (Fake Signature):
```
⚠️ UNOFFICIAL / SHOP PRINT
Data is readable, but Digital Signature is FAKE/INVALID
Name: John Doe
(Same data, but signature verification failed)
```

### DigiLocker/Text QR:
```
⚠️ DIGILOCKER / TEXT QR
Valid Data, but No Cryptographic Security
Name: John Doe
(No signature to verify)
```

---

## 🐛 Common Issues & Solutions

### Issue 1: "No certificates loaded"
**Solution:** Ensure `.cer` files are in `assets/certificates/` and added to `pubspec.yaml`

### Issue 2: "Signature verification always fails"
**Solution:** You need the specific UIDAI certificate that matches the card's generation date

### Issue 3: "Camera permission denied"
**Solution:** Check `AndroidManifest.xml` and `Info.plist` configurations

### Issue 4: "Decompression failed"
**Solution:** The QR might be corrupted or not an Aadhaar QR code

---

## 🎯 Next Steps

1. ✅ Copy `.cer` certificate files to `assets/certificates/`
2. ✅ Run `flutter pub get`
3. ✅ Test on real device (camera required)
4. ✅ Test with different Aadhaar QR types
5. ✅ Add error logging/analytics
6. ✅ Implement data export (PDF/Image)
7. ✅ Add offline certificate updates

---

## 📚 Additional Resources

- **Mobile Scanner**: https://pub.dev/packages/mobile_scanner
- **PointyCastle Crypto**: https://pub.dev/packages/pointycastle
- **XML Parsing**: https://pub.dev/packages/xml
- **UIDAI Specifications**: https://uidai.gov.in/

---

## ✅ Checklist

- [ ] Dependencies added to `pubspec.yaml`
- [ ] Permissions configured (Android & iOS)
- [ ] All model/service files created
- [ ] Certificates placed in `assets/certificates/`
- [ ] Scanner screen implemented
- [ ] Result screen with UI
- [ ] Main app navigation
- [ ] Tested on real device
- [ ] Error handling implemented
- [ ] Security best practices followed

---

**You're all set! 🎉** Run `flutter run` and start scanning Aadhaar QR codes!
