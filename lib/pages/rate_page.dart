import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/theme_provider.dart';
import '../models/rating.dart';
import '../services/ratings_service.dart';
import '../services/auth_storage_service.dart';
import '../services/language_service.dart';
import '../services/theme_service.dart';
import '../utils/formatters.dart';
import '../utils/widgets/placeholder_avatar.dart';
import '../widgets/rating_form_widget.dart';

class RatePage extends StatefulWidget {
  final bool isVerified;

  const RatePage({
    super.key,
    required this.isVerified,
  });

  @override
  State<RatePage> createState() => _RatePageState();
}

class _RatePageState extends State<RatePage> {
  final RatingsService _ratingsService = RatingsService();

  /// Reads the current dark-mode flag from the provider.
  bool get isDarkMode => context.read<ThemeProvider>().isDarkMode;

  // â”€â”€â”€ Static in-memory cache (survives widget rebuilds) â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static List<Rating>? _cachedRatings;
  static bool? _cachedIsAuthenticated;

  static void clearCache() {
    _cachedRatings = null;
    _cachedIsAuthenticated = null;
  }

  List<Rating> _userRatings = [];
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuthAndLoadRatings();
  }

  Future<void> _checkAuthAndLoadRatings() async {
    if (_cachedIsAuthenticated != null && _cachedRatings != null) {
      setState(() {
        _isAuthenticated = _cachedIsAuthenticated!;
        _userRatings = _cachedRatings!;
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      _isAuthenticated = await AuthStorageService.isAuthenticated();
      _cachedIsAuthenticated = _isAuthenticated;

      if (_isAuthenticated) {
        final ratings = await _ratingsService.getCurrentUserRatings();
        _cachedRatings = ratings;
        setState(() {
          _userRatings = ratings;
          _isLoading = false;
        });
      } else {
        _cachedRatings = [];
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshRatings() async {
    clearCache();
    await _checkAuthAndLoadRatings();
  }

  Future<void> _deleteRating(Rating rating) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          decoration: BoxDecoration(
            color: isDarkMode ? ThemeService.bgElev : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  LanguageService.tr('delete_rating'),
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : const Color(0xFF222222),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${LanguageService.tr('delete_rating_confirm')}\n${rating.representativeName ?? LanguageService.tr('this_representative')}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDarkMode ? const Color(0xFFB0B0B0) : const Color(0xFF717171),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          backgroundColor: isDarkMode
                              ? ThemeService.bgBorder
                              : const Color(0xFFF5F5F5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          LanguageService.tr('cancel'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          LanguageService.tr('delete'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed == true) {
      try {
        await _ratingsService.deleteRating(rating.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(LanguageService.tr('rating_deleted'))),
          );
          clearCache();
          _checkAuthAndLoadRatings();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${LanguageService.tr('failed_delete_rating')}: $e')),
          );
        }
      }
    }
  }

  void _editRating(Rating rating) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: RatingFormWidget(
          representativeId: rating.representativeId,
          representativeName: rating.representativeName ?? 'Unknown',
          officeType: rating.officeType ?? 'MP',
          isDarkMode: isDarkMode,
          isVerified: widget.isVerified,
          existingRating: rating,
          onRatingSubmitted: () {
            clearCache();
            _checkAuthAndLoadRatings();
          },
        ),
      ),
    );
  }

  // â”€â”€â”€ Star bar helper â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildStarRow(int stars, {double size = 14}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) => Icon(
        i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
        size: size,
        color: i < stars
            ? ThemeService.accent
            : (isDarkMode ? const Color(0xFF444444) : const Color(0xFFD5D5D5)),
      )),
    );
  }

  // â”€â”€â”€ Rating card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildRatingCard(Rating rating, {required Color textColor, required Color subtextColor}) {
    final borderColor = isDarkMode
        ? ThemeService.bgBorder
        : const Color(0xFFEEEEEE);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? ThemeService.bgCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _editRating(rating),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // â”€â”€ Top row: avatar + name + overall stars â”€â”€
                Row(
                  children: [
                    // Circular avatar
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: borderColor, width: 1.5),
                      ),
                      child: ClipOval(
                        child: rating.representativeImage != null
                            ? CachedNetworkImage(
                                imageUrl: rating.representativeImage!,
                                fit: BoxFit.cover,
                                memCacheWidth: 88,
                                memCacheHeight: 88,
                                placeholder: (context, url) => Shimmer.fromColors(
                                  baseColor: Colors.grey[300]!,
                                  highlightColor: Colors.grey[100]!,
                                  child: Container(color: Colors.white),
                                ),
                                errorWidget: (context, url, error) =>
                                    _buildPlaceholderAvatar(rating.representativeName ?? 'U'),
                              )
                            : _buildPlaceholderAvatar(rating.representativeName ?? 'U'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Name + meta
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rating.representativeName ?? 'Unknown',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (rating.party != null && rating.party!.isNotEmpty) rating.party!,
                              if (rating.constituency != null && rating.constituency!.isNotEmpty) rating.constituency!,
                            ].join(' • '),
                            style: TextStyle(
                              fontSize: 12,
                              color: subtextColor,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Overall star display
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: ThemeService.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded, size: 16, color: ThemeService.accent),
                          const SizedBox(width: 3),
                          Text(
                            rating.overallStars.toStringAsFixed(0),
                            style: TextStyle(
                              color: ThemeService.accent,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // â”€â”€ Star breakdown â”€â”€
                Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 2),
                  child: Row(
                    children: [
                      _buildMiniStat(LanguageService.tr('development'), rating.question1Stars, subtextColor),
                      Container(
                        width: 1,
                        height: 28,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        color: borderColor,
                      ),
                      _buildMiniStat(LanguageService.tr('responsiveness'), rating.question2Stars, subtextColor),
                      Container(
                        width: 1,
                        height: 28,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        color: borderColor,
                      ),
                      _buildMiniStat(LanguageService.tr('integrity'), rating.question3Stars, subtextColor),
                    ],
                  ),
                ),

                // â”€â”€ Review text â”€â”€
                if (rating.reviewText != null && rating.reviewText!.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      '"${LanguageService.translitName(rating.reviewText!)}"',
                      style: TextStyle(
                        fontSize: 13,
                        color: subtextColor,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],

                // â”€â”€ Footer: status + date + actions â”€â”€
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      // Status chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: rating.isVerified
                              ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                              : subtextColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          rating.isAnonymous
                              ? LanguageService.tr('anonymous')
                              : rating.isVerified
                                  ? LanguageService.tr('verified')
                                  : LanguageService.tr('unverified'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: rating.isVerified ? const Color(0xFF4CAF50) : subtextColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(rating.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: subtextColor,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const Spacer(),
                      // Edit icon
                      _buildActionIcon(
                        Icons.edit_outlined,
                        subtextColor,
                        () => _editRating(rating),
                      ),
                      const SizedBox(width: 4),
                      // Delete icon
                      _buildActionIcon(
                        Icons.delete_outline_rounded,
                        subtextColor,
                        () => _deleteRating(rating),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, int stars, Color subtextColor) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: subtextColor,
              letterSpacing: 0.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          _buildStarRow(stars, size: 12),
        ],
      ),
    );
  }

  Widget _buildActionIcon(IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  Widget _buildPlaceholderAvatar(String name) {
    return PlaceholderAvatar(name: name, fontSize: 18, useGradient: false);
  }

  String _formatDate(DateTime date) {
    return Formatters.formatRelativeDate(date);
  }

  // â”€â”€â”€ Empty/auth states â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color textColor,
    required Color subtextColor,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 56,
              color: subtextColor.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textColor,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: subtextColor,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<ThemeProvider>().isDarkMode;
    final backgroundColor = isDarkMode ? ThemeService.bgMain : const Color(0xFFF7F7F7);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF222222);
    final subtextColor = isDarkMode ? const Color(0xFFB0B0B0) : const Color(0xFF717171);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: ThemeService.accent,
                  strokeWidth: 2.5,
                ),
              )
            : !_isAuthenticated
                ? _buildEmptyState(
                    icon: Icons.person_outline_rounded,
                    title: LanguageService.tr('sign_in_required'),
                    subtitle: LanguageService.tr('sign_in_subtitle'),
                    textColor: textColor,
                    subtextColor: subtextColor,
                  )
                : _userRatings.isEmpty
                    ? _buildEmptyState(
                        icon: Icons.star_outline_rounded,
                        title: LanguageService.tr('no_ratings'),
                        subtitle: LanguageService.tr('no_ratings_subtitle'),
                        textColor: textColor,
                        subtextColor: subtextColor,
                      )
                    : Column(
                        children: [
                          // â”€â”€ Header â”€â”€
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        LanguageService.tr('my_ratings'),
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_userRatings.length} ${_userRatings.length == 1 ? LanguageService.tr('rating') : LanguageService.tr('ratings')}',
                                        style: TextStyle(
                                          color: subtextColor,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (widget.isVerified)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.verified_rounded,
                                          color: Color(0xFF4CAF50),
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          LanguageService.tr('verified'),
                                          style: const TextStyle(
                                            color: Color(0xFF4CAF50),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // â”€â”€ Ratings list â”€â”€
                          Expanded(
                            child: RefreshIndicator(
                              color: ThemeService.accent,
                              onRefresh: _refreshRatings,
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                                itemCount: _userRatings.length,
                                itemBuilder: (context, index) => _buildRatingCard(
                                  _userRatings[index],
                                  textColor: textColor,
                                  subtextColor: subtextColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }
}
