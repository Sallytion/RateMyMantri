import 'package:intl/intl.dart';

/// Shared date/currency formatting utilities.
class Formatters {
  Formatters._();

  /// Format an RSS pubDate string (e.g. "Mon, 01 Jan 2024 12:00:00 GMT")
  /// into a relative time string: "3m ago", "2h ago", "5d ago", or "1/3/2024".
  static String formatPubDate(String pubDate) {
    try {
      final date =
          DateFormat('EEE, dd MMM yyyy HH:mm:ss zzz').parseUtc(pubDate);
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

  /// Format a [DateTime] into a relative time string:
  /// "3m ago", "2h ago", "5d ago", "2mo ago", "1y ago".
  static String formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 30) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else {
      return '${(difference.inDays / 365).floor()}y ago';
    }
  }

  /// Format an integer amount in Indian currency style:
  /// ₹1.2 Cr, ₹3.5 L, ₹12 K, ₹500.
  ///
  /// Set [showSymbol] to false for bare numbers (e.g. "1.2Cr").
  static String formatCurrency(int amount, {bool showSymbol = true}) {
    final prefix = showSymbol ? '₹' : '';
    final space = showSymbol ? ' ' : '';
    if (amount >= 10000000) {
      return '$prefix${(amount / 10000000).toStringAsFixed(1)}${space}Cr';
    } else if (amount >= 100000) {
      return '$prefix${(amount / 100000).toStringAsFixed(1)}${space}L';
    } else if (amount >= 1000) {
      return '$prefix${(amount / 1000).toStringAsFixed(0)}${space}K';
    }
    return '$prefix$amount';
  }
}
