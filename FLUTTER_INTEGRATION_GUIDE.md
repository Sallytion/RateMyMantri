# Flutter Integration Guide - India PC Vector Tiles

## Quick Summary for Frontend Team

**What you're integrating:** Interactive map showing India's 543 Parliamentary Constituencies with state-wise color coding.

**Server URL:** `https://IndiaMap.sallytion.qzz.io`

**Tile URL Pattern:** `https://IndiaMap.sallytion.qzz.io/{z}/{x}/{y}.pbf`

---

## 📦 Required Package

Add to your `pubspec.yaml`:

```yaml
dependencies:
  maplibre_gl: ^0.18.0  # or latest version
```

Run:
```bash
flutter pub get
```

---

## 🗺️ Key Configuration Values

Copy these exactly:

| Parameter | Value |
|-----------|-------|
| **Tile URL** | `https://IndiaMap.sallytion.qzz.io/{z}/{x}/{y}.pbf` |
| **Source Layer Name** | `india_pc_2024_simplified` |
| **Min Zoom** | 4 |
| **Max Zoom** | 10 |
| **Initial Center** | Latitude: `20.5937`, Longitude: `78.9629` |
| **Initial Zoom** | 4 |
| **Tile Format** | PBF (Protocol Buffer Format) - Vector Tiles |

---

## 🎨 Available Data Fields

Each constituency polygon has these properties:

| Field | Type | Example | Description |
|-------|------|---------|-------------|
| `pc_name` | String | `"Mumbai North"` | Constituency name |
| `st_name` | String | `"MAHARASHTRA"` | State name (ALL CAPS) |
| `pc_no` | Number | `23` | Constituency number within state |
| `pc_id` | Number | `2723` | Unique constituency ID |
| `st_code` | String | `"27"` | State code |
| `Phase` | String | `"5TH PHASE"` | Election phase |
| `Date_of_Poll` | String | `"5/20/2024"` | Polling date |
| `OBJECTID` | Number | `425` | Feature object ID |

---

## 📝 Basic Flutter Implementation

### Step 1: Basic Map Setup

```dart
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class IndiaPCMapScreen extends StatefulWidget {
  @override
  _IndiaPCMapScreenState createState() => _IndiaPCMapScreenState();
}

class _IndiaPCMapScreenState extends State<IndiaPCMapScreen> {
  MapLibreMapController? mapController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MapLibreMap(
        styleString: _getMapStyleJson(),
        initialCameraPosition: CameraPosition(
          target: LatLng(20.5937, 78.9629), // Center of India
          zoom: 4,
        ),
        onMapCreated: _onMapCreated,
        onMapClick: _onMapClick,
      ),
    );
  }

  void _onMapCreated(MapLibreMapController controller) {
    mapController = controller;
  }

  void _onMapClick(Point<double> point, LatLng coordinates) async {
    // Handle constituency clicks - see "Click Handling" section below
  }

  String _getMapStyleJson() {
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
        "background-color": "#f8f8f8"
      }
    },
    {
      "id": "pc-fill",
      "type": "fill",
      "source": "india-pc",
      "source-layer": "india_pc_2024_simplified",
      "paint": {
        "fill-color": "#4a90e2",
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
        "line-width": 0.8
      }
    }
  ]
}
''';
  }
}
```

---

## 🎨 State-wise Color Coding (Like viewer.html)

To get the same colorful state-wise styling as the HTML viewer:

```dart
String _getMapStyleJson() {
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
        "background-color": "#f8f8f8"
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
        "line-width": 0.8
      }
    }
  ]
}
''';
}
```

---

## 👆 Click Handling - Get Constituency Info

```dart
void _onMapClick(Point<double> point, LatLng coordinates) async {
  if (mapController == null) return;

  // Query features at clicked point
  final features = await mapController!.queryRenderedFeatures(
    point,
    ['pc-fill'], // Layer ID to query
    null,
  );

  if (features.isNotEmpty) {
    final properties = features.first.properties;
    
    // Extract constituency data
    final String pcName = properties['pc_name'] ?? 'Unknown';
    final String stateName = properties['st_name'] ?? 'Unknown';
    final String pcNo = properties['pc_no']?.toString() ?? 'N/A';
    final String phase = properties['Phase'] ?? 'N/A';
    final String pollDate = properties['Date_of_Poll'] ?? 'N/A';
    final int pcId = properties['pc_id'] ?? 0;
    
    // Show the data (example: in a bottom sheet)
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pcName,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('State: $stateName'),
            Text('Constituency No: $pcNo'),
            Text('Phase: $phase'),
            Text('Poll Date: $pollDate'),
          ],
        ),
      ),
    );
  }
}
```

---

## 🎯 Adding Highlight on Click

To highlight the clicked constituency (yellow overlay):

```dart
class _IndiaPCMapScreenState extends State<IndiaPCMapScreen> {
  int? selectedPcId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MapLibreMap(
        styleString: _getMapStyleJsonWithHighlight(),
        // ... rest of config
      ),
    );
  }

  void _onMapClick(Point<double> point, LatLng coordinates) async {
    final features = await mapController!.queryRenderedFeatures(
      point,
      ['pc-fill'],
      null,
    );

    if (features.isNotEmpty) {
      final properties = features.first.properties;
      final int pcId = properties['pc_id'] ?? 0;
      
      setState(() {
        selectedPcId = pcId;
      });

      // Update the highlight layer filter
      mapController!.setFilter(
        'pc-highlight',
        ['==', ['get', 'pc_id'], pcId],
      );
      
      // Show info...
    }
  }

  String _getMapStyleJsonWithHighlight() {
    return '''
{
  "version": 8,
  "sources": { ... },
  "layers": [
    {
      "id": "background",
      "type": "background",
      "paint": {
        "background-color": "#f8f8f8"
      }
    },
    {
      "id": "pc-fill",
      "type": "fill",
      "source": "india-pc",
      "source-layer": "india_pc_2024_simplified",
      "paint": {
        "fill-color": [...state colors...],
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
        "line-width": 0.8
      }
    },
    {
      "id": "pc-highlight",
      "type": "fill",
      "source": "india-pc",
      "source-layer": "india_pc_2024_simplified",
      "paint": {
        "fill-color": "#FFFF00",
        "fill-opacity": 0.9
      },
      "filter": ["==", ["get", "pc_id"], 0]
    }
  ]
}
''';
  }
}
```

---

## 🔍 Important Notes

### Zoom Levels
- **Tiles only exist for zoom 4-10**
- Below zoom 4: No tiles available
- Above zoom 10: Uses zoom 10 tiles (may look pixelated)

### Source Layer Name
- **CRITICAL:** Must use `"india_pc_2024_simplified"` as source-layer
- This is NOT the source name (which is `"india-pc"`)
- Source = where tiles come from
- Source-layer = which layer within the tiles to render

### State Names
- All state names in data are **UPPERCASE**
- Example: `"MAHARASHTRA"` not `"Maharashtra"`
- Important for color matching

### Network Security (Android)
Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<application
    android:usesCleartextTraffic="true">
    <!-- Your existing configuration -->
</application>
```

Or add network security config if using HTTPS only.

### iOS Configuration
Add to `ios/Runner/Info.plist` if needed:
```xml
<key>io.flutter.embedded_views_preview</key>
<true/>
```

---

## 📚 Alternative Approach: Using JSON Style File

Create `assets/map_style.json`:

```json
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
    // ... your layers here
  ]
}
```

Then in Flutter:
```dart
MapLibreMap(
  styleString: await rootBundle.loadString('assets/map_style.json'),
  // ...
)
```

---

## 🧪 Testing Checklist

- [ ] Map loads centered on India
- [ ] Constituencies visible at zoom level 5-8
- [ ] Different colors for different states
- [ ] Click on constituency shows info
- [ ] Clicked constituency highlights in yellow
- [ ] Pan and zoom work smoothly
- [ ] No tiles beyond India boundaries is normal
- [ ] Zoom 4-10 range enforced

---

## 🆘 Troubleshooting

**Problem:** Blank map
- Check internet connection
- Verify URL: `https://IndiaMap.sallytion.qzz.io/{z}/{x}/{y}.pbf`
- Check console for network errors
- Ensure zoom level is between 4-10

**Problem:** No features visible
- Verify source-layer name: `india_pc_2024_simplified`
- Check you're zoomed into India (not defaulting to 0,0)

**Problem:** Wrong colors
- State names must be UPPERCASE
- Check the match expression in fill-color

**Problem:** Can't click features
- Ensure layer ID in `queryRenderedFeatures` matches your fill layer ID
- Check that the layer is actually rendered

---

## 📞 Quick Reference

```dart
// Tile URL
"https://IndiaMap.sallytion.qzz.io/{z}/{x}/{y}.pbf"

// Source-layer name
"india_pc_2024_simplified"

// India center
LatLng(20.5937, 78.9629)

// Zoom range
4 to 10

// Query features on click
await mapController.queryRenderedFeatures(
  point,
  ['pc-fill'],
  null,
);
```

---

## 📦 Complete Working Example

See the attached `viewer.html` file for a complete working web implementation that your Flutter app should replicate. The Flutter code above mirrors that implementation.

**Key takeaway:** The viewer.html exactly shows what your Flutter app should display - same colors, same interactions, same data.

---

That's it! Your frontend team now has everything needed to integrate the India PC tiles. 🎉
