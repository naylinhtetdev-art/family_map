import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

@pragma('vm:entry-point')
void startLocationTask() {
  FlutterForegroundTask.setTaskHandler(LocationTaskHandler());
}

class LocationTaskHandler extends TaskHandler {
  StreamSubscription<Position>? _positionSubscription;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    final LocationSettings locationSettings = switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        forceLocationManager: true,
        foregroundNotificationConfig: null,
      ),
      TargetPlatform.iOS => AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.fitness,
        distanceFilter: 10,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      ),
      _ => const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    };

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (position) {
            FlutterForegroundTask.sendDataToMain({
              'type': 'location',
              'latitude': position.latitude,
              'longitude': position.longitude,
              'accuracy': position.accuracy,
              'timestamp': position.timestamp.millisecondsSinceEpoch,
            });
          },
        );
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  @override
  void onReceiveData(Object data) {}
}

class LocationProvider extends ChangeNotifier {
  bool _isTracking = false;
  bool _isTaskDataCallbackRegistered = false;
  String? _errorMessage;
  Position? _currentPosition;

  bool get isTracking => _isTracking;
  String? get errorMessage => _errorMessage;
  Position? get currentPosition => _currentPosition;

  StreamSubscription? _memberSubscription;

  void clearData() {
    _memberSubscription?.cancel();
    _memberSubscription = null;
    _currentPosition = null;
    notifyListeners();
  }

  // 1. GPS Service ပွင့်/မပွင့် စစ်ဆေးခြင်း
  Future<bool> checkAndEnableLocationService(BuildContext context) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled && context.mounted) {
        _showEnableGpsDialog(context);
      }
    }
    return serviceEnabled;
  }

  void _showEnableGpsDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Location Service Disabled'),
          content: const Text(
            'Your device Location (GPS) is turned off. Please turn it on to share your live location.',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await Geolocator.openLocationSettings();
              },
              child: const Text('Turn On Location'),
            ),
          ],
        );
      },
    );
  }

  // 2. Permission စစ်ဆေးခြင်း (Always Location Permission ပါ တောင်းဆိုရန် ပြင်ထားသည်)
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

  // 3. Foreground Task စတင်ခြင်း နှင့် Service Start လုပ်ခြင်း
  Future<void> startLocationTracking(String userId) async {
    try {
      final hasPermission = await _checkPermission();
      if (!hasPermission) return;

      final notificationPermission =
          await FlutterForegroundTask.checkNotificationPermission();
      if (notificationPermission != NotificationPermission.granted) {
        final result =
            await FlutterForegroundTask.requestNotificationPermission();
        if (result != NotificationPermission.granted) {
          _errorMessage =
              'Notification permission is required for live tracking.';
          notifyListeners();
          return;
        }
      }

      await FlutterForegroundTask.saveData(key: 'userId', value: userId);

      // Service စတင်ထားခြင်း ရှိမရှိ စစ်ဆေးခြင်း
      bool isRunning = await FlutterForegroundTask.isRunningService;

      if (!_isTaskDataCallbackRegistered) {
        FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
        _isTaskDataCallbackRegistered = true;
      }

      if (!isRunning) {
        // Background Task အား စတင်ရန် တောင်းဆိုခြင်း
        await FlutterForegroundTask.startService(
          serviceId: 256,
          notificationTitle: 'Family Map Service',
          notificationText: 'Sharing live location in background...',
          notificationIcon: const NotificationIcon(
            metaDataName: 'flutter_foreground_task_notification_icon',
          ),
          callback: startLocationTask,
        );
      }

      _isTracking = true;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Location Tracking Start Error: $e';
      debugPrint("Location Tracking Start Error: $e");
    }
  }

  // 4. Task မှ အချက်အလက်များ လက်ခံရရှိချိန် Call back ပြုလုပ်ခြင်း
  void _onReceiveTaskData(Object data) {
    if (data is! Map || data['type'] != 'location') return;

    final latitude = (data['latitude'] as num?)?.toDouble();
    final longitude = (data['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) return;

    _currentPosition = Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (data['timestamp'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      ),
      accuracy: (data['accuracy'] as num?)?.toDouble() ?? 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
    notifyListeners();
  }

  // 5. Tracking နှင့် Foreground Service ကို ပိတ်ခြင်း
  Future<void> stopLocationTracking() async {
    if (_isTaskDataCallbackRegistered) {
      FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
      _isTaskDataCallbackRegistered = false;
    }

    // Foreground Service ကို ရပ်တန့်ပေးခြင်း
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }

    _isTracking = false;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_isTaskDataCallbackRegistered) {
      FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    }
    _memberSubscription?.cancel();
    super.dispose();
  }
}
