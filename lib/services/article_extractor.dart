import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';

/// A simplified Dart implementation of article extraction
/// Extracts metadata and images from article URLs
class ArticleExtractor {
  /// Fetch HTML content from a URL
  Future<String?> fetchUrl(String url) async {
    try {
      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return response.body;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Extract both image and article text
  /// Returns a map with 'imageUrl' and 'content' keys
  Future<Map<String, String?>> extractArticle(String url, {int articleIndex = 0}) async {
    try {
      final html = await fetchUrl(url);
      if (html == null) {
        return {
          'imageUrl': _getPicsumFallback(articleIndex),
          'content': null,
        };
      }

      // Parse HTML in a background isolate to avoid UI jank
      final result = await compute(_parseArticleHtml, html);
      return {
        'imageUrl': result['imageUrl'] ?? _getPicsumFallback(articleIndex),
        'content': result['content'],
      };
    } catch (e) {
      return {
        'imageUrl': _getPicsumFallback(articleIndex),
        'content': null,
      };
    }
  }

  /// Extract just the main image from an article (lightweight)
  /// Returns article image URL or a random picsum fallback if extraction fails
  Future<String?> extractImageOnly(String url, {int articleIndex = 0}) async {
    try {
      final html = await fetchUrl(url);
      if (html == null) {
        return _getPicsumFallback(articleIndex);
      }

      // Parse HTML in a background isolate
      final imageUrl = await compute(_parseImageOnlyHtml, html);
      return imageUrl ?? _getPicsumFallback(articleIndex);
    } catch (e) {
      return _getPicsumFallback(articleIndex);
    }
  }

  /// Get a random picsum placeholder image
  String _getPicsumFallback(int seed) {
    return 'https://picsum.photos/600/1000?random=$seed';
  }

  // _extractMainImage moved to top-level _extractMainImageStatic for compute() usage
}

/// Top-level function for compute() — parses HTML and extracts both image and text.
Map<String, String?> _parseArticleHtml(String html) {
  final document = html_parser.parse(html);
  final imageUrl = _extractMainImageStatic(document);
  final content = _extractArticleTextStatic(document);
  return {'imageUrl': imageUrl, 'content': content};
}

/// Top-level function for compute() — parses HTML and extracts image only.
String? _parseImageOnlyHtml(String html) {
  final document = html_parser.parse(html);
  return _extractMainImageStatic(document);
}

/// Static version of _extractArticleText for use in isolates.
String? _extractArticleTextStatic(Document document) {
  final selectors = [
    'article',
    '[class*="article-content"]',
    '[class*="post-content"]',
    '[class*="story-body"]',
    '[class*="entry-content"]',
    'main',
    '.content',
  ];

  for (final selector in selectors) {
    final element = document.querySelector(selector);
    if (element != null) {
      element
          .querySelectorAll(
            'script, style, nav, footer, aside, .ad, .advertisement, [class*="ad-"], [id*="ad-"]',
          )
          .forEach((e) => e.remove());

      final paragraphs = element.querySelectorAll('p');
      if (paragraphs.isNotEmpty) {
        final text = paragraphs
            .map((p) => p.text.trim())
            .where((text) => text.isNotEmpty && text.length > 50)
            .join('\n\n');

        if (text.isNotEmpty) {
          return text;
        }
      }
    }
  }
  return null;
}

/// Static version of _extractMainImage for use in isolates.
String? _extractMainImageStatic(Document document) {
  var imgElement = document.querySelector('meta[property="og:image"]');
  if (imgElement != null) {
    final imageUrl = imgElement.attributes['content'];
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return _normalizeUrlStatic(imageUrl);
    }
  }

  imgElement = document.querySelector('meta[name="twitter:image"]');
  if (imgElement != null) {
    final imageUrl = imgElement.attributes['content'];
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return _normalizeUrlStatic(imageUrl);
    }
  }

  final articleImages = document.querySelectorAll(
    'article img, main img, .article-content img, .post-content img, .story-body img, [class*="article"] img',
  );

  for (final img in articleImages) {
    final src = img.attributes['src'];
    if (src != null &&
        src.isNotEmpty &&
        !src.contains('icon') &&
        !src.contains('logo') &&
        !src.contains('avatar') &&
        !src.contains('placeholder')) {
      final normalized = _normalizeUrlStatic(src);
      if (normalized != null) {
        return normalized;
      }
    }
  }
  return null;
}

/// Static URL normalizer for use in isolates.
String? _normalizeUrlStatic(String? url) {
  if (url == null || url.isEmpty) return null;
  url = url.trim();
  if (url.startsWith('//')) return 'https:$url';
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return url.replaceFirst('http://', 'https://');
  }
  return null;
}