import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

/// A Dart implementation of Google News URL decoder
/// Decodes Google News article URLs to their original source URLs
class GoogleNewsDecoder {
  final String? proxy;

  GoogleNewsDecoder({this.proxy});

  /// Extracts the base64 string from a Google News URL
  Future<Map<String, dynamic>> getBase64Str(String sourceUrl) async {
    try {
      final uri = Uri.parse(sourceUrl);
      final pathSegments = uri.pathSegments;

      if (uri.host == 'news.google.com' &&
          pathSegments.length > 1 &&
          (pathSegments[pathSegments.length - 2] == 'articles' ||
              pathSegments[pathSegments.length - 2] == 'read')) {
        return {'status': true, 'base64_str': pathSegments.last};
      }

      return {'status': false, 'message': 'Invalid Google News URL format.'};
    } catch (e) {
      return {'status': false, 'message': 'Error in getBase64Str: $e'};
    }
  }

  /// Fetches signature and timestamp required for decoding from Google News
  Future<Map<String, dynamic>> getDecodingParams(String base64Str) async {
    // Try the first URL format
    try {
      final url = 'https://news.google.com/articles/$base64Str';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        final dataElement = document.querySelector('c-wiz > div[jscontroller]');

        if (dataElement != null) {
          final signature = dataElement.attributes['data-n-a-sg'];
          final timestamp = dataElement.attributes['data-n-a-ts'];

          if (signature != null && timestamp != null) {
            return {
              'status': true,
              'signature': signature,
              'timestamp': timestamp,
              'base64_str': base64Str,
            };
          }
        }
      }
    } catch (e) {
      // Fall through to try RSS URL
    }

    // Fallback: try RSS URL format
    try {
      final url = 'https://news.google.com/rss/articles/$base64Str';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        final dataElement = document.querySelector('c-wiz > div[jscontroller]');

        if (dataElement != null) {
          final signature = dataElement.attributes['data-n-a-sg'];
          final timestamp = dataElement.attributes['data-n-a-ts'];

          if (signature != null && timestamp != null) {
            return {
              'status': true,
              'signature': signature,
              'timestamp': timestamp,
              'base64_str': base64Str,
            };
          }
        }
      }

      return {
        'status': false,
        'message': 'Failed to fetch data attributes from Google News.',
      };
    } catch (e) {
      return {
        'status': false,
        'message': 'Request error in getDecodingParams: $e',
      };
    }
  }

  /// Decodes the Google News URL using signature and timestamp
  Future<Map<String, dynamic>> decodeUrl(
    String signature,
    String timestamp,
    String base64Str,
  ) async {
    try {
      final url = 'https://news.google.com/_/DotsSplashUi/data/batchexecute';

      final payload = [
        'Fbv4je',
        '["garturlreq",[["X","X",["X","X"],null,null,1,1,"US:en",null,1,null,null,null,null,null,0,1],"X","X",1,[1,1,1],1,1,null,0,0,null,0],"$base64Str",$timestamp,"$signature"]',
      ];

      final headers = {
        'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36',
      };

      final body =
          'f.req=${Uri.encodeComponent(jsonEncode([
            [payload],
          ]))}';

      final response = await http
          .post(Uri.parse(url), headers: headers, body: body)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // Parse the response
        final lines = response.body.split('\n\n');
        if (lines.length > 1) {
          final parsedData = jsonDecode(lines[1]);

          // Remove last 2 elements
          final dataList = parsedData.sublist(0, parsedData.length - 2);

          if (dataList.isNotEmpty && dataList[0].length > 2) {
            final innerData = jsonDecode(dataList[0][2]);
            final decodedUrl = innerData[1];

            return {'status': true, 'decoded_url': decodedUrl};
          }
        }
      }

      return {
        'status': false,
        'message': 'Failed to decode URL. Status: ${response.statusCode}',
      };
    } catch (e) {
      return {'status': false, 'message': 'Error in decodeUrl: $e'};
    }
  }

  /// Main method to decode a Google News article URL
  Future<Map<String, dynamic>> decodeGoogleNewsUrl(String sourceUrl) async {
    try {
      // Step 1: Extract base64 string from URL
      final base64Response = await getBase64Str(sourceUrl);
      if (base64Response['status'] != true) {
        return base64Response;
      }

      // Step 2: Get decoding parameters (signature & timestamp)
      final decodingParamsResponse = await getDecodingParams(
        base64Response['base64_str'],
      );
      if (decodingParamsResponse['status'] != true) {
        return decodingParamsResponse;
      }

      // Step 3: Decode the URL
      final decodedUrlResponse = await decodeUrl(
        decodingParamsResponse['signature'],
        decodingParamsResponse['timestamp'],
        decodingParamsResponse['base64_str'],
      );

      return decodedUrlResponse;
    } catch (e) {
      return {'status': false, 'message': 'Error in decodeGoogleNewsUrl: $e'};
    }
  }
}
