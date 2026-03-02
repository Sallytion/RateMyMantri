import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:xml/xml.dart' as xml;
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/formatters.dart';
import '../utils/location_service.dart';
import '../providers/theme_provider.dart';
import '../services/theme_service.dart';
import '../services/language_service.dart';
import '../services/google_news_decoder.dart';
import '../services/article_extractor.dart';
import '../services/saved_articles_service.dart';
import '../services/constituency_notifier.dart';
import '../services/constituency_service.dart';
import '../widgets/skeleton_widgets.dart';
import 'article_viewer_page.dart';

class Article {
  final String title;
  final String link;
  final String source;
  final String pubDate;
  String? decodedUrl;
  String? articleText;

  Article({
    required this.title,
    required this.link,
    required this.source,
    required this.pubDate,
    this.decodedUrl,
    this.articleText,
  });
}

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  /// Reads the current dark-mode flag from the provider.
  bool get isDarkMode => context.read<ThemeProvider>().isDarkMode;

  List<Article> _articles = [];
  bool _loading = false;
  String _error = '';
  final PageController _pageController = PageController();
  final List<String> _tags = [
    'All',
    'Local',
    'Politics',
    'Business',
    'Technology',
    'Sports',
    'Entertainment',
    'Health',
    'Science',
    'World',
    'India',
  ];
  String _selectedTag = 'All';
  final Map<int, String> _imageCache = {};
  final Set<int> _processingIndices = {};
  final GoogleNewsDecoder _newsDecoder = GoogleNewsDecoder();
  final ArticleExtractor _articleExtractor = ArticleExtractor();
  final SavedArticlesService _savedArticlesService = SavedArticlesService();
  final Set<String> _savedArticleLinks = {};

  // â”€â”€â”€ Static per-tag cache (survives widget rebuilds) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static final Map<String, List<Article>> _cachedArticlesByTag = {};
  static final Map<String, Map<int, String>> _cachedImagesByTag = {};
  static String? _cachedSelectedTag;

  @override
  void initState() {
    super.initState();
    // Restore last selected tag and cached data if available
    if (_cachedSelectedTag != null) {
      _selectedTag = _cachedSelectedTag!;
    }
    if (_cachedArticlesByTag.containsKey(_selectedTag)) {
      _articles = _cachedArticlesByTag[_selectedTag]!;
      _imageCache.clear();
      _imageCache.addAll(_cachedImagesByTag[_selectedTag] ?? {});
    } else {
      _fetchFeed();
    }
    _pageController.addListener(_onPageChanged);
    _loadSavedArticles();
  }

  Future<void> _loadSavedArticles() async {
    final savedArticles = await _savedArticlesService.getSavedArticles();
    setState(() {
      _savedArticleLinks.clear();
      _savedArticleLinks.addAll(savedArticles.map((a) => a.link));
    });
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged() {
    if (!_pageController.position.hasContentDimensions) return;
    final currentPage = _pageController.page?.round() ?? 0;
    _processArticlesLazy(currentPage);
  }

  Future<void> _fetchFeed({
    String? url,
    String? tag,
  }) async {
    url ??= 'https://news.google.com/rss?${LanguageService.newsGlParams}';
    final effectiveTag = tag ?? _selectedTag;

    // Check per-tag cache first
    if (_cachedArticlesByTag.containsKey(effectiveTag)) {
      setState(() {
        _articles = _cachedArticlesByTag[effectiveTag]!;
        _imageCache.clear();
        _imageCache.addAll(_cachedImagesByTag[effectiveTag] ?? {});
        _processingIndices.clear();
        _loading = false;
        _error = '';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');

      final doc = xml.XmlDocument.parse(res.body);
      final items = doc.findAllElements('item');

      final List<Article> parsed = [];
      for (var item in items) {
        final titleElem = item.findElements('title').first;
        final linkElem = item.findElements('link').first;
        final sourceElem = item.findElements('source');
        final pubDateElem = item.findElements('pubDate');

        parsed.add(
          Article(
            title: titleElem.innerText,
            link: linkElem.innerText,
            source: sourceElem.isNotEmpty ? sourceElem.first.innerText : '',
            pubDate: pubDateElem.isNotEmpty ? pubDateElem.first.innerText : '',
          ),
        );
      }

      // Store in per-tag cache
      _cachedArticlesByTag[effectiveTag] = parsed;
      _cachedImagesByTag[effectiveTag] = {};

      setState(() {
        _articles = parsed;
        _imageCache.clear();
        _processingIndices.clear();
        _loading = false;
      });

      _processArticlesLazy(0);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _processArticlesLazy(int currentIndex) {
    // Process current page + next page immediately for instant display
    final immediateFutures = <Future<void>>[];
    for (int i = currentIndex; i < currentIndex + 2 && i < _articles.length; i++) {
      immediateFutures.add(_processArticle(i));
    }
    Future.wait(immediateFutures).then((_) {
      if (mounted) setState(() {});
      // After immediate pages are ready, prefetch next 3 in the background
      _prefetchAhead(currentIndex + 2, 3);
    });
  }

  /// Prefetch [count] articles starting from [startIndex] in the background
  void _prefetchAhead(int startIndex, int count) {
    final futures = <Future<void>>[];
    for (int i = startIndex; i < startIndex + count && i < _articles.length; i++) {
      futures.add(_processArticle(i));
    }
    if (futures.isNotEmpty) {
      Future.wait(futures).then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _processArticle(int index) async {
    if (index >= _articles.length ||
        _imageCache.containsKey(index) ||
        _processingIndices.contains(index)) {
      return;
    }

    _processingIndices.add(index);
    final article = _articles[index];
    String? decodedUrl;

    try {
      final result = await _newsDecoder.decodeGoogleNewsUrl(article.link);
      if (result['status'] == true && result['decoded_url'] != null) {
        decodedUrl = result['decoded_url'] as String;
        article.decodedUrl = decodedUrl;
      }
    } catch (_) {}

    String imageUrl = 'https://picsum.photos/600/1000?random=$index';

    if (decodedUrl != null && !decodedUrl.contains('news.google.com')) {
      try {
        final extracted = await _articleExtractor.extractArticle(
          decodedUrl,
          articleIndex: index,
        );
        if (extracted['imageUrl'] != null && extracted['imageUrl']!.isNotEmpty) {
          imageUrl = extracted['imageUrl']!;
        }
        if (extracted['content'] != null) {
          article.articleText = extracted['content'];
        }
      } catch (_) {}
    }

    if (mounted) {
      _imageCache[index] = imageUrl;
      // Sync image back to per-tag cache
      _cachedImagesByTag[_selectedTag]?[index] = imageUrl;
    }

    _processingIndices.remove(index);
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LanguageService.tr('could_not_open_link'))),
        );
      }
    }
  }

  Future<Map<String, String>?> _getCityFromIp({int ttlSeconds = 86400}) async {
    return LocationService.instance.getCityFromIp(ttlSeconds: ttlSeconds);
  }

  String _buildGNewsUrlForCity(String city, String countryCode) {
    final q = Uri.encodeComponent(city);
    final params = countryCode == 'IN'
        ? LanguageService.newsGlParams
        : 'hl=en-US&gl=$countryCode&ceid=$countryCode:en';
    return 'https://news.google.com/rss/search?q=$q&$params';
  }

  /// Returns the RSS URL for a given tag using the current language params.
  /// Returns null for 'Local' (requires async IP lookup â€” handled separately).
  String? _buildUrlForTag(String tag) {
    final p = LanguageService.newsGlParams;
    final map = {
      'All': 'https://news.google.com/rss?$p',
      'Politics': 'https://news.google.com/rss/headlines/section/topic/POLITICS?$p',
      'Business': 'https://news.google.com/rss/headlines/section/topic/BUSINESS?$p',
      'Technology': 'https://news.google.com/rss/headlines/section/topic/TECHNOLOGY?$p',
      'Sports': 'https://news.google.com/rss/headlines/section/topic/SPORTS?$p',
      'Entertainment': 'https://news.google.com/rss/headlines/section/topic/ENTERTAINMENT?$p',
      'Health': 'https://news.google.com/rss/headlines/section/topic/HEALTH?$p',
      'Science': 'https://news.google.com/rss/headlines/section/topic/SCIENCE?$p',
      'World': 'https://news.google.com/rss/headlines/section/topic/WORLD?hl=en-US&gl=US&ceid=US:en',
      'India': 'https://news.google.com/rss/headlines/section/topic/NATION?$p',
    };
    return map[tag];
  }

  String _formatDate(String pubDate) {
    return Formatters.formatPubDate(pubDate);
  }

  Widget _buildImage(String imageUrl, int fallbackIndex) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      memCacheWidth: 800,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (context, url) => Container(color: Colors.grey[900]),
      errorWidget: (_, _, _) => CachedNetworkImage(
        imageUrl: 'https://picsum.photos/600/1000?random=$fallbackIndex',
        fit: BoxFit.cover,
        memCacheWidth: 800,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: (context, url) => Container(color: Colors.grey[900]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<ThemeProvider>().isDarkMode;
    return Scaffold(
      backgroundColor: isDarkMode ? ThemeService.bgAlt : Colors.white,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Text(
                    LanguageService.tr('news'),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : const Color(0xFF222222),
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _tags.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final t = _tags[idx];
                    final selected = t == _selectedTag;
                    return ChoiceChip(
                      label: Text(LanguageService.tr(t.toLowerCase())),
                      selected: selected,
                      onSelected: (sel) async {
                        final messenger = ScaffoldMessenger.of(context);
                        setState(() {
                          _selectedTag = t;
                        });
                        _cachedSelectedTag = t;

                        if (t == 'Local') {
                          // Check cache first for Local
                          if (_cachedArticlesByTag.containsKey('Local')) {
                            await _fetchFeed(tag: 'Local');
                            return;
                          }
                          // Primary: use set constituency
                          var constituency = ConstituencyNotifier.instance.current;
                          constituency ??= await ConstituencyService().getCurrentConstituency();
                          if (constituency != null) {
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('${LanguageService.tr('showing_news_for')} ${constituency.name}'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                            final query = Uri.encodeComponent(constituency.nameEn);
                            final url = 'https://news.google.com/rss/search?q=$query&${LanguageService.newsGlParams}';
                            await _fetchFeed(url: url, tag: 'Local');
                          } else {
                            // Fallback: IP-based city detection
                            final loc = await _getCityFromIp();
                            if (loc != null) {
                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('${LanguageService.tr('showing_news_for')} ${loc['city']}, ${loc['country']}'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                              final url = _buildGNewsUrlForCity(loc['city']!, loc['country']!);
                              await _fetchFeed(url: url, tag: 'Local');
                            } else {
                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text(LanguageService.tr('could_not_detect_location'))),
                                );
                              }
                              await _fetchFeed(tag: 'Local');
                            }
                          }
                          return;
                        }

                        final url = _buildUrlForTag(t);
                        await _fetchFeed(url: url, tag: t);
                      },
                    );
                  },
                ),
              ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? NewsPageSkeleton(isDarkMode: isDarkMode)
                : _error.isNotEmpty
                    ? ListView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text('${LanguageService.tr('error_prefix')}: $_error'),
                          ),
                        ],
                      )
                    : PageView.builder(
                        controller: _pageController,
                        scrollDirection: Axis.vertical,
                        itemCount: _articles.length,
                        itemBuilder: (context, i) {
                          final a = _articles[i];
                          final cachedImg = _imageCache[i];
                          final cardH = MediaQuery.of(context).size.height * 0.82;

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: GestureDetector(
                              onTap: () {
                                // If article text could not be extracted, open in browser directly
                                if (a.articleText == null || a.articleText!.isEmpty) {
                                  final urlToOpen = a.decodedUrl ?? a.link;
                                  _openLink(urlToOpen);
                                } else {
                                  // Navigate to article viewer page
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ArticleViewerPage(
                                        title: a.title,
                                        imageUrl: cachedImg ?? 'https://picsum.photos/600/1000?random=$i',
                                        articleText: a.articleText,
                                        source: a.source,
                                        pubDate: _formatDate(a.pubDate),
                                        originalUrl: a.decodedUrl ?? a.link,
                                        isDarkMode: isDarkMode,
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                height: cardH,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: cachedImg != null
                                            ? _buildImage(cachedImg, i)
                                            : Container(
                                                color: isDarkMode
                                                    ? ThemeService.bgCard
                                                    : Colors.grey[200],
                                                child: SkeletonShimmer(
                                                  isDarkMode: isDarkMode,
                                                  child: Container(
                                                    margin: const EdgeInsets.all(20),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius: BorderRadius.circular(20),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                      ),
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.transparent,
                                                Colors.transparent,
                                                Colors.black.withValues(alpha: 0.3),
                                                Colors.black.withValues(alpha: 0.7),
                                                Colors.black,
                                              ],
                                              stops: const [0.0, 0.4, 0.6, 0.8, 1.0],
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 16,
                                        right: 16,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.3),
                                                shape: BoxShape.circle,
                                              ),
                                              child: IconButton(
                                                icon: Icon(
                                                  _savedArticleLinks.contains(a.link)
                                                      ? Icons.bookmark
                                                      : Icons.bookmark_outline,
                                                  color: _savedArticleLinks.contains(a.link)
                                                      ? const Color(0xFF00BCD4)
                                                      : Colors.white,
                                                ),
                                                onPressed: () async {
                                                  final messenger = ScaffoldMessenger.of(context);
                                                  if (_savedArticleLinks.contains(a.link)) {
                                                    await _savedArticlesService.removeArticle(a.link);
                                                    setState(() {
                                                      _savedArticleLinks.remove(a.link);
                                                    });
                                                    if (mounted) {
                                                      messenger.showSnackBar(
                                                        SnackBar(
                                                          content: Text(LanguageService.tr('removed_from_saved')),
                                                          backgroundColor: isDarkMode
                                                              ? ThemeService.bgElev
                                                              : const Color(0xFF323232),
                                                          duration: const Duration(seconds: 2),
                                                        ),
                                                      );
                                                    }
                                                  } else {
                                                    final savedArticle = SavedArticle(
                                                      title: a.title,
                                                      link: a.link,
                                                      source: a.source,
                                                      pubDate: a.pubDate,
                                                      decodedUrl: a.decodedUrl,
                                                      articleText: a.articleText,
                                                      imageUrl: _imageCache[i],
                                                      savedAt: DateTime.now(),
                                                    );
                                                    await _savedArticlesService.saveArticle(savedArticle);
                                                    setState(() {
                                                      _savedArticleLinks.add(a.link);
                                                    });
                                                    if (mounted) {
                                                      messenger.showSnackBar(
                                                        SnackBar(
                                                          content: Text(LanguageService.tr('saved_to_bookmarks')),
                                                          backgroundColor: isDarkMode
                                                              ? ThemeService.bgElev
                                                              : const Color(0xFF323232),
                                                          duration: const Duration(seconds: 2),
                                                        ),
                                                      );
                                                    }
                                                  }
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.3),
                                                shape: BoxShape.circle,
                                              ),
                                              child: IconButton(
                                                icon: const Icon(Icons.share, color: Colors.white),
                                                onPressed: () {
                                                  final urlToShare = a.decodedUrl ?? a.link;
                                                  Share.share('${a.title}\n\n$urlToShare', subject: a.title);
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Positioned(
                                        left: 16,
                                        right: 16,
                                        bottom: 24,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              LanguageService.translitName(a.title),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 28,
                                                fontWeight: FontWeight.bold,
                                                height: 1.2,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            if (a.source.isNotEmpty)
                                              Text(
                                                LanguageService.translitName(a.source),
                                                style: TextStyle(
                                                  color: Colors.white.withValues(alpha: 0.8),
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            if (a.pubDate.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                _formatDate(a.pubDate),
                                                style: TextStyle(
                                                  color: Colors.white.withValues(alpha: 0.6),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
