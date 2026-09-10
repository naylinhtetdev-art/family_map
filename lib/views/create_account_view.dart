import 'package:family_map/provider/auth_provider.dart';
import 'package:family_map/utils/constants.dart';
import 'package:family_map/views/home_view.dart';
import 'package:family_map/views/login_view.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key});

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late TapGestureRecognizer _tapRecognizer;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final ValueNotifier<bool> remember = ValueNotifier(false);

  bool obscurePassword = true;
  bool confirmObscurePassword = true;

  @override
  void initState() {
    super.initState();
    _tapRecognizer = TapGestureRecognizer()
      ..onTap = () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LoginView()),
        );
      };
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    remember.dispose();
    _tapRecognizer.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final pass = passwordController.text;

    final ok = await auth.signUp(name, email, pass);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeView()),
        (_) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Registration failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isTablet = MediaQuery.sizeOf(context).shortestSide >= 600;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: isTablet ? 0 : 16.w),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isTablet ? 412.w : double.infinity,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 70.w : 0,
                  vertical: 16.h,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.family_restroom_sharp,
                            color: AppColors.green,
                            size: 42.r,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'Family Map',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 38.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/logo/app_logo_no_bk.png',
                            width: 80.w,
                            height: 80.h,
                          ),
                        ],
                      ),
                      SizedBox(height: 0),
                      Center(
                        child: Text(
                          'Create Account!',
                          style: TextStyle(
                            fontSize: isTablet ? 11.sp : 22.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      SizedBox(height: 0),
                      Center(
                        child: Text(
                          'Create new an account to get started and enjoy\n seamless access to our features.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isTablet ? 6.sp : 12.sp,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Text(
                        'Full Name',
                        style: TextStyle(
                          fontSize: isTablet ? 7.sp : 16.sp,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: 5.h),
                      TextFormField(
                        controller: nameController,
                        keyboardType: TextInputType.name,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Enter your full name'
                            : null,
                        style: TextStyle(
                          fontSize: isTablet ? 7.sp : 16.sp,
                          color: Colors.black,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Full Name',
                          hintStyle: TextStyle(
                            fontSize: isTablet ? 7.sp : 14.sp,
                            color: Colors.grey.shade500,
                          ),
                          prefixIcon: Icon(
                            Icons.person_outlined,
                            size: 24.r,
                            color: Colors.grey.shade500,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF0F0F5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.r),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 4.h,
                            horizontal: 8.w,
                          ),
                        ),
                      ),
                      SizedBox(height: 18.h),
                      Text(
                        'Email Address',
                        style: TextStyle(
                          fontSize: isTablet ? 7.sp : 16.sp,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: 5.h),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Enter your email';
                          }
                          final emailRegex = RegExp(
                            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                          );
                          if (!emailRegex.hasMatch(v.trim())) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                        style: TextStyle(
                          fontSize: isTablet ? 7.sp : 16.sp,
                          color: Colors.black,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Email Address',
                          hintStyle: TextStyle(
                            fontSize: isTablet ? 7.sp : 14.sp,
                            color: Colors.grey.shade500,
                          ),
                          prefixIcon: Icon(
                            Icons.mail_outline,
                            size: 24.r,
                            color: Colors.grey.shade500,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF0F0F5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(5.r),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 4.h,
                            horizontal: 8.w,
                          ),
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Text(
                        'Password',
                        style: TextStyle(
                          fontSize: isTablet ? 7.sp : 16.sp,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: 5.h),
                      TextFormField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        validator: (v) => v == null || v.length < 6
                            ? 'Use at least 6 characters'
                            : null,
                        style: TextStyle(
                          fontSize: isTablet ? 7.sp : 16.sp,
                          color: Colors.black,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Password',
                          hintStyle: TextStyle(
                            fontSize: isTablet ? 7.sp : 14.sp,
                            color: Colors.grey.shade500,
                          ),
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            size: 24.r,
                            color: Colors.grey.shade500,
                          ),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                obscurePassword = !obscurePassword;
                              });
                            },
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 22.r,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF0F0F5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(5.r),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 4.h,
                            horizontal: 8.w,
                          ),
                        ),
                      ),
                      SizedBox(height: 18.h),
                      Text(
                        'Confirm Password',
                        style: TextStyle(
                          fontSize: isTablet ? 7.sp : 16.sp,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: 5.h),
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: confirmObscurePassword,
                        validator: (v) => v != passwordController.text
                            ? 'Passwords do not match'
                            : null,
                        style: TextStyle(
                          fontSize: isTablet ? 7.sp : 16.sp,
                          color: Colors.black,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Confirm Password',
                          hintStyle: TextStyle(
                            fontSize: isTablet ? 7.sp : 14.sp,
                            color: Colors.grey.shade500,
                          ),
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            size: 24.r,
                            color: Colors.grey.shade500,
                          ),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                confirmObscurePassword =
                                    !confirmObscurePassword;
                              });
                            },
                            icon: Icon(
                              confirmObscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 22.r,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF0F0F5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(5.r),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 4.h,
                            horizontal: 8.w,
                          ),
                        ),
                      ),
                      SizedBox(height: 20.h),

                      SizedBox(
                        width: double.infinity,
                        height: 48.h,
                        child: ElevatedButton(
                          onPressed: auth.loading ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                          ),
                          child: auth.loading
                              ? SizedBox(
                                  height: 20.h,
                                  width: 20.w,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Sign Up',
                                  style: TextStyle(
                                    fontSize: isTablet ? 9.sp : 18.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ValueListenableBuilder<bool>(
                            valueListenable: remember,
                            builder: (context, isRemembered, child) {
                              return SizedBox(
                                width: 24.w,
                                height: 24.h,
                                child: Checkbox(
                                  value: isRemembered,
                                  activeColor: Colors.green,
                                  side: BorderSide(
                                    color: Colors.black,
                                    width: 1.5.w,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4.r),
                                  ),
                                  onChanged: (value) {
                                    remember.value = value ?? false;
                                  },
                                ),
                              );
                            },
                          ),
                          SizedBox(width: 8.h),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                style: TextStyle(
                                  fontSize: isTablet ? 6.sp : 12.sp,
                                  color: Colors.black,
                                  height: 1.3.h,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'By continuing, you agree to our ',
                                  ),
                                  TextSpan(
                                    text: 'Terms & Conditions',
                                    style: TextStyle(
                                      color: Color(0xFFD02BDD),
                                      fontWeight: FontWeight.bold,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {},
                                  ),
                                  TextSpan(text: '\nand '),
                                  TextSpan(
                                    text: 'Privacy Policy',
                                    style: const TextStyle(
                                      color: Color(0xFFD02BDD),
                                      fontWeight: FontWeight.bold,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {},
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: Colors.grey.shade200,
                              thickness: 3,
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12.w),
                            child: Text(
                              'Or',
                              style: TextStyle(
                                fontSize: isTablet ? 8.sp : 16.sp,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: Colors.grey.shade200,
                              thickness: 3,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Center(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: isTablet ? 6.sp : 12.sp,
                              color: Colors.grey.shade500,
                            ),
                            children: [
                              TextSpan(
                                text: 'Already have an account?  ',
                                style: TextStyle(fontSize: 16.sp),
                              ),
                              TextSpan(
                                text: 'Sign in',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16.sp,
                                ),
                                recognizer: _tapRecognizer,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
