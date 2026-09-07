import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final double latitude;
  final double longitude;
  final DateTime? lastUpdated;

  UserModel({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel(
      id: doc.id,
      latitude: (data['latitude'] ?? 0.0) as double,
      longitude: (data['longitude'] ?? 0.0) as double,
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate(),
    );
  }
}
