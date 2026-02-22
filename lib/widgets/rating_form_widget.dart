import 'package:flutter/material.dart';
import '../models/rating.dart';
import '../services/language_service.dart';
import '../services/ratings_service.dart';
import '../services/theme_service.dart';

class RatingFormWidget extends StatefulWidget {
  final int representativeId;
  final String representativeName;
  final String officeType;
  final bool isDarkMode;
  final bool isVerified;
  final Rating? existingRating;
  final VoidCallback? onRatingSubmitted;

  const RatingFormWidget({
    super.key,
    required this.representativeId,
    required this.representativeName,
    required this.officeType,
    required this.isDarkMode,
    required this.isVerified,
    this.existingRating,
    this.onRatingSubmitted,
  });

  @override
  State<RatingFormWidget> createState() => _RatingFormWidgetState();
}

class _RatingFormWidgetState extends State<RatingFormWidget> {
  final RatingsService _ratingsService = RatingsService();
  final TextEditingController _reviewController = TextEditingController();

  int _question1Stars = 0;
  int _question2Stars = 0;
  int _question3Stars = 0;
  bool _anonymous = false;
  bool _isSubmitting = false;

  late List<String> _questions;

  @override
  void initState() {
    super.initState();
    _questions = RatingsService.getRatingQuestions(widget.officeType);

    // Load existing rating if available
    if (widget.existingRating != null) {
      _question1Stars = widget.existingRating!.question1Stars;
      _question2Stars = widget.existingRating!.question2Stars;
      _question3Stars = widget.existingRating!.question3Stars;
      _anonymous = widget.existingRating!.isAnonymous;
      _reviewController.text = widget.existingRating!.reviewText ?? '';
    }
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    // Validation
    if (_question1Stars == 0 || _question2Stars == 0 || _question3Stars == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LanguageService.tr('rate_all_questions'))),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (widget.existingRating != null) {
        // Update existing rating
        await _ratingsService.updateRating(
          ratingId: widget.existingRating!.id,
          question1Stars: _question1Stars,
          question2Stars: _question2Stars,
          question3Stars: _question3Stars,
          anonymous: _anonymous,
          reviewText: _reviewController.text.trim().isEmpty
              ? null
              : _reviewController.text.trim(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(LanguageService.tr('rating_updated'))),
          );
          // Call callback and close
          widget.onRatingSubmitted?.call();
          Navigator.pop(context, true);
        }
      } else {
        // Create new rating
        await _ratingsService.createRating(
          representativeId: widget.representativeId,
          question1Stars: _question1Stars,
          question2Stars: _question2Stars,
          question3Stars: _question3Stars,
          anonymous: _anonymous,
          reviewText: _reviewController.text.trim().isEmpty
              ? null
              : _reviewController.text.trim(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(LanguageService.tr('rating_submitted'))),
          );
          // Call callback and close
          widget.onRatingSubmitted?.call();
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${LanguageService.tr('failed_submit_rating')}: ${e.toString()}')),
        );
        // Still close the modal after a delay so user isn't stuck
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context, false);
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildStarSelector({
    required String question,
    required int currentStars,
    required Function(int) onStarSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: TextStyle(
            fontSize: 14,
            color: widget.isDarkMode ? Colors.white : const Color(0xFF222222),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final starValue = index + 1;
            return GestureDetector(
              onTap: () => onStarSelected(starValue),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  starValue <= currentStars ? Icons.star : Icons.star_border,
                  color: starValue <= currentStars ? Colors.amber : Colors.grey,
                  size: 36,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            currentStars == 0
                ? LanguageService.tr('tap_to_rate')
                : '$currentStars ${currentStars == 1 ? LanguageService.tr('star_singular') : LanguageService.tr('stars_plural')}',
            style: TextStyle(
              fontSize: 12,
              color: widget.isDarkMode
                  ? Colors.white60
                  : const Color(0xFF888888),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDarkMode ? ThemeService.bgMain : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 24),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.existingRating != null
                              ? LanguageService.tr('edit_rating')
                              : LanguageService.tr('rate_representative'),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: widget.isDarkMode
                                ? Colors.white
                                : const Color(0xFF222222),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.representativeName,
                          style: TextStyle(
                            fontSize: 14,
                            color: widget.isDarkMode
                                ? Colors.white70
                                : const Color(0xFF555555),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close,
                      color: widget.isDarkMode
                          ? Colors.white
                          : const Color(0xFF222222),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Question 1
              _buildStarSelector(
                question: _questions[0],
                currentStars: _question1Stars,
                onStarSelected: (stars) =>
                    setState(() => _question1Stars = stars),
              ),

              const SizedBox(height: 24),
              Divider(
                color: widget.isDarkMode ? Colors.white24 : Colors.black12,
              ),
              const SizedBox(height: 24),

              // Question 2
              _buildStarSelector(
                question: _questions[1],
                currentStars: _question2Stars,
                onStarSelected: (stars) =>
                    setState(() => _question2Stars = stars),
              ),

              const SizedBox(height: 24),
              Divider(
                color: widget.isDarkMode ? Colors.white24 : Colors.black12,
              ),
              const SizedBox(height: 24),

              // Question 3
              _buildStarSelector(
                question: _questions[2],
                currentStars: _question3Stars,
                onStarSelected: (stars) =>
                    setState(() => _question3Stars = stars),
              ),

              const SizedBox(height: 24),
              Divider(
                color: widget.isDarkMode ? Colors.white24 : Colors.black12,
              ),
              const SizedBox(height: 24),

              // Review Text (Optional)
              Text(
                LanguageService.tr('review_optional'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: widget.isDarkMode
                      ? Colors.white
                      : const Color(0xFF222222),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _reviewController,
                maxLines: 4,
                maxLength: 500,
                style: TextStyle(
                  color: widget.isDarkMode
                      ? Colors.white
                      : const Color(0xFF222222),
                ),
                decoration: InputDecoration(
                  hintText: LanguageService.tr('review_hint'),
                  hintStyle: TextStyle(
                    color: widget.isDarkMode
                        ? Colors.white38
                        : const Color(0xFFBBBBBB),
                  ),
                  filled: true,
                  fillColor: widget.isDarkMode
                      ? ThemeService.bgElev
                      : const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),

              const SizedBox(height: 16),

              // Anonymous Toggle (Only for verified users)
              if (widget.isVerified) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: widget.isDarkMode
                        ? ThemeService.bgElev
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.privacy_tip_outlined,
                        color: widget.isDarkMode
                            ? Colors.white70
                            : const Color(0xFF555555),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              LanguageService.tr('post_anonymously'),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: widget.isDarkMode
                                    ? Colors.white
                                    : const Color(0xFF222222),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              LanguageService.tr('name_not_visible'),
                              style: TextStyle(
                                fontSize: 12,
                                color: widget.isDarkMode
                                    ? Colors.white60
                                    : const Color(0xFF888888),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _anonymous,
                        onChanged: (value) =>
                            setState(() => _anonymous = value),
                        activeTrackColor: Colors.green,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Verification notice for unverified users
              if (!widget.isVerified) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          LanguageService.tr('verify_aadhaar_notice'),
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.isDarkMode
                                ? Colors.white70
                                : const Color(0xFF555555),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitRating,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.isDarkMode
                        ? Colors.white
                        : const Color(0xFF222222),
                    foregroundColor: widget.isDarkMode
                        ? const Color(0xFF222222)
                        : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: Colors.grey,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          widget.existingRating != null
                              ? LanguageService.tr('update_rating')
                              : LanguageService.tr('submit_rating'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
