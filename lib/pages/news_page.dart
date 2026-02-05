import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart' as xml;
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:ip_detector/ip_detector.dart';
import '../services/google_news_decoder.dart';
import '../services/article_extractor.dart';
import '../services/saved_articles_service.dart';
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
  final bool isDarkMode;

  const NewsPage({super.key, required this.isDarkMode});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage>
    with AutomaticKeepAliveClientMixin {
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

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchFeed();
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
    String url = 'https://news.google.com/rss?hl=en-IN&gl=IN&ceid=IN:en',
  }) async {
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

      setState(() {
        _articles = parsed;
        _imageCache.clear();
        _processingIndices.clear();
      });

      _processArticlesLazy(0);
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _processArticlesLazy(int currentIndex) {
    for (int i = currentIndex; i < currentIndex + 2 && i < _articles.length; i++) {
      _processArticle(i);
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
      setState(() {
        _imageCache[index] = imageUrl;
      });
    }

    _processingIndices.remove(index);
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
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

  String _buildGNewsUrlForCity(String city, String countryCode) {
    final q = Uri.encodeComponent(city);
    final hl = countryCode == 'IN' ? 'en-IN' : 'en-US';
    final gl = countryCode;
    final ceid = '$countryCode:en';
    return 'https://news.google.com/rss/search?q=$q&hl=$hl&gl=$gl&ceid=$ceid';
  }

  String _formatDate(String pubDate) {
    try {
      // Parse RFC 822 format (e.g., "Wed, 04 Feb 2025 10:18:45 GMT")
      final date = DateFormat('EEE, dd MMM yyyy HH:mm:ss zzz').parseUtc(pubDate);
      final now = DateTime.now().toUtc();
      final diff = now.difference(date);

      if (diff.inDays == 0) {
        if (diff.inHours == 0) {
          return '${diff.inMinutes}m ago';
        }
        return '${diff.inHours}h ago';
      } else if (diff.inDays < 7) {
        return '${diff.inDays}d ago';
      } else {
        // Convert to IST (UTC+5:30) for display
        final ist = date.add(const Duration(hours: 5, minutes: 30));
        return '${ist.day}/${ist.month}/${ist.year}';
      }
    } catch (_) {
      return pubDate;
    }
  }

  Widget _buildImage(String imageUrl, int fallbackIndex) {
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : Container(
              color: widget.isDarkMode ? const Color(0xFF121212) : Colors.grey[300],
              child: const Center(child: CircularProgressIndicator()),
            ),
      errorBuilder: (_, __, ___) => Image.network(
        'https://picsum.photos/600/1000?random=$fallbackIndex',
        fit: BoxFit.cover,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: widget.isDarkMode ? const Color(0xFF121212) : Colors.white,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: SizedBox(
              height: 60,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _tags.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final t = _tags[idx];
                    final selected = t == _selectedTag;
                    return ChoiceChip(
                      label: Text(t),
                      selected: selected,
                      onSelected: (sel) async {
                        setState(() {
                          _selectedTag = t;
                        });

                        if (t == 'Local') {
                          final loc = await _getCityFromIp();
                          if (loc != null) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Showing news for ${loc['city']}, ${loc['country']}'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                            final url = _buildGNewsUrlForCity(loc['city']!, loc['country']!);
                            await _fetchFeed(url: url);
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Could not detect location — showing default news')),
                              );
                            }
                            await _fetchFeed();
                          }
                          return;
                        }

                        final map = {
                          'All': 'https://news.google.com/rss?hl=en-IN&gl=IN&ceid=IN:en',
                          'Politics': 'https://news.google.com/rss/headlines/section/topic/POLITICS?hl=en-IN&gl=IN&ceid=IN:en',
                          'Business': 'https://news.google.com/rss/headlines/section/topic/BUSINESS?hl=en-IN&gl=IN&ceid=IN:en',
                          'Technology': 'https://news.google.com/rss/headlines/section/topic/TECHNOLOGY?hl=en-IN&gl=IN&ceid=IN:en',
                          'Sports': 'https://news.google.com/rss/headlines/section/topic/SPORTS?hl=en-IN&gl=IN&ceid=IN:en',
                          'Entertainment': 'https://news.google.com/rss/headlines/section/topic/ENTERTAINMENT?hl=en-IN&gl=IN&ceid=IN:en',
                          'Health': 'https://news.google.com/rss/headlines/section/topic/HEALTH?hl=en-IN&gl=IN&ceid=IN:en',
                          'Science': 'https://news.google.com/rss/headlines/section/topic/SCIENCE?hl=en-IN&gl=IN&ceid=IN:en',
                          'World': 'https://news.google.com/rss/headlines/section/topic/WORLD?hl=en-US&gl=US&ceid=US:en',
                          'India': 'https://news.google.com/rss/headlines/section/topic/NATION?hl=en-IN&gl=IN&ceid=IN:en',
                        };
                        await _fetchFeed(url: map[t] ?? map['All']!);
                      },
                    );
                  },
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? ListView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text('Error: $_error'),
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
                                        isDarkMode: widget.isDarkMode,
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
                                                color: widget.isDarkMode
                                                    ? const Color(0xFF1E1E1E)
                                                    : Colors.grey[200],
                                                child: const Center(child: CircularProgressIndicator()),
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
                                                  if (_savedArticleLinks.contains(a.link)) {
                                                    await _savedArticlesService.removeArticle(a.link);
                                                    setState(() {
                                                      _savedArticleLinks.remove(a.link);
                                                    });
                                                    if (mounted) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: const Text('Removed from saved articles'),
                                                          backgroundColor: widget.isDarkMode
                                                              ? const Color(0xFF2A2A2A)
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
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: const Text('Saved to bookmarks'),
                                                          backgroundColor: widget.isDarkMode
                                                              ? const Color(0xFF2A2A2A)
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
                                              a.title,
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
                                                a.source,
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