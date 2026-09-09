// Location Request လက်ခံရန်/ငင်းပယ်ရန် ပေါ်လာမည့် Dialog
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_map/provider/member_provider.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:provider/provider.dart';

void showRequestsDialog(
  BuildContext context,
  List<QueryDocumentSnapshot> requests,
  String myUid,
) {
  if (requests.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No pending location requests')),
    );
    return;
  }

  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Location Requests (${requests.length})'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: requests.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final doc = requests[index];
              final data = doc.data() as Map<String, dynamic>;
              final senderEmail = data['senderEmail'] ?? 'Unknown Email';
              final senderUid = data['senderUid'] ?? '';

              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  senderEmail,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('wants to share location with you.'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Reject / Cancel Button
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      tooltip: 'Reject',
                      onPressed: () async {
                        await context.read<MemberProvider>().rejectRequest(
                          doc.id,
                        );

                        // Request ၁ ခုပဲ ရှိရင် Dialog ပါ ပိတ်မည်၊ ၁ ခုထက် ပိုပါက Dialog မပိတ်ဘဲ ကျန်ခဲ့မည်
                        if (requests.length <= 1 && dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Rejected request from $senderEmail',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    // Accept Button
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      tooltip: 'Accept',
                      onPressed: () async {
                        await context.read<MemberProvider>().acceptRequest(
                          requestId: doc.id,
                          senderUid: senderUid,
                          receiverUid: myUid,
                        );

                        // Request ၁ ခုပဲ ရှိရင် Dialog ပါ ပိတ်မည်၊ ၁ ခုထက် ပိုပါက Dialog မပိတ်ဘဲ ကျန်ခဲ့မည်
                        if (requests.length <= 1 && dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Accepted request from $senderEmail',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}
