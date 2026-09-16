import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_map/provider/auth_provider.dart';
import 'package:family_map/provider/location_provider.dart';
import 'package:family_map/provider/track_record_provider.dart';
import 'package:family_map/utils/constants.dart';
import 'package:family_map/widgtes/save_location_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

class TrackRecordTapScreen extends StatefulWidget {
  const TrackRecordTapScreen({super.key});

  @override
  State<TrackRecordTapScreen> createState() => _TrackRecordTapScreenState();
}

class _TrackRecordTapScreenState extends State<TrackRecordTapScreen> {
  final MapController _mapController = MapController();

  LatLng? _destinationLocation;
  String? _destinationPlaceName;
  bool _isLoadingRoute = false;
  List<LatLng> _routePoints = [];
  double? _distanceInKm;
  String? _drivingDuration;
  String? _walkingDuration;
  final List<Marker> _customMarkers = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final trackVM = context.read<TrackRecordProvider>();
      final currentUser = context.read<AuthProvider>().user;

      // 1. အကယ်၍ ဖုန်းထဲမှာ Record လုပ်လက်စ Active Session ရှိနေရင် Local SQLite DB မှ ပြန်ယူမည်
      if (trackVM.isRecording) {
        await trackVM.reloadCurrentSessionPath();
      }
      // 2. Active Session မရှိပါက (ဖုန်းအသစ် သို့မဟုတ် Fresh Launch ဖြစ်ပါက) Firebase Firestore မှ Data ဆွဲမည်
      else if (currentUser != null) {
        await trackVM.fetchUserTracksFromFirebase(currentUser.uid);
      }
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  // ၁။ Map Single Tap Handle လုပ်ခြင်း
  Future<void> _handleMapTap(LatLng tappedPoint, LatLng currentLocation) async {
    final placeName =
        'Tapped Location (${tappedPoint.latitude.toStringAsFixed(4)}, ${tappedPoint.longitude.toStringAsFixed(4)})';

    setState(() {
      _destinationLocation = tappedPoint;
      _destinationPlaceName = placeName;
    });

    final trackVM = context.read<TrackRecordProvider>();
    if (trackVM.isRecording) {
      trackVM.addTappedPoint(tappedPoint, placeName);
    }

    await _fetchRouteDetails(currentLocation, tappedPoint);
  }

  // ၂။ Map Long Press ဖြင့် Custom Location / Marker သိမ်းဆည်းခြင်း
  Future<void> _handleMapLongPress(
    LatLng tappedPoint,
    LatLng currentLocation,
  ) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final initialText =
        'Tapped Location (${tappedPoint.latitude.toStringAsFixed(4)}, ${tappedPoint.longitude.toStringAsFixed(4)})';

    // StatefulBuilder မသုံးဘဲ သီးသန့် Dialog Widget အဖြစ် ခေါ်ယူခြင်း
    final String? customName = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return SaveLocationDialog(initialText: initialText);
      },
    );

    if (customName == null) return;

    FocusManager.instance.primaryFocus?.unfocus();
    await Future.delayed(const Duration(milliseconds: 100));

    if (!mounted) return;
    setState(() {
      _destinationLocation = tappedPoint;
      _destinationPlaceName = customName;

      _customMarkers.add(
        Marker(
          key: ValueKey('${tappedPoint.latitude}_${tappedPoint.longitude}'),
          point: tappedPoint,
          width: 60.w,
          height: 60.h,
          child: GestureDetector(
            onTap: () => _showRemoveMarkerDialog(tappedPoint, customName),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on,
                  color: Colors.redAccent,
                  size: 36,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    customName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
    // 💡 DATABASE ထဲသို့ သိမ်းဆည်းခြင်း Logic
    try {
      final currentUser = context.read<AuthProvider>().user;
      if (currentUser != null) {
        await context.read<TrackRecordProvider>().saveCustomLocation(
          userId: currentUser.uid,
          placeName: customName,
          point: tappedPoint,
        );

        if (mounted) {
          _showSnackBar('Location saved successfully!');
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to save location to database.');
      }
    }
    // final trackVM = context.read<TrackRecordProvider>();
    // if (trackVM.isRecording) {
    //   trackVM.addTappedPoint(tappedPoint, customName);
    // }

    // await _fetchRouteDetails(currentLocation, tappedPoint);
  }

  // ၃။ Route & Distance/Duration ရယူခြင်း
  Future<void> _fetchRouteDetails(LatLng start, LatLng end) async {
    if ((start.latitude == 0.0 && start.longitude == 0.0) ||
        (end.latitude == 0.0 && end.longitude == 0.0)) {
      if (mounted) _showSnackBar('Invalid start or end coordinates');
      return;
    }

    setState(() {
      _isLoadingRoute = true;
    });

    try {
      final driveUrl = Uri.https(
        'router.project-osrm.org',
        '/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}',
        {'overview': 'full', 'geometries': 'geojson', 'alternatives': 'true'},
      );

      final walkUrl = Uri.https(
        'router.project-osrm.org',
        '/route/v1/walking/${start.longitude},${start.latitude};${end.longitude},${end.latitude}',
        {'overview': 'false', 'alternatives': 'true'},
      );

      final headers = {
        'User-Agent': 'FamilyMapApp/1.0 (com.naylinhtet.family_map)',
      };

      final results = await Future.wait([
        http
            .get(driveUrl, headers: headers)
            .timeout(const Duration(seconds: 5)),
        http.get(walkUrl, headers: headers).timeout(const Duration(seconds: 5)),
      ]);

      final driveRes = results[0];
      final walkRes = results[1];
      if (driveRes.statusCode == 200) {
        final driveData = json.decode(driveRes.body);
        final List driveRoutes = driveData['routes'] ?? [];

        if (driveRoutes.isNotEmpty) {
          var shortestRoute = driveRoutes[0];
          for (var route in driveRoutes) {
            if ((route['distance'] as num) <
                (shortestRoute['distance'] as num)) {
              shortestRoute = route;
            }
          }

          final double distanceMeters = (shortestRoute['distance'] as num)
              .toDouble();
          final double distanceKm = distanceMeters / 1000;
          final double driveSeconds = (shortestRoute['duration'] as num)
              .toDouble();
          final String driveDurationStr = _formatDuration(driveSeconds * 3);

          final List geometry = shortestRoute['geometry']['coordinates'];
          final List<LatLng> points = geometry.map((coord) {
            return LatLng(
              (coord[1] as num).toDouble(),
              (coord[0] as num).toDouble(),
            );
          }).toList();

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
              walkDurationStr = _formatDuration(walkSeconds * 9);
            }
          }

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
        _showSnackBar('Error fetching route details');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRoute = false;
        });
      }
    }
  }

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

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _animatedMoveToCurrentLocation(LatLng targetLocation) {
    _mapController.move(targetLocation, 16.0);
  }

  // ၄။ Current GPS update များကို Listener / Callback မှတဆင့် ဖမ်းယူရန် Sync Method
  void _syncRecordingPath(LatLng newPos, TrackRecordProvider trackVM) {
    if (!trackVM.isRecording) return;

    if (trackVM.recordedPath.isEmpty) {
      Future.microtask(() => trackVM.addCurrentLocation(newPos));
      return;
    }

    LatLng lastPos = trackVM.recordedPath.last;

    // မီတာ 10 မီတာထက် ပိုရွှေ့မှသာ Path ထဲ ထည့်မည်
    double distanceInMeters = Geolocator.distanceBetween(
      lastPos.latitude,
      lastPos.longitude,
      newPos.latitude,
      newPos.longitude,
    );

    if (distanceInMeters > 10) {
      Future.microtask(() => trackVM.addCurrentLocation(newPos));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().user;
    final locationVM = context.watch<LocationProvider>();
    final trackVM = context.watch<TrackRecordProvider>();

    final currentPos = locationVM.currentPosition;
    final LatLng myLocation = currentPos != null
        ? LatLng(currentPos.latitude, currentPos.longitude)
        : const LatLng(16.8505666, 96.1286914);

    final String myName =
        currentUser?.displayName ?? currentUser?.email?.split('@')[0] ?? 'You';

    // Build တိုင်းတွင် PostFrameCallback ပြန်ထည့်ပေးခြင်း
    // if (currentPos != null && trackVM.isRecording) {
    //   WidgetsBinding.instance.addPostFrameCallback((_) {
    //     _syncRecordingPath(myLocation, trackVM);
    //   });
    // }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Flutter Map View Layer
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: myLocation,
              initialZoom: 15.0,
              onTap: (_, point) => _handleMapTap(point, myLocation),
              onLongPress: (_, point) => _handleMapLongPress(point, myLocation),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.naylinhtet.family_map',
                tileProvider: NetworkTileProvider(
                  headers: Map<String, String>.from({
                    'User-Agent':
                        'MyCustomFamilyApp/1.0 (naylinhtet.dev@gmail.com)',
                  }),
                ),
              ),
              PolylineLayer(
                polylines: [
                  if (trackVM.recordedPath.isNotEmpty)
                    Polyline(
                      points: trackVM.recordedPath,
                      strokeWidth: 5.0,
                      color: Colors.redAccent,
                    ),
                  if (_routePoints.isNotEmpty)
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 4.5,
                      color: Colors.blueAccent,
                    ),
                ],
              ),

              // MarkerLayer အပိုင်းကို အောက်ပါ StreamBuilder ဖြင့် ဝန်းရံ
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('saved_locations')
                    .where('userId', isEqualTo: currentUser?.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  List<Marker> dbMarkers = [];

                  if (snapshot.hasData) {
                    dbMarkers = snapshot.data!.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final point = LatLng(data['latitude'], data['longitude']);
                      final placeName = data['placeName'] ?? 'Saved Location';

                      return Marker(
                        key: ValueKey(doc.id),
                        point: point,
                        width: 60.w,
                        height: 60.h,
                        child: GestureDetector(
                          onTap: () =>
                              _showRemoveMarkerDialog(point, placeName),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: Colors.redAccent,
                                size: 36,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  placeName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList();
                  }

                  return MarkerLayer(
                    markers: [
                      // Current Location Marker
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
                      if (_destinationLocation != null)
                        Marker(
                          point: _destinationLocation!,
                          width: 80.w,
                          height: 80.h,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 45.0,
                          ),
                        ),
                      // Database ထဲမှ Marker များနှင့် Memory ထဲမှ Marker များ ပေါင်းစပ်ခြင်း
                      ...dbMarkers,
                      ..._customMarkers,
                      // ..._routePoints,
                    ],
                  );
                },
              ),
            ],
          ),

          // Recording State Top Banner Indicator
          if (trackVM.isRecording)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10.h,
              left: 20.w,
              right: 20.w,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(25.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.fiber_manual_record,
                        color: Colors.white,
                        size: 18,
                      ),
                      SizedBox(width: 8.w),
                      const Text(
                        'Track Recording...',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Bottom Route Details Card
          if (_destinationLocation != null)
            Positioned(
              bottom: 10.h,
              left: 10.w,
              right: 10.w,
              child: Container(
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12.r),
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
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
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
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildInfoItem(
                                icon: Icons.straighten,
                                iconColor: Colors.blue,
                                title: 'Distance',
                                value: _distanceInKm != null
                                    ? '${_distanceInKm!.toStringAsFixed(1)} km'
                                    : 'N/A',
                              ),
                              _buildInfoItem(
                                icon: Icons.directions_car,
                                iconColor: Colors.amber.shade800,
                                title: 'Drive',
                                value: _drivingDuration ?? 'N/A',
                              ),
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
          bottom: _destinationLocation != null ? 110.h : 0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton(
              heroTag: 'btnMyLoc',
              onPressed: () => _animatedMoveToCurrentLocation(myLocation),
              backgroundColor: Theme.of(context).primaryColor,
              child: Image.asset(
                'assets/logo/app_logo_no_bk.png',
                width: 42.w,
                height: 42.h,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 10.h),
            FloatingActionButton(
              heroTag: 'btnRecord',
              onPressed: () {
                if (currentUser != null) {
                  context.read<TrackRecordProvider>().toggleRecording(
                    currentUser.uid,
                  );
                }
              },
              backgroundColor: trackVM.isRecording
                  ? Colors.red
                  : Colors.grey.shade200,
              child: Icon(
                Icons.fork_right_sharp,
                size: 32.r,
                color: trackVM.isRecording ? Colors.white : AppColors.primary,
              ),
            ),
          ],
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

  void _showRemoveMarkerDialog(LatLng pointToRemove, String placeName) {
    final locationVM = context.read<LocationProvider>();
    final currentPos = locationVM.currentPosition;
    final LatLng myLocation = currentPos != null
        ? LatLng(currentPos.latitude, currentPos.longitude)
        : const LatLng(16.8505666, 96.1286914);
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('$placeName Point'),
          content: const Text(
            'Do you want to go or remove \n this saved point?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () {
                setState(() {
                  _customMarkers.removeWhere(
                    (marker) => marker.point == pointToRemove,
                  );

                  if (_destinationLocation == pointToRemove) {
                    _destinationLocation = null;
                    _destinationPlaceName = null;
                    _routePoints.clear();
                  }
                });

                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.white),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () {
                _handleMapTap(pointToRemove, myLocation);
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Select',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}
