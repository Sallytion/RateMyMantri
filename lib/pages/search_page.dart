import 'dart:async';
import 'package:flutter/material.dart';
import '../models/representative.dart';
import '../services/representative_service.dart';
import 'representative_detail_page.dart';
import '../widgets/india_pc_map_widget.dart';

class SearchPage extends StatefulWidget {
  final bool isDarkMode;

  const SearchPage({super.key, required this.isDarkMode});

  /// Global key so MainScreen can call methods on the state.
  static final GlobalKey<_SearchPageState> globalKey = GlobalKey<_SearchPageState>();

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final RepresentativeService _representativeService = RepresentativeService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // ─── Static in-memory cache (survives widget rebuilds) ─────────
  static List<Representative>? _cachedResults;
  static String? _cachedQuery;

  /// Call this to force-clear cached search data.
  static void clearCache() {
    _cachedResults = null;
    _cachedQuery = null;
  }
  
  List<Representative> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounceTimer;

  /// Called from MainScreen when user double-taps the search nav tab.
  void focusSearchBar() {
    _searchFocusNode.requestFocus();
  }

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus && _searchController.text.isEmpty) {
        setState(() {
          _searchResults = [];
        });
      }
    });

    // Restore cached search query & results if available
    if (_cachedQuery != null && _cachedQuery!.isNotEmpty) {
      _searchController.text = _cachedQuery!;
      if (_cachedResults != null) {
        _searchResults = _cachedResults!;
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      _cachedQuery = null;
      _cachedResults = null;
      _debounceTimer?.cancel();
      return;
    }

    _debounceTimer?.cancel();
    setState(() {
      _isSearching = true;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final response = await _representativeService.searchRepresentatives(
          query,
          limit: 50,
        );
        final results = (response['results'] as List?)?.cast<Representative>() ?? [];

        if (mounted) {
          _cachedQuery = query;
          _cachedResults = results;
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isSearching = false;
          });
        }
      }
    });
  }

  void _selectRepresentative(Representative rep) {
    _searchFocusNode.unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RepresentativeDetailPage(
          representativeId: rep.id.toString(),
          isDarkMode: widget.isDarkMode,
        ),
      ),
    );  }

  String _formatCurrency(int amount) {
    if (amount >= 10000000) {
      return '${(amount / 10000000).toStringAsFixed(1)}Cr';
    } else if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toString();
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.isDarkMode ? const Color(0xFF121212) : const Color(0xFFFAFAFA);
    final cardColor = widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : const Color(0xFF222222);
    final subtextColor = widget.isDarkMode ? const Color(0xFFB0B0B0) : const Color(0xFF717171);
    
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          // Enhanced Search Header
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: widget.isDarkMode ? 0.3 : 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Find Representatives',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Search by name, constituency, or state',
                      style: TextStyle(
                        color: subtextColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Search Input
                    Container(
                      decoration: BoxDecoration(
                        color: widget.isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _searchFocusNode.hasFocus
                              ? const Color(0xFFFF385C)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onChanged: _onSearchChanged,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Start typing to search...',
                          hintStyle: TextStyle(
                            color: subtextColor.withValues(alpha: 0.6),
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Icon(
                              Icons.search_rounded,
                              color: _searchFocusNode.hasFocus
                                  ? const Color(0xFFFF385C)
                                  : subtextColor,
                              size: 24,
                            ),
                          ),
                          suffixIcon: _isSearching
                              ? const Padding(
                                  padding: EdgeInsets.all(14.0),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF385C)),
                                    ),
                                  ),
                                )
                              : _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: subtextColor.withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.close,
                                          color: subtextColor,
                                          size: 16,
                                        ),
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        _cachedQuery = null;
                                        _cachedResults = null;
                                        setState(() {
                                          _searchResults = [];
                                        });
                                      },
                                    )
                                  : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Results Section
          Expanded(
            child: _searchController.text.isEmpty
                ? IndiaPCMapWidget(isDarkMode: widget.isDarkMode)
                : _searchResults.isEmpty && !_isSearching
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: widget.isDarkMode
                                    ? const Color(0xFF2A2A2A)
                                    : const Color(0xFFF0F0F0),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.person_off_outlined,
                                size: 64,
                                color: subtextColor.withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'No Results Found',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try adjusting your search',
                              style: TextStyle(
                                fontSize: 15,
                                color: subtextColor,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final rep = _searchResults[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: widget.isDarkMode ? 0.3 : 0.06),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => _selectRepresentative(rep),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      // Profile Image
                                      Container(
                                        width: 68,
                                        height: 68,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: widget.isDarkMode
                                                ? const Color(0xFF3A3A3A)
                                                : const Color(0xFFE0E0E0),
                                            width: 2,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(14),
                                          child: rep.imageUrl != null && rep.imageUrl!.isNotEmpty
                                              ? Image.network(
                                                  rep.imageUrl!,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) =>
                                                      _buildPlaceholderAvatar(rep, textColor),
                                                )
                                              : _buildPlaceholderAvatar(rep, textColor),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              rep.fullName,
                                              style: TextStyle(
                                                color: textColor,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 17,
                                                letterSpacing: -0.3,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.location_on_rounded,
                                                  size: 14,
                                                  color: subtextColor,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    '${rep.constituency}, ${rep.state}',
                                                    style: TextStyle(
                                                      color: subtextColor,
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                if (rep.averageRating != null) ...[
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFFFB800).withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(
                                                          Icons.star_rounded,
                                                          size: 14,
                                                          color: Color(0xFFFFB800),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          rep.averageRating!.toStringAsFixed(1),
                                                          style: const TextStyle(
                                                            color: Color(0xFFFFB800),
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w700,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 2),
                                                        Text(
                                                          '(${rep.totalRatings ?? 0})',
                                                          style: TextStyle(
                                                            color: subtextColor,
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                ],
                                                if (rep.netWorth != null)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      '₹${_formatCurrency(rep.netWorth!)}',
                                                      style: const TextStyle(
                                                        color: Color(0xFF4CAF50),
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Party Badge
                                      Container(
                                        constraints: const BoxConstraints(maxWidth: 80),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              const Color(0xFFFF385C),
                                              const Color(0xFFFF385C).withValues(alpha: 0.8),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          rep.party.length > 8 ? '${rep.party.substring(0, 8)}...' : rep.party,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.3,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
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

  Widget _buildPlaceholderAvatar(Representative rep, Color textColor) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF385C),
            const Color(0xFFFF385C).withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          rep.fullName.isNotEmpty ? rep.fullName[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 24,
          ),
        ),
      ),
    );
  }
}
