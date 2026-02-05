enum QRType {
  secureV2, // Dense QR from official PVC Aadhar
  digilockerXML, // Text QR from DigiLocker/shop print
  unknown,
}

enum UserType {
  verified, // User has verified Aadhar (can be anonymous)
  unverified, // User without verified Aadhar (cannot be anonymous)
}

class AadharData {
  final QRType type;
  final bool isSecure;
  final String name;
  final String dob;
  final String gender;
  final String? careOf;
  final String address;
  final String cardGenDate;
  final String uidLast4;
  final String? errorMessage;

  AadharData({
    required this.type,
    required this.isSecure,
    required this.name,
    required this.dob,
    required this.gender,
    this.careOf,
    required this.address,
    required this.cardGenDate,
    required this.uidLast4,
    this.errorMessage,
  });

  factory AadharData.error(String message) {
    return AadharData(
      type: QRType.unknown,
      isSecure: false,
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
    if (errorMessage != null) {
      return '❌ ERROR';
    }
    if (isSecure) {
      return '✅ SECURE AADHAR';
    } else {
      return '⚠️ UNSECURE / SHOP PRINT';
    }
  }

  String get statusDescription {
    if (errorMessage != null) {
      return errorMessage!;
    }
    if (isSecure) {
      return 'Official PVC Aadhar with Dense QR Code\nYou can verify as an anonymous user';
    } else {
      return 'This QR is from DigiLocker or shop print\nPlease scan the dense QR code from your official PVC Aadhar card (not shop printed)';
    }
  }

  UserType get userType {
    return isSecure ? UserType.verified : UserType.unverified;
  }
}
