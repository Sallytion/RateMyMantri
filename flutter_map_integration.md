# Flutter Integration Guide for India Map

## Server Status ✅

Your tile server is **LIVE** at:
- **Main URL**: https://indiamap.sallytion.qzz.io/
- **Tiles**: https://indiamap.sallytion.qzz.io/tiles/{z}/{x}/{y}.pbf
- **TileJSON**: https://indiamap.sallytion.qzz.io/tilejson.json
- **Style**: https://indiamap.sallytion.qzz.io/style.json

## Testing Endpoints

```bash
# Check server status
curl https://indiamap.sallytion.qzz.io/

# Get TileJSON spec
curl https://indiamap.sallytion.qzz.io/tilejson.json

# Get map style
curl https://indiamap.sallytion.qzz.io/style.json
```

## Flutter Setup

### 1. Add dependencies to `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  maplibre_gl: ^0.20.0  # or latest version
  http: ^1.1.0
```

### 2. Android Permissions (`android/app/src/main/AndroidManifest.xml`):

```xml
<manifest>
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
    
    <application>
        <!-- ... your existing config -->
    </application>
</manifest>
```

### 3. Main Map Widget (`lib/india_map_page.dart`):

```dart
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class IndiaMapPage extends StatefulWidget {
  const IndiaMapPage({Key? key}) : super(key: key);

  @override
  State<IndiaMapPage> createState() => _IndiaMapPageState();
}

class _IndiaMapPageState extends State<IndiaMapPage> {
  MapLibreMapController? _mapController;
  LatLng? _selectedLocation;
  
  // India center coordinates
  static const LatLng _indiaCenter = LatLng(20.5937, 78.9629);
  
  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
    
    // Listen for map taps
    controller.onFeatureTapped.add(_onFeatureTapped);
  }
  
  void _onMapClick(Point<double> point, LatLng coordinates) {
    setState(() {
      _selectedLocation = coordinates;
    });
    
    print('📍 User tapped at:');
    print('   Latitude: ${coordinates.latitude}');
    print('   Longitude: ${coordinates.longitude}');
    
    // Send to your backend
    _sendLocationToBackend(coordinates);
    
    // Show on UI
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Location: ${coordinates.latitude.toStringAsFixed(4)}, '
          '${coordinates.longitude.toStringAsFixed(4)}',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  void _onFeatureTapped(dynamic featureId, Point<double> point, LatLng coordinates) {
    print('Feature tapped: $featureId at $coordinates');
    _onMapClick(point, coordinates);
  }
  
  Future<void> _sendLocationToBackend(LatLng location) async {
    // Replace with your actual API endpoint
    final apiUrl = 'https://your-backend-api.com/location';
    
    try {
      // Example using http package
      // final response = await http.post(
      //   Uri.parse(apiUrl),
      //   headers: {'Content-Type': 'application/json'},
      //   body: jsonEncode({
      //     'latitude': location.latitude,
      //     'longitude': location.longitude,
      //     'timestamp': DateTime.now().toIso8601String(),
      //   }),
      // );
      
      print('Would send to backend: ${location.latitude}, ${location.longitude}');
    } catch (e) {
      print('Error sending location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('India Map'),
        backgroundColor: Colors.blue,
      ),
      body: Stack(
        children: [
          MapLibreMap(
            styleString: 'https://indiamap.sallytion.qzz.io/style.json',
            initialCameraPosition: const CameraPosition(
              target: _indiaCenter,
              zoom: 4.0,
            ),
            onMapCreated: _onMapCreated,
            onMapClick: _onMapClick,
            myLocationEnabled: false,
            trackCameraPosition: true,
            compassEnabled: true,
            rotateGesturesEnabled: true,
            scrollGesturesEnabled: true,
            tiltGesturesEnabled: true,
            zoomGesturesEnabled: true,
            minMaxZoomPreference: const MinMaxZoomPreference(0, 14),
          ),
          
          // Display selected coordinates
          if (_selectedLocation != null)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selected Location:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Lat: ${_selectedLocation!.latitude.toStringAsFixed(6)}'),
                      Text('Lng: ${_selectedLocation!.longitude.toStringAsFixed(6)}'),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
```

### 4. Use in your app (`lib/main.dart`):

```dart
import 'package:flutter/material.dart';
import 'india_map_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'India Map',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const IndiaMapPage(),
    );
  }
}
```

## Map Features

- ✅ Vector tiles (very lightweight, ~432KB total)
- ✅ India boundary layer with 1092 points
- ✅ All Indian states and constituencies
- ✅ CORS enabled for web/mobile access
- ✅ Tap to get coordinates
- ✅ Zoom levels 0-14
- ✅ Auto-centered on India

## Data Available

Your map includes these fields for each feature:
- State name, code, LGD code
- PC (Parliamentary Constituency) name, ID, number
- Poll dates and phases
- Geographic boundaries (SHAPE_Area, SHAPE_Length)

Access these in Flutter via the `onFeatureTapped` callback.