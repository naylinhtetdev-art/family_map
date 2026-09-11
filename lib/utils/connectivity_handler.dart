import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ConnectivityHandler {
  // Internet ရှိ မရှိ စစ်ဆေးပြီး ပိတ်ထားပါက Dialog ပြရန်
  static Future<bool> checkAndPromptInternet(BuildContext context) async {
    final List<ConnectivityResult> connectivityResult = await (Connectivity()
        .checkConnectivity());

    // Internet Connection မရှိပါက (Wi-Fi, Mobile, Ethernet တစ်ခုမှ မရှိလျှင်)
    if (connectivityResult.contains(ConnectivityResult.none)) {
      if (context.mounted) {
        _showNoInternetDialog(context);
      }
      return false; // Internet ပိတ်ထားသည်
    }
    return true; // Internet ပွင့်နေသည်
  }

  // Internet ဖွင့်ရန် Alert Dialog ပြပေးခြင်း
  static void _showNoInternetDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible:
          true, // Dialog ကို အပြင်နှိပ်ပြီး ပိတ်မရအောင် ပြုလုပ်ထားခြင်း
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          title: Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.red),
              SizedBox(width: 10.w),
              Text('No Internet Connection'),
            ],
          ),
          content: const Text(
            'Your Internet connection is turned off. Please enable Wi-Fi or Mobile Data to update your live location and fetch family member details.',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                // User ကို အင်တာနက် ပြန်စစ်ဆေးနိုင်ရန် ထပ်မံ call လုပ်ပေးခြင်း
                await checkAndPromptInternet(context);
              },
              child: const Text('Retry'),
            ),
          ],
        );
      },
    );
  }
}
