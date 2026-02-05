import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

class ArticleViewerPage extends StatelessWidget {
  final String title;
  final String imageUrl;
  final String? articleText;
  final String source;
  final String pubDate;
  final String originalUrl;
  final bool isDarkMode;

  const ArticleViewerPage({
    super.key,
    required this.title,
    required this.imageUrl,
    this.articleText,
    required this.source,
    required this.pubDate,
    required this.originalUrl,
    required this.isDarkMode,
  });

  Future<void> _openOriginalLink() async {
    final uri = Uri.parse(originalUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // Silently fail if can't open
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  Icons.share,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                onPressed: () {
                  Share.share('$title\n\n$originalUrl', subject: title);
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.open_in_browser,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                onPressed: _openOriginalLink,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey[300],
                      child: const Icon(Icons.image_not_supported, size: 60),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.source,
                        size: 16,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          source,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        pubDate,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Divider(
                    color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                  ),
                  const SizedBox(height: 24),
                  if (articleText != null && articleText!.isNotEmpty)
                    Text(
                      articleText!,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.7,
                        color: isDarkMode ? Colors.grey[200] : Colors.black87,
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.article_outlined,
                            size: 48,
                            color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Article content could not be extracted',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _openOriginalLink,
                            icon: const Icon(Icons.open_in_browser),
                            label: const Text('Read on Original Site'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                              foregroundColor: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 32),
                  Divider(
                    color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Credits',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Source: $source',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _openOriginalLink,
                          child: Text(
                            originalUrl,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDarkMode ? Colors.blue[300] : Colors.blue[700],
                              decoration: TextDecoration.underline,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
