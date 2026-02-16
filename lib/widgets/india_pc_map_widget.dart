import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';
import '../models/representative.dart';
import '../services/representative_service.dart';
import '../pages/representative_detail_page.dart';

class IndiaPCMapWidget extends StatefulWidget {
  final bool isDarkMode;

  const IndiaPCMapWidget({
    super.key,
    required this.isDarkMode,
  });

  @override
  State<IndiaPCMapWidget> createState() => _IndiaPCMapWidgetState();
}

class _IndiaPCMapWidgetState extends State<IndiaPCMapWidget> {
  final RepresentativeService _representativeService = RepresentativeService();
  MapLibreMapController? mapController;
  Symbol? droppedPin;

  @override
  Widget build(BuildContext context) {
    return MapLibreMap(
      styleString: _getMapStyleJson(),
      initialCameraPosition: const CameraPosition(
        target: LatLng(20.5937, 78.9629),
        zoom: 4,
      ),
      onMapCreated: _onMapCreated,
      onMapClick: _onMapClick,
      minMaxZoomPreference: const MinMaxZoomPreference(4, 10),
      cameraTargetBounds: CameraTargetBounds(
        LatLngBounds(
          southwest: const LatLng(6.0, 67.0),
          northeast: const LatLng(38.0, 98.0),
        ),
      ),
      attributionButtonMargins: const Point(-100, -100),
      trackCameraPosition: true,
    );
  }

  void _onMapCreated(MapLibreMapController controller) {
    mapController = controller;
  }

  void _onMapClick(Point<double> point, LatLng coordinates) async {
    if (mapController == null) return;

    try {
      // Remove existing pin
      if (droppedPin != null) {
        await mapController!.removeSymbol(droppedPin!);
        droppedPin = null;
      }

      // Reverse geocode the tapped coordinates via Nominatim
      String? cityName;
      String? stateName;
      try {
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse'
          '?lat=${coordinates.latitude}&lon=${coordinates.longitude}&format=json',
        );
        final response = await http.get(url, headers: {
          'User-Agent': 'RateMyMantri/1.0',
        });
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final address = data['address'];
          if (address != null) {
            cityName = address['city']?? address['town'] ?? address['village'] ?? address['county'] ?? address['state_district'];
            stateName = address['state'];
          }
        }
      } catch (e) {
        debugPrint('Nominatim reverse geocode error: $e');
      }

      // Drop pin
      droppedPin = await mapController!.addSymbol(
        SymbolOptions(
          geometry: coordinates,
          iconImage: 'marker-15',
          iconSize: 2.0,
          iconAnchor: 'bottom',
        ),
      );

      if (!mounted) return;

      // Show bottom sheet with loading state, then fetch representatives
      showModalBottomSheet(
        context: context,
        backgroundColor: widget.isDarkMode
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        isScrollControlled: true,
        builder: (context) => _RepresentativesSheet(
          isDarkMode: widget.isDarkMode,
          coordinates: coordinates,
          pcName: cityName,
          stateName: stateName,
          representativeService: _representativeService,
          onRemovePin: () async {
            if (droppedPin != null && mapController != null) {
              await mapController!.removeSymbol(droppedPin!);
              droppedPin = null;
            }
          },
        ),
      );
    } catch (e) {
      debugPrint('Error handling map tap: $e');
    }
  }

  String _getMapStyleJson() {
    final backgroundColor = widget.isDarkMode ? '#1a1a1a' : '#f8f8f8';

    return '''
{
  "version": 8,
  "sources": {
    "india-pc": {
      "type": "vector",
      "tiles": ["https://IndiaMap.sallytion.qzz.io/{z}/{x}/{y}.pbf"],
      "minzoom": 4,
      "maxzoom": 10
    }
  },
  "layers": [
    {
      "id": "background",
      "type": "background",
      "paint": {
        "background-color": "$backgroundColor"
      }
    },
    {
      "id": "pc-fill",
      "type": "fill",
      "source": "india-pc",
      "source-layer": "india_pc_2024_simplified",
      "paint": {
        "fill-color": [
          "match",
          ["get", "st_name"],
          "UTTAR PRADESH", "#FF6B6B",
          "MAHARASHTRA", "#4ECDC4",
          "BIHAR", "#45B7D1",
          "WEST BENGAL", "#FFA07A",
          "MADHYA PRADESH", "#98D8C8",
          "TAMIL NADU", "#F7B731",
          "RAJASTHAN", "#5F27CD",
          "KARNATAKA", "#00D2D3",
          "GUJARAT", "#FF9FF3",
          "ANDHRA PRADESH", "#54A0FF",
          "ODISHA", "#48DBFB",
          "TELANGANA", "#FFA502",
          "KERALA", "#1DD1A1",
          "JHARKHAND", "#FECA57",
          "ASSAM", "#EE5A6F",
          "PUNJAB", "#C4E538",
          "CHHATTISGARH", "#F8B500",
          "HARYANA", "#FDA7DF",
          "DELHI", "#D980FA",
          "JAMMU & KASHMIR", "#12CBC4",
          "UTTARAKHAND", "#B53471",
          "HIMACHAL PRADESH", "#A3CB38",
          "TRIPURA", "#EA8685",
          "MEGHALAYA", "#778BEB",
          "MANIPUR", "#F19066",
          "NAGALAND", "#63CDDA",
          "GOA", "#CF6A87",
          "ARUNACHAL PRADESH", "#786FA6",
          "MIZORAM", "#F8A5C2",
          "SIKKIM", "#63D471",
          "CHANDIGARH", "#FD79A8",
          "PUDUCHERRY", "#6C5CE7",
          "ANDAMAN & NICOBAR", "#00B894",
          "DADRANAGARHAVELI DAMANDIU", "#FDCB6E",
          "LAKSHADWEEP", "#74B9FF",
          "LADAKH", "#A29BFE",
          "#CCCCCC"
        ],
        "fill-opacity": 0.7
      }
    },
    {
      "id": "pc-outline",
      "type": "line",
      "source": "india-pc",
      "source-layer": "india_pc_2024_simplified",
      "paint": {
        "line-color": "#333333",
        "line-width": 0.5,
        "line-opacity": 0.3
      }
    }
  ]
}
''';
  }
}

// ─── Stateful Bottom Sheet ─────────────────────────────────────────

class _RepresentativesSheet extends StatefulWidget {
  final bool isDarkMode;
  final LatLng coordinates;
  final String? pcName;
  final String? stateName;
  final RepresentativeService representativeService;
  final Future<void> Function() onRemovePin;

  const _RepresentativesSheet({
    required this.isDarkMode,
    required this.coordinates,
    required this.pcName,
    required this.stateName,
    required this.representativeService,
    required this.onRemovePin,
  });

  @override
  State<_RepresentativesSheet> createState() => _RepresentativesSheetState();
}

class _RepresentativesSheetState extends State<_RepresentativesSheet> {
  List<Representative> _representatives = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchRepresentatives();
  }

  Future<void> _fetchRepresentatives() async {
    if (widget.pcName == null || widget.pcName!.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
      return;
    }

    try {
      final result = await widget.representativeService
          .getMyRepresentatives(widget.pcName!);
      if (mounted) {
        setState(() {
          _representatives =
              result['representatives'] as List<Representative>? ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching representatives: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  String _getOfficeLabel(String officeType) {
    switch (officeType) {
      case 'LOK_SABHA':
        return 'MP (Lok Sabha)';
      case 'STATE_ASSEMBLY':
        return 'MLA';
      case 'RAJYA_SABHA':
        return 'MP (Rajya Sabha)';
      case 'VIDHAN_PARISHAD':
        return 'MLC';
      default:
        return officeType;
    }
  }

  Color _getPartyColor(String party) {
    switch (party.toUpperCase()) {
      case 'BJP':
        return const Color(0xFFFF9933);
      case 'INC':
        return const Color(0xFF19AAED);
      case 'AAP':
        return const Color(0xFF0066B3);
      case 'TMC':
        return const Color(0xFF00A651);
      case 'DMK':
        return const Color(0xFFE71C23);
      case 'SP':
        return const Color(0xFFE40612);
      case 'BSP':
        return const Color(0xFF22409A);
      default:
        return const Color(0xFF5A5A5A);
    }
  }

  String _formatName(String name) {
    return name
        .split(' ')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
            : '')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final textColor =
        widget.isDarkMode ? Colors.white : const Color(0xFF222222);
    final subtextColor =
        widget.isDarkMode ? const Color(0xFFB0B0B0) : const Color(0xFF717171);
    final cardBg =
        widget.isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5);

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: subtextColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // Header
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: Color(0xFFFF385C),
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.pcName != null
                              ? _formatName(widget.pcName!)
                              : 'Unknown Location',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        if (widget.stateName != null)
                          Text(
                            _formatName(widget.stateName!),
                            style: TextStyle(
                              fontSize: 14,
                              color: subtextColor,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              // Coordinates row
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 12),
                child: Row(
                  children: [
                    const SizedBox(width: 34),
                    Text(
                      '${widget.coordinates.latitude.toStringAsFixed(4)}°N, '
                      '${widget.coordinates.longitude.toStringAsFixed(4)}°E',
                      style: TextStyle(
                        fontSize: 13,
                        color: subtextColor,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                color: subtextColor.withValues(alpha: 0.2),
                height: 1,
              ),
              const SizedBox(height: 12),
              // Title for representatives list
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Representatives',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF385C),
                        ),
                      )
                    : _hasError || widget.pcName == null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 48,
                                  color: subtextColor.withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Tap on a constituency\nto see representatives',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: subtextColor,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : _representatives.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.person_off_outlined,
                                      size: 48,
                                      color:
                                          subtextColor.withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No representatives found\nfor this constituency',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: subtextColor,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                controller: scrollController,
                                itemCount: _representatives.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                padding:
                                    const EdgeInsets.only(bottom: 20),
                                itemBuilder: (context, index) {
                                  final rep = _representatives[index];
                                  return _buildRepCard(
                                      rep, textColor, subtextColor, cardBg);
                                },
                              ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRepCard(
    Representative rep,
    Color textColor,
    Color subtextColor,
    Color cardBg,
  ) {
    final partyColor = _getPartyColor(rep.party);
    final officeLabel = _getOfficeLabel(rep.officeType);
    final rating = rep.averageRating;

    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RepresentativeDetailPage(
              representativeId: rep.id.toString(),
              isDarkMode: widget.isDarkMode,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: partyColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Avatar / Image
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: partyColor.withValues(alpha: 0.15),
              ),
              clipBehavior: Clip.antiAlias,
              child: rep.imageUrl != null && rep.imageUrl!.isNotEmpty
                  ? Image.network(
                      rep.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          rep.fullName.isNotEmpty
                              ? rep.fullName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: partyColor,
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        rep.fullName.isNotEmpty
                            ? rep.fullName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: partyColor,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatName(rep.fullName),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: partyColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          rep.party,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: partyColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          officeLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: subtextColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (rep.constituency.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${rep.constituency}, ${rep.state}',
                      style: TextStyle(
                        fontSize: 12,
                        color: subtextColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Rating + Arrow
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (rating != null) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded,
                          color: Color(0xFFFFA41C), size: 18),
                      const SizedBox(width: 2),
                      Text(
                        rating.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                Icon(
                  Icons.chevron_right_rounded,
                  color: subtextColor.withValues(alpha: 0.5),
                  size: 22,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
