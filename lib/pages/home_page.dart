import 'package:flutter/material.dart';
import '../models/constituency.dart';
import '../services/constituency_service.dart';
import 'constituency_search_page.dart';

class HomePage extends StatefulWidget {
  final bool isDarkMode;

  const HomePage({super.key, required this.isDarkMode});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ConstituencyService _constituencyService = ConstituencyService();
  Constituency? _currentConstituency;
  bool _isLoadingConstituency = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentConstituency();
  }

  Future<void> _loadCurrentConstituency() async {
    final constituency = await _constituencyService.getCurrentConstituency();
    if (mounted) {
      setState(() {
        _currentConstituency = constituency;
        _isLoadingConstituency = false;
      });
    }
  }

  Future<void> _navigateToConstituencySearch() async {
    final result = await Navigator.push<Constituency>(
      context,
      MaterialPageRoute(
        builder: (context) => ConstituencySearchPage(
          isDarkMode: widget.isDarkMode,
          currentConstituency: _currentConstituency,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _currentConstituency = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isDarkMode
          ? const Color(0xFF1A1A1A)
          : const Color(0xFFF7F7F7),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Rate My Mantri',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: widget.isDarkMode
                            ? Colors.white
                            : const Color(0xFF222222),
                      ),
                    ),
                    InkWell(
                      onTap: _navigateToConstituencySearch,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: widget.isDarkMode
                              ? const Color(0xFF2A2A2A)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: widget.isDarkMode
                                ? const Color(0xFF3A3A3A)
                                : const Color(0xFFDDDDDD),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 16,
                              color: widget.isDarkMode
                                  ? Colors.white
                                  : const Color(0xFF222222),
                            ),
                            const SizedBox(width: 4),
                            _isLoadingConstituency
                                ? SizedBox(
                                    width: 80,
                                    height: 14,
                                    child: Center(
                                      child: SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.deepPurple,
                                        ),
                                      ),
                                    ),
                                  )
                                : Text(
                                    _currentConstituency?.name ??
                                        'Set Location',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: widget.isDarkMode
                                          ? Colors.white
                                          : const Color(0xFF222222),
                                    ),
                                  ),
                            const SizedBox(width: 4),
                            const Icon(Icons.keyboard_arrow_down, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Hero Card - Politician
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF5A5A5A), Color(0xFF3A3A3A)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: 0,
                        bottom: 0,
                        top: 0,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                          child: Container(
                            width: 180,
                            color: const Color(0xFF4A4A4A),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Arjun Sharma, MP',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Manik Majaan Rating',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFFCCCCCC),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Text(
                                  '4.2',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ...List.generate(
                                  4,
                                  (index) => const Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 20,
                                  ),
                                ),
                                const Icon(
                                  Icons.star_half,
                                  color: Colors.amber,
                                  size: 20,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF7A59),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Rate Performance',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Constituency Overview
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Constituency Overview',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: widget.isDarkMode
                        ? Colors.white
                        : const Color(0xFF222222),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 140,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  children: [
                    _buildOverviewCard(
                      'Issues',
                      Icons.report_problem,
                      const Color(0xFFE57373),
                    ),
                    const SizedBox(width: 12),
                    _buildOverviewCard(
                      'Events',
                      Icons.event,
                      const Color(0xFF64B5F6),
                    ),
                    const SizedBox(width: 12),
                    _buildOverviewCard(
                      'Rank',
                      Icons.trending_up,
                      const Color(0xFF81C784),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // News Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'News',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: widget.isDarkMode
                        ? Colors.white
                        : const Color(0xFF222222),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 280,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  children: [
                    _buildNewsCard(
                      'Hemalitan annear hanors in tritarance of batigu',
                      '2 hours ago',
                    ),
                    const SizedBox(width: 12),
                    _buildNewsCard(
                      'Movcka straumiz introduces new policy',
                      '1 hours ago',
                    ),
                    const SizedBox(width: 12),
                    _buildNewsCard(
                      'Infrastructure development reaches milestone',
                      '5 hours ago',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewCard(String title, IconData icon, Color color) {
    return Container(
      width: 140,
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: widget.isDarkMode ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 40,
            child: Container(
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Icon(icon, size: 48, color: color),
            ),
          ),
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: widget.isDarkMode
                    ? Colors.white
                    : const Color(0xFF222222),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsCard(String headline, String time) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: widget.isDarkMode ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: const Center(
              child: Icon(Icons.image, size: 48, color: Color(0xFFBDBDBD)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'News',
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.isDarkMode
                        ? const Color(0xFFB0B0B0)
                        : const Color(0xFF717171),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  headline,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: widget.isDarkMode
                        ? Colors.white
                        : const Color(0xFF222222),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.isDarkMode
                        ? const Color(0xFF717171)
                        : const Color(0xFF999999),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
