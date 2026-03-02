import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/formatters.dart';
import '../services/saved_articles_service.dart';
import '../services/language_service.dart';
import '../services/theme_service.dart';
import 'article_viewer_page.dart';

class SavedArticlesPage extends StatefulWidget {
  final bool isDarkMode;

  const SavedArticlesPage({super.key, required this.isDarkMode});

  @override
  State<SavedArticlesPage> createState() => _SavedArticlesPageState();
}

class _SavedArticlesPageState extends State<SavedArticlesPage> {
  final SavedArticlesService _savedArticlesService = SavedArticlesService();
  List<SavedArticle> _savedArticles = [];
  bool _isLoading = true;

  Color get _backgroundColor =>
      widget.isDarkMode ? ThemeService.bgMain : Colors.white;
  Color get _primaryText =>
      widget.isDarkMode ? const Color(0xFFFFFFFF) : const Color(0xFF222222);
  Color get _secondaryText =>
      widget.isDarkMode ? const Color(0xFFB0B0B0) : const Color(0xFF717171);
  Color get _cardBackground =>
      widget.isDarkMode ? ThemeService.bgElev : const Color(0xFFF7F7F7);

  @override
  void initState() {
    super.initState();
    _loadSavedArticles();
  }

  Future<void> _loadSavedArticles() async {
    setState(() => _isLoading = true);
    final articles = await _savedArticlesService.getSavedArticles();
    setState(() {
      _savedArticles = articles;
      _isLoading = false;
    });
  }

  Future<void> _removeArticle(SavedArticle article) async {
    await _savedArticlesService.removeArticle(article.link);
    await _loadSavedArticles();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LanguageService.tr('article_removed')),
          backgroundColor: widget.isDarkMode ? ThemeService.bgElev : const Color(0xFF323232),
        ),
      );
    }
  }

  String _formatDate(String dateStr) {
    return Formatters.formatPubDate(dateStr);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: _primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          LanguageService.tr('saved'),
          style: TextStyle(
            color: _primaryText,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          if (_savedArticles.isNotEmpty)
            TextButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: _cardBackground,
                    title: Text(LanguageService.tr('clear_all_q'), style: TextStyle(color: _primaryText)),
                    content: Text(
                      LanguageService.tr('remove_all_saved'),
                      style: TextStyle(color: _secondaryText),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(LanguageService.tr('cancel')),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(LanguageService.tr('clear_all'), style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _savedArticlesService.clearAll();
                  await _loadSavedArticles();
                }
              },
              child: Text(
                LanguageService.tr('clear_all'),
                style: TextStyle(color: _secondaryText),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: widget.isDarkMode ? Colors.white : Colors.black,
              ),
            )
          : _savedArticles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bookmark_outline,
                        size: 80,
                        color: _secondaryText.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        LanguageService.tr('no_saved_articles'),
                        style: TextStyle(
                          fontSize: 18,
                          color: _secondaryText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        LanguageService.tr('bookmark_appear_here'),
                        style: TextStyle(
                          fontSize: 14,
                          color: _secondaryText.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.3),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.amber[700],
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              LanguageService.tr('saved_locally_warning'),
                              style: TextStyle(
                                fontSize: 13,
                                color: widget.isDarkMode
                                    ? Colors.amber[300]
                                    : Colors.amber[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _savedArticles.length,
                        padding: const EdgeInsets.only(bottom: 8),
                        itemBuilder: (context, index) {
                    final article = _savedArticles[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: _cardBackground,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          if (article.articleText != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ArticleViewerPage(
                                  title: article.title,
                                  imageUrl: article.imageUrl ?? 'https://picsum.photos/600/1000',
                                  articleText: article.articleText,
                                  source: article.source,
                                  pubDate: _formatDate(article.pubDate),
                                  originalUrl: article.decodedUrl ?? article.link,
                                  isDarkMode: widget.isDarkMode,
                                ),
                              ),
                            );
                          } else {
                            final url = article.decodedUrl ?? article.link;
                            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (article.imageUrl != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: article.imageUrl!,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 200,
                                    memCacheHeight: 200,
                                    placeholder: (context, url) => Shimmer.fromColors(
                                      baseColor: Colors.grey[300]!,
                                      highlightColor: Colors.grey[100]!,
                                      child: Container(
                                        width: 80,
                                        height: 80,
                                        color: Colors.white,
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                      width: 80,
                                      height: 80,
                                      color: _secondaryText.withValues(alpha: 0.1),
                                      child: Icon(Icons.image, color: _secondaryText),
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      LanguageService.translitName(article.title),
                                      style: TextStyle(
                                        color: _primaryText,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(Icons.access_time, size: 14, color: _secondaryText),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatDate(article.pubDate),
                                          style: TextStyle(
                                            color: _secondaryText,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Icon(Icons.source, size: 14, color: _secondaryText),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            LanguageService.translitName(article.source),
                                            style: TextStyle(
                                              color: _secondaryText,
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.bookmark, color: Color(0xFF00BCD4)),
                                    onPressed: () => _removeArticle(article),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.share, color: _secondaryText),
                                    onPressed: () {
                                      final urlToShare = article.decodedUrl ?? article.link;
                                      Share.share('${article.title}\n\n$urlToShare',
                                          subject: article.title);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),                    ),
                  ],
                ),    );
  }
}
