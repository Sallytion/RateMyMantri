import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import '../services/aadhar_qr_parser.dart';
import '../services/aadhaar_verification_service.dart';
import '../services/language_service.dart';
import 'aadhar_result_page.dart';
import '../main.dart';
import '../services/theme_service.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AadharVerificationPage extends StatefulWidget {
  final String userEmail;
  final String userName;
  final String userId;
  final String? photoUrl;
  final VoidCallback? onComplete;
  final bool isInline;

  const AadharVerificationPage({
    super.key,
    required this.userEmail,
    required this.userName,
    required this.userId,
    this.photoUrl,
    this.onComplete,
    this.isInline = false,
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
            onComplete: widget.onComplete,
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
    if (widget.onComplete != null) {
      widget.onComplete!();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF222222);
    final secondaryTextColor = isDark ? Colors.white70 : const Color(0xFF717171);

    final content = _isProcessing
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: ThemeService.accent),
                const SizedBox(height: 16),
                Text(
                  LanguageService.tr('processing_qr'),
                  style: TextStyle(color: primaryTextColor, fontSize: 16),
                ),
              ],
            ),
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icon
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: ThemeService.accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SvgPicture.asset(
                      'lib/assets/logo/aadhaar.svg',
                      colorFilter: ColorFilter.mode(ThemeService.accent, BlendMode.srcIn),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              Text(
                LanguageService.tr('scan_aadhar_qr'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: primaryTextColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                LanguageService.tr('photo_or_gallery'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: secondaryTextColor,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 24),

              // Information Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF333333) : const Color(0xFFE5E5E5)),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.security_rounded, size: 20, color: Colors.green),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Aadhar is only used to verify reviews. No aadhar data is stored on the server.",
                            style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1, thickness: 1, color: isDark ? const Color(0xFF333333) : const Color(0xFFE5E5E5)),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 20, color: Colors.orange.shade400),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Scan the physical Aadhar card. Digilocker Aadhar QR codes may not work.",
                            style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Camera button
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _scanFromCamera,
                  icon: const Icon(Icons.camera_alt_rounded, size: 22),
                  label: Text(LanguageService.tr('take_photo')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeService.accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Gallery button
              SizedBox(
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _scanFromGallery,
                  icon: const Icon(Icons.photo_library_rounded, size: 22),
                  label: Text(LanguageService.tr('choose_gallery')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryTextColor,
                    side: BorderSide(color: isDark ? Colors.white24 : Colors.black12, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),

              if (widget.isInline) ...[
                const SizedBox(height: 32),
                TextButton(
                  onPressed: _skipVerification,
                  child: Text(
                    LanguageService.tr('skip_continue_guest'),
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          );

    if (widget.isInline) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: content,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          LanguageService.tr('verification'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            color: primaryTextColor,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: primaryTextColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: BackButton(color: primaryTextColor),
        actions: [
          TextButton(
            onPressed: _skipVerification,
            child: Text(
              LanguageService.tr('skip'),
              style: TextStyle(
                color: secondaryTextColor,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: content,
        ),
      ),
    );
  }
}
