import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:family_map/main.dart';
import 'package:family_map/provider/auth_provider.dart';
import 'package:family_map/provider/language_provider.dart';
import 'package:family_map/provider/location_provider.dart';
import 'package:family_map/provider/member_provider.dart';
import 'package:family_map/provider/theme_provider.dart';
import 'package:family_map/utils/app_language.dart';
import 'package:family_map/utils/connectivity_handler.dart';
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

class _HomeViewState extends State<HomeView> with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  int index = 0;
  bool _isCheckingServices = false;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  final pages = const [
    LocationTapScreen(),
    MemberTapScreen(),
    ProfileTapScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Lifecycle listen စလုပ်မည်
    //_checkGps();
    // 2. Realtime Internet ပိတ်/ဖွင့် စောင့်ကြည့်မည့် Stream ကို ဤနေရာတွင် Listen လုပ်ပါ
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> result,
    ) {
      if (result.contains(ConnectivityResult.none) && mounted) {
        ConnectivityHandler.checkAndPromptInternet(context);
      }
    });

    // Initial Screen Load တွင် GPS နှင့် Internet စစ်ဆေးခြင်း
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkServices();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      //_checkGps();
      _checkServices();
    }
  }

  // Future<void> _checkGps() async {
  //   final user = context.read<AuthProvider>().user;
  //   final isGpsOn = await context
  //       .read<LocationProvider>()
  //       .checkAndEnableLocationService(context);

  //   if (isGpsOn && user != null && mounted) {
  //     context.read<MemberProvider>().startLocationTracking(user.uid);
  //   }
  // }
  Future<void> _checkServices() async {
    if (!mounted || _isCheckingServices) return;
    _isCheckingServices = true;

    try {
      // 1. Internet ရှိ မရှိ စစ်ဆေးခြင်း
      final isInternetOn = await ConnectivityHandler.checkAndPromptInternet(
        context,
      );
      if (!mounted || !isInternetOn) return;

      // 2. GPS (Location) ပွင့် မပွင့် စစ်ဆေးခြင်း
      final locationProvider = context.read<LocationProvider>();
      final isGpsOn = await locationProvider.checkAndEnableLocationService(
        context,
      );
      if (!mounted || !isGpsOn) return;

      // 3. နှစ်ခုလုံး ပွင့်မှသာ Location Tracking စတင်မည်
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        await locationProvider.startLocationTracking(user.uid);
      }
    } finally {
      _isCheckingServices = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _connectivitySubscription.cancel();
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
        onPressed: () async {
          final authProvider = context.read<AuthProvider>();
          final locationProvider = context.read<LocationProvider>();
          final memberProvider = context.read<MemberProvider>();
          final languageProvider = context.read<LanguageProvider>();

          try {
            await locationProvider
                .stopLocationTracking(); // Tracking အရင်ပိတ်ပါ
            memberProvider.clearData();
            locationProvider.clearData();
            languageProvider.clearData();
            await authProvider.logout();
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
