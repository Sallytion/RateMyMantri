import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../services/language_service.dart';
import '../services/theme_service.dart';

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
      backgroundColor: isDarkMode ? ThemeService.bgAlt : Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: isDarkMode ? ThemeService.bgCard : Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.share_outlined, size: 16, color: Colors.white),
                ),
                onPressed: () {
                  Share.share('$title\n\n$originalUrl', subject: title);
                },
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.open_in_browser, size: 16, color: Colors.white),
                ),
                onPressed: _openOriginalLink,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 800,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    placeholder: (context, url) => Container(
                      color: isDarkMode ? ThemeService.bgCard : Colors.grey[300],
                    ),
                    errorWidget: (_, _, _) => Container(
                      color: isDarkMode ? ThemeService.bgCard : Colors.grey[300],
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
                    LanguageService.translitName(title),
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
                          LanguageService.translitName(source),
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
                      LanguageService.translitName(articleText!),
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
                        color: isDarkMode ? ThemeService.bgCard : Colors.grey[100],
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
                            LanguageService.tr('article_not_extracted'),
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
                            label: Text(LanguageService.tr('read_original')),
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
                      color: isDarkMode ? ThemeService.bgCard : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          LanguageService.tr('credits'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${LanguageService.tr('source_label')}: ${LanguageService.translitName(source)}',
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
