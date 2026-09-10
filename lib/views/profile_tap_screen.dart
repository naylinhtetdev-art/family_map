import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_map/provider/auth_provider.dart';
import 'package:family_map/provider/language_provider.dart';
import 'package:family_map/provider/location_provider.dart';
import 'package:family_map/provider/member_provider.dart';
import 'package:family_map/provider/theme_provider.dart';
import 'package:family_map/utils/app_language.dart';
import 'package:family_map/widgtes/change_password.dart';
import 'package:family_map/widgtes/show_noti_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

class ProfileTapScreen extends StatelessWidget {
  const ProfileTapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final memberVM = context.watch<MemberProvider>();
    final languageProvider = context.watch<LanguageProvider>();
    final user = auth.user;
    final theme = Theme.of(context);
    final bgColor = theme.scaffoldBackgroundColor;
    final textColor = theme.colorScheme.onSurface;
    final displayName = user?.displayName ?? 'Family Map user';
    final email = user?.email ?? '';
    final avatarLetter = (user?.displayName ?? user?.email ?? 'U').isNotEmpty
        ? (user?.displayName ?? user?.email ?? 'U')[0].toUpperCase()
        : 'U';

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              CircleAvatar(radius: 30, child: Text(avatarLetter)),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(email),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Preferences',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),

          // Notifications Tile (Real-time Pending Request Count ပါဝင်သည်)
          if (user != null)
            StreamBuilder<QuerySnapshot>(
              stream: memberVM.getPendingRequestsStream(user.uid),
              builder: (context, snapshot) {
                final requests = snapshot.data?.docs ?? [];
                final count = requests.length;

                return ListTile(
                  leading: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.notifications_outlined),
                      if (count > 0)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: const Text('Notifications'),
                  subtitle: Text(
                    count > 0
                        ? 'You have $count location sharing request(s)'
                        : 'No new notifications',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showRequestsDialog(context, requests, user.uid),
                );
              },
            ),
          // _tile(
          //   context,
          //   Icons.language,
          //   'Change Language',
          //   ' Engilsh or Myanmar',
          //   onTap: () {},
          // ),
          ListTile(
            leading: Icon(Icons.language_outlined, color: textColor),
            title: Text(
              AppLocale.selectLanguage.getString(context),
              style: TextStyle(color: textColor),
            ),
            trailing: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: languageProvider.currentLanguage,
                icon: Icon(Icons.arrow_drop_down, color: textColor),
                dropdownColor: Theme.of(context).canvasColor,
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'my', child: Text('မြန်မာ')),
                ],
                onChanged: (String? languageCode) {
                  if (languageCode != null) {
                    context.read<LanguageProvider>().changeLanguage(
                      languageCode,
                    );
                    // FlutterLocalization.instance.translate(
                    //   languageCode,
                    // );
                  }
                },
              ),
            ),
            onTap: () {},
          ),
          Consumer<ThemeProvider>(
            builder: (_, p, __) {
              return SwitchListTile(
                value: p.themeMode == ThemeMode.dark,
                title: const Text('Dark mode'),
                secondary: const Icon(Icons.dark_mode_outlined),
                onChanged: (v) =>
                    p.setThemeMode(v ? ThemeMode.dark : ThemeMode.light),
              );
            },
          ),
          const Divider(),
          const Text('Account', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _tile(
            context,
            Icons.lock_outline,
            'Change password',
            'Send a password reset email',
            onTap: () async {
              showChangePasswordDialog(context);
            },
          ),
          _tile(
            context,
            Icons.info_outline,
            'About Family Map',
            'naylinhtet.dev@gmail.com',
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Log out', style: TextStyle(color: Colors.red)),
            onTap: () async {
              final locationProvider = context.read<LocationProvider>();
              final memberProvider = context.read<MemberProvider>();
              final languageProvider = context.read<LanguageProvider>();

              try {
                await auth.logout();
                locationProvider.stopLocationTracking();
                memberProvider.clearData();
                languageProvider.clearData();
                locationProvider.clearData();
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Unable to log out. Please try again.'),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle, {
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
