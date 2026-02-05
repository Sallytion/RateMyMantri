import 'package:flutter/material.dart';
import '../models/representative_detail.dart';
import '../models/rating.dart';
import '../models/rating_statistics.dart';
import '../services/representative_service.dart';
import '../services/ratings_service.dart';
import '../services/auth_storage_service.dart';
import '../widgets/rating_form_widget.dart';
import '../widgets/ratings_display_widget.dart';

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
      print('Error checking auth/rating: $e');
      if (mounted) {
        setState(() => _loadingRating = false);
      }
    }
  }

  Future<void> _loadRatingStatistics() async {
    try {
      final stats = await _ratingsService.getRatingStatistics(
        int.parse(widget.representativeId),
      );
      if (mounted) {
        setState(() => _ratingStats = stats);
      }
    } catch (e) {
      print('Error loading rating statistics: $e');
    }
  }

  void _showRatingForm() {
    if (!_isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to rate this representative'),
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
    final bgColor = widget.isDarkMode ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = widget.isDarkMode
        ? Colors.white
        : const Color(0xFF222222);
    final cardColor = widget.isDarkMode
        ? const Color(0xFF2A2A2A)
        : const Color(0xFFF9F9F9);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _detail?.name ?? '',
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: Colors.deepPurple))
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
                    'Failed to load details',
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
            child: ClipOval(
              child: _detail!.imageUrl != null
                  ? Image.network(
                      _detail!.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildPlaceholderAvatar();
                      },
                    )
                  : _buildPlaceholderAvatar(),
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
            '${_detail!.officeType.replaceAll('_', ' ')} • ${_detail!.constituency}',
            style: TextStyle(fontSize: 14, color: textColor.withValues(alpha: 0.6)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderAvatar() {
    return Container(
      color: Colors.grey[300],
      child: Icon(Icons.person, size: 70, color: Colors.grey[600]),
    );
  }

  Widget _buildStats(Color textColor, Color cardColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem(
            _detail!.assets != null ? _formatCurrency(_detail!.assets!) : 'N/A',
            'Total Assets',
            textColor,
          ),
          Container(width: 1, height: 40, color: textColor.withValues(alpha: 0.1)),
          _buildStatItem(
            _ratingStats != null && _ratingStats!.overallStars > 0
                ? '${_ratingStats!.overallStars.toStringAsFixed(1)}★'
                : 'No ratings',
            _ratingStats != null && _ratingStats!.totalRatings > 0
                ? 'Rating (${_ratingStats!.totalRatings})'
                : 'Public Rating',
            textColor,
          ),
          Container(width: 1, height: 40, color: textColor.withValues(alpha: 0.1)),
          _buildStatItem(
            _detail!.totalCases.toString(),
            _detail!.totalCases == 1 ? 'Case' : 'Cases',
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
                  'Has Criminal Cases',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_detail!.totalCases} criminal case${_detail!.totalCases > 1 ? 's' : ''} on record',
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
            'Details',
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
            'Current Position',
            '${_detail!.officeType.replaceAll('_', ' ')}\n${_detail!.state} • ${_detail!.party}',
            textColor,
          ),
          const SizedBox(height: 20),
          // Education
          if (_detail!.education != null)
            _buildSectionItem(
              Icons.school_outlined,
              'Education',
              _detail!.education!,
              textColor,
            ),
          if (_detail!.education != null) const SizedBox(height: 20),
          // Financial
          if (_detail!.assets != null || _detail!.liabilities != null)
            _buildSectionItem(
              Icons.account_balance_wallet_outlined,
              'Financial Details',
              _buildFinancialText(),
              textColor,
            ),
          if (_detail!.assets != null || _detail!.liabilities != null)
            const SizedBox(height: 20),
          // Profession
          if (_detail!.selfProfession != null)
            _buildSectionItem(
              Icons.work_outline,
              'Profession',
              _detail!.selfProfession! +
                  (_detail!.spouseProfession != null
                      ? '\nSpouse: ${_detail!.spouseProfession}'
                      : ''),
              textColor,
            ),
          if (_detail!.selfProfession != null) const SizedBox(height: 20),
          // ITR
          if (_detail!.selfItr != null || _detail!.spouseItr != null)
            _buildSectionItem(
              Icons.receipt_long_outlined,
              'Income Tax Returns',
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
      parts.add('Assets: ${_formatCurrency(_detail!.assets!)}');
    }
    if (_detail!.liabilities != null) {
      parts.add('Liabilities: ${_formatCurrency(_detail!.liabilities!)}');
    }
    if (_detail!.netWorth != null) {
      parts.add('Net Worth: ${_formatCurrency(_detail!.netWorth!)}');
    }
    return parts.join('\n');
  }

  String _buildITRText() {
    List<String> parts = [];
    if (_detail!.selfItr != null && _detail!.selfItr!.isNotEmpty) {
      parts.add('Self ITR:');
      _detail!.selfItr!.forEach((year, amount) {
        parts.add('  $year: ${_formatCurrency(amount)}');
      });
    }
    if (_detail!.spouseItr != null && _detail!.spouseItr!.isNotEmpty) {
      if (parts.isNotEmpty) parts.add('');
      parts.add('Spouse ITR:');
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
                        'Criminal Cases',
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
    if (amount >= 10000000) {
      return '₹${(amount / 10000000).toStringAsFixed(1)} Cr';
    } else if (amount >= 100000) {
      return '₹${(amount / 100000).toStringAsFixed(1)} L';
    } else if (amount >= 1000) {
      return '₹${(amount / 1000).toStringAsFixed(0)} K';
    } else {
      return '₹$amount';
    }
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
                            ? 'Your Rating'
                            : 'Rate This Representative',
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
                              ? 'Share your experience'
                              : 'Sign in to rate',
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
            'Public Ratings',
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
