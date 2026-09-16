import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_map/utils/track_database_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class TrackRecordProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isRecording = false;
  String? _currentSessionId;
  StreamSubscription<Position>? _positionSubscription;

  final List<LatLng> _recordedPath = [];
  final List<Map<String, dynamic>> _tappedMarkers = [];

  bool get isRecording => _isRecording;
  List<LatLng> get recordedPath => List.unmodifiable(_recordedPath);
  List<Map<String, dynamic>> get tappedMarkers =>
      List.unmodifiable(_tappedMarkers);

  TrackRecordProvider() {
    // App စဖွင့်ချိန်တွင် SQLite DB ထဲမှ Tapped Point (Saved Markers) များကို Load လုပ်ပါမည်
    loadSavedTappedPoints();
  }

  // ⭐ Record စတင်ခြင်း / ရပ်တန့်ခြင်း Switch
  Future<void> toggleRecording(String userId) async {
    if (_isRecording) {
      await stopRecording();
    } else {
      await startRecording(userId);
    }
  }

  // 🟢 Record စတင်ခြင်း
  Future<void> startRecording(String userId) async {
    _isRecording = true;
    _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _recordedPath.clear();
    notifyListeners();

    // ၁။ SQLite တွင် Session အသစ်ဆောက်မည်
    await TrackDatabaseHelper.instance.insertSession(
      _currentSessionId!,
      userId,
    );

    // ၂။ Live GPS Stream နားထောင်ပြီး Path Points များကို Memory ထဲရော SQLite ထဲပါ တန်းသိမ်းမည်
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5, // ၅ မီတာ ရွှေ့တိုင်း Point အသစ်ယူမည်
          ),
        ).listen((Position position) async {
          final point = LatLng(position.latitude, position.longitude);
          _recordedPath.add(point);
          notifyListeners();

          // SQLite သို့ GPS Point ကို တိုက်ရိုက်သိမ်းမည်
          if (_currentSessionId != null) {
            await TrackDatabaseHelper.instance.insertPoint(
              sessionId: _currentSessionId!,
              latitude: position.latitude,
              longitude: position.longitude,
              pointType: 'path',
            );
          }
          notifyListeners();
        });
  }

  // 🔄 Active Session ရှိနေပါက SQLite မှ Path Points များကို ပြန်လည် Load လုပ်သည့် Function
  Future<void> reloadCurrentSessionPath() async {
    if (_isRecording && _currentSessionId != null) {
      try {
        final pointsData = await TrackDatabaseHelper.instance
            .getPointsForSession(_currentSessionId!);
        _recordedPath.clear();

        for (var p in pointsData) {
          if (p['pointType'] == 'path') {
            _recordedPath.add(
              LatLng(p['latitude'] as double, p['longitude'] as double),
            );
          }
        }
        notifyListeners();
      } catch (e) {
        debugPrint('Error reloading session path: $e');
      }
    }
  }

  // 🔴 Record ရပ်တန့်ခြင်း
  Future<void> stopRecording() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;

    if (_currentSessionId != null) {
      // Session ကို End Time ဖြည့်ပြီး ပိတ်မည်
      await TrackDatabaseHelper.instance.closeSession(_currentSessionId!);

      // အော့ဖ်လိုင်း/အွန်လိုင်း Data များကို Firebase Firestore သို့ Sync လုပ်မည်
      await syncUnsyncedTracksToFirebase();
    }

    _isRecording = false;
    _currentSessionId = null;
    notifyListeners();
  }

  // ☁️ ဖုန်းအသစ် သို့မဟုတ် App ပြန်ပွင့်ချိန် Firestore ထဲမှ Records များကို ပြန်ဆွဲယူခြင်း
  Future<void> fetchUserTracksFromFirebase(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('records')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      _recordedPath.clear();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final List pathPoints = data['pathPoints'] ?? [];

        // Firestore ထဲမှ Path Points များကို Map Polyline အတွက် LatLng List အဖြစ် ပြောင်းပေးခြင်း
        for (var p in pathPoints) {
          if (p['latitude'] != null && p['longitude'] != null) {
            _recordedPath.add(
              LatLng(
                (p['latitude'] as num).toDouble(),
                (p['longitude'] as num).toDouble(),
              ),
            );
          }
        }
      }

      // SQLite DB ထဲသို့လည်း Synchronize ပြန်လုပ်ပေးခြင်း (Offline ရနိုင်ရန်)
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching tracks from Firebase: $e');
    }
  }

  // 📍 Tap / Long Press လုပ်ထားသော Marker ကို သိမ်းဆည်းခြင်း
  Future<void> addTappedPoint(LatLng point, String placeName) async {
    // Session မရှိသေးပါက Temp Session ID တစ်ခုဖြင့် သိမ်းပေးမည်
    final sessionId = _currentSessionId ?? 'SAVED_MARKERS_SESSION';

    // Temp Session ID သုံးထားပါက Table Constraint မငြိစေရန် DB Session အရင် Insert လုပ်မည်
    if (_currentSessionId == null) {
      await TrackDatabaseHelper.instance.insertSession(sessionId, 'local_user');
    }

    final newMarker = {
      'point': point,
      'name': placeName,
      'latitude': point.latitude,
      'longitude': point.longitude,
    };

    _tappedMarkers.add(newMarker);
    notifyListeners();

    // SQLite သို့ Tapped Point သိမ်းမည်
    await TrackDatabaseHelper.instance.insertPoint(
      sessionId: sessionId,
      latitude: point.latitude,
      longitude: point.longitude,
      pointType: 'tapped',
      placeName: placeName,
    );
  }

  // 🗑️ DB ထဲမှ Tapped Marker ဖျက်ခြင်း
  Future<void> removeTappedPoint(LatLng point) async {
    await TrackDatabaseHelper.instance.deleteTappedPoint(
      point.latitude,
      point.longitude,
    );
    _tappedMarkers.removeWhere((m) {
      final p = m['point'] as LatLng;
      return p.latitude == point.latitude && p.longitude == point.longitude;
    });
    notifyListeners();
  }

  // 🔄 DB မှ Tapped Points များကို Load ပြန်လုပ်ခြင်း
  Future<void> loadSavedTappedPoints() async {
    try {
      final savedData = await TrackDatabaseHelper.instance.getAllTappedPoints();
      _tappedMarkers.clear();

      for (var item in savedData) {
        _tappedMarkers.add({
          'point': LatLng(
            item['latitude'] as double,
            item['longitude'] as double,
          ),
          'name': item['placeName'] ?? 'Saved Location',
          'latitude': item['latitude'],
          'longitude': item['longitude'],
        });
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading saved markers: $e');
    }
  }

  // ☁️ Sync Unsynced Tracks to Firebase Firestore
  Future<void> syncUnsyncedTracksToFirebase() async {
    try {
      final unsyncedSessions = await TrackDatabaseHelper.instance
          .getUnsyncedSessions();

      for (var session in unsyncedSessions) {
        final sessionId = session['id'] as String;
        final userId = session['userId'] as String;
        final points = await TrackDatabaseHelper.instance.getPointsForSession(
          sessionId,
        );

        final List<Map<String, dynamic>> pathPoints = [];
        final List<Map<String, dynamic>> tappedPoints = [];

        for (var p in points) {
          final pointData = {
            'latitude': p['latitude'],
            'longitude': p['longitude'],
            'timestamp': p['timestamp'],
          };

          if (p['pointType'] == 'path') {
            pathPoints.add(pointData);
          } else {
            pointData['placeName'] = p['placeName'];
            tappedPoints.add(pointData);
          }
        }

        // Firestore သို့ သိမ်းမည်
        await FirebaseFirestore.instance
            .collection('records')
            .doc(sessionId)
            .set({
              'sessionId': sessionId,
              'userId': userId,
              'startTime': session['startTime'],
              'endTime': session['endTime'] ?? DateTime.now().toIso8601String(),
              'pathPoints': pathPoints,
              'tappedMarkers': tappedPoints,
              'createdAt': FieldValue.serverTimestamp(),
            });

        // Sync အောင်မြင်ပါက SQLite တွင် isSynced = 1 ဟု ပြောင်းမည်
        await TrackDatabaseHelper.instance.markSessionSynced(sessionId);
      }
    } catch (e) {
      debugPrint('Offline mode or Sync error: $e');
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  void addCurrentLocation(LatLng newPos) {
    _recordedPath.add(newPos);
    notifyListeners();
  }

  final List<Map<String, dynamic>> _savedLocations = [];
  List<Map<String, dynamic>> get savedLocations => _savedLocations;

  Future<void> saveCustomLocation({
    required String userId,
    required String placeName,
    required LatLng point,
  }) async {
    try {
      final docRef = await _firestore.collection('saved_locations').add({
        'userId': userId,
        'placeName': placeName,
        'latitude': point.latitude,
        'longitude': point.longitude,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Local State ထဲသို့လည်း ချက်ချင်း ထည့်ပေးပါ
      _savedLocations.add({
        'id': docRef.id,
        'userId': userId,
        'placeName': placeName,
        'latitude': point.latitude,
        'longitude': point.longitude,
      });

      // UI ကို ချက်ချင်း Refresh ဖြစ်အောင် လုပ်ပေးပါ
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving location: $e');
      rethrow;
    }
  }
}
