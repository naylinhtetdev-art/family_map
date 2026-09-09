import 'package:family_map/firebase_options.dart';
import 'package:family_map/provider/auth_provider.dart';
import 'package:family_map/provider/language_provider.dart';
import 'package:family_map/provider/location_provider.dart';
import 'package:family_map/provider/member_provider.dart';
import 'package:family_map/provider/theme_provider.dart';
import 'package:family_map/utils/app_language.dart';
import 'package:family_map/utils/constants.dart';
import 'package:family_map/views/create_account_view.dart';
import 'package:family_map/views/home_view.dart';
import 'package:family_map/views/login_view.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterLocalization.instance.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final prefs = await SharedPreferences.getInstance();
  final savedLanguageCode = prefs.getString('selected_language') ?? 'en';

  FlutterLocalization.instance.init(
    mapLocales: [
      const MapLocale('en', AppLocale.EN),
      const MapLocale('my', AppLocale.MY),
    ],
    initLanguageCode: savedLanguageCode,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()..loadThemeMode()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => MemberProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LanguageProvider>(
      builder: (context, themeProvider, languageProvider, _) {
        return ScreenUtilInit(
          designSize: const Size(375, 812),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, child) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              supportedLocales: FlutterLocalization.instance.supportedLocales,
              localizationsDelegates:
                  FlutterLocalization.instance.localizationsDelegates,
              themeMode: themeProvider.themeMode,
              theme: ThemeData(
                brightness: Brightness.light,
                scaffoldBackgroundColor: AppColors.lightBackground,
                cardColor: AppColors.lightSurface,
                appBarTheme: const AppBarTheme(
                  backgroundColor: AppColors.lightBackground,
                  iconTheme: IconThemeData(color: AppColors.lightTextPrimary),
                  titleTextStyle: TextStyle(
                    color: AppColors.primary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                colorScheme: const ColorScheme.light(
                  primary: AppColors.primary,
                  surface: AppColors.lightSurface,
                  onSurface: AppColors.lightTextPrimary,
                ),
              ),
              darkTheme: ThemeData(
                brightness: Brightness.dark,
                scaffoldBackgroundColor: AppColors.darkBackground,
                cardColor: AppColors.darkSurface,
                appBarTheme: const AppBarTheme(
                  backgroundColor: AppColors.darkBackground,
                  iconTheme: IconThemeData(color: AppColors.darkTextPrimary),
                  titleTextStyle: TextStyle(
                    color: AppColors.primary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                colorScheme: const ColorScheme.dark(
                  primary: AppColors.primary,
                  surface: AppColors.darkSurface,
                  onSurface: AppColors.darkTextPrimary,
                ),
              ),
              home: const LandingPage(),
            );
          },
        );
      },
    );
  }
}

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (auth.signedIn && auth.isRemembered) {
      return const HomeView();
    }
    if (auth.isFirstTimeUser) {
      return Scaffold(
        body: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/cover-2.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Container(color: Colors.black.withValues(alpha: 0.35)),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 24.0.w,
                  vertical: 16.h,
                ),
                child: Column(
                  children: [
                    SizedBox(height: 40.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.family_restroom_sharp,
                          color: AppColors.accentYellow,
                          size: 42.r,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'Family Map',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 38.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Spacer(),
                    Text(
                      'Share your location with\nyour family in real-time',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                        height: 1.3.h,
                      ),
                    ),
                    SizedBox(height: 20.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildDot(isActive: true),
                        _buildDot(isActive: false),
                        _buildDot(isActive: false),
                      ],
                    ),
                    SizedBox(height: 30.h),
                    SizedBox(
                      width: double.infinity,
                      height: 54.h,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CreateScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30.r),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Get started',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 20.h),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginView(),
                          ),
                        );
                      },
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.white,
                          ),
                          children: [
                            TextSpan(text: 'Already have an account? '),
                            TextSpan(
                              text: 'Sign in',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 10.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    return const LoginView();
  }

  Widget _buildDot({required bool isActive}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      height: 8.h,
      width: 8.w,
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
    );
  }
}
