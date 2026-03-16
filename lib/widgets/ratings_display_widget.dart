import 'package:flutter/material.dart';
import '../models/rating.dart';
import '../models/rating_statistics.dart';
import '../services/language_service.dart';
import '../services/ratings_service.dart';
import '../services/theme_service.dart';
import '../utils/formatters.dart';

class RatingsDisplayWidget extends StatefulWidget {
  final int representativeId;
  final bool isDarkMode;

  const RatingsDisplayWidget({
    super.key,
    required this.representativeId,
    required this.isDarkMode,
  });

  @override
  State<RatingsDisplayWidget> createState() => _RatingsDisplayWidgetState();
}

class _RatingsDisplayWidgetState extends State<RatingsDisplayWidget> {
  final RatingsService _ratingsService = RatingsService();

  RatingStatistics? _statistics;
  List<Rating> _ratings = [];
  bool _isLoading = true;
  final int _pageSize = 10;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([_loadStatistics(), _loadRatings()]);
  }

  Future<void> _loadStatistics() async {
    try {
      final stats = await _ratingsService.getRatingStatistics(
        widget.representativeId,
      );
      if (mounted) {
        setState(() => _statistics = stats);
      }
    } catch (e) {
    }
  }

  Future<void> _loadRatings({bool loadMore = false}) async {
    try {
      final offset = loadMore ? _ratings.length : 0;

      final result = await _ratingsService.getRatingsForRepresentative(
        representativeId: widget.representativeId,
        limit: _pageSize,
        offset: offset,
      );

      if (mounted) {
        setState(() {
          if (loadMore) {
            _ratings.addAll(result['ratings'] as List<Rating>);
          } else {
            _ratings = result['ratings'] as List<Rating>;
            // Use statistics from ratings endpoint (more reliable than separate stats endpoint)
            if (result['statistics'] != null) {
              _statistics = result['statistics'] as RatingStatistics;
            }
          }
          _hasMore = (result['ratings'] as List<Rating>).length >= _pageSize;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildStarRating(int stars, {double size = 16}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < stars ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: size,
        );
      }),
    );
  }

  Widget _buildStatisticsCard() {
    if (_statistics == null) {
      return const SizedBox.shrink();
    }

    return Card(
      color: widget.isDarkMode ? ThemeService.bgElev : ThemeService.lightCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ThemeService.cardRadius),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LanguageService.tr('overall_rating'),
                        style: TextStyle(
                          fontSize: 14,
                          color: widget.isDarkMode
                              ? Colors.white70
                              : ThemeService.lightSubtext,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildStarRating(_statistics!.overallStars, size: 24),
                      const SizedBox(height: 4),
                      Text(
                        '${_statistics!.avgOverallScore.toStringAsFixed(1)}/100',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: widget.isDarkMode
                              ? Colors.white
                              : ThemeService.lightText,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: widget.isDarkMode
                        ? ThemeService.bgMain
                        : ThemeService.lightCardAlt,
                    borderRadius: BorderRadius.circular(ThemeService.smallRadius),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${_statistics!.totalRatings}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: widget.isDarkMode
                              ? Colors.white
                              : ThemeService.lightText,
                        ),
                      ),
                      Text(
                        LanguageService.tr('ratings'),
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.isDarkMode
                              ? Colors.white70
                              : ThemeService.lightSubtext,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            Divider(color: widget.isDarkMode ? Colors.white24 : ThemeService.lightBorder),
            const SizedBox(height: 16),

            // Detailed Breakdown
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    LanguageService.tr('q1_avg'),
                    _statistics!.avgQ1Stars.toStringAsFixed(1),
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    LanguageService.tr('q2_avg'),
                    _statistics!.avgQ2Stars.toStringAsFixed(1),
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    LanguageService.tr('q3_avg'),
                    _statistics!.avgQ3Stars.toStringAsFixed(1),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Privacy breakdown
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    LanguageService.tr('ratings'),
                    '${_statistics!.totalRatings}',
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    LanguageService.tr('anonymous'),
                    '${_statistics!.verifiedAnonymousCount}',
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Named',
                    '${_statistics!.totalRatings - _statistics!.verifiedAnonymousCount}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: widget.isDarkMode ? Colors.white : ThemeService.lightText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: widget.isDarkMode ? Colors.white60 : ThemeService.lightSubtext,
          ),
        ),
      ],
    );
  }

  Widget _buildRatingCard(Rating rating) {
    return Card(
      color: widget.isDarkMode ? ThemeService.bgElev : ThemeService.lightCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ThemeService.cardRadius - 4),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Info & Overall Rating
            Row(
              children: [
                if (rating.userProfileImage != null && !rating.isAnonymous)
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: NetworkImage(rating.userProfileImage!),
                  )
                else
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: widget.isDarkMode
                        ? ThemeService.bgBorder
                        : const Color(0xFFE0E0E0),
                    child: Icon(
                      rating.isAnonymous ? Icons.person_outline : Icons.person,
                      color: widget.isDarkMode
                          ? Colors.white70
                          : ThemeService.lightSubtext,
                      size: 20,
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rating.isAnonymous
                            ? LanguageService.tr('anonymous')
                            : LanguageService.translitName(rating.userName ?? LanguageService.tr('user')),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: widget.isDarkMode
                              ? Colors.white
                              : ThemeService.lightText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: rating.isAnonymous
                                  ? ThemeService.accent.withValues(alpha: 0.2)
                                  : Colors.grey.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(ThemeService.chipRadius),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  rating.isAnonymous
                                      ? Icons.visibility_off_outlined
                                      : Icons.person_outline,
                                  size: 10,
                                  color: rating.isAnonymous
                                      ? ThemeService.accent
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  rating.isAnonymous ? LanguageService.tr('anonymous') : 'Named',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: widget.isDarkMode
                                        ? Colors.white70
                                        : ThemeService.lightSubtext,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDate(rating.createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: widget.isDarkMode
                                  ? Colors.white60
                                  : ThemeService.lightSubtext,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildStarRating(rating.overallStars.round()),
                    const SizedBox(height: 4),
                    Text(
                      '${rating.overallScore}/100',
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.isDarkMode
                            ? Colors.white70
                            : ThemeService.lightSubtext,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Individual Ratings
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LanguageService.tr('q1'),
                        style: TextStyle(
                          fontSize: 10,
                          color: widget.isDarkMode
                              ? Colors.white60
                              : ThemeService.lightSubtext,
                        ),
                      ),
                      _buildStarRating(rating.question1Stars, size: 14),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LanguageService.tr('q2'),
                        style: TextStyle(
                          fontSize: 10,
                          color: widget.isDarkMode
                              ? Colors.white60
                              : ThemeService.lightSubtext,
                        ),
                      ),
                      _buildStarRating(rating.question2Stars, size: 14),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LanguageService.tr('q3'),
                        style: TextStyle(
                          fontSize: 10,
                          color: widget.isDarkMode
                              ? Colors.white60
                              : ThemeService.lightSubtext,
                        ),
                      ),
                      _buildStarRating(rating.question3Stars, size: 14),
                    ],
                  ),
                ),
              ],
            ),

            // Review Text
            if (rating.reviewText != null && rating.reviewText!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.isDarkMode
                      ? ThemeService.bgMain
                      : ThemeService.lightCardAlt,
                  borderRadius: BorderRadius.circular(ThemeService.chipRadius),
                ),
                child: Text(
                  LanguageService.translitName(rating.reviewText!),
                  style: TextStyle(
                    fontSize: 13,
                    color: widget.isDarkMode
                        ? Colors.white70
                        : ThemeService.lightSubtext,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return Formatters.formatRelativeDate(date);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: widget.isDarkMode ? Colors.white : ThemeService.lightText,
        ),
      );
    }

    if (_statistics == null || _statistics!.totalRatings == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.star_border,
                size: 48,
                color: widget.isDarkMode
                    ? Colors.white38
                    : ThemeService.lightSubtext,
              ),
              const SizedBox(height: 16),
              Text(
                LanguageService.tr('no_ratings'),
                style: TextStyle(
                  fontSize: 16,
                  color: widget.isDarkMode
                      ? Colors.white70
                      : ThemeService.lightSubtext,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                LanguageService.tr('be_first_rate'),
                style: TextStyle(
                  fontSize: 12,
                  color: widget.isDarkMode
                      ? Colors.white60
                      : ThemeService.lightSubtext,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Statistics Card
        _buildStatisticsCard(),

        // Ratings List Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            '${LanguageService.tr('all_ratings')} (${_statistics!.totalRatings})',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: widget.isDarkMode ? Colors.white : ThemeService.lightText,
            ),
          ),
        ),

        // Ratings List
        ..._ratings.map((rating) => _buildRatingCard(rating)),

        // Load More Button
        if (_hasMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: OutlinedButton(
                onPressed: () => _loadRatings(loadMore: true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: widget.isDarkMode
                      ? Colors.white
                      : ThemeService.lightText,
                  side: BorderSide(
                    color: widget.isDarkMode
                        ? Colors.white38
                        : ThemeService.lightBorder,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ThemeService.smallRadius),
                  ),
                ),
                child: Text(LanguageService.tr('load_more')),
              ),
            ),
          ),
      ],
    );
  }
}
