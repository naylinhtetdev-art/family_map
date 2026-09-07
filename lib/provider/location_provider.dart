import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_map/model/user_model.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<Position>? _positionStreamSubscription;

  bool _isTracking = false;
  String? _errorMessage;
  Position? _currentPosition;

  bool get isTracking => _isTracking;
  String? get errorMessage => _errorMessage;
  Position? get currentPosition => _currentPosition;

  // Location Permission စစ်ဆေးခြင်း
  Future<bool> _checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _errorMessage = 'Location services are disabled.';
      notifyListeners();
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _errorMessage = 'Location permissions are denied.';
        notifyListeners();
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _errorMessage = 'Location permissions are permanently denied.';
      notifyListeners();
      return false;
    }

    _errorMessage = null;
    return true;
  }

  // Live Location Tracking စတင်ခြင်း
  Future<void> startLocationTracking(String userId) async {
    final hasPermission = await _checkPermission();
    if (!hasPermission) return;

    _isTracking = true;
    notifyListeners();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // 10 meters ရွေ့မှ update လုပ်မည်
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            _currentPosition = position;
            _updateLocationInFirestore(userId, position);
            notifyListeners();
          },
        );
  }

  // Firestore ထဲသို့ Location Update လုပ်ခြင်း
  Future<void> _updateLocationInFirestore(
    String userId,
    Position position,
  ) async {
    final userLocation = UserModel(
      id: userId,
      latitude: position.latitude,
      longitude: position.longitude,
    );

    await _firestore
        .collection('users')
        .doc(userId)
        .set(userLocation.toMap(), SetOptions(merge: true));
  }

  // Tracking ရပ်တန့်ခြင်း
  void stopLocationTracking() {
    _positionStreamSubscription?.cancel();
    _isTracking = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }
}
