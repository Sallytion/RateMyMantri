import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart' as xml;
import 'package:intl/intl.dart';
import 'package:ip_detector/ip_detector.dart';
import '../models/constituency.dart';
import '../models/representative.dart';
import '../services/constituency_service.dart';
import '../services/representative_service.dart';
import '../services/google_news_decoder.dart';
import '../services/article_extractor.dart';
import 'constituency_search_page.dart';
import 'representative_detail_page.dart';
import 'article_viewer_page.dart';

class _HomeArticle {
  final String title;
  final String link;
  final String source;
  final String pubDate;
  String? decodedUrl;
  String? articleText;
  String? imageUrl;

  _HomeArticle({
    required this.title,
    required this.link,
    required this.source,
    required this.pubDate,
    this.decodedUrl,
    this.articleText,
    this.imageUrl,
  });
}

class HomePage extends StatefulWidget {
  final bool isDarkMode;
  final void Function(int)? onNavigateToTab;

  const HomePage({super.key, required this.isDarkMode, this.onNavigateToTab});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ConstituencyService _constituencyService = ConstituencyService();
  final RepresentativeService _representativeService = RepresentativeService();
  final GoogleNewsDecoder _newsDecoder = GoogleNewsDecoder();
  final ArticleExtractor _articleExtractor = ArticleExtractor();

  // ─── Static in-memory cache (survives widget rebuilds) ─────────
  static Constituency? _cachedConstituency;
  static List<Representative>? _cachedRepresentatives;
  static String? _cachedRepConstituencyName; // key for rep cache
  static List<_HomeArticle>? _cachedNewsArticles;
  static bool _newsFetchedThisSession = false;

  /// Call this to force-clear all cached data (e.g. on logout).
  static void clearCache() {
    _cachedConstituency = null;
    _cachedRepresentatives = null;
    _cachedRepConstituencyName = null;
    _cachedNewsArticles = null;
    _newsFetchedThisSession = false;
  }

  Constituency? _currentConstituency;
  bool _isLoadingConstituency = true;

  // Representatives
  List<Representative> _representatives = [];
  bool _isLoadingRepresentatives = true;
  final PageController _repPageController = PageController(viewportFraction: 1.0);
  int _currentRepIndex = 0;

  // News
  List<_HomeArticle> _newsArticles = [];
  bool _isLoadingNews = true;

  @override
  void initState() {
    super.initState();

    // Pre-populate from cache synchronously to avoid loading spinners
    if (_cachedConstituency != null) {
      _currentConstituency = _cachedConstituency;
      _isLoadingConstituency = false;
    }
    if (_cachedRepresentatives != null) {
      _representatives = _cachedRepresentatives!;
      _isLoadingRepresentatives = false;
    }
    if (_newsFetchedThisSession && _cachedNewsArticles != null) {
      _newsArticles = _cachedNewsArticles!;
      _isLoadingNews = false;
    }

    _loadCurrentConstituency();
    _loadLocalNews();
  }

  @override
  void dispose() {
    _repPageController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentConstituency() async {
    final constituency = await _constituencyService.getCurrentConstituency();
    if (!mounted) return;

    setState(() {
      _currentConstituency = constituency;
      _isLoadingConstituency = false;
    });

    if (constituency == null) {
      setState(() => _isLoadingRepresentatives = false);
      return;
    }

    // If the constituency hasn't changed and we already have cached reps, reuse them
    if (_cachedConstituency?.name == constituency.name &&
        _cachedRepresentatives != null) {
      setState(() {
        _representatives = _cachedRepresentatives!;
        _isLoadingRepresentatives = false;
      });
    } else {
      _loadRepresentatives(constituency.name);
    }

    _cachedConstituency = constituency;
  }

  Future<void> _loadRepresentatives(String location) async {
    setState(() => _isLoadingRepresentatives = true);
    final result = await _representativeService.getMyRepresentatives(location);
    if (mounted) {
      final reps = result['representatives'] as List<Representative>? ?? [];
      _cachedRepresentatives = reps;
      _cachedRepConstituencyName = location;
      setState(() {
        _representatives = reps;
        _isLoadingRepresentatives = false;
      });
    }
  }

  Future<Map<String, String>?> _getCityFromIp({int ttlSeconds = 86400}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ts = prefs.getInt('geo_ts') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (now - ts < ttlSeconds) {
        final city = prefs.getString('geo_city');
        final country = prefs.getString('geo_country');
        if (city != null && country != null) {
          return {'city': city, 'country': country};
        }
      }

      final ipDetector = IpDetector(timeout: const Duration(seconds: 10));
      final response = await ipDetector.fetch(enableLog: false);

      if (response.type == IpDetectorResponseType.succeedResponse) {
        final city = ipDetector.city()?.trim();
        final country = ipDetector.countryCode()?.trim();

        if (city != null && city.isNotEmpty && country != null && country.isNotEmpty) {
          await prefs.setString('geo_city', city);
          await prefs.setString('geo_country', country);
          await prefs.setInt('geo_ts', now);
          return {'city': city, 'country': country};
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadLocalNews() async {
    // If news was already fetched this session, use the cache
    if (_newsFetchedThisSession && _cachedNewsArticles != null) {
      setState(() {
        _newsArticles = _cachedNewsArticles!;
        _isLoadingNews = false;
      });
      return;
    }

    setState(() => _isLoadingNews = true);
    try {
      final loc = await _getCityFromIp();
      String url;
      if (loc != null) {
        final city = Uri.encodeComponent(loc['city']!);
        final countryCode = loc['country']!;
        final hl = countryCode == 'IN' ? 'en-IN' : 'en-US';
        url = 'https://news.google.com/rss/search?q=$city&hl=$hl&gl=$countryCode&ceid=$countryCode:en';
      } else {
        url = 'https://news.google.com/rss?hl=en-IN&gl=IN&ceid=IN:en';
      }

      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');

      final doc = xml.XmlDocument.parse(res.body);
      final items = doc.findAllElements('item').take(3);

      final List<_HomeArticle> parsed = [];
      for (var item in items) {
        final titleElem = item.findElements('title').first;
        final linkElem = item.findElements('link').first;
        final sourceElem = item.findElements('source');
        final pubDateElem = item.findElements('pubDate');

        parsed.add(_HomeArticle(
          title: titleElem.innerText,
          link: linkElem.innerText,
          source: sourceElem.isNotEmpty ? sourceElem.first.innerText : '',
          pubDate: pubDateElem.isNotEmpty ? pubDateElem.first.innerText : '',
        ));
      }

      if (mounted) {
        _cachedNewsArticles = parsed;
        _newsFetchedThisSession = true;
        setState(() {
          _newsArticles = parsed;
          _isLoadingNews = false;
        });
      }

      // Process images in background
      for (int i = 0; i < parsed.length; i++) {
        _processArticleImage(i);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingNews = false);
      }
    }
  }

  Future<void> _processArticleImage(int index) async {
    if (index >= _newsArticles.length) return;
    final article = _newsArticles[index];
    String? decodedUrl;

    try {
      final result = await _newsDecoder.decodeGoogleNewsUrl(article.link);
      if (result['status'] == true && result['decoded_url'] != null) {
        decodedUrl = result['decoded_url'] as String;
        article.decodedUrl = decodedUrl;
      }
    } catch (_) {}

    if (decodedUrl != null && !decodedUrl.contains('news.google.com')) {
      try {
        final extracted = await _articleExtractor.extractArticle(
          decodedUrl,
          articleIndex: index,
        );
        if (extracted['imageUrl'] != null && extracted['imageUrl']!.isNotEmpty) {
          article.imageUrl = extracted['imageUrl'];
        }
        if (extracted['content'] != null) {
          article.articleText = extracted['content'];
        }
      } catch (_) {}
    }

    if (mounted) setState(() {});
  }

  String _formatDate(String pubDate) {
    try {
      final date = DateFormat('EEE, dd MMM yyyy HH:mm:ss zzz').parseUtc(pubDate);
      final now = DateTime.now().toUtc();
      final diff = now.difference(date);

      if (diff.inDays == 0) {
        if (diff.inHours == 0) return '${diff.inMinutes}m ago';
        return '${diff.inHours}h ago';
      } else if (diff.inDays < 7) {
        return '${diff.inDays}d ago';
      } else {
        final ist = date.add(const Duration(hours: 5, minutes: 30));
        return '${ist.day}/${ist.month}/${ist.year}';
      }
    } catch (_) {
      return pubDate;
    }
  }

  Future<void> _navigateToConstituencySearch() async {
    final result = await Navigator.push<Constituency>(
      context,
      MaterialPageRoute(
        builder: (context) => ConstituencySearchPage(
          isDarkMode: widget.isDarkMode,
          currentConstituency: _currentConstituency,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _currentConstituency = result;
      });
      _cachedConstituency = result;
      // Constituency changed — invalidate representative cache and refetch
      _cachedRepresentatives = null;
      _cachedRepConstituencyName = null;
      _loadRepresentatives(result.name);
    }
  }

  String _getOfficeLabel(String officeType) {
    switch (officeType) {
      case 'LOK_SABHA':
        return 'Member of Parliament';
      case 'STATE_ASSEMBLY':
        return 'MLA';
      case 'RAJYA_SABHA':
        return 'Rajya Sabha MP';
      case 'VIDHAN_PARISHAD':
        return 'MLC';
      default:
        return officeType;
    }
  }

  Color _getPartyColor(String party) {
    switch (party.toUpperCase()) {
      case 'BJP':
        return const Color(0xFFFF9933);
      case 'INC':
        return const Color(0xFF19AAED);
      case 'AAP':
        return const Color(0xFF0066B3);
      case 'TMC':
        return const Color(0xFF00A651);
      case 'DMK':
        return const Color(0xFFE71C23);
      case 'SP':
        return const Color(0xFFE40612);
      case 'BSP':
        return const Color(0xFF22409A);
      default:
        return const Color(0xFF5A5A5A);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isDarkMode
          ? const Color(0xFF1A1A1A)
          : const Color(0xFFF7F7F7),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Rate My Mantri',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: widget.isDarkMode
                            ? Colors.white
                            : const Color(0xFF222222),
                      ),
                    ),
                    InkWell(
                      onTap: _navigateToConstituencySearch,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: widget.isDarkMode
                              ? const Color(0xFF2A2A2A)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: widget.isDarkMode
                                ? const Color(0xFF3A3A3A)
                                : const Color(0xFFDDDDDD),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 16,
                              color: widget.isDarkMode
                                  ? Colors.white
                                  : const Color(0xFF222222),
                            ),
                            const SizedBox(width: 4),
                            _isLoadingConstituency
                                ? SizedBox(
                                    width: 80,
                                    height: 14,
                                    child: Center(
                                      child: SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.deepPurple,
                                        ),
                                      ),
                                    ),
                                  )
                                : Text(
                                    _currentConstituency?.name ??
                                        'Set Location',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: widget.isDarkMode
                                          ? Colors.white
                                          : const Color(0xFF222222),
                                    ),
                                  ),
                            const SizedBox(width: 4),
                            const Icon(Icons.keyboard_arrow_down, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Representatives Hero Cards (Swipable)
              _buildRepresentativesSection(),

              const SizedBox(height: 24),

              // Local News Section
              _buildNewsSection(),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Representatives Swipable Cards ────────────────────────────

  Widget _buildRepresentativesSection() {
    if (_isLoadingRepresentatives) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Container(
          height: 220,
          decoration: BoxDecoration(
            color: widget.isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: Colors.deepPurple),
          ),
        ),
      );
    }

    if (_representatives.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Container(
          height: 160,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF5A5A5A), Color(0xFF3A3A3A)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_off, color: Colors.white54, size: 40),
                const SizedBox(height: 12),
                Text(
                  _currentConstituency == null
                      ? 'Set your constituency to see representatives'
                      : 'No representatives found',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                if (_currentConstituency == null) ...[
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _navigateToConstituencySearch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7A59),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Set Location'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 240,
          child: PageView.builder(
            controller: _repPageController,
            itemCount: _representatives.length,
            onPageChanged: (index) {
              setState(() => _currentRepIndex = index);
            },
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildRepresentativeCard(_representatives[index]),
              );
            },
          ),
        ),
        if (_representatives.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _representatives.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 8,
                width: _currentRepIndex == index ? 24 : 8,
                decoration: BoxDecoration(
                  color: _currentRepIndex == index
                      ? const Color(0xFFFF7A59)
                      : (widget.isDarkMode
                          ? const Color(0xFF4A4A4A)
                          : const Color(0xFFDDDDDD)),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRepresentativeCard(Representative rep) {
    final partyColor = _getPartyColor(rep.party);
    final officeLabel = _getOfficeLabel(rep.officeType);
    final rating = rep.averageRating;
    final fullStars = rating != null ? rating.floor() : 0;
    final hasHalfStar = rating != null && (rating - fullStars) >= 0.25;
    final emptyStars = 5 - fullStars - (hasHalfStar ? 1 : 0);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            partyColor.withValues(alpha: 0.9),
            partyColor.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: partyColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Profile image on right
          if (rep.imageUrl != null && rep.imageUrl!.isNotEmpty)
            Positioned(
              right: 0,
              bottom: 0,
              top: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                child: ShaderMask(
                  shaderCallback: (rect) => LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [
                      Colors.white.withValues(alpha: 0.3),
                      Colors.transparent,
                    ],
                  ).createShader(rect),
                  blendMode: BlendMode.dstIn,
                  child: Image.network(
                    rep.imageUrl!,
                    width: 160,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 160,
                      color: partyColor.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
            ),
          // Content
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Party badge + Office type
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        rep.party,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      officeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Name
                Text(
                  _formatRepName(rep.fullName),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                // Constituency
                Text(
                  '${rep.constituency}, ${rep.state}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 12),
                // Rating
                Row(
                  children: [
                    Text(
                      rating != null ? rating.toStringAsFixed(1) : 'N/A',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (rating != null) ...[
                      ...List.generate(fullStars, (_) => const Icon(Icons.star, color: Colors.amber, size: 18)),
                      if (hasHalfStar) const Icon(Icons.star_half, color: Colors.amber, size: 18),
                      ...List.generate(emptyStars, (_) => const Icon(Icons.star_border, color: Colors.amber, size: 18)),
                      const SizedBox(width: 6),
                      Text(
                        '(${rep.totalRatings ?? 0})',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ] else ...[
                      Text(
                        'Not yet rated',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                // Buttons
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RepresentativeDetailPage(
                              representativeId: rep.id.toString(),
                              isDarkMode: widget.isDarkMode,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: partyColor,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Rate Performance',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatRepName(String name) {
    // Convert "ALL CAPS NAME" to "Title Case"
    return name.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  // ─── News Section ──────────────────────────────────────────────

  Widget _buildNewsSection() {
    return Column(
      children: [
        // Section header with arrow
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Local News',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: widget.isDarkMode
                      ? Colors.white
                      : const Color(0xFF222222),
                ),
              ),
              GestureDetector(
                onTap: () {
                  // Navigate to News tab (index 3)
                  widget.onNavigateToTab?.call(3);
                },
                child: Row(
                  children: [
                    Text(
                      'See all',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFFF7A59),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward,
                      size: 18,
                      color: Color(0xFFFF7A59),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_isLoadingNews)
          SizedBox(
            height: 120,
            child: Center(
              child: CircularProgressIndicator(color: Colors.deepPurple),
            ),
          )
        else if (_newsArticles.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: widget.isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'No news available',
                  style: TextStyle(
                    color: widget.isDarkMode ? Colors.white54 : Colors.grey,
                  ),
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: _newsArticles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _buildNewsListTile(_newsArticles[index], index);
            },
          ),
      ],
    );
  }

  Widget _buildNewsListTile(_HomeArticle article, int index) {
    return GestureDetector(
      onTap: () {
        final url = article.decodedUrl ?? article.link;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArticleViewerPage(
              title: article.title,
              imageUrl: article.imageUrl ?? '',
              articleText: article.articleText,
              source: article.source,
              pubDate: article.pubDate,
              originalUrl: url,
              isDarkMode: widget.isDarkMode,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: widget.isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: widget.isDarkMode ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: SizedBox(
                width: 100,
                height: 100,
                child: article.imageUrl != null
                    ? Image.network(
                        article.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFE0E0E0),
                          child: const Icon(Icons.article, color: Color(0xFFBDBDBD), size: 32),
                        ),
                      )
                    : Container(
                        color: widget.isDarkMode ? const Color(0xFF3A3A3A) : const Color(0xFFE0E0E0),
                        child: const Icon(Icons.article, color: Color(0xFFBDBDBD), size: 32),
                      ),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (article.source.isNotEmpty)
                      Text(
                        article.source,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFFF7A59),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      article.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: widget.isDarkMode
                            ? Colors.white
                            : const Color(0xFF222222),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatDate(article.pubDate),
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.isDarkMode
                            ? const Color(0xFF717171)
                            : const Color(0xFF999999),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                Icons.chevron_right,
                size: 20,
                color: widget.isDarkMode ? Colors.white38 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
