import 'package:family_map/main.dart';
import 'package:family_map/provider/auth_provider.dart';
import 'package:family_map/provider/language_provider.dart';
import 'package:family_map/provider/location_provider.dart';
import 'package:family_map/provider/member_provider.dart';
import 'package:family_map/provider/theme_provider.dart';
import 'package:family_map/utils/app_language.dart';
import 'package:family_map/utils/constants.dart';
import 'package:family_map/views/location_tap_screen.dart';
import 'package:family_map/views/member_tap_screen.dart';
import 'package:family_map/views/profile_tap_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final PageController _pageController = PageController();
  int index = 0;

  final pages = const [
    LocationTapScreen(),
    MemberTapScreen(),
    ProfileTapScreen(),
  ];
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNavigationTap(int value) {
    setState(() {
      index = value;
    });

    _pageController.animateToPage(
      value,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = theme.scaffoldBackgroundColor;
    final textColor = theme.colorScheme.onSurface;
    final iconColor = theme.iconTheme.color ?? textColor;

    return Scaffold(
      backgroundColor: bgColor,
      body: NestedScrollView(
        floatHeaderSlivers: true,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            if (index == 2)
              SliverAppBar(
                floating: true,
                snap: true,
                pinned: false,
                backgroundColor: bgColor,
                elevation: 8,
                iconTheme: IconThemeData(color: iconColor),
                titleSpacing: 10,
                // title: Text(
                //   AppLocale.appTitle.getString(context),
                //   style: TextStyle(
                //     color: AppColors.primary,
                //     fontSize: 28.sp,
                //     fontWeight: FontWeight.bold,
                //   ),
                // ),
                title: Row(
                  children: [
                    Image.asset(
                      'assets/logo/app_logo_no_bk.png',
                      width: 32.w,
                      height: 32.h,
                      fit: BoxFit.contain,
                    ),
                    SizedBox(width: 8.w),
                    // 2. Title Text
                    Text(
                      AppLocale.appTitle.getString(context),
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 28.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                actions: _buildAppBarActions(iconColor),
              ),
          ];
        },
        body: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (pageIndex) {
            setState(() {
              index = pageIndex;
            });
          },
          children: pages,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: bgColor,
        selectedIndex: index,
        indicatorColor: Colors.transparent,
        onDestinationSelected: _onNavigationTap,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            );
          }
          return TextStyle(color: textColor.withValues(alpha: 0.6));
        }),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.location_on, size: 24.r, color: iconColor),
            selectedIcon: Icon(
              Icons.location_on,
              size: 24.r,
              color: AppColors.primary,
            ),
            label: AppLocale.navLocation.getString(context),
          ),
          NavigationDestination(
            icon: Icon(Icons.group, size: 24.r, color: iconColor),
            selectedIcon: Icon(
              Icons.group,
              size: 24.r,
              color: AppColors.primary,
            ),
            label: AppLocale.navMember.getString(context),
          ),

          NavigationDestination(
            icon: Icon(Icons.person, size: 24.r, color: iconColor),
            selectedIcon: Icon(
              Icons.person,
              size: 24.r,
              color: AppColors.primary,
            ),
            label: AppLocale.navProfile.getString(context),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAppBarActions(Color iconColor) {
    return [
      // IconButton(
      //   icon: Icon(Icons.notifications, color: iconColor),
      //   onPressed: () {
      //     // Search action
      //   },
      // ),
      IconButton(
        icon: Icon(Icons.logout, color: iconColor),
        onPressed: () {
          final authProvider = context.read<AuthProvider>();
          final locationProvider = context.read<LocationProvider>();
          final memberProvider = context.read<MemberProvider>();
          final languageProvider = context.read<LanguageProvider>();

          try {
            authProvider.logout();
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
          // context.read<LocationProvider>().stopLocationTracking();
          // context.read<MemberProvider>().clearData();
          // context.read<LanguageProvider>().clearData();
          // context.read<LocationProvider>().clearData();
          // context.read<AuthProvider>().logout();
          // if (context.mounted) {
          //   Navigator.of(context).pushAndRemoveUntil(
          //     MaterialPageRoute(builder: (_) => const MyApp()),
          //     (_) => false,
          //   );
          // }
        },
      ),
    ];
  }
}
