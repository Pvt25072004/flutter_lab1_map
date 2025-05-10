import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const String googleAPIKey = 'AIzaSyC6-i8B-xBDZ3BgEAOZqg2ZUBeG9XfCaOM';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Google Map with OSRM Directions',
      home: const MapScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  Set<Marker> _markers = {};
  Polyline? _polyline;
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _autocompleteResults = [];
  MapType _currentMapType = MapType.normal;
  String? _distanceText = '';
  String? _timeText = '';
  
  // List of past search history
  List<String> _searchHistory = [];

  // List of transportation modes (with corresponding speeds)
  final List<Map<String, dynamic>> _transportModes = [
    {'label': 'Đi bộ', 'speed': 5},  // 5 km/h
    {'label': 'Xe đạp', 'speed': 15},  // 15 km/h
    {'label': 'Xe máy', 'speed': 40},  // 40 km/h
    {'label': 'Ô tô', 'speed': 50},  // 50 km/h
  ];
  
  String _selectedTransportMode = 'Xe máy';  // Default to "Xe máy"
  int _speed = 30;  // Default speed is 30 km/h for xe máy

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    LocationPermission permission = await Geolocator.requestPermission();
    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });
  }

  void _onMapTapped(LatLng position) {
    final markerId = MarkerId(position.toString());

    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: markerId,
          position: position,
          infoWindow: const InfoWindow(title: 'Vị trí bạn chọn'),
        ),
      );
    });
  }

  void _searchAddress(String query) async {
    if (query.isEmpty) return;

    final url =
        'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}&addressdetails=1&limit=5';
    final response = await http.get(Uri.parse(url));
    final data = json.decode(response.body);

    setState(() {
      _autocompleteResults = data; // Lưu các kết quả gợi ý
    });
  }

  void _onAutocompleteItemSelected(dynamic result) {
    final lat = result['lat'];
    final lon = result['lon'];
    final position = LatLng(double.parse(lat), double.parse(lon));

    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('searched_location'),
          position: position,
          infoWindow: InfoWindow(title: result['display_name']),
        ),
      );
    });

    _mapController?.animateCamera(CameraUpdate.newLatLng(position));
    _searchController.clear();
    setState(() {
      _autocompleteResults = []; // Xóa kết quả gợi ý sau khi chọn
      _searchHistory.add(result['display_name']); // Thêm vào lịch sử tìm kiếm
    });
  }

  Future<void> _getDirections(LatLng start, LatLng end) async {
    final url =
        'http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson';
    final response = await http.get(Uri.parse(url));
    final data = json.decode(response.body);

    if (data['routes'].isNotEmpty) {
      final route = data['routes'][0];
      final geometry = route['geometry'];
      final coordinates = geometry['coordinates'];

      List<LatLng> points = [];
      for (var coord in coordinates) {
        points.add(LatLng(coord[1], coord[0]));
      }

      double distance = route['legs'][0]['distance'] / 1000; // km
      double duration = route['legs'][0]['duration'] / 60; // minutes

      // Calculate adjusted time based on the selected transport speed
      double adjustedDuration = distance / _speed * 60;  // minutes

      String formattedDistance = distance < 1
          ? '${(distance * 1000).toStringAsFixed(0)} m'
          : '${distance.toStringAsFixed(2)} km';

      int hours = adjustedDuration ~/ 60;
      int minutes = adjustedDuration.round() % 60;
      String formattedTime = hours > 0
          ? '${hours} giờ ${minutes} phút'
          : '${minutes} phút';

      setState(() {
        _polyline = Polyline(
          polylineId: const PolylineId('route'),
          points: points,
          color: Colors.blue,
          width: 5,
        );
        _distanceText = formattedDistance;
        _timeText = formattedTime;
      });
    }
  }

  void _toggleMapType() {
    setState(() {
      _currentMapType = _currentMapType == MapType.satellite
          ? MapType.normal
          : MapType.satellite;
    });
  }
  bool isSearchHistoryVisible = true;


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chỉ đường với OSRM')),
      body: _currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition!,
                    zoom: 15,
                  ),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  onTap: _onMapTapped,
                  markers: _markers,
                  polylines: _polyline != null ? {_polyline!} : {},
                  mapType: _currentMapType,
                ),
                Positioned(
                  top: 20,
                  left: 20,
                  right: 70,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Tìm kiếm địa chỉ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () {
                          _searchAddress(_searchController.text);
                          setState(() {
                            isSearchHistoryVisible = false;
                          });
                        },
                      ),
                    ),
                    onChanged: _searchAddress,
                  ),
                ),
                
                Positioned(
                  top: 60,
                  right: 10,
                  child: FloatingActionButton(
                    heroTag: 'directionsBtn',
                    onPressed: () {
                      if (_currentPosition != null && _markers.isNotEmpty) {
                        final start = _currentPosition!;
                        final end = _markers.first.position;
                        _getDirections(start, end);
                        setState(() {
                          isSearchHistoryVisible = false;
                        });
                      }
                    },
                    child: const Icon(Icons.directions),
                    tooltip: 'Chỉ đường',
                  ),
                ),
                Positioned(
                  bottom: 16,
                  right: 60,
                  child: FloatingActionButton(
                    heroTag: 'mapTypeBtn',
                    onPressed: _toggleMapType,
                    child: const Icon(Icons.satellite),
                    tooltip: 'Chuyển chế độ bản đồ',
                  ),
                ),
                // Dropdown for transportation mode
                Positioned(
                  bottom: 30,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(126, 255, 255, 255),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedTransportMode,
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedTransportMode = newValue!;
                          _speed = _transportModes
                              .firstWhere(
                                  (mode) => mode['label'] == newValue)['speed'];
                        });
                      },
                      items: _transportModes.map((mode) {
                        return DropdownMenuItem<String>(
                          value: mode['label'],
                          child: Text(mode['label']),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                // Gợi ý địa chỉ tự động
                if (_autocompleteResults.isNotEmpty)
                  Positioned(
                    top: 70,
                    left: 20,
                    right: 20,
                    child: Container(
                      color: Colors.white,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _autocompleteResults.length,
                        itemBuilder: (context, index) {
                          final result = _autocompleteResults[index];
                          return ListTile(
                            title: Text(result['display_name']),
                            onTap: () => _onAutocompleteItemSelected(result),
                          );
                        },
                      ),
                    ),
                  ),
                // Hiển thị lịch sử tìm kiếm
                if (_searchHistory.isNotEmpty && isSearchHistoryVisible )
                  Positioned(
                    top: 150,
                    left: 20,
                    right: 20,
                    child: Container(
                      color: Colors.white,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _searchHistory.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            title: Text(_searchHistory[index]),
                            onTap: () {
                              _searchController.text = _searchHistory[index];
                              _searchAddress(_searchHistory[index]);
                            },
                          );
                        },
                      ),
                    ),
                  ),
                // Hiển thị thông tin khoảng cách và thời gian
                if (_distanceText != null && _timeText != null)
                  Positioned(
                    bottom: 80,
                    left: 6,
                    child: Container(
                      color: const Color.fromARGB(137, 255, 255, 255),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Khoảng cách: $_distanceText',
                            style: const TextStyle(fontSize: 16),
                          ),
                          Text(
                            'Thời gian: $_timeText',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
