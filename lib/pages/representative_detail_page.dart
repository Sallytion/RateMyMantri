import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../models/representative_detail.dart';
import '../models/rating.dart';
import '../models/rating_statistics.dart';
import '../services/representative_service.dart';
import '../services/ratings_service.dart';
import '../services/auth_storage_service.dart';
import '../services/prefetch_service.dart';
import '../services/language_service.dart';
import '../services/theme_service.dart';
import '../utils/formatters.dart';
import '../utils/widgets/placeholder_avatar.dart';
import '../widgets/rating_form_widget.dart';
import '../widgets/ratings_display_widget.dart';
import '../widgets/skeleton_widgets.dart';

class RepresentativeDetailPage extends StatefulWidget {
  final String representativeId;
  final bool isDarkMode;

  const RepresentativeDetailPage({
    super.key,
    required this.representativeId,
    required this.isDarkMode,
  });

  @override
  State<RepresentativeDetailPage> createState() =>
      _RepresentativeDetailPageState();
}

class _RepresentativeDetailPageState extends State<RepresentativeDetailPage> {
  final RepresentativeService _service = RepresentativeService();
  final RatingsService _ratingsService = RatingsService();
  final PrefetchService _prefetchService = PrefetchService();

  RepresentativeDetail? _detail;
  bool _isLoading = true;
  bool _isAuthenticated = false;
  bool _isVerified = false;
  Rating? _userRating;
  bool _loadingRating = true;
  int _ratingsRefreshKey = 0;
  RatingStatistics? _ratingStats;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadRepresentativeDetail(),
      _checkAuthAndLoadUserRating(),
      _loadRatingStatistics(),
    ]);
  }

  Future<void> _loadRepresentativeDetail() async {
    // Check for prefetched data first
    final prefetched = _prefetchService.getPrefetchedDetail(widget.representativeId);
    if (prefetched != null) {
      if (mounted) {
        setState(() {
          _detail = prefetched;
          _isLoading = false;
        });
      }
      return;
    }

    final detail = await _service.getRepresentativeById(
      widget.representativeId,
    );
    if (mounted) {
      setState(() {
        _detail = detail;
        _isLoading = false;
      });
    }
  }

  Future<void> _checkAuthAndLoadUserRating() async {
    try {
      _isAuthenticated = await AuthStorageService.isAuthenticated();

      if (_isAuthenticated) {
        _isVerified = await AuthStorageService.getAadhaarVerificationStatus();
        final rating = await _ratingsService.getUserRatingForRepresentative(
          int.parse(widget.representativeId),
        );

        if (mounted) {
          setState(() {
            _userRating = rating;
            _loadingRating = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _loadingRating = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingRating = false);
      }
    }
  }

  Future<void> _loadRatingStatistics() async {
    try {
      // Check for prefetched stats first
      final prefetchedStats = _prefetchService.getPrefetchedStats(widget.representativeId);
      if (prefetchedStats != null && prefetchedStats is RatingStatistics) {
        if (mounted) {
          setState(() => _ratingStats = prefetchedStats);
        }
        return;
      }

      final stats = await _ratingsService.getRatingStatistics(
        int.parse(widget.representativeId),
      );
      if (mounted) {
        setState(() => _ratingStats = stats);
      }
    } catch (e) {
    }
  }

  void _showRatingForm() {
    if (!_isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LanguageService.tr('sign_in_to_rate_rep')),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: RatingFormWidget(
          representativeId: int.parse(widget.representativeId),
          representativeName: _detail?.name ?? '',
          officeType: _detail?.officeType ?? '',
          isDarkMode: widget.isDarkMode,
          isVerified: _isVerified,
          existingRating: _userRating,
          onRatingSubmitted: () {
            _prefetchService.invalidate(widget.representativeId);
            _checkAuthAndLoadUserRating();
            _loadRatingStatistics();
            // Force refresh the ratings display
            setState(() {
              _ratingsRefreshKey++;
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDarkMode ? ThemeService.bgMain : Colors.white;
    final textColor = widget.isDarkMode
        ? Colors.white
        : const Color(0xFF222222);
    final cardColor = widget.isDarkMode
        ? ThemeService.bgElev
        : const Color(0xFFF9F9F9);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _detail?.name ?? '',
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? RepresentativeDetailSkeleton(isDarkMode: widget.isDarkMode)
            : _detail == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: textColor.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    LanguageService.tr('failed_load_details'),
                    style: TextStyle(
                      fontSize: 18,
                      color: textColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeader(textColor, cardColor),
                  _buildStats(textColor, cardColor),
                  const SizedBox(height: 16),
                  _buildRatingButton(textColor, cardColor),
                  const SizedBox(height: 16),
                  if (_detail!.totalCases > 0) _buildBadge(textColor),
                  _buildSections(textColor, cardColor),
                  const SizedBox(height: 24),
                  _buildRatingsSection(textColor),
                  const SizedBox(height: 32),
                ],
              ),
            ),
      ),
    );
  }

  String _officeTypeLabel(String officeType) {
    switch (officeType) {
      case 'LOK_SABHA':
        return LanguageService.tr('mp_lok_sabha');
      case 'RAJYA_SABHA':
        return LanguageService.tr('mp_rajya_sabha');
      case 'STATE_ASSEMBLY':
        return LanguageService.tr('mla');
      case 'VIDHAN_PARISHAD':
        return LanguageService.tr('mlc');
      default:
        return officeType.replaceAll('_', ' ');
    }
  }

  Widget _buildHeader(Color textColor, Color cardColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          // Profile Image
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: textColor.withValues(alpha: 0.1), width: 2),
            ),
            child: Hero(
              tag: 'rep_avatar_${widget.representativeId}',
              child: ClipOval(
                child: _detail!.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: _detail!.imageUrl!,
                        fit: BoxFit.cover,
                        memCacheWidth: 280,
                        memCacheHeight: 280,
                        placeholder: (context, url) => Shimmer.fromColors(
                          baseColor: Colors.grey[300]!,
                          highlightColor: Colors.grey[100]!,
                          child: Container(color: Colors.white),
                        ),
                        errorWidget: (context, url, error) {
                          return _buildPlaceholderAvatar();
                        },
                      )
                    : _buildPlaceholderAvatar(),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Name
          Text(
            _detail!.name,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // Subtitle
          Text(
            '${_officeTypeLabel(_detail!.officeType)} • ${_detail!.constituency}',
            style: TextStyle(fontSize: 14, color: textColor.withValues(alpha: 0.6)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderAvatar() {
    return PlaceholderAvatar(name: _detail?.name ?? '');
  }

  Widget _buildStats(Color textColor, Color cardColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem(
            _detail!.assets != null ? _formatCurrency(_detail!.assets!) : 'N/A',
            LanguageService.tr('total_assets'),
            textColor,
          ),
          Container(width: 1, height: 40, color: textColor.withValues(alpha: 0.1)),
          _buildStatItem(
            _ratingStats != null && _ratingStats!.overallStars > 0
                ? '${_ratingStats!.overallStars.toStringAsFixed(1)}★'
                : LanguageService.tr('no_ratings_short'),
            _ratingStats != null && _ratingStats!.totalRatings > 0
                ? '${LanguageService.tr('rating')} (${_ratingStats!.totalRatings})'
                : LanguageService.tr('public_rating'),
            textColor,
          ),
          Container(width: 1, height: 40, color: textColor.withValues(alpha: 0.1)),
          _buildStatItem(
            _detail!.totalCases.toString(),
            _detail!.totalCases == 1 ? LanguageService.tr('case_singular') : LanguageService.tr('cases_plural'),
            textColor,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, Color textColor) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.6)),
        ),
      ],
    );
  }

  Widget _buildBadge(Color textColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_outlined, color: Colors.red, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LanguageService.tr('has_criminal_cases'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_detail!.totalCases} ${LanguageService.tr('criminal_cases_record')}',
                  style: TextStyle(
                    fontSize: 13,
                    color: textColor.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSections(Color textColor, Color cardColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            LanguageService.tr('details'),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 20),
          // Position
          _buildSectionItem(
            Icons.location_city_outlined,
            LanguageService.tr('current_position'),
            '${LanguageService.translitName(_detail!.officeType.replaceAll('_', ' '))}\n${LanguageService.translitName(_detail!.state)} • ${LanguageService.translitName(_detail!.party)}',
            textColor,
          ),
          const SizedBox(height: 20),
          // Education
          if (_detail!.education != null)
            _buildSectionItem(
              Icons.school_outlined,
              LanguageService.tr('education_label'),
              _detail!.education!,
              textColor,
            ),
          if (_detail!.education != null) const SizedBox(height: 20),
          // Financial
          if (_detail!.assets != null || _detail!.liabilities != null)
            _buildSectionItem(
              Icons.account_balance_wallet_outlined,
              LanguageService.tr('financial_details'),
              _buildFinancialText(),
              textColor,
            ),
          if (_detail!.assets != null || _detail!.liabilities != null)
            const SizedBox(height: 20),
          // Profession
          if (_detail!.selfProfession != null)
            _buildSectionItem(
              Icons.work_outline,
              LanguageService.tr('profession'),
              _detail!.selfProfession! +
                  (_detail!.spouseProfession != null
                      ? '\n${LanguageService.tr('spouse_label')}: ${_detail!.spouseProfession!}'
                      : ''),
              textColor,
            ),
          if (_detail!.selfProfession != null) const SizedBox(height: 20),
          // ITR
          if (_detail!.selfItr != null || _detail!.spouseItr != null)
            _buildSectionItem(
              Icons.receipt_long_outlined,
              LanguageService.tr('income_tax_returns'),
              _buildITRText(),
              textColor,
            ),
          if (_detail!.selfItr != null || _detail!.spouseItr != null)
            const SizedBox(height: 20),
          // Criminal Cases
          if (_detail!.totalCases > 0) _buildCriminalCasesSection(textColor),
        ],
      ),
    );
  }

  Widget _buildSectionItem(
    IconData icon,
    String title,
    String description,
    Color textColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.isDarkMode
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 24, color: textColor.withValues(alpha: 0.7)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: textColor.withValues(alpha: 0.7),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _buildFinancialText() {
    List<String> parts = [];
    if (_detail!.assets != null) {
      parts.add('${LanguageService.tr('assets_label')}: ${_formatCurrency(_detail!.assets!)}');
    }
    if (_detail!.liabilities != null) {
      parts.add('${LanguageService.tr('liabilities_label')}: ${_formatCurrency(_detail!.liabilities!)}');
    }
    if (_detail!.netWorth != null) {
      parts.add('${LanguageService.tr('net_worth_label')}: ${_formatCurrency(_detail!.netWorth!)}');
    }
    return parts.join('\n');
  }

  String _buildITRText() {
    List<String> parts = [];
    if (_detail!.selfItr != null && _detail!.selfItr!.isNotEmpty) {
      parts.add('${LanguageService.tr('self_itr')}:');
      _detail!.selfItr!.forEach((year, amount) {
        parts.add('  $year: ${_formatCurrency(amount)}');
      });
    }
    if (_detail!.spouseItr != null && _detail!.spouseItr!.isNotEmpty) {
      if (parts.isNotEmpty) parts.add('');
      parts.add('${LanguageService.tr('spouse_itr')}:');
      _detail!.spouseItr!.forEach((year, amount) {
        parts.add('  $year: ${_formatCurrency(amount)}');
      });
    }
    return parts.join('\n');
  }

  Widget _buildCriminalCasesSection(Color textColor) {
    final allCases = [...?_detail!.ipcCases, ...?_detail!.bnsCases];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.gavel, size: 24, color: Colors.red),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        LanguageService.tr('criminal_cases'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${allCases.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...allCases.map(
                    (caseDetail) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '• ',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              caseDetail,
                              style: TextStyle(
                                fontSize: 14,
                                color: textColor.withValues(alpha: 0.7),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatCurrency(int amount) {
    return Formatters.formatCurrency(amount);
  }

  Widget _buildRatingButton(Color textColor, Color cardColor) {
    if (_loadingRating) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: textColor.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showRatingForm,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _userRating != null
                    ? Colors.amber.withValues(alpha: 0.5)
                    : textColor.withValues(alpha: 0.1),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.star, color: Colors.amber, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userRating != null
                            ? LanguageService.tr('your_rating')
                            : LanguageService.tr('rate_this_rep'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (_userRating != null)
                        Row(
                          children: [
                            ...List.generate(5, (index) {
                              return Icon(
                                index < _userRating!.overallStars.round()
                                    ? Icons.star
                                    : Icons.star_border,
                                color: Colors.amber,
                                size: 16,
                              );
                            }),
                            const SizedBox(width: 8),
                            Text(
                              '${_userRating!.overallScore}/100',
                              style: TextStyle(
                                fontSize: 12,
                                color: textColor.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          _isAuthenticated
                              ? LanguageService.tr('share_experience')
                              : LanguageService.tr('sign_in_to_rate_short'),
                          style: TextStyle(
                            fontSize: 12,
                            color: textColor.withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  _userRating != null ? Icons.edit : Icons.arrow_forward_ios,
                  color: textColor.withValues(alpha: 0.4),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRatingsSection(Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            LanguageService.tr('public_ratings'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: RatingsDisplayWidget(
            key: ValueKey(_ratingsRefreshKey),
            representativeId: int.parse(widget.representativeId),
            isDarkMode: widget.isDarkMode,
          ),
        ),
      ],
    );
  }
}
