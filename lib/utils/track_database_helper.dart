import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class TrackDatabaseHelper {
  static final TrackDatabaseHelper instance = TrackDatabaseHelper._init();
  static Database? _database;

  TrackDatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('track_records.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    // Session Table
    await db.execute('''
      CREATE TABLE track_sessions (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        startTime TEXT NOT NULL,
        endTime TEXT,
        isSynced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Points Table (Path points & Tapped points)
    await db.execute('''
      CREATE TABLE track_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sessionId TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        timestamp TEXT NOT NULL,
        pointType TEXT NOT NULL, -- 'path' or 'tapped'
        placeName TEXT,
        FOREIGN KEY (sessionId) REFERENCES track_sessions (id) ON DELETE CASCADE
      )
    ''');
  }

  // ၁။ Session စတင်ခြင်း
  Future<void> insertSession(String sessionId, String userId) async {
    final db = await instance.database;
    await db.insert('track_sessions', {
      'id': sessionId,
      'userId': userId,
      'startTime': DateTime.now().toIso8601String(),
      'isSynced': 0,
    });
  }

  // ⭐ ၂။ Record ပိတ်သည့်အခါ Session ကို အဆုံးသတ်ခြင်း (endTime ဖြည့်မည်)
  Future<void> closeSession(String sessionId) async {
    final db = await instance.database;
    await db.update(
      'track_sessions',
      {'endTime': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  // ၃။ Point တစ်ခုချင်း သိမ်းခြင်း (Tapped Point သိမ်းရန် သုံးနိုင်သည်)
  Future<void> insertPoint({
    required String sessionId,
    required double latitude,
    required double longitude,
    required String pointType,
    String? placeName,
  }) async {
    final db = await instance.database;
    await db.insert('track_points', {
      'sessionId': sessionId,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': DateTime.now().toIso8601String(),
      'pointType': pointType,
      'placeName': placeName,
    });
  }

  // ⭐ ၄။ Record ပိတ်ချိန်တွင် Recorded Path Points များကို Batch ဖြင့် Fast Insert သိမ်းဆည်းခြင်း
  Future<void> insertPathPointsBatch({
    required String sessionId,
    required List<Map<String, double>> points, // [{'lat': 16.8, 'lng': 96.1}]
  }) async {
    final db = await instance.database;
    final batch = db.batch();
    final nowStr = DateTime.now().toIso8601String();

    for (var pt in points) {
      batch.insert('track_points', {
        'sessionId': sessionId,
        'latitude': pt['lat'],
        'longitude': pt['lng'],
        'timestamp': nowStr,
        'pointType': 'path',
        'placeName': null,
      });
    }

    await batch.commit(noResult: true);
  }

  // ⭐ ၅။ သိမ်းထားသမျှ Tapped Location Markers အားလုံးကို ပြန်ယူခြင်း
  Future<List<Map<String, dynamic>>> getAllTappedPoints() async {
    final db = await instance.database;
    return await db.query(
      'track_points',
      where: 'pointType = ?',
      whereArgs: ['tapped'],
      orderBy: 'id DESC',
    );
  }

  // ⭐ ၆။ Tapped Marker ကို တည်နေရာဖြင့် ရှာပြီး ဖျက်ခြင်း
  Future<void> deleteTappedPoint(double latitude, double longitude) async {
    final db = await instance.database;
    await db.delete(
      'track_points',
      where: 'pointType = ? AND latitude = ? AND longitude = ?',
      whereArgs: ['tapped', latitude, longitude],
    );
  }

  Future<List<Map<String, dynamic>>> getUnsyncedSessions() async {
    final db = await instance.database;
    return await db.query(
      'track_sessions',
      where: 'isSynced = ?',
      whereArgs: [0],
    );
  }

  Future<List<Map<String, dynamic>>> getPointsForSession(
    String sessionId,
  ) async {
    final db = await instance.database;
    return await db.query(
      'track_points',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> markSessionSynced(String sessionId) async {
    final db = await instance.database;
    await db.update(
      'track_sessions',
      {'isSynced': 1},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }
}
