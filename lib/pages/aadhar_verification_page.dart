import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import '../services/aadhar_qr_parser.dart';
import '../services/aadhaar_verification_service.dart';
import '../services/language_service.dart';
import 'aadhar_result_page.dart';
import 'main_screen.dart';

class AadharVerificationPage extends StatefulWidget {
  final String userEmail;
  final String userName;
  final String userId;
  final String? photoUrl;

  const AadharVerificationPage({
    super.key,
    required this.userEmail,
    required this.userName,
    required this.userId,
    this.photoUrl,
  });

  @override
  State<AadharVerificationPage> createState() => _AadharVerificationPageState();
}

class _AadharVerificationPageState extends State<AadharVerificationPage> {
  final AadharQRParser _parser = AadharQRParser();
  final ImagePicker _picker = ImagePicker();
  final BarcodeScanner _barcodeScanner = BarcodeScanner(
    formats: [BarcodeFormat.qrCode],
  );
  bool _isProcessing = false;

  @override
  void dispose() {
    _barcodeScanner.close();
    super.dispose();
  }

  Future<void> _scanFromCamera() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      // Take photo with camera
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 100, // Max quality for dense QR
      );

      if (photo == null) {
        setState(() => _isProcessing = false);
        return;
      }

      await _processImage(photo.path);
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${LanguageService.tr('camera_error')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _scanFromGallery() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      // Pick from gallery
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (image == null) {
        setState(() => _isProcessing = false);
        return;
      }

      await _processImage(image.path);
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${LanguageService.tr('gallery_error')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _processImage(String imagePath) async {
    try {
      // Use ML Kit to scan the QR code from image
      final inputImage = InputImage.fromFilePath(imagePath);
      final barcodes = await _barcodeScanner.processImage(inputImage);

      if (barcodes.isEmpty) {
        if (mounted) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                LanguageService.tr('no_qr_found'),
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Get the first QR code
      final barcode = barcodes.first;
      final rawValue = barcode.rawValue;

      if (rawValue == null || rawValue.isEmpty) {
        if (mounted) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(LanguageService.tr('cannot_read_qr')),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Hash the raw QR data and send to backend for verification
      final verificationResult =
          await AadhaarVerificationService.processAadhaarQR(rawValue);

      if (verificationResult['success'] == true) {
      } else {
        // Show warning but continue to show user details
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                verificationResult['error'] ?? LanguageService.tr('verification_warning'),
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }

      // Parse the QR code (existing functionality - still show user details)
      final result = await _parser.parseQRCode(rawValue);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => AadharResultPage(
            data: result,
            userEmail: widget.userEmail,
            userName: widget.userName,
            userId: widget.userId,
            photoUrl: widget.photoUrl,
            rawQrData: rawValue, // Pass raw data
            backendVerified: verificationResult['success'] == true,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${LanguageService.tr('error_prefix')}: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _skipVerification() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => MainScreen(
          userName: widget.userName,
          isVerified: false,
          userEmail: widget.userEmail,
          userId: widget.userId,
          photoUrl: widget.photoUrl,
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: Text(
          LanguageService.tr('verification'),
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const BackButton(),
        actions: [
          TextButton(
            onPressed: _skipVerification,
            child: Text(
              LanguageService.tr('skip'),
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _isProcessing
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                      LanguageService.tr('processing_qr'),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      LanguageService.tr('scan_aadhar_qr'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      LanguageService.tr('photo_or_gallery'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Camera button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _scanFromCamera,
                        icon: const Icon(Icons.camera_alt, size: 24),
                        label: Text(LanguageService.tr('take_photo')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Gallery button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: _scanFromGallery,
                        icon: const Icon(Icons.photo_library, size: 24),
                        label: Text(LanguageService.tr('choose_gallery')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(
                            color: Colors.white54,
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Info cards
                    _buildInfoCard(
                      Icons.check_circle,
                      Colors.green,
                      LanguageService.tr('secure'),
                      LanguageService.tr('secure_desc'),
                    ),
                    const SizedBox(height: 8),
                    _buildInfoCard(
                      Icons.warning,
                      Colors.orange,
                      LanguageService.tr('unsecure'),
                      LanguageService.tr('unsecure_desc'),
                    ),

                    const SizedBox(height: 24),

                    // Tip
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.lightbulb,
                            color: Colors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              LanguageService.tr('camera_tip'),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Skip button
                    TextButton(
                      onPressed: _skipVerification,
                      child: Text(
                        LanguageService.tr('skip_continue_guest'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildInfoCard(
    IconData icon,
    Color color,
    String title,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
