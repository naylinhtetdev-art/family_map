import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:family_map/utils/db_helper.dart';

class SyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sync Logic လုပ်ဆောင်ရန်
  Future<void> syncLocalDataToFirestore(String tripId) async {
    // အင်တာနက် ရှိ/မရှိ စစ်ဆေးခြင်း
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
      print('No Internet Connection. Skipping Sync.');
      return;
    }

    // Sync မလုပ်ရသေးသော Data များ ဆွဲထုတ်ခြင်း
    List<Map<String, dynamic>> unsyncedPoints =
        await DBHelper.getUnsyncedPoints();
    if (unsyncedPoints.isEmpty) return;

    WriteBatch batch = _firestore.batch();
    List<int> syncedIds = [];

    for (var point in unsyncedPoints) {
      DocumentReference docRef = _firestore
          .collection('trips')
          .doc(tripId)
          .collection('points')
          .doc(point['id'].toString());

      batch.set(docRef, {
        'latitude': point['latitude'],
        'longitude': point['longitude'],
        'timestamp': point['timestamp'],
      });

      syncedIds.add(point['id']);
    }

    // Firestore သို့ Batch တင်ခြင်း
    await batch.commit();

    // Local DB မှာ Synced အဖြစ် အမှတ်အသားပြုခြင်း
    await DBHelper.markAsSynced(syncedIds);
    print('Successfully synced ${syncedIds.length} points to Firestore!');
  }
}
