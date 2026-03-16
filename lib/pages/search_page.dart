import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/theme_provider.dart';
import '../models/representative.dart';
import '../services/representative_service.dart';
import '../services/prefetch_service.dart';
import '../services/theme_service.dart';
import '../services/language_service.dart';
import '../utils/formatters.dart';
import '../utils/party_utils.dart';
import '../utils/widgets/placeholder_avatar.dart';
import '../widgets/skeleton_widgets.dart';
import 'representative_detail_page.dart';
import '../widgets/india_pc_map_widget.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  // ignore: library_private_types_in_public_api
  static final GlobalKey<_SearchPageState> globalKey = GlobalKey<_SearchPageState>();
  static void clearCache() => _SearchPageState.clearCache();

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final RepresentativeService _representativeService = RepresentativeService();
  final PrefetchService _prefetchService = PrefetchService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool get isDarkMode => context.read<ThemeProvider>().isDarkMode;

  static List<Representative>? _cachedResults;
  static String? _cachedQuery;

  static void clearCache() {
    _cachedResults = null;
    _cachedQuery = null;
  }

  List<Representative> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounceTimer;

  void focusSearchBar() {
    _searchFocusNode.requestFocus();
  }

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus && _searchController.text.isEmpty) {
        setState(() => _searchResults = []);
      }
    });
    if (_cachedQuery != null && _cachedQuery!.isNotEmpty) {
      _searchController.text = _cachedQuery!;
      if (_cachedResults != null) _searchResults = _cachedResults!;
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
      setState(() { _searchResults = []; _isSearching = false; });
      _cachedQuery = null;
      _cachedResults = null;
      _debounceTimer?.cancel();
      return;
    }
    _debounceTimer?.cancel();
    setState(() => _isSearching = true);
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final response = await _representativeService.searchRepresentatives(
          LanguageService.translitToLatin(query), limit: 50,
        );
        final results = (response['results'] as List?)?.cast<Representative>() ?? [];
        if (mounted) {
          _cachedQuery = query;
          _cachedResults = results;
          setState(() { _searchResults = results; _isSearching = false; });
        }
      } catch (e) {
        if (mounted) setState(() => _isSearching = false);
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
          isDarkMode: isDarkMode,
        ),
      ),
    );
  }

  String _formatCurrency(int amount) {
    return Formatters.formatCurrency(amount, showSymbol: false);
  }

  String? _validatedImageUrl(String? rawUrl) {
    if (rawUrl == null) return null;
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.isAbsolute) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;

    // Skip image formats that are frequently unsupported by Android decoders.
    final lowerPath = uri.path.toLowerCase();
    const unsupportedExts = ['.svg', '.avif', '.heic', '.heif', '.ico'];
    final hasUnsupportedExt = unsupportedExts.any(lowerPath.endsWith);
    if (hasUnsupportedExt) return null;

    return uri.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<ThemeProvider>().isDarkMode;
    final bg = isDarkMode ? ThemeService.bgAlt : ThemeService.lightBg;
    final textColor = isDarkMode ? Colors.white : ThemeService.lightText;
    final subtextColor = isDarkMode ? const Color(0xFFB0B0B0) : ThemeService.lightSubtext;
    final hasFocus = _searchFocusNode.hasFocus;

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          // ── Header ─────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LanguageService.tr('search'),
                    style: TextStyle(
                      color: textColor,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ── Search bar ──────────────────────────────────
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isDarkMode ? ThemeService.bgElev : ThemeService.lightCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: hasFocus
                            ? ThemeService.accent
                            : isDarkMode ? ThemeService.bgBorder : ThemeService.lightBorder,
                        width: hasFocus ? 1.5 : 1,
                      ),
                      boxShadow: hasFocus
                          ? [BoxShadow(
                              color: ThemeService.accent.withValues(alpha: 0.06),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            )]
                          : [],
                    ),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onChanged: _onSearchChanged,
                      style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: LanguageService.tr('search_hint'),
                        hintStyle: TextStyle(color: subtextColor.withValues(alpha: 0.5), fontSize: 15),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 14, right: 10),
                          child: Icon(
                            Icons.search_rounded,
                            color: hasFocus ? ThemeService.accent : subtextColor,
                            size: 22,
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(minWidth: 44),
                        suffixIcon: _isSearching
                            ? Padding(
                                padding: const EdgeInsets.all(14),
                                child: SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(ThemeService.accent),
                                  ),
                                ),
                              )
                            : _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.close_rounded, color: subtextColor, size: 20),
                                    onPressed: () {
                                      _searchController.clear();
                                      _cachedQuery = null;
                                      _cachedResults = null;
                                      setState(() => _searchResults = []);
                                    },
                                  )
                                : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Results / map / empty ──────────────────────────────
          Expanded(
            child: _searchController.text.isEmpty
                ? IndiaPCMapWidget(isDarkMode: isDarkMode)
                : _isSearching && _searchResults.isEmpty
                    ? _buildLoadingState(isDarkMode)
                    : _searchResults.isEmpty
                        ? _buildNoResults(textColor, subtextColor)
                        : _buildResultsList(textColor, subtextColor, isDarkMode),
          ),
        ],
      ),
    );
  }

  // ─── Loading shimmer ─────────────────────────────────────────────
  Widget _buildLoadingState(bool isDarkMode) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 20),
      itemCount: 5,
      itemBuilder: (context, index) {
        return SearchResultSkeleton(isDarkMode: isDarkMode);
      },
    );
  }

  // ─── No results ──────────────────────────────────────────────────
  Widget _buildNoResults(Color textColor, Color subtextColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: isDarkMode ? ThemeService.bgElev : ThemeService.pastelLavender,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search_off_rounded, size: 40,
                color: isDarkMode ? Colors.white24 : ThemeService.lightSubtext.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 20),
            Text(
              LanguageService.tr('no_results'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textColor),
            ),
            const SizedBox(height: 6),
            Text(
              LanguageService.tr('try_adjusting_search'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: subtextColor, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Results list ────────────────────────────────────────────────
  Widget _buildResultsList(Color textColor, Color subtextColor, bool isDarkMode) {
    final listBg = isDarkMode ? ThemeService.bgElev : ThemeService.lightCard;
    final borderColor = isDarkMode ? ThemeService.bgBorder : ThemeService.lightBorder;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      children: [
        Container(
          decoration: BoxDecoration(
            color: listBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: List.generate(_searchResults.length, (index) {
              final rep = _searchResults[index];
              _prefetchService.prefetch(rep.id.toString());

              return Column(
                children: [
                  _buildResultCard(rep, textColor, subtextColor, isDarkMode),
                  if (index != _searchResults.length - 1)
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: borderColor,
                      indent: 14,
                      endIndent: 14,
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  // ─── Individual result card ──────────────────────────────────────
  Widget _buildResultCard(
    Representative rep, Color textColor, Color subtextColor, bool isDarkMode,
  ) {
    final partyColor = PartyUtils.getPartyColor(rep.party);
    final tagBg = isDarkMode
        ? const Color(0xFF3A392E)
        : const Color(0xFFE8DFC7);
    final tagText = isDarkMode ? const Color(0xFFD5C28A) : const Color(0xFF6E5A25);
    final location = '${rep.constituency}, ${rep.state}'.trim();
    final safeImageUrl = _validatedImageUrl(rep.imageUrl);

    return GestureDetector(
      onTap: () => _selectRepresentative(rep),
      onLongPress: () => _prefetchService.prefetch(rep.id.toString()),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row with name/location and right-side net worth price tag.
            Stack(
              clipBehavior: Clip.none,
              children: [
                if (rep.netWorth != null)
                  Positioned(
                    right: -14,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: tagBg,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                        ),
                      ),
                      child: Text(
                        '\u20B9${_formatCurrency(rep.netWorth!)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: tagText,
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.only(right: rep.netWorth != null ? 128 : 0),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: partyColor.withValues(alpha: 0.45), width: 2),
                        ),
                        child: Hero(
                          tag: 'rep_avatar_${rep.id}',
                          child: ClipOval(
                            child: safeImageUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: safeImageUrl,
                                    fit: BoxFit.cover,
                                    width: 54,
                                    height: 54,
                                    memCacheWidth: 108,
                                    memCacheHeight: 108,
                                    placeholder: (_, __) => Shimmer.fromColors(
                                      baseColor: Colors.grey[300]!,
                                      highlightColor: Colors.grey[100]!,
                                      child: Container(color: ThemeService.lightCard),
                                    ),
                                    errorWidget: (_, __, ___) => PlaceholderAvatar(name: rep.fullName),
                                  )
                                : PlaceholderAvatar(name: rep.fullName),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  fit: FlexFit.loose,
                                  child: Text(
                                    rep.fullName,
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      letterSpacing: -0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: partyColor.withValues(alpha: 0.8), width: 1.2),
                                  ),
                                  child: Text(
                                    rep.party.length > 12 ? '${rep.party.substring(0, 12)}..' : rep.party,
                                    style: TextStyle(
                                      color: partyColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(Icons.location_on_rounded, size: 12,
                                    color: subtextColor.withValues(alpha: 0.65)),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    location,
                                    style: TextStyle(color: subtextColor, fontSize: 12, height: 1.2),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
