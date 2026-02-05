import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../services/saved_articles_service.dart';
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
      widget.isDarkMode ? const Color(0xFF1A1A1A) : Colors.white;
  Color get _primaryText =>
      widget.isDarkMode ? const Color(0xFFFFFFFF) : const Color(0xFF222222);
  Color get _secondaryText =>
      widget.isDarkMode ? const Color(0xFFB0B0B0) : const Color(0xFF717171);
  Color get _cardBackground =>
      widget.isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFF7F7F7);

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
          content: const Text('Article removed from saved'),
          backgroundColor: widget.isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFF323232),
        ),
      );
    }
  }

  String _formatDate(String dateStr) {
    try {
      final parsedDate = DateFormat('EEE, dd MMM yyyy HH:mm:ss Z').parse(dateStr);
      final istDate = parsedDate.add(const Duration(hours: 5, minutes: 30));
      final now = DateTime.now();
      final difference = now.difference(istDate);

      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          return '${difference.inMinutes}m ago';
        }
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return DateFormat('MMM dd, yyyy').format(istDate);
      }
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Saved Articles',
          style: TextStyle(
            color: _primaryText,
            fontSize: 20,
            fontWeight: FontWeight.w600,
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
                    title: Text('Clear All?', style: TextStyle(color: _primaryText)),
                    content: Text(
                      'Remove all saved articles?',
                      style: TextStyle(color: _secondaryText),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Clear All', style: TextStyle(color: Colors.red)),
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
                'Clear All',
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
                        'No saved articles',
                        style: TextStyle(
                          fontSize: 18,
                          color: _secondaryText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Articles you bookmark will appear here',
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
                              'All articles are saved locally. If you logout or delete the app, articles will be gone.',
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
                                  child: Image.network(
                                    article.imageUrl!,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
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
                                      article.title,
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
                                            article.source,
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
