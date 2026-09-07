import 'package:family_map/provider/auth_provider.dart';
import 'package:family_map/provider/location_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        // Firebase Auth UID ကို ယူ၍ Live Location Tracking စတင်ပါ
        context.read<LocationProvider>().startLocationTracking(user.uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthProvider>();
    final locationVM = context.watch<LocationProvider>();
    final user = authVM.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Location Tracker'),
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Logged in as: ${user?.email ?? ""}'),
            Text('User ID: ${user?.uid ?? ""}'),
            const Divider(height: 30),
            if (locationVM.currentPosition != null) ...[
              Text('Latitude: ${locationVM.currentPosition!.latitude}'),
              Text('Longitude: ${locationVM.currentPosition!.longitude}'),
            ],
            const SizedBox(height: 20),
            Text(
              locationVM.isTracking
                  ? 'Tracking Status: Active'
                  : 'Tracking Status: Inactive',
              style: TextStyle(
                color: locationVM.isTracking ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
