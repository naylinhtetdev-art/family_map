import 'package:family_map/provider/auth_provider.dart';
import 'package:family_map/utils/constants.dart';
import 'package:family_map/views/create_account_view.dart';
import 'package:family_map/views/home_view.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late TapGestureRecognizer _tapRecognizer;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _remember = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _tapRecognizer = TapGestureRecognizer()
      ..onTap = () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CreateScreen()),
        );
      };
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('saved_email');
      final pass = prefs.getString('saved_password');
      if (email != null && pass != null) {
        _emailController.text = email;
        _passwordController.text = pass;
        setState(() => _remember = true);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _tapRecognizer.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.login(
      _emailController.text.trim(),
      _passwordController.text,
      _remember,
    );
    if (!mounted) return;
    if (success) {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (_remember) {
          await prefs.setString('saved_email', _emailController.text.trim());
          await prefs.setString('saved_password', _passwordController.text);
        } else {
          await prefs.remove('saved_email');
          await prefs.remove('saved_password');
        }
      } catch (_) {}
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeView()),
        (_) => false,
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(auth.error ?? 'Login failed')));
    }
  }

  Future<void> _forgot() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter your email first.')));
      return;
    }
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final ok = await auth.resetPassword(email);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Password reset email sent.'
              : (auth.error ?? 'Unable to send reset email'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isTablet = MediaQuery.sizeOf(context).shortestSide >= 600;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: isTablet ? 0 : 16.w),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
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
                          mainAxisAlignment: MainAxisAlignment
                              .center, // ဒေါင်လိုက် အလယ်တည့်တည့် ပေါ်စေမည်
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                    color: AppColors.primary,
                                    fontSize: 38.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 40.h),
                            Center(
                              child: Text(
                                'Login Account!',
                                style: TextStyle(
                                  fontSize: isTablet ? 11.sp : 22.sp,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Center(
                              child: Text(
                                'Login an account to get started and enjoy\n seamless access to our features.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: isTablet ? 6.sp : 12.sp,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ),
                            SizedBox(height: 18.h),

                            Text(
                              'Email Address',
                              style: TextStyle(
                                fontSize: isTablet ? 7.sp : 14.sp,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            SizedBox(height: 5.h),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => v == null || !v.contains('@')
                                  ? 'Enter a valid email'
                                  : null,
                              style: TextStyle(
                                fontSize: isTablet ? 7.sp : 14.sp,
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
                                fontSize: isTablet ? 7.sp : 14.sp,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            SizedBox(height: 5.h),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscure,
                              validator: (v) => v == null || v.isEmpty
                                  ? 'Enter your password'
                                  : null,
                              style: TextStyle(
                                fontSize: isTablet ? 7.sp : 14.sp,
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
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                  icon: Icon(
                                    _obscure
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

                            SizedBox(height: 16.h),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Checkbox(
                                      value: _remember,
                                      onChanged: (v) => setState(
                                        () => _remember = v ?? false,
                                      ),
                                    ),
                                    Text(
                                      'Remember me',
                                      style: TextStyle(
                                        fontSize: isTablet ? 7.sp : 14.sp,
                                      ),
                                    ),
                                  ],
                                ),
                                TextButton(
                                  onPressed: _forgot,
                                  child: Text('Forgot password?'),
                                ),
                              ],
                            ),
                            if (auth.error != null && auth.error!.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.h),
                                child: Text(
                                  auth.error!,
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            SizedBox(height: 12.h),

                            SizedBox(
                              width: double.infinity,
                              height: 48.h,
                              child: ElevatedButton(
                                onPressed: auth.loading ? null : _login,
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
                                        'Login',
                                        style: TextStyle(
                                          fontSize: isTablet ? 9.sp : 18.sp,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                              ),
                            ),

                            SizedBox(height: 15.h),
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: Colors.grey.shade200,
                                    thickness: 3,
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12.w,
                                  ),
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
                            SizedBox(height: 15.h),
                            Center(
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: isTablet ? 6.sp : 12.sp,
                                    color: Colors.grey.shade500,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'Don\'t you have a account?  ',
                                    ),
                                    TextSpan(
                                      text: 'Create Account',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
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
            );
          },
        ),
      ),
    );
  }
}
