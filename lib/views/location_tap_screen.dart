import 'dart:convert';

import 'package:family_map/provider/auth_provider.dart';
import 'package:family_map/provider/location_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationTapScreen extends StatefulWidget {
  const LocationTapScreen({super.key});

  @override
  State<LocationTapScreen> createState() => _LocationTapScreenState();
}

class _LocationTapScreenState extends State<LocationTapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  LatLng? _destinationLocation;
  String? _destinationPlaceName;

  // Route, Distance & Duration Data
  List<LatLng> _routePoints = [];
  double? _distanceInKm;
  String? _drivingDuration;
  String? _walkingDuration;

  bool _isSearching = false;
  bool _isLoadingRoute = false;

  List<String> _searchHistory = [];
  bool _showHistory = false;

  @override
  void dispose() {
    _mapController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();

    _searchFocusNode.addListener(() {
      setState(() {
        _showHistory = _searchFocusNode.hasFocus;
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        context.read<LocationProvider>().startLocationTracking(user.uid);
      }
    });
  }

  // SharedPreferences မှ Search History ယူခြင်း
  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _searchHistory = prefs.getStringList('search_history') ?? [];
    });
  }

  Future<void> _saveSearchQuery(String query) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList('search_history') ?? [];
    history.remove(query);
    history.insert(0, query);

    if (history.length > 10) {
      history = history.sublist(0, 10);
    }

    await prefs.setStringList('search_history', history);
    setState(() {
      _searchHistory = history;
    });
  }

  Future<void> _deleteHistoryItem(String query) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList('search_history') ?? [];
    history.remove(query);
    await prefs.setStringList('search_history', history);
    setState(() {
      _searchHistory = history;
    });
  }

  // OSRM API မှတစ်ဆင့် Route (လမ်းကြောင်း)၊ Distance & Durations ရယူခြင်း
  Future<void> _fetchRouteDetails(LatLng start, LatLng end) async {
    // Start သို့မဟုတ် End Point တွေ LatLng (0.0, 0.0) ဖြစ်နေပါက ရပ်တန့်ရန်
    if ((start.latitude == 0.0 && start.longitude == 0.0) ||
        (end.latitude == 0.0 && end.longitude == 0.0)) {
      if (mounted) _showSnackBar('Invalid start or end coordinates');
      return;
    }

    setState(() {
      _isLoadingRoute = true;
    });

    try {
      // 1. Driving Route API URL (alternatives=true ထည့်သွင်းထားသည်)
      final driveUrl = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
        '?overview=full&geometries=geojson&alternatives=true',
      );

      // 2. Walking Route API URL (alternatives=true ထည့်သွင်းထားသည်)
      final walkUrl = Uri.parse(
        'https://router.project-osrm.org/route/v1/walking/'
        '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
        '?overview=false&alternatives=true',
      );

      // OSRM Server Request မပိတ်စေရန် Custom User-Agent Header
      final headers = {
        'User-Agent': 'FamilyMapApp/1.0 (com.naylinhtet.family_map)',
      };

      final driveRes = await http.get(driveUrl, headers: headers);
      final walkRes = await http.get(walkUrl, headers: headers);

      if (driveRes.statusCode == 200) {
        final driveData = json.decode(driveRes.body);
        final List driveRoutes = driveData['routes'] ?? [];

        if (driveRoutes.isNotEmpty) {
          // --- အနီးဆုံး (Distance အတိုဆုံး) Driving Route ကို Auto ရွေးချယ်ခြင်း ---
          var shortestRoute = driveRoutes[0];
          for (var route in driveRoutes) {
            if ((route['distance'] as num) <
                (shortestRoute['distance'] as num)) {
              shortestRoute = route;
            }
          }

          // Distance in meters to Km
          final double distanceMeters = (shortestRoute['distance'] as num)
              .toDouble();
          final double distanceKm = distanceMeters / 1000;

          // Driving duration in seconds
          final double driveSeconds = (shortestRoute['duration'] as num)
              .toDouble();
          final double realisticDriveSeconds = driveSeconds * 3;
          final String driveDurationStr = _formatDuration(
            realisticDriveSeconds,
          );

          // Route coordinates for Polyline
          final List geometry = shortestRoute['geometry']['coordinates'];
          final List<LatLng> points = geometry.map((coord) {
            return LatLng(
              (coord[1] as num).toDouble(),
              (coord[0] as num).toDouble(),
            );
          }).toList();

          // --- အနီးဆုံး Walking Route ကို Auto ရွေးချယ်ခြင်း ---
          String walkDurationStr = 'N/A';
          if (walkRes.statusCode == 200) {
            final walkData = json.decode(walkRes.body);
            final List walkRoutes = walkData['routes'] ?? [];

            if (walkRoutes.isNotEmpty) {
              var shortestWalkRoute = walkRoutes[0];
              for (var walkRoute in walkRoutes) {
                if ((walkRoute['distance'] as num) <
                    (shortestWalkRoute['distance'] as num)) {
                  shortestWalkRoute = walkRoute;
                }
              }

              final double walkSeconds = (shortestWalkRoute['duration'] as num)
                  .toDouble();

              // Walking Duration Realistic ဖြစ်အောင် Multiplier မြှောက်ခြင်း
              // (မိတ်ဆွေသုံးထားတဲ့ * 3 အဆ ကိန်းဂဏန်းအတိုင်း ထားပေးထားပါတယ်)
              final double realisticWalkSeconds = walkSeconds * 9;
              walkDurationStr = _formatDuration(realisticWalkSeconds);
            }
          }

          // Widget Tree ထဲမှာ ရှိနေသေးမှသာ setState ခေါ်ရန်
          if (mounted) {
            setState(() {
              _routePoints = points;
              _distanceInKm = distanceKm;
              _drivingDuration = driveDurationStr;
              _walkingDuration = walkDurationStr;
            });
          }
        }
      } else {
        if (mounted) {
          _showSnackBar('Failed to get route (${driveRes.statusCode})');
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error fetching route');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRoute = false;
        });
      }
    }
  }

  // ကြာချိန် စက္ကန့်မှ မိနစ်/နာရီ သို့ ပြောင်းလဲပေးသည့် Helper
  String _formatDuration(double seconds) {
    final int minutes = (seconds / 60).round();
    if (minutes < 60) {
      return '$minutes mins';
    } else {
      final int hours = minutes ~/ 60;
      final int remainingMins = minutes % 60;
      return '$hours hr $remainingMins mins';
    }
  }

  // Search Bar မှ ရှာဖွေခြင်း
  Future<void> _searchLocation(String query, LatLng currentLocation) async {
    if (query.trim().isEmpty) return;

    _searchFocusNode.unfocus();
    setState(() {
      _isSearching = true;
      _showHistory = false;
    });

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'MyCustomFamilyApp/1.0 (naylinhtet.dev@gmail.com)',
        },
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          final double lat = double.parse(data[0]['lat']);
          final double lon = double.parse(data[0]['lon']);
          final String displayName = data[0]['display_name'];

          final LatLng destination = LatLng(lat, lon);

          setState(() {
            _destinationLocation = destination;
            _destinationPlaceName = displayName;
          });

          await _saveSearchQuery(query);

          // လမ်းကြောင်းနှင့် ကြာချိန်များ ယူမည်
          await _fetchRouteDetails(currentLocation, destination);

          _mapController.move(destination, 14.5);
        } else {
          _showSnackBar('Location not found');
        }
      }
    } catch (e) {
      _showSnackBar('Error searching location');
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  // Map ပေါ်တွင် Tap (နှိပ်) လိုက်သည့်အခါ လမ်းကြောင်းဆွဲပေးခြင်း
  Future<void> _handleMapTap(LatLng tappedPoint, LatLng currentLocation) async {
    _searchFocusNode.unfocus();
    setState(() {
      _destinationLocation = tappedPoint;
      _destinationPlaceName =
          'Tapped Location (${tappedPoint.latitude.toStringAsFixed(4)}, ${tappedPoint.longitude.toStringAsFixed(4)})';
      _showHistory = false;
    });

    await _fetchRouteDetails(currentLocation, tappedPoint);
  }

  void _clearSelection() {
    _searchController.clear();
    setState(() {
      _destinationLocation = null;
      _destinationPlaceName = null;
      _routePoints = [];
      _distanceInKm = null;
      _drivingDuration = null;
      _walkingDuration = null;
    });
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _animatedMoveToCurrentLocation(LatLng targetLocation) {
    _mapController.move(targetLocation, 16.0);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().user;
    final locationVM = context.watch<LocationProvider>();
    final currentPos = locationVM.currentPosition;

    final LatLng myLocation = currentPos != null
        ? LatLng(currentPos.latitude, currentPos.longitude)
        : const LatLng(16.8505666, 96.1286914);

    final String myName =
        currentUser?.displayName ?? currentUser?.email?.split('@')[0] ?? 'You';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: currentPos == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // ၁။ Map View
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: myLocation,
                    initialZoom: 15.0,
                    onTap: (tapPosition, point) =>
                        _handleMapTap(point, myLocation),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.naylinhtet.family_map',
                      tileProvider: NetworkTileProvider(
                        headers: Map<String, String>.from({
                          'User-Agent':
                              'MyCustomFamilyApp/1.0 (naylinhtet.dev@gmail.com)',
                        }),
                      ),
                    ),

                    // Route Polyline (လမ်းကြောင်း)
                    if (_routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePoints,
                            strokeWidth: 4.5,
                            color: Colors.blueAccent,
                          ),
                        ],
                      ),

                    MarkerLayer(
                      markers: [
                        // မိမိ တည်နေရာ Marker (အမည် Tag ပါဝင်သည်)
                        Marker(
                          point: myLocation,
                          width: 80.w,
                          height: 80.h,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6.w,
                                  vertical: 2.h,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent,
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Text(
                                  myName,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Image.asset(
                                'assets/logo/app_logo_no_bk.png',
                                width: 46.w,
                                height: 46.h,
                                fit: BoxFit.contain,
                              ),
                            ],
                          ),
                        ),

                        // Destination Marker
                        if (_destinationLocation != null)
                          Marker(
                            point: _destinationLocation!,
                            width: 80,
                            height: 80,
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 45.0,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                // ၂။ Search Bar & History List
                SafeArea(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 10.h,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(30.r),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: 'Search here ',
                              hintStyle: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16.sp,
                              ),
                              prefixIcon: _isSearching
                                  ? const Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : IconButton(
                                      icon: Image.asset(
                                        'assets/logo/app_logo_no_bk.png',
                                        width: 32.w,
                                        height: 32.h,
                                        fit: BoxFit.contain,
                                      ),
                                      onPressed: () => _searchLocation(
                                        _searchController.text,
                                        myLocation,
                                      ),
                                    ),
                              suffixIcon: IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                  color: Colors.grey,
                                ),
                                onPressed: _clearSelection,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 14.h,
                              ),
                            ),
                            onSubmitted: (value) =>
                                _searchLocation(value, myLocation),
                          ),
                        ),

                        // Search History Dropdown
                        if (_showHistory && _searchHistory.isNotEmpty)
                          Container(
                            margin: EdgeInsets.only(top: 6.h),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(16.r),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            constraints: BoxConstraints(maxHeight: 200.h),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _searchHistory.length,
                              itemBuilder: (context, index) {
                                final item = _searchHistory[index];
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(
                                    Icons.history,
                                    size: 18,
                                    color: Colors.grey,
                                  ),
                                  title: Text(
                                    item,
                                    style: TextStyle(fontSize: 14.sp),
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(
                                      Icons.close,
                                      size: 16.r,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () => _deleteHistoryItem(item),
                                  ),
                                  onTap: () {
                                    _searchController.text = item;
                                    _searchLocation(item, myLocation);
                                  },
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // ၃။ အောက်ခြေရှိ Route Info Card (Distance, Driving Time, Walking Time)
                if (_destinationLocation != null && !_showHistory)
                  Positioned(
                    bottom: 10.h,
                    left: 10.w,
                    right: 10.w,
                    child: Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(10.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _isLoadingRoute
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(width: 12),
                                Text('Calculating route...'),
                              ],
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _destinationPlaceName ?? 'Selected Location',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15.sp,
                                  ),
                                ),
                                SizedBox(height: 12.h),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    // Distance Info
                                    _buildInfoItem(
                                      icon: Icons.straighten,
                                      iconColor: Colors.blue,
                                      title: 'Distance',
                                      value: _distanceInKm != null
                                          ? '${_distanceInKm!.toStringAsFixed(1)} km'
                                          : 'N/A',
                                    ),

                                    // Driving Duration Info
                                    _buildInfoItem(
                                      icon: Icons.directions_car,
                                      iconColor: Colors.amber.shade800,
                                      title: 'Drive',
                                      value: _drivingDuration ?? 'N/A',
                                    ),

                                    // Walking Duration Info
                                    _buildInfoItem(
                                      icon: Icons.directions_walk,
                                      iconColor: Colors.green,
                                      title: 'Walk',
                                      value: _walkingDuration ?? 'N/A',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                    ),
                  ),
              ],
            ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: _destinationLocation != null ? 120.h : 0,
        ),
        child: FloatingActionButton(
          onPressed: () => _animatedMoveToCurrentLocation(myLocation),
          backgroundColor: Theme.of(context).primaryColor,
          child: Image.asset(
            'assets/logo/app_logo_no_bk.png',
            width: 42.w,
            height: 42.h,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 20.r),
            SizedBox(width: 4.w),
            Text(
              title,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12.sp),
            ),
          ],
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14.sp,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
      ],
    );
  }
}
