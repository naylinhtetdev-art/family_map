import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_map/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
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
  String? _userId;
  DateTime? _lastPositionAt;
  bool _isRestarting = false;
  bool _isWriting = false;
  Position? _pendingPosition;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // The foreground task runs in its own Dart isolate.
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    // 2. FlutterForegroundTask တွင် သိမ်းထားသော userId ကို ပြန်ယူပါ
    _userId = await FlutterForegroundTask.getData<String>(key: 'userId');
    await _startLocationStream();
  }

  // Location Stream ကို သီးသန့် Function ခွဲထုတ်ထားခြင်း
  Future<void> _startLocationStream() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;

    final LocationSettings locationSettings = switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        intervalDuration: const Duration(seconds: 30),
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

    try {
      final initialPosition = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );
      await _handlePosition(initialPosition);
    } catch (error) {
      debugPrint('Initial location error: $error');
    }
    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          _handlePosition,
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('Location stream error: $error');
            unawaited(_restartLocationStream());
          },
        );
  }

  Future<void> _handlePosition(Position position) async {
    _lastPositionAt = DateTime.now();
    FlutterForegroundTask.sendDataToMain({
      'type': 'location',
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
      'timestamp': position.timestamp.millisecondsSinceEpoch,
    });

    await _updateLocationToFirebase(position);
  }

  // Keep only one Firestore write active. If GPS emits faster than the network,
  // retain the newest point instead of building an unbounded queue.
  Future<void> _updateLocationToFirebase(Position position) async {
    if (_isWriting) {
      _pendingPosition = position;
      return;
    }

    _isWriting = true;
    var nextPosition = position;
    try {
      while (true) {
        _pendingPosition = null;
        final userId = _userId;
        if (userId == null || userId.isEmpty) return;
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'latitude': nextPosition.latitude,
          'longitude': nextPosition.longitude,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        final pending = _pendingPosition;
        if (pending == null) return;
        nextPosition = pending;
      }
    } catch (error) {
      debugPrint('Firestore update error: $error');
    } finally {
      _isWriting = false;
    }
  }

  Future<void> _restartLocationStream() async {
    if (_isRestarting) return;
    _isRestarting = true;
    try {
      await _positionSubscription?.cancel();
      _positionSubscription = null;
      await Future<void>.delayed(const Duration(seconds: 5));
      await _startLocationStream();
    } finally {
      _isRestarting = false;
    }
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    FlutterForegroundTask.sendDataToMain({'type': 'ping'});

    // If the platform has provided no position for a minute, request one as a
    // fallback. This protects against a paused stream after screen lock without
    // polling Firebase/GPS on every foreground-task tick.
    if (_lastPositionAt == null ||
        DateTime.now().difference(_lastPositionAt!) >=
            const Duration(minutes: 1)) {
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 20),
          ),
        );
        await _handlePosition(position);
      } catch (error) {
        debugPrint('Background location fallback error: $error');
        unawaited(_restartLocationStream());
      }
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    // Service ကို ရပ်တန့်ပေးမည်
    //await FlutterForegroundTask.stopService();
  }

  @override
  void onReceiveData(Object data) {}
}

class LocationProvider extends ChangeNotifier {
  bool _isTracking = false;
  bool _isTaskDataCallbackRegistered = false;
  bool _isForegroundTaskInitialized = false;
  String? _errorMessage;
  Position? _currentPosition;

  bool get isTracking => _isTracking;
  String? get errorMessage => _errorMessage;
  Position? get currentPosition => _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription? _memberSubscription;

  void clearData() {
    _positionStreamSubscription?.cancel();
    _memberSubscription?.cancel();
    _memberSubscription = null;
    _currentPosition = null;
    notifyListeners();
  }

  // App ဖွင့်ဖွင့်ချင်း တည်နေရာရယူရန်နှင့် Live Stream စတင်ရန်
  Future<void> fetchInitialLocation() async {
    try {
      bool hasPermission = await _checkPermission();
      if (!hasPermission) return;

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _currentPosition = position;
      notifyListeners();
      _startLocalLocationStream();
    } catch (e) {
      debugPrint("Error fetching initial location: $e");
    }
  }

  // UI ပေါ်တွင် Location အမြဲတမ်း Live ပြောင်းနေစေရန် Local Stream
  void _startLocalLocationStream() {
    _positionStreamSubscription?.cancel();
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // 10 မီတာ ရွှေ့တိုင်း UI update လုပ်မည်
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            _currentPosition = position;
            notifyListeners(); // UI ထံ တည်နေရာသစ် ပို့ပေးမည်
          },
        );
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

  Future<bool> _checkPermission() async {
    // 1. GPS Service ပွင့်/မပွင့် စစ်ဆေးခြင်း
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _errorMessage = 'Location services are disabled.';
      notifyListeners();
      return false;
    }

    // 2. လက်ရှိ Permission အခြေအနေ စစ်ဆေးခြင်း
    LocationPermission permission = await Geolocator.checkPermission();

    // 3. Permission ငြင်းထားဆဲ (denied) ဖြစ်မှသာ တောင်းဆိုမည်
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _errorMessage =
            'Location permission is required to share your live location.';
        notifyListeners();
        return false;
      }
    }

    // 4. Permanently Denied ဖြစ်နေပါက Settings သို့ သွားခိုင်းမည်
    if (permission == LocationPermission.deniedForever) {
      _errorMessage = 'Location permissions are permanently denied.';
      notifyListeners();
      return false;
    }

    // 5. Platform အလိုက် Background Tracking Permission စစ်ဆေးခြင်း
    final bool permissionAllowsTracking = Platform.isAndroid
        ? (permission == LocationPermission.whileInUse ||
              permission == LocationPermission.always)
        : (permission == LocationPermission.always);

    if (!permissionAllowsTracking) {
      _errorMessage = Platform.isIOS
          ? 'Set location access to "Always" to share location in the background.'
          : 'Location permission is required to share your live location.';
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

      // Some Android vendors stop foreground services aggressively after the
      // display is locked. The user can approve the platform battery exemption.
      if (Platform.isAndroid &&
          !await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }

      await FlutterForegroundTask.saveData(key: 'userId', value: userId);

      if (!_isForegroundTaskInitialized) {
        FlutterForegroundTask.init(
          androidNotificationOptions: AndroidNotificationOptions(
            channelId: 'foreground_service',
            channelName: 'Location Tracking Service',
            channelDescription: 'Running location service in background.',
            channelImportance: NotificationChannelImportance.LOW,
            priority: NotificationPriority.LOW,
          ),
          iosNotificationOptions: const IOSNotificationOptions(),
          foregroundTaskOptions: ForegroundTaskOptions(
            eventAction: ForegroundTaskEventAction.repeat(30000),
            autoRunOnBoot: false,
            autoRunOnMyPackageReplaced: false,
            stopWithTask: false,
            allowWakeLock: true,
            allowWifiLock: true,
          ),
        );
        _isForegroundTaskInitialized = true;
      }

      // Service စတင်ထားခြင်း ရှိမရှိ စစ်ဆေးခြင်း
      bool isRunning = await FlutterForegroundTask.isRunningService;

      if (!_isTaskDataCallbackRegistered) {
        FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
        _isTaskDataCallbackRegistered = true;
      }

      if (!isRunning) {
        // Background Task အား စတင်ရန် တောင်းဆိုခြင်း
        final result = await FlutterForegroundTask.startService(
          serviceId: 256,
          notificationTitle: 'Family Map Service',
          notificationText: 'Sharing live location in background...',
          callback: startLocationTask,
        );
        if (result is ServiceRequestFailure) {
          _errorMessage = 'Unable to start location service: ${result.error}';
          _isTracking = false;
          notifyListeners();
          return;
        }
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
