import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await initDB();
    return _db!;
  }

  static Future<Database> initDB() async {
    String path = join(await getDatabasesPath(), 'location_tracker.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE route_points (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            latitude REAL,
            longitude REAL,
            timestamp INTEGER,
            is_synced INTEGER DEFAULT 0
          )
        ''');
      },
    );
  }

  // ၁။ Location Point အသစ် ထည့်ခြင်း
  static Future<int> insertPoint(double lat, double lng, int timestamp) async {
    final db = await database;
    return await db.insert('route_points', {
      'latitude': lat,
      'longitude': lng,
      'timestamp': timestamp,
      'is_synced': 0, // အစမှာ sync မလုပ်ရသေး
    });
  }

  // ၂။ Unsynced ဖြစ်နေသော (Sync မလုပ်ရသေးသော) Points များကို ဆွဲထုတ်ခြင်း
  static Future<List<Map<String, dynamic>>> getUnsyncedPoints() async {
    final db = await database;
    return await db.query(
      'route_points',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
  }

  // ၃။ Sync လုပ်ပြီးပါက Status ပြောင်းခြင်း
  static Future<void> markAsSynced(List<int> ids) async {
    final db = await database;
    for (int id in ids) {
      await db.update(
        'route_points',
        {'is_synced': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  // ၄။ မြေပုံပေါ်မှာ ပြသရန် Point အားလုံး ဆွဲထုတ်ခြင်း
  static Future<List<Map<String, dynamic>>> getAllPoints() async {
    final db = await database;
    return await db.query('route_points', orderBy: 'timestamp ASC');
  }
}
