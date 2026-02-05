import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import '../models/aadhar_data.dart';

class AadharQRParser {
  /// Parse QR code and determine if it's secure or not
  Future<AadharData> parseQRCode(String rawData) async {
    try {
      // Detect QR Type
      if (rawData.trim().startsWith('<?xml') ||
          rawData.contains('<PrintLetterBarcodeData')) {
        // Old XML format - UNSECURE (DigiLocker/Shop Print)
        return _parseXmlQR(rawData, isSecure: false);
      } else if (_isNumeric(rawData)) {
        // Numeric format - This is the SECURE dense QR from PVC Aadhar
        return await _parseSecureQR(rawData);
      } else {
        return AadharData.error('Unknown QR Format');
      }
    } catch (e) {
      return AadharData.error('Parsing failed: $e');
    }
  }

  bool _isNumeric(String str) {
    return RegExp(r'^[0-9]+$').hasMatch(str);
  }

  /// Parse Old XML Format (DigiLocker/Text QR) - UNSECURE
  AadharData _parseXmlQR(String rawData, {required bool isSecure}) {
    try {
      final startIndex = rawData.indexOf('<');
      final cleanXml = rawData.substring(startIndex);
      final document = XmlDocument.parse(cleanXml);
      final root = document.rootElement;

      // Extract attributes
      final name = root.getAttribute('name') ?? 'Unknown';
      final uid = root.getAttribute('uid') ?? '';
      final dob =
          root.getAttribute('dob') ?? root.getAttribute('yob') ?? 'Unknown';
      final gender = root.getAttribute('gender') ?? 'Unknown';
      final careOf = root.getAttribute('co');

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

      return AadharData(
        type: QRType.digilockerXML,
        isSecure: isSecure,
        name: name,
        dob: dob,
        gender: gender,
        careOf: careOf,
        address: address,
        cardGenDate: 'N/A',
        uidLast4: maskedUid,
      );
    } catch (e) {
      return AadharData.error('XML Parse Failed: $e');
    }
  }

  /// Parse Secure QR V2.0 (Numeric Dense QR) - SECURE
  Future<AadharData> _parseSecureQR(String rawData) async {
    try {
      // 1. Convert BigInt String to Bytes
      final bigInt = BigInt.parse(rawData);
      final byteLength = (bigInt.bitLength + 7) ~/ 8;
      final byteArray = _bigIntToBytes(bigInt, byteLength);

      // 2. Decompress using Gzip
      final decompressed = GZipDecoder().decodeBytes(byteArray);

      if (decompressed.length <= 256) {
        return AadharData.error('Data too short - Invalid QR');
      }

      // 3. Split Data (we ignore signature verification as per user requirement)
      final dataBody = Uint8List.fromList(
        decompressed.sublist(0, decompressed.length - 256),
      );

      // 4. Parse Data Fields
      final parsedData = _parseSecureQRData(dataBody);

      // 5. This is a SECURE QR (dense numeric QR from official PVC Aadhar)
      return AadharData(
        type: QRType.secureV2,
        isSecure: true, // This is the secure dense QR
        name: parsedData['name'] ?? 'Unknown',
        dob: parsedData['dob'] ?? 'Unknown',
        gender: parsedData['gender'] ?? 'Unknown',
        careOf: parsedData['co'],
        address: _buildAddress(parsedData),
        cardGenDate: parsedData['cardGenDate'] ?? 'Unknown',
        uidLast4: parsedData['uidLast4'] ?? 'Unknown',
      );
    } catch (e) {
      return AadharData.error('Secure QR Processing Failed: $e');
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
      cardGenDate =
          '${datePart.substring(0, 4)}-'
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
