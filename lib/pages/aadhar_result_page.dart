import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/aadhar_data.dart';
import '../services/language_service.dart';
import '../services/theme_service.dart';
import '../main.dart';

class AadharResultPage extends StatelessWidget {
  final AadharData data;
  final String userEmail;
  final String userName;
  final String userId;
  final String? photoUrl;
  final String? rawQrData;
  final bool backendVerified;
  final VoidCallback? onComplete;

  const AadharResultPage({
    super.key,
    required this.data,
    required this.userEmail,
    required this.userName,
    required this.userId,
    this.photoUrl,
    this.rawQrData,
    this.backendVerified = false,
    this.onComplete,
  });

  void _finishLogic(BuildContext context) {
    if (onComplete != null) {
      onComplete!();
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const AuthChecker(),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasError = data.errorMessage != null;
    final bool isSkipped = data.name == 'Guest User';
    final Color statusColor = _getStatusColor();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          isSkipped ? LanguageService.tr('unverified_label') : LanguageService.tr('result'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        ),
        backgroundColor: statusColor,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
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
                    LanguageService.translitName(data.statusLabel),
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
                      LanguageService.translitName(data.statusDescription),
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
                                ? LanguageService.tr('verified_user').toUpperCase()
                                : LanguageService.tr('unverified_user').toUpperCase(),
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
                                ? LanguageService.tr('can_be_anonymous')
                                : LanguageService.tr('cannot_be_anonymous'),
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
                          LanguageService.tr('personal_details'),
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF222222),
                          ),
                        ),
                        const Divider(height: 24),
                        _buildDetailRow('👤 ${LanguageService.tr('name_label')}', LanguageService.translitName(data.name)),
                        _buildDetailRow('🎂 ${LanguageService.tr('dob_label')}', data.dob),
                        _buildDetailRow('⚥ ${LanguageService.tr('gender_label')}', LanguageService.translitName(data.gender)),
                        if (data.careOf != null && data.careOf!.isNotEmpty)
                          _buildDetailRow('👪 ${LanguageService.tr('care_of_label')}', LanguageService.translitName(data.careOf!)),
                        _buildDetailRow('🏠 ${LanguageService.tr('address_label')}', LanguageService.translitName(data.address)),
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
                          LanguageService.tr('card_information'),
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF222222),
                          ),
                        ),
                        const Divider(height: 24),
                        _buildDetailRow('📅 ${LanguageService.tr('card_generated')}', data.cardGenDate),
                        _buildDetailRow('💳 ${LanguageService.tr('uid_last4')}', data.uidLast4),
                        _buildDetailRow('🔍 ${LanguageService.tr('qr_type')}', _getQRTypeName()),
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
                                      ? '✔ ${LanguageService.tr('verified_backend')}'
                                      : '⚠ ${LanguageService.tr('backend_pending')}',
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
                            _finishLogic(context);
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
                        child: Text(
                          LanguageService.tr('continue_verified'),
                          style: const TextStyle(
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
                          backgroundColor: ThemeService.accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          LanguageService.tr('scan_official_pvc'),
                          style: const TextStyle(
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
                          _finishLogic(context);
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF222222)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          LanguageService.tr('continue_unverified'),
                          style: const TextStyle(
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
                              LanguageService.tr('verify_anytime'),
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
                          _finishLogic(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThemeService.accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          LanguageService.tr('continue_without_verification'),
                          style: const TextStyle(
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
                          backgroundColor: ThemeService.accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          LanguageService.tr('try_again'),
                          style: const TextStyle(
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
        return LanguageService.tr('secure_v2');
      case QRType.digilockerXML:
        return LanguageService.tr('digilocker_xml');
      case QRType.unknown:
        return LanguageService.tr('unknown_type');
    }
  }
}
