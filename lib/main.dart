// pubspec.yaml dependencies yang diperlukan:
/*
dependencies:
  flutter:
    sdk: flutter
  flutter_map: ^6.1.0
  latlong2: ^0.8.1
  http: ^1.1.0
  geolocator: ^10.1.0
  permission_handler: ^11.0.1
*/

import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Map Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController mapController = MapController();
  LatLng? currentLocation;
  bool isLoading = false;
  LatLng currentCenter = LatLng(-6.2088, 106.8456); // Jakarta default
  double currentZoom = 12.0;
  String alamat = "";

  double minZoom = 0.0;
  double maxZoom = 18.0;

  // Beberapa lokasi marker contoh di Jakarta
  final List<LatLng> markerLocations = [
    LatLng(-6.2088, 106.8456), // Jakarta Pusat
    LatLng(-6.1751, 106.8650), // Jakarta Utara
    LatLng(-6.2615, 106.8106), // Jakarta Selatan
    LatLng(-6.1845, 106.8229), // Jakarta Barat
    LatLng(-6.2146, 106.8451), // Monas
  ];

  // List radius tiap marker
  List<CircleMarker> circles = [];

  @override
  void initState() {
    super.initState();
    // get initial posisi
    _getCurrentLocation();
  }

  // Fungsi untuk mendapatkan lokasi saat ini
  Future<void> _getCurrentLocation() async {
    setState(() => isLoading = true);

    try {
      // Cek permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar('Permission lokasi ditolak');
          setState(() => isLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar('Permission lokasi ditolak permanen');
        setState(() => isLoading = false);
        return;
      }

      // Dapatkan posisi saat ini
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.high),
      );

      // mendapatkan nama kota, kecamatan, provinsi dan negara berdasarkan lokasi user
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      setState(() {
        currentLocation = LatLng(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          log('Lokasi saat iniKecamatan: ${place.subLocality}');
          log('Kota Lokasi saat ini: ${place.locality}');
          log('Lokasi saat ini Province: ${place.administrativeArea}');
          log('Lokasi saat ini Country: ${place.country}');
        }

        isLoading = false;
      });

      // Pindah kamera ke lokasi saat ini
      if (currentLocation != null) {
        setState(() {
          currentCenter = currentLocation!;
          currentZoom = 15.0;
        });
        mapController.move(currentLocation!, 15.0);
      }

      circles = [
        if (currentLocation != null)
          CircleMarker(
            point: currentLocation!,
            useRadiusInMeter: true,
            radius: 100,
            color: Colors.blue.withOpacity(0.2),
            borderColor: Colors.blue,
            borderStrokeWidth: 2,
          ),

        ...markerLocations.map(
          (position) => CircleMarker(
            point: position,
            useRadiusInMeter: true,
            radius: 100,
            color: Colors.blue.withOpacity(0.2),
            borderColor: Colors.blue,
            borderStrokeWidth: 2,
          ),
        ),
      ];
    } catch (e) {
      setState(() => isLoading = false);
      _showSnackBar('Error mendapatkan lokasi: $e');
    }
  }

  // digunakan untuk cek, apakah yang kita tap di layar dalam poisisi marker
  void _checkPointInRadius(LatLng tappedPoint) {
    final Distance distance = Distance(); // dari package latlong2
    bool isInside = false;

    for (final circle in circles) {
      if (circle.useRadiusInMeter) {
        final double meterDistance = distance(tappedPoint, circle.point);

        if (meterDistance <= circle.radius) {
          isInside = true;
          _showSnackBar(
            'Anda berada di dalam radius circle: '
            '${circle.point.latitude.toStringAsFixed(4)}, '
            '${circle.point.longitude.toStringAsFixed(4)} '
            '(jarak: ${meterDistance.toStringAsFixed(1)} m)',
          );
          break;
        }
      }
    }

    if (!isInside) {
      _showSnackBar('Anda di luar semua circle');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // Fungsi untuk pindah ke lokasi tertentu
  void _moveToLocation(LatLng location) {
    setState(() {
      currentCenter = location;
      currentZoom = 15.0;
    });
    mapController.move(location, 15.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(alamat),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Widget Map
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              // Koordinat Jakarta sebagai center default
              initialCenter: currentLocation ?? currentCenter,
              initialZoom: currentZoom,
              minZoom: minZoom,
              maxZoom: maxZoom,
              // Callback saat map di-tap
              onTap: (tapPosition, point) {
                // Panggil fungsi cek radius
                _checkPointInRadius(point);
                log('Map ditap di: ${point.latitude}, ${point.longitude}');
              },
            ),
            children: [
              // Layer tile - menggunakan CartoDB Positron (alternatif yang lebih stabil)
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.flutter_map_app',
                additionalOptions: {
                  'attribution': '© OpenStreetMap contributors © CARTO',
                },
                maxZoom: maxZoom,
                minZoom: minZoom,
              ),

              // Layer marker
              MarkerLayer(
                markers: [
                  // Marker lokasi saat ini
                  if (currentLocation != null)
                    Marker(
                      point: currentLocation!,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(
                          Icons.my_location,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),

                  // Marker lokasi-lokasi lain
                  ...markerLocations.map(
                    (location) => Marker(
                      point: location,
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () {
                          _showSnackBar(
                            'Marker diklik: ${location.latitude}, ${location.longitude}',
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(
                            Icons.location_pin,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Layer polyline (garis)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: markerLocations,
                    strokeWidth: 3.0,
                    color: Colors.blue.withOpacity(0.6),
                  ),
                ],
              ),

              // Layer circle
              CircleLayer(circles: circles),
            ],
          ),

          // Loading indicator
          if (isLoading)
            Container(
              color: Colors.black26,
              child: Center(child: CircularProgressIndicator()),
            ),

          // Tombol kontrol zoom
          Positioned(
            right: 16,
            top: 100,
            child: Column(
              children: [
                FloatingActionButton(
                  mini: true,
                  heroTag: "zoom_in",
                  onPressed: () {
                    setState(() {
                      currentZoom = (currentZoom + 1).clamp(minZoom, maxZoom);
                      mapController.move(currentCenter, currentZoom);
                    });
                  },

                  child: Icon(Icons.zoom_in),
                ),
                SizedBox(height: 8),
                FloatingActionButton(
                  mini: true,
                  heroTag: "zoom_out",
                  onPressed: () {
                    setState(() {
                      currentZoom = (currentZoom - 1).clamp(minZoom, maxZoom);
                      mapController.move(currentCenter, currentZoom);
                    });
                  },

                  child: Icon(Icons.zoom_out),
                ),
              ],
            ),
          ),
        ],
      ),

      // Bottom sheet dengan lokasi-lokasi cepat
      bottomSheet: SizedBox(
        height: 80,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.all(8),
          children: [
            _buildLocationChip('Jakarta Pusat', LatLng(-6.2088, 106.8456)),
            _buildLocationChip('Jakarta Utara', LatLng(-6.1751, 106.8650)),
            _buildLocationChip('Jakarta Selatan', LatLng(-6.2615, 106.8106)),
            _buildLocationChip('Monas', LatLng(-6.2146, 106.8451)),
            if (currentLocation != null)
              _buildLocationChip('Lokasi Saya', currentLocation!),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationChip(String label, LatLng location) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: ActionChip(
        label: Text(label),
        onPressed: () => _moveToLocation(location),
        backgroundColor: Colors.blue.shade100,
      ),
    );
  }
}
