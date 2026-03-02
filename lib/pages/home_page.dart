import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:xml/xml.dart' as xml;
import 'package:url_launcher/url_launcher.dart';
import '../utils/formatters.dart';
import '../utils/location_service.dart';
import '../utils/party_utils.dart';
import '../models/constituency.dart';
import '../models/home_section.dart';
import '../models/representative.dart';
import '../services/theme_service.dart';
import '../services/language_service.dart';
import '../services/constituency_service.dart';
import '../services/constituency_notifier.dart';
import '../services/representative_service.dart';
import '../services/google_news_decoder.dart';
import '../services/article_extractor.dart';
import '../services/home_sections_service.dart';
import 'constituency_search_page.dart';
import 'representative_detail_page.dart';
import 'article_viewer_page.dart';
import 'webview_page.dart';
import '../widgets/skeleton_widgets.dart';

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
  });
}

class HomePage extends StatefulWidget {
  final void Function(int)? onNavigateToTab;

  const HomePage({super.key, this.onNavigateToTab});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ConstituencyService _constituencyService = ConstituencyService();
  final RepresentativeService _representativeService = RepresentativeService();
  final GoogleNewsDecoder _newsDecoder = GoogleNewsDecoder();
  final ArticleExtractor _articleExtractor = ArticleExtractor();

  /// Reads the current dark-mode flag from the provider.
  /// build() calls context.watch to subscribe; helpers use this getter.
  bool get isDarkMode => context.read<ThemeProvider>().isDarkMode;

  // â”€â”€â”€ Static in-memory cache (survives widget rebuilds) â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static Constituency? _cachedConstituency;
  static List<Representative>? _cachedRepresentatives;
  static List<_HomeArticle>? _cachedNewsArticles;
  static bool _newsFetchedThisSession = false;

  // Home sections (API-driven)
  List<HomeSection> _homeSections = [];
  bool _isLoadingSections = true;

  Constituency? _currentConstituency;
  bool _isLoadingConstituency = true;

  // Representatives
  List<Representative> _representatives = [];
  bool _isLoadingRepresentatives = true;
  final PageController _repPageController = PageController(viewportFraction: 1.0);
  final ScrollController _dotScrollController = ScrollController();
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

    _loadCurrentConstituency().then((_) => _loadLocalNews());
    _loadHomeSections();

    // Listen for constituency changes made on the Profile page
    ConstituencyNotifier.instance.notifier.addListener(_onConstituencyNotified);
  }

  void _onConstituencyNotified() {
    final c = ConstituencyNotifier.instance.current;
    if (c == null || c.id == _currentConstituency?.id) return;
    // We already have the full Constituency object â€” apply immediately,
    // no API round-trip needed.
    _cachedConstituency = c;
    _cachedRepresentatives = null;
    // Constituency changed â€” also invalidate news cache so we fetch for new area
    _cachedNewsArticles = null;
    _newsFetchedThisSession = false;
    setState(() {
      _currentConstituency = c;
      _isLoadingConstituency = false;
      _isLoadingRepresentatives = true;
    });
    _loadRepresentatives(c.nameEn);
    _loadLocalNews();
  }

  @override
  void dispose() {
    ConstituencyNotifier.instance.notifier.removeListener(_onConstituencyNotified);
    _repPageController.dispose();
    _dotScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentConstituency() async {
    final constituency = await _constituencyService.getCurrentConstituency();
    if (!mounted) return;

    // Determine all state changes before calling setState once
    List<Representative>? repsToUse;
    bool shouldLoadReps = false;

    if (constituency != null &&
        _cachedConstituency?.id == constituency.id &&
        _cachedRepresentatives != null) {
      repsToUse = _cachedRepresentatives!;
    } else if (constituency != null) {
      shouldLoadReps = true;
    }

    setState(() {
      _currentConstituency = constituency;
      _isLoadingConstituency = false;
      if (constituency == null) {
        _isLoadingRepresentatives = false;
      } else if (repsToUse != null) {
        _representatives = repsToUse;
        _isLoadingRepresentatives = false;
      }
    });

    _cachedConstituency = constituency;

    // Populate the global notifier so other pages (e.g. NewsPage) can read it
    if (constituency != null &&
        ConstituencyNotifier.instance.current?.id != constituency.id) {
      ConstituencyNotifier.instance.set(constituency);
    }

    if (shouldLoadReps) {
      _loadRepresentatives(constituency!.nameEn);
    }
  }

  Future<void> _loadRepresentatives(String location) async {
    setState(() => _isLoadingRepresentatives = true);
    final result = await _representativeService.getMyRepresentatives(location);
    if (mounted) {
      final reps = result['representatives'] as List<Representative>? ?? [];
      _cachedRepresentatives = reps;
      setState(() {
        _representatives = reps;
        _isLoadingRepresentatives = false;
      });
    }
  }

  Future<Map<String, String>?> _getCityFromIp({int ttlSeconds = 86400}) async {
    return LocationService.instance.getCityFromIp(ttlSeconds: ttlSeconds);
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
      String url;

      // Primary: use the set constituency name for local news
      final constituency = _currentConstituency ?? _cachedConstituency;
      if (constituency != null) {
        final query = Uri.encodeComponent(constituency.nameEn);
        url = 'https://news.google.com/rss/search?q=$query&${LanguageService.newsGlParams}';
      } else {
        // Fallback: use IP-based city detection
        final loc = await _getCityFromIp();
        if (loc != null) {
          final city = Uri.encodeComponent(loc['city']!);
          final countryCode = loc['country']!;
          final params = countryCode == 'IN'
              ? LanguageService.newsGlParams
              : 'hl=en-US&gl=$countryCode&ceid=$countryCode:en';
          url = 'https://news.google.com/rss/search?q=$city&$params';
        } else {
          url = 'https://news.google.com/rss?${LanguageService.newsGlParams}';
        }
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

      // Process all images in parallel, then rebuild once
      _processAllArticleImages(parsed.length);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingNews = false);
      }
    }
  }

  /// Process all article images in parallel, then trigger a single rebuild.
  Future<void> _processAllArticleImages(int count) async {
    await Future.wait(
      List.generate(count, (i) => _processArticleImage(i)),
    );
    if (mounted) setState(() {});
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
  }

  String _formatDate(String pubDate) {
    return Formatters.formatPubDate(pubDate);
  }

  Future<void> _navigateToConstituencySearch() async {
    final result = await Navigator.push<Constituency>(
      context,
      MaterialPageRoute(
        builder: (context) => ConstituencySearchPage(
          isDarkMode: isDarkMode,
          currentConstituency: _currentConstituency,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _currentConstituency = result;
      });
      _cachedConstituency = result;
      // Constituency changed â€” invalidate representative cache and refetch
      _cachedRepresentatives = null;
      _loadRepresentatives(result.nameEn);
      // Constituency changed â€” also invalidate news cache and refetch
      _cachedNewsArticles = null;
      _newsFetchedThisSession = false;
      _loadLocalNews();
      // Notify ProfilePage (and any other listeners) of the change
      ConstituencyNotifier.instance.set(result);
    }
  }

  String _getOfficeLabel(String officeType) {
    return PartyUtils.getOfficeLabel(officeType);
  }

  Color _getPartyColor(String party) {
    return PartyUtils.getPartyColor(party);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<ThemeProvider>().isDarkMode;
    return Scaffold(
      backgroundColor: isDarkMode
          ? ThemeService.bgMain
          : const Color(0xFFF7F7F7),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Top Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      LanguageService.tr('home'),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode
                            ? Colors.white
                            : const Color(0xFF222222),
                        letterSpacing: -0.3,
                      ),
                    ),
                    GestureDetector(
                      onTap: _navigateToConstituencySearch,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? ThemeService.bgElev
                              : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 15,
                              color: isDarkMode
                                  ? const Color(0xFFB0B0B0)
                                  : const Color(0xFF717171),
                            ),
                            const SizedBox(width: 4),
                            _isLoadingConstituency
                                ? SkeletonShimmer(
                                    isDarkMode: isDarkMode,
                                    child: SkeletonBox(
                                      width: 70,
                                      height: 13,
                                      borderRadius: 4,
                                    ),
                                  )
                                : Text(
                                    _currentConstituency != null
                                        ? _currentConstituency!.name
                                        : LanguageService.tr('set_location'),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: isDarkMode
                                          ? const Color(0xFFB0B0B0)
                                          : const Color(0xFF717171),
                                    ),
                                  ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.keyboard_arrow_down,
                              size: 16,
                              color: isDarkMode
                                  ? const Color(0xFFB0B0B0)
                                  : const Color(0xFF717171),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Representatives Hero Cards (Swipable)
            SliverToBoxAdapter(child: _buildRepresentativesSection()),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Local News Section (returns List<Widget> of slivers)
            ..._buildNewsSlivers(),

            // API-driven banner sections (Noticeboard, Games, â€¦)
            ..._buildApiSections(),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  // â”€â”€â”€ Representatives Swipable Cards â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildRepresentativesSection() {
    if (_isLoadingRepresentatives) {
      return RepresentativeListSkeleton(isDarkMode: isDarkMode);
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
                      ? LanguageService.tr('set_constituency')
                      : LanguageService.tr('no_reps_found'),
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
                    child: Text(LanguageService.tr('set_location')),
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
              _scrollDotsToActive(index);
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
          _buildRepDots(),
        ],
      ],
    );
  }

  /// Smoothly scrolls the dot strip to keep the active dot centered.
  void _scrollDotsToActive(int index) {
    if (!_dotScrollController.hasClients) return;
    // Each dot slot is 16px wide (8px dot + 4px margin each side).
    const double slotW = 16.0;
    const double visibleW = 7 * slotW; // 112px viewport
    final double target = (index * slotW) - (visibleW / 2) + (slotW / 2);
    final double maxScroll = _dotScrollController.position.maxScrollExtent;
    _dotScrollController.animateTo(
      target.clamp(0.0, maxScroll),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Dot indicator: renders ALL dots in a clipped scrollable row.
  /// The strip scrolls (via [_dotScrollController]) so the active dot
  /// is always centered â€” giving a true sliding animation.
  Widget _buildRepDots() {
    final int total = _representatives.length;
    if (total <= 1) return const SizedBox.shrink();

    // Fixed layout slot per dot so scroll math is exact.
    const double slotW = 16.0;   // 8px dot + 4px margin each side
    const double dotH  = 8.0;
    const double activeDotW   = 24.0;
    const double inactiveDotW = 8.0;
    const int    maxVisible   = 7;
    const double viewportW    = maxVisible * slotW; // 112px

    Widget buildDot(int i) {
      final bool isActive = i == _currentRepIndex;
      return SizedBox(
        width: slotW,
        height: dotH,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: dotH,
            width: isActive ? activeDotW : inactiveDotW,
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFFFF7A59)
                  : (isDarkMode
                      ? const Color(0xFF4A4A4A)
                      : const Color(0xFFDDDDDD)),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      );
    }

    // â‰¤ 7 reps: just a plain row, no scrolling needed.
    if (total <= maxVisible) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(total, buildDot),
      );
    }

    // > 7 reps: clipped scrollable strip.
    return SizedBox(
      width: viewportW,
      height: dotH,
      child: ClipRect(
        child: SingleChildScrollView(
          controller: _dotScrollController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Row(
            children: List.generate(total, buildDot),
          ),
        ),
      ),
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
                  child: CachedNetworkImage(
                    imageUrl: rep.imageUrl!,
                    width: 160,
                    fit: BoxFit.cover,
                    memCacheWidth: 320,
                    placeholder: (context, url) => Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(width: 160, color: Colors.white),
                    ),
                    errorWidget: (_, _, _) => Container(
                      width: 160,
                      color: partyColor.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
            ),
          // Content
          ClipRect(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: [
                // Party badge + Office type
                Row(
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _safeTranslit(rep.party),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        officeLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Name
                Text(
                  _safeTranslit(_formatRepName(rep.fullName)),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // Constituency
                Text(
                  '${_safeTranslit(rep.constituency)}, ${_safeTranslit(rep.state)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // Rating
                Row(
                  children: [
                    Text(
                      rating != null ? rating.toStringAsFixed(1) : 'N/A',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (rating != null) ...[
                      ...List.generate(fullStars, (_) => const Icon(Icons.star, color: Colors.amber, size: 16)),
                      if (hasHalfStar) const Icon(Icons.star_half, color: Colors.amber, size: 16),
                      ...List.generate(emptyStars, (_) => const Icon(Icons.star_border, color: Colors.amber, size: 16)),
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
                        LanguageService.tr('not_yet_rated'),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
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
                              isDarkMode: isDarkMode,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: partyColor,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        LanguageService.tr('rate_performance'),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        ],
      ),
    );
  }

  /// Transliterates [text] only if the backend hasn't already done so.
  /// Once the backend adds ?lang= support to /v2/my-representatives,
  /// it will return non-ASCII text and this becomes a no-op.
  String _safeTranslit(String text) {
    return PartyUtils.safeTranslit(text);
  }

  String _formatRepName(String name) {
    // Convert "ALL CAPS NAME" to "Title Case"
    return name.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  // â”€â”€â”€ API-driven Banner Sections â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Fetches sections from the backend and stores them in state.
  Future<void> _loadHomeSections() async {
    if (!mounted) return;
    setState(() => _isLoadingSections = true);

    final theme = isDarkMode ? 'dark' : 'light';
    final lang = LanguageService.languageCode;

    final sections = await HomeSectionsService.fetchSections(
      lang: lang,
      theme: theme,
    );

    if (mounted) {
      setState(() {
        _homeSections = sections;
        _isLoadingSections = false;
      });
    }
  }

  /// Converts the `icon` string from the API to a Material [IconData].
  /// Falls back to a generic play/arrow icon for any unknown value.
  IconData _iconFromString(String iconName) {
    switch (iconName) {
      case 'campaign_outlined':
        return Icons.campaign_outlined;
      case 'sports_esports_outlined':
        return Icons.sports_esports_outlined;
      case 'notifications_outlined':
        return Icons.notifications_outlined;
      case 'info_outline':
        return Icons.info_outline;
      case 'star_outline':
        return Icons.star_outline;
      case 'emoji_events_outlined':
        return Icons.emoji_events_outlined;
      case 'chat_bubble_outline':
        return Icons.chat_bubble_outline;
      case 'poll_outlined':
        return Icons.poll_outlined;
      case 'article_outlined':
        return Icons.article_outlined;
      case 'video_library_outlined':
        return Icons.video_library_outlined;
      default:
        return Icons.play_arrow_outlined;
    }
  }

  /// Builds section slivers from the API response.
  /// Shows a shimmer placeholder while loading; hides completely on empty list.
  List<Widget> _buildApiSections() {
    if (_isLoadingSections) {
      // Subtle shimmer placeholder for two expected sections
      return [
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SkeletonShimmer(
              isDarkMode: isDarkMode,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 140, height: 20, borderRadius: 6),
                  const SizedBox(height: 12),
                  SkeletonBox(
                    width: double.infinity,
                    height: 160,
                    borderRadius: 16,
                  ),
                  const SizedBox(height: 16),
                  SkeletonBox(width: 100, height: 20, borderRadius: 6),
                  const SizedBox(height: 12),
                  SkeletonBox(
                    width: double.infinity,
                    height: 160,
                    borderRadius: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    if (_homeSections.isEmpty) return [];

    final slivers = <Widget>[];
    for (final section in _homeSections) {
      if (section.type == 'webview_banner') {
        slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 16)));
        slivers.add(
          SliverToBoxAdapter(
            child: _buildWebviewBannerCard(section),
          ),
        );
      }
      // Unknown types are silently skipped (per Â§11 of the spec)
    }
    return slivers;
  }

  /// Renders a single `webview_banner` section card.
  Widget _buildWebviewBannerCard(HomeSection section) {
    final icon = _iconFromString(section.icon);
    final webviewTitle = section.webviewTitle!;

    // Append lang & theme to the webview URL so the page opens in the correct language
    final rawWebviewUri = Uri.parse(section.webviewUrl!);
    final finalWebviewUrl = rawWebviewUri.replace(
      queryParameters: {
        ...rawWebviewUri.queryParameters,
        'lang': LanguageService.languageCode,
        'theme': isDarkMode ? 'dark' : 'light',
      },
    ).toString();

    // Append lang & theme so the backend returns the correctly
    // localized / themed banner image.
    final rawBannerUri = Uri.parse(section.bannerImageUrl!);
    final bannerImageUrl = rawBannerUri.replace(
      queryParameters: {
        ...rawBannerUri.queryParameters,
        'lang': LanguageService.languageCode,
        'theme': isDarkMode ? 'dark' : 'light',
      },
    ).toString();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFFFF7A59)),
              const SizedBox(width: 8),
              Text(
                section.title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode
                      ? Colors.white
                      : const Color(0xFF222222),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WebViewPage(
                  title: webviewTitle,
                  url: finalWebviewUrl,
                  isDarkMode: isDarkMode,
                ),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: bannerImageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                placeholder: (_, __) => Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? ThemeService.bgElev
                        : const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  height: 160,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDarkMode
                          ? [const Color(0xFF1a1d27), const Color(0xFF0f1117)]
                          : [const Color(0xFFFFF7EE), const Color(0xFFFFE0CC)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      size: 48,
                      color: const Color(0xFFFF7A59),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€ News Section â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  List<Widget> _buildNewsSlivers() {
    return [
      // Section header with arrow
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  LanguageService.tr('local_news'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode
                        ? Colors.white
                        : const Color(0xFF222222),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  // Navigate to News tab (index 3)
                  widget.onNavigateToTab?.call(3);
                },
                child: Row(
                  children: [
                    Text(
                      LanguageService.tr('see_all'),
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
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 12)),
      if (_isLoadingNews)
        SliverToBoxAdapter(
          child: NewsListSkeleton(isDarkMode: isDarkMode),
        )
      else if (_newsArticles.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: isDarkMode ? ThemeService.bgElev : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  LanguageService.tr('no_news_available'),
                  style: TextStyle(
                    color: isDarkMode ? Colors.white54 : Colors.grey,
                  ),
                ),
              ),
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                // Interleave items with 12px separators
                final itemIndex = index ~/ 2;
                if (index.isOdd) {
                  return const SizedBox(height: 12);
                }
                return _buildNewsListTile(_newsArticles[itemIndex], itemIndex);
              },
              childCount: _newsArticles.isEmpty
                  ? 0
                  : _newsArticles.length * 2 - 1,
            ),
          ),
        ),
    ];
  }

  Widget _buildNewsListTile(_HomeArticle article, int index) {
    return GestureDetector(
      onTap: () {
        final url = article.decodedUrl ?? article.link;
        // If article text couldn't be extracted, open link directly
        if (article.articleText == null || article.articleText!.isEmpty) {
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
          return;
        }
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
              isDarkMode: isDarkMode,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? ThemeService.bgElev : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.05),
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
                    ? CachedNetworkImage(
                        imageUrl: article.imageUrl!,
                        fit: BoxFit.cover,
                        memCacheWidth: 200,
                        memCacheHeight: 200,
                        placeholder: (context, url) => Shimmer.fromColors(
                          baseColor: Colors.grey[300]!,
                          highlightColor: Colors.grey[100]!,
                          child: Container(color: Colors.white),
                        ),
                        errorWidget: (_, _, _) => Container(
                          color: const Color(0xFFE0E0E0),
                          child: const Icon(Icons.article, color: Color(0xFFBDBDBD), size: 32),
                        ),
                      )
                    : Container(
                        color: isDarkMode ? ThemeService.bgBorder : const Color(0xFFE0E0E0),
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
                        LanguageService.translitName(article.source),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFFF7A59),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      LanguageService.translitName(article.title),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode
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
                        color: isDarkMode
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
                color: isDarkMode ? Colors.white38 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
