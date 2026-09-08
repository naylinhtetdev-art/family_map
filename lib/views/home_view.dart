import 'package:family_map/provider/auth_provider.dart';
import 'package:family_map/provider/location_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final MapController _mapController = MapController();

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

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthProvider>();
    final locationVM = context.watch<LocationProvider>();

    // LocationProvider ထဲမှ Current Position ကို ယူသုံးခြင်း
    final currentPos = locationVM.currentPosition;

    // Position မရသေးပါက Default Location ပြထားမည် (Position ရလာပါက Real Coordinates ကို သုံးမည်)
    final LatLng location = currentPos != null
        ? LatLng(currentPos.latitude, currentPos.longitude)
        : const LatLng(37.4219983, -122.084);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<LocationProvider>().stopLocationTracking();
              authVM.logout();
            },
          ),
        ],
      ),
      body: currentPos == null
          ? const Center(
              child: CircularProgressIndicator(),
            ) // Location မရသေးမီ Loading ပြထားခြင်း
          : FlutterMap(
              mapController: _mapController,
              options: MapOptions(initialCenter: location, initialZoom: 15.0),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.naylinhtet.family_map',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: location,
                      width: 80,
                      height: 80,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
