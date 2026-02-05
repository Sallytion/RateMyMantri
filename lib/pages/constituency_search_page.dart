import 'package:flutter/material.dart';
import 'dart:async';
import '../models/constituency.dart';
import '../services/constituency_service.dart';

class ConstituencySearchPage extends StatefulWidget {
  final bool isDarkMode;
  final Constituency? currentConstituency;

  const ConstituencySearchPage({
    super.key,
    required this.isDarkMode,
    this.currentConstituency,
  });

  @override
  State<ConstituencySearchPage> createState() => _ConstituencySearchPageState();
}

class _ConstituencySearchPageState extends State<ConstituencySearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final ConstituencyService _constituencyService = ConstituencyService();
  final FocusNode _searchFocusNode = FocusNode();

  Timer? _debounceTimer;
  List<Constituency> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  Constituency? _selectedConstituency;

  @override
  void initState() {
    super.initState();
    _selectedConstituency = widget.currentConstituency;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }

    if (value.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      _performSearch(value);
    });
  }

  Future<void> _performSearch(String query) async {
    final result = await _constituencyService.searchConstituencies(query);

    if (mounted) {
      setState(() {
        _searchResults = result['constituencies'] as List<Constituency>;
        _isSearching = false;
      });
    }
  }

  Future<void> _setConstituency(Constituency constituency) async {
    setState(() {
      _isSearching = true;
    });

    final result = await _constituencyService.setCurrentConstituency(
      constituency.id,
    );

    if (mounted) {
      setState(() {
        _isSearching = false;
      });

      if (result['success'] == true) {
        _selectedConstituency = result['constituency'] as Constituency?;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Constituency set to ${constituency.name}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Return the selected constituency to previous screen
        Navigator.pop(context, _selectedConstituency);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to set constituency'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDarkMode
        ? const Color(0xFF1A1A1A)
        : const Color(0xFFF9F9F9);
    final textColor = widget.isDarkMode
        ? Colors.white
        : const Color(0xFF222222);
    final cardColor = widget.isDarkMode
        ? const Color(0xFF2A2A2A)
        : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Select Constituency',
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: cardColor,
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Search for your constituency...',
                hintStyle: TextStyle(color: textColor.withValues(alpha: 0.5)),
                prefixIcon: Icon(
                  Icons.search,
                  color: textColor.withValues(alpha: 0.7),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: textColor.withValues(alpha: 0.7),
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                            _hasSearched = false;
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: widget.isDarkMode
                    ? const Color(0xFF3A3A3A)
                    : const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.deepPurple, width: 2),
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),

          // Current Constituency (if set)
          if (_selectedConstituency != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.deepPurple, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Constituency',
                          style: TextStyle(
                            fontSize: 12,
                            color: textColor.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedConstituency!.name,
                          style: TextStyle(
                            fontSize: 16,
                            color: textColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _selectedConstituency!.displayType,
                          style: TextStyle(
                            fontSize: 13,
                            color: textColor.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Search Results
          Expanded(
            child: _isSearching
                ? Center(
                    child: CircularProgressIndicator(color: Colors.deepPurple),
                  )
                : !_hasSearched
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 64,
                          color: textColor.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Search for your constituency',
                          style: TextStyle(
                            fontSize: 16,
                            color: textColor.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  )
                : _searchResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: textColor.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No constituencies found',
                          style: TextStyle(
                            fontSize: 16,
                            color: textColor.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _searchResults.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final constituency = _searchResults[index];
                      final isSelected =
                          _selectedConstituency?.id == constituency.id;

                      return InkWell(
                        onTap: () => _setConstituency(constituency),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.deepPurple.withValues(alpha: 0.1)
                                : cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.deepPurple
                                  : textColor.withValues(alpha: 0.1),
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.deepPurple
                                      : Colors.deepPurple.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.location_on,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.deepPurple,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      constituency.name,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      constituency.displayType,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: textColor.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.deepPurple,
                                  size: 24,
                                ),
                            ],
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
}
