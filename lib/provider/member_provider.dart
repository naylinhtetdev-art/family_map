import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_map/model/member_model.dart';
import 'package:flutter/foundation.dart';

class MemberProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  StreamSubscription? _memberSubscription;

  void clearData() {
    _memberSubscription?.cancel();
    _memberSubscription = null;
    // အခြား Member Data များကိုပါ Reset လုပ်ပါ
    notifyListeners();
  }

  // -------------------------------------------------------------
  // Realtime Shared Members Stream
  // -------------------------------------------------------------
  Stream<List<MemberModel>> getSharedMembersStream(String currentUid) {
    return _firestore.collection('users').doc(currentUid).snapshots().asyncExpand((
      userDoc,
    ) {
      if (!userDoc.exists || userDoc.data() == null) {
        return Stream.value([]);
      }

      final data = userDoc.data()!;
      // 'sharedMembers' array ကို ဆွဲထုတ်ခြင်း
      final List<dynamic> sharedUids = data['sharedMembers'] ?? [];

      if (sharedUids.isEmpty) {
        return Stream.value([]);
      }

      // String List အဖြစ် ပြောင်းလဲခြင်း
      final List<String> targetUids = sharedUids
          .map((e) => e.toString())
          .toList();

      // Firestore whereIn ဖြင့် Target Users Document များကို Stream Listen လုပ်ခြင်း
      // (whereIn သည် အများဆုံး ၁၀ ခုအထိ ရသဖြင့် အခြေခံ ၁၀ ခုထိ Realtime Listen လုပ်ပါမည်)
      final chunk = targetUids.length > 10
          ? targetUids.sublist(0, 10)
          : targetUids;

      return _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .snapshots()
          .map((querySnapshot) {
            return querySnapshot.docs.map((doc) {
              return MemberModel.fromMap(doc.data(), doc.id);
            }).toList();
          });
    });
  }

  // Pending Requests Stream (Profile Screen အတွက်)
  Stream<QuerySnapshot> getPendingRequestsStream(String currentUid) {
    return _firestore
        .collection('requests')
        .where('receiverUid', isEqualTo: currentUid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  // Send Location Sharing Request
  Future<String?> sendLocationRequest({
    required String senderUid,
    required String senderEmail,
    required String targetEmail,
  }) async {
    _setLoading(true);
    try {
      if (senderEmail.trim().toLowerCase() ==
          targetEmail.trim().toLowerCase()) {
        return "You cannot send request to yourself";
      }

      final targetUserQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: targetEmail.trim())
          .limit(1)
          .get();

      if (targetUserQuery.docs.isEmpty) {
        return "User with this email not found";
      }

      final targetUserDoc = targetUserQuery.docs.first;
      final targetUid = targetUserDoc.id;

      // 2. Already shared ဖြစ်ပြီးသားလား စစ်ဆေးခြင်း
      final senderDoc = await _firestore
          .collection('users')
          .doc(senderUid)
          .get();
      if (senderDoc.exists) {
        final List<dynamic> sharedMembers =
            senderDoc.data()?['sharedMembers'] ?? [];
        if (sharedMembers.contains(targetUid)) {
          return "This member is already in your family list";
        }
      }

      final existingReq = await _firestore
          .collection('requests')
          .where('senderUid', isEqualTo: senderUid)
          .where('receiverUid', isEqualTo: targetUid)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingReq.docs.isNotEmpty) {
        return "Request already sent to this user";
      }

      await _firestore.collection('requests').add({
        'senderUid': senderUid,
        'senderEmail': senderEmail,
        'receiverUid': targetUid,
        'receiverEmail': targetEmail,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return null;
    } catch (e) {
      return e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // Accept Request
  Future<String?> acceptRequest({
    required String requestId,
    required String senderUid,
    required String receiverUid,
  }) async {
    try {
      await _firestore.collection('requests').doc(requestId).update({
        'status': 'accepted',
      });

      // နှစ်ဖက်လုံး၏ sharedMembers Array ထဲသို့ arrayUnion ဖြင့် UID ထည့်ခြင်း
      await _firestore.collection('users').doc(senderUid).set({
        'sharedMembers': FieldValue.arrayUnion([receiverUid]),
      }, SetOptions(merge: true));

      await _firestore.collection('users').doc(receiverUid).set({
        'sharedMembers': FieldValue.arrayUnion([senderUid]),
      }, SetOptions(merge: true));

      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Reject Request
  Future<String?> rejectRequest(String requestId) async {
    try {
      await _firestore.collection('requests').doc(requestId).update({
        'status': 'rejected',
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Remove Member
  Future<String?> removeMember({
    required String currentUid,
    required String memberUid,
  }) async {
    try {
      await _firestore.collection('users').doc(currentUid).update({
        'sharedMembers': FieldValue.arrayRemove([memberUid]),
      });

      await _firestore.collection('users').doc(memberUid).update({
        'sharedMembers': FieldValue.arrayRemove([currentUid]),
      });

      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
