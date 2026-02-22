import '../models/representative_detail.dart';
import 'representative_service.dart';
import 'ratings_service.dart';

/// Prefetch service that pre-loads representative detail data
/// before the user navigates to the detail page.
class PrefetchService {
  static final PrefetchService _instance = PrefetchService._();
  factory PrefetchService() => _instance;
  PrefetchService._();

  final RepresentativeService _repService = RepresentativeService();
  final RatingsService _ratingsService = RatingsService();

  // Cache for prefetched data
  final Map<String, _PrefetchedData> _cache = {};

  // Track in-flight prefetch requests to avoid duplicates
  final Set<String> _inFlight = {};

  /// Start prefetching data for a representative.
  /// Call this when the user shows intent (e.g., long press, or visible in list).
  void prefetch(String representativeId) {
    if (_cache.containsKey(representativeId) || _inFlight.contains(representativeId)) {
      return; // Already cached or in progress
    }

    _inFlight.add(representativeId);

    _doPrefetch(representativeId);
  }

  Future<void> _doPrefetch(String representativeId) async {
    try {
      final results = await Future.wait([
        _repService.getRepresentativeById(representativeId),
        _ratingsService.getRatingStatistics(int.parse(representativeId)),
      ]);

      _cache[representativeId] = _PrefetchedData(
        detail: results[0] as RepresentativeDetail?,
        stats: results[1],
        fetchedAt: DateTime.now(),
      );
    } catch (e) {
    } finally {
      _inFlight.remove(representativeId);
    }
  }

  /// Get prefetched detail data if available and fresh (within 5 minutes).
  RepresentativeDetail? getPrefetchedDetail(String representativeId) {
    final data = _cache[representativeId];
    if (data == null) return null;
    if (DateTime.now().difference(data.fetchedAt).inMinutes > 5) {
      _cache.remove(representativeId);
      return null;
    }
    return data.detail;
  }

  /// Get prefetched rating statistics if available and fresh.
  dynamic getPrefetchedStats(String representativeId) {
    final data = _cache[representativeId];
    if (data == null) return null;
    if (DateTime.now().difference(data.fetchedAt).inMinutes > 5) {
      return null;
    }
    return data.stats;
  }

  /// Clear prefetch cache for a specific representative (e.g., after rating).
  void invalidate(String representativeId) {
    _cache.remove(representativeId);
  }

  /// Clear entire prefetch cache.
  void clearAll() {
    _cache.clear();
  }
}

class _PrefetchedData {
  final RepresentativeDetail? detail;
  final dynamic stats;
  final DateTime fetchedAt;

  _PrefetchedData({
    this.detail,
    this.stats,
    required this.fetchedAt,
  });
}
