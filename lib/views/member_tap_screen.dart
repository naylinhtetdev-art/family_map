import 'dart:convert';
import 'package:family_map/model/member_model.dart';
import 'package:family_map/provider/auth_provider.dart';
import 'package:family_map/provider/location_provider.dart';
import 'package:family_map/provider/member_provider.dart';
import 'package:family_map/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

class MemberTapScreen extends StatefulWidget {
  const MemberTapScreen({super.key});

  @override
  State<MemberTapScreen> createState() => _MemberTapScreenState();
}

class _MemberTapScreenState extends State<MemberTapScreen> {
  final MapController _mapController = MapController();

  MemberModel? _selectedMember;
  List<LatLng> _selectedRoutePoints = [];
  double? _distanceInKm;
  String? _drivingDuration;
  String? _walkingDuration;
  bool _isLoadingRoute = false;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        context.read<LocationProvider>().startLocationTracking(user.uid);
      }
    });
  }

  // Selected Member ဆီသို့ အကွာအဝေးနှင့် ကြာချိန် ရယူခြင်း
  Future<void> _fetchMemberRouteDetails(
    LatLng myLocation,
    MemberModel member,
  ) async {
    // Member Location Lat/Lng မရှိပါက Route ရှာမရအောင် စစ်ဆေးခြင်း
    if (member.latitude == 0.0 && member.longitude == 0.0) {
      _showSnackBar('Member location is unavailable');
      return;
    }

    final memberLocation = LatLng(member.latitude, member.longitude);

    setState(() {
      _selectedMember = member;
      _isLoadingRoute = true;
    });

    _mapController.move(memberLocation, 15.0);

    try {
      final driveUrl = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${myLocation.longitude},${myLocation.latitude};${memberLocation.longitude},${memberLocation.latitude}'
        '?overview=full&geometries=geojson',
      );

      final walkUrl = Uri.parse(
        'https://router.project-osrm.org/route/v1/walking/'
        '${myLocation.longitude},${myLocation.latitude};${memberLocation.longitude},${memberLocation.latitude}'
        '?overview=false',
      );

      final headers = {
        'User-Agent': 'FamilyMapApp/1.0 (com.naylinhtet.family_map)',
      };

      final driveRes = await http.get(driveUrl, headers: headers);
      final walkRes = await http.get(walkUrl, headers: headers);

      if (driveRes.statusCode == 200) {
        final driveData = json.decode(driveRes.body);
        if (driveData['routes'] != null &&
            (driveData['routes'] as List).isNotEmpty) {
          final route = driveData['routes'][0];

          final double distanceMeters = (route['distance'] as num).toDouble();
          final double distanceKm = distanceMeters / 1000;

          final double driveSeconds = (route['duration'] as num).toDouble();
          final double realisticDriveSeconds = driveSeconds * 3;
          final String driveDurationStr = _formatDuration(
            realisticDriveSeconds,
          );

          final List geometry = route['geometry']['coordinates'];
          final List<LatLng> points = geometry.map((coord) {
            return LatLng(
              (coord[1] as num).toDouble(),
              (coord[0] as num).toDouble(),
            );
          }).toList();

          String walkDurationStr = 'N/A';
          if (walkRes.statusCode == 200) {
            final walkData = json.decode(walkRes.body);
            if (walkData['routes'] != null &&
                (walkData['routes'] as List).isNotEmpty) {
              final double walkSeconds =
                  (walkData['routes'][0]['duration'] as num).toDouble();
              final double realisticWalkSeconds = walkSeconds * 9;
              walkDurationStr = _formatDuration(realisticWalkSeconds);
            }
          }

          setState(() {
            _selectedRoutePoints = points;
            _distanceInKm = distanceKm;
            _drivingDuration = driveDurationStr;
            _walkingDuration = walkDurationStr;
          });
        }
      }
    } catch (e) {
      _showSnackBar('Error fetching route details');
    } finally {
      setState(() {
        _isLoadingRoute = false;
      });
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

  void _clearSelection() {
    setState(() {
      _selectedMember = null;
      _selectedRoutePoints = [];
      _distanceInKm = null;
      _drivingDuration = null;
      _walkingDuration = null;
    });
  }

  void _animatedMoveToCurrentLocation(LatLng targetLocation) {
    _clearSelection();
    _mapController.move(targetLocation, 16.0);
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  List<Marker> _buildMemberMarkers(
    List<MemberModel> members,
    LatLng myLocation,
  ) {
    return members
        .where(
          (m) => m.latitude != 0.0 && m.longitude != 0.0,
        ) // Location ရှိမှ Marker ပြမည်
        .map((member) {
          final isSelected = _selectedMember?.uid == member.uid;
          final name = member.name.isNotEmpty
              ? member.name
              : member.email.split('@')[0];

          return Marker(
            point: LatLng(member.latitude, member.longitude),
            width: 80.w,
            height: 80.h,
            child: GestureDetector(
              onTap: () => _fetchMemberRouteDetails(myLocation, member),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 6.w,
                      vertical: 2.h,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.purple : Colors.black87,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.sp,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.person_pin_circle,
                    color: isSelected ? Colors.deepPurpleAccent : Colors.purple,
                    size: isSelected ? 44.0 : 38.0,
                  ),
                ],
              ),
            ),
          );
        })
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().user;
    final locationVM = context.watch<LocationProvider>();
    final memberVM = context.watch<MemberProvider>();

    final currentPos = locationVM.currentPosition;
    final LatLng myLocation = currentPos != null
        ? LatLng(currentPos.latitude, currentPos.longitude)
        : const LatLng(16.8505666, 96.1286914);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: currentUser == null
          ? const Center(child: Text('User not logged in'))
          : StreamBuilder<List<MemberModel>>(
              stream: memberVM.getSharedMembersStream(currentUser.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final members = snapshot.data ?? [];

                final List<Polyline> defaultPolylines = members
                    .where((m) => m.latitude != 0.0 && m.longitude != 0.0)
                    .map((member) {
                      return Polyline(
                        points: [
                          myLocation,
                          LatLng(member.latitude, member.longitude),
                        ],
                        strokeWidth: 3.0,
                        color: Colors.blueAccent.withOpacity(0.7),
                      );
                    })
                    .toList();

                return Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: myLocation,
                        initialZoom: 15.0,
                        onTap: (_, __) => _clearSelection(),
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
                        PolylineLayer(
                          polylines: [
                            if (_selectedRoutePoints.isNotEmpty)
                              Polyline(
                                points: _selectedRoutePoints,
                                strokeWidth: 4.5,
                                color: Colors.purpleAccent,
                              )
                            else
                              ...defaultPolylines,
                          ],
                        ),
                        MarkerLayer(
                          markers: [
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
                                      currentUser.displayName ??
                                          currentUser.email?.split('@')[0] ??
                                          'You',
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
                                  ),
                                ],
                              ),
                            ),
                            ..._buildMemberMarkers(members, myLocation),
                          ],
                        ),
                      ],
                    ),

                    // Top Member List Chips Horizontal View
                    SafeArea(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 10.h,
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                ActionChip(
                                  avatar: const Icon(
                                    Icons.person,
                                    color: Colors.blue,
                                    size: 18,
                                  ),
                                  label: const Text('You'),
                                  backgroundColor: Colors.white,
                                  elevation: 2,
                                  onPressed: () =>
                                      _animatedMoveToCurrentLocation(
                                        myLocation,
                                      ),
                                ),
                                SizedBox(width: 8.w),
                                if (members.isEmpty)
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12.w,
                                      vertical: 6.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20.r),
                                    ),
                                    child: const Text(
                                      'No members added yet',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  )
                                else
                                  ...members.map((m) {
                                    final name = m.name.isNotEmpty
                                        ? m.name
                                        : m.email.split('@')[0];
                                    final isSelected =
                                        _selectedMember?.uid == m.uid;

                                    return Padding(
                                      padding: EdgeInsets.only(right: 8.w),
                                      child: Material(
                                        elevation: isSelected ? 4 : 2,
                                        borderRadius: BorderRadius.circular(
                                          20.r,
                                        ),
                                        color: isSelected
                                            ? Colors.purple.shade50
                                            : Colors.white,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            20.r,
                                          ),
                                          onTap: () => _fetchMemberRouteDetails(
                                            myLocation,
                                            m,
                                          ),
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 10.w,
                                              vertical: 6.h,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.person_pin_circle,
                                                  color: isSelected
                                                      ? Colors.deepPurple
                                                      : Colors.purple,
                                                  size: 18,
                                                ),
                                                SizedBox(width: 4.w),
                                                Text(
                                                  name,
                                                  style: TextStyle(
                                                    fontSize: 13.sp,
                                                    fontWeight: isSelected
                                                        ? FontWeight.bold
                                                        : FontWeight.w500,
                                                    color: isSelected
                                                        ? Colors.deepPurple
                                                        : Colors.black,
                                                  ),
                                                ),
                                                SizedBox(width: 4.w),
                                                GestureDetector(
                                                  onTap: () {
                                                    _showRemoveMemberDialog(
                                                      context,
                                                      member: m,
                                                      currentUid:
                                                          currentUser.uid,
                                                    );
                                                  },
                                                  child: Icon(
                                                    Icons.cancel,
                                                    color: Colors.grey.shade600,
                                                    size: 18.r,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    if (_selectedMember != null)
                      Positioned(
                        bottom: 10.h,
                        left: 10.w,
                        right: 80.w,
                        child: Container(
                          padding: EdgeInsets.all(10.r),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(10.r),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
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
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Text('Calculating route...'),
                                  ],
                                )
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _selectedMember!.name.isNotEmpty
                                                ? _selectedMember!.name
                                                : _selectedMember!.email,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14.sp,
                                            ),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: _clearSelection,
                                          child: Icon(
                                            Icons.close,
                                            size: 18.r,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 10.h),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
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
                );
              },
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'btnMemberLoc',
            onPressed: () => _showAddMemberBottomSheet(context),
            backgroundColor: Colors.blueGrey,
            child: const Icon(Icons.add, color: Colors.white),
          ),
          SizedBox(height: 10.h),
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
        ],
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
            Icon(icon, color: iconColor, size: 16.r),
            SizedBox(width: 2.w),
            Text(
              title,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11.sp),
            ),
          ],
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp),
        ),
      ],
    );
  }

  void _showAddMemberBottomSheet(BuildContext context) {
    final TextEditingController emailController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {
        return Consumer<MemberProvider>(
          builder: (context, memberVM, child) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20.w,
                right: 20.w,
                top: 20.h,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Family Member',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Enter member email to share location:',
                    style: TextStyle(color: Colors.grey, fontSize: 13.sp),
                  ),
                  SizedBox(height: 15.h),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'e.g. member@gmail.com',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  SizedBox(
                    width: double.infinity,
                    height: 48.h,
                    child: ElevatedButton(
                      onPressed: memberVM.isLoading
                          ? null
                          : () async {
                              final email = emailController.text.trim();
                              if (email.isEmpty) return;

                              final user = context.read<AuthProvider>().user;
                              if (user == null) return;

                              final error = await memberVM.sendLocationRequest(
                                senderUid: user.uid,
                                senderEmail: user.email ?? '',
                                targetEmail: email,
                              );

                              if (mounted) {
                                if (error != null) {
                                  _showSnackBar(error);
                                } else {
                                  _showSnackBar(
                                    'Request sent to $email successfully',
                                  );
                                  Navigator.pop(context);
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: memberVM.isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Send Invitation',
                              style: TextStyle(color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showRemoveMemberDialog(
    BuildContext context, {
    required MemberModel member,
    required String currentUid,
  }) {
    final name = member.name.isNotEmpty ? member.name : member.email;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          title: const Text('Remove Member'),
          content: Text(
            'Do you want to remove $name from your member list and stop location sharing?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);

                final error = await context.read<MemberProvider>().removeMember(
                  currentUid: currentUid,
                  memberUid: member.uid,
                );

                if (mounted) {
                  if (error != null) {
                    _showSnackBar('Failed to remove: $error');
                  } else {
                    _clearSelection();
                    _showSnackBar('Removed $name successfully');
                  }
                }
              },
              child: const Text(
                'Yes',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
