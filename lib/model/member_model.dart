// class MemberModel {
//   final String uid;
//   final String name;
//   final String email;
//   final double latitude;
//   final double longitude;

//   MemberModel({
//     required this.uid,
//     required this.name,
//     required this.email,
//     required this.latitude,
//     required this.longitude,
//   });

//   factory MemberModel.fromMap(Map<String, dynamic> map, String id) {
//     return MemberModel(
//       uid: id,
//       name: map['name'] ?? '',
//       email: map['email'] ?? '',
//       latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
//       longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
//     );
//   }
// }
class MemberModel {
  final String uid;
  final String name;
  final String email;
  final double latitude;
  final double longitude;

  MemberModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.latitude,
    required this.longitude,
  });

  factory MemberModel.fromMap(Map<String, dynamic> map, String docId) {
    return MemberModel(
      uid: docId,
      name: map['name'] ?? map['displayName'] ?? '',
      email: map['email'] ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
