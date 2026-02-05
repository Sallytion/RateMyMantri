import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/aadhar_data.dart';
import 'main_screen.dart';

class AadharResultPage extends StatelessWidget {
  final AadharData data;
  final String userEmail;
  final String userName;
  final String userId;
  final String? photoUrl;
  final String? rawQrData;
  final bool backendVerified;

  const AadharResultPage({
    super.key,
    required this.data,
    required this.userEmail,
    required this.userName,
    required this.userId,
    this.photoUrl,
    this.rawQrData,
    this.backendVerified = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasError = data.errorMessage != null;
    final bool isSkipped = data.name == 'Guest User';
    final Color statusColor = _getStatusColor();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          isSkipped ? 'Continue Without Verification' : 'Verification Result',
        ),
        backgroundColor: statusColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Status Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  Icon(_getStatusIcon(), size: 80, color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    data.statusLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      data.statusDescription,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),

            if (!hasError && !isSkipped) ...[
              // User Type Badge
              Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: data.isSecure
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: data.isSecure
                          ? Colors.green.shade200
                          : Colors.orange.shade200,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        data.isSecure
                            ? Icons.verified_user
                            : Icons.person_outline,
                        color: data.isSecure ? Colors.green : Colors.orange,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data.userType == UserType.verified
                                ? 'VERIFIED USER'
                                : 'UNVERIFIED USER',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: data.isSecure
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                          Text(
                            data.isSecure
                                ? 'Can be anonymous'
                                : 'Cannot be anonymous',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Personal Details Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Personal Details',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF222222),
                          ),
                        ),
                        const Divider(height: 24),
                        _buildDetailRow('ðŸ‘¤ Name', data.name),
                        _buildDetailRow('ðŸŽ‚ Date of Birth', data.dob),
                        _buildDetailRow('âš¥ Gender', data.gender),
                        if (data.careOf != null && data.careOf!.isNotEmpty)
                          _buildDetailRow('ðŸ‘ª Care Of', data.careOf!),
                        _buildDetailRow('ðŸ  Address', data.address),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Card Information
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Card Information',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF222222),
                          ),
                        ),
                        const Divider(height: 24),
                        _buildDetailRow('ðŸ“… Card Generated', data.cardGenDate),
                        _buildDetailRow('ðŸ’³ UID (Last 4)', data.uidLast4),
                        _buildDetailRow('ðŸ” QR Type', _getQRTypeName()),
                        if (rawQrData != null) ...[
                          const Divider(height: 24),
                          Row(
                            children: [
                              Icon(
                                backendVerified
                                    ? Icons.cloud_done
                                    : Icons.cloud_off,
                                size: 20,
                                color: backendVerified
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  backendVerified
                                      ? 'âœ“ Verified with Backend (Hash stored securely)'
                                      : 'âš  Backend verification pending',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: backendVerified
                                        ? Colors.green.shade700
                                        : Colors.orange.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],

            // Action Buttons
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (data.isSecure && !hasError)
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () async {
                          // No need to fetch user profile - new tokens already include is_verified
                          // The backend now returns updated tokens after verification

                          if (context.mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MainScreen(
                                  userName: userName,
                                  isVerified: true,
                                  userEmail: userEmail,
                                  userId: userId,
                                  photoUrl: photoUrl,
                                ),
                              ),
                              (route) => false,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Continue as Verified User',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                  if (!data.isSecure && !hasError && !isSkipped) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF385C),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Scan Official PVC Aadhar QR',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MainScreen(
                                userName: userName,
                                isVerified: false,
                                userEmail: userEmail,
                                userId: userId,
                                photoUrl: photoUrl,
                              ),
                            ),
                            (route) => false,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF222222)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Continue as Unverified (No Anonymous)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF222222),
                          ),
                        ),
                      ),
                    ),
                  ],

                  // Skip/Guest scenario
                  if (isSkipped) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'You can verify your Aadhar anytime from Profile settings to enable anonymous ratings',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MainScreen(
                                userName: userName,
                                isVerified: false,
                                userEmail: userEmail,
                                userId: userId,
                                photoUrl: photoUrl,
                              ),
                            ),
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF385C),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Continue Without Verification',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],

                  if (hasError && !isSkipped)
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF385C),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Try Again',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Color(0xFF717171),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: Color(0xFF222222)),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    if (data.errorMessage != null) {
      return Colors.red;
    }
    return data.isSecure ? Colors.green : Colors.orange;
  }

  IconData _getStatusIcon() {
    if (data.errorMessage != null) {
      return Icons.error;
    }
    return data.isSecure ? Icons.verified : Icons.warning_amber;
  }

  String _getQRTypeName() {
    switch (data.type) {
      case QRType.secureV2:
        return 'Secure V2.0 (Dense QR)';
      case QRType.digilockerXML:
        return 'DigiLocker/Text (XML)';
      case QRType.unknown:
        return 'Unknown';
    }
  }
}
