import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'main_shell.dart';
import 'zentrixa_theme.dart';
import 'zx_api.dart';
import 'i18n.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController otpController = TextEditingController();
  final TextEditingController referralController = TextEditingController();

  bool isOtpScreen = false;
  bool _hidePassword = true;
  bool _loading = false;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> requestOtp() async {
    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final referral = referralController.text.trim();

    if (firstName.isEmpty || email.isEmpty || password.isEmpty) {
      _snack('Please fill all required fields'.tr);
      return;
    }
    if (password.length < 6) {
      _snack('Password must be at least 6 characters'.tr);
      return;
    }

    setState(() => _loading = true);
    final res = await ZxApi.post('/api/signup', {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'password': password,
      if (referral.isNotEmpty) 'referral': referral,
    });
    if (!mounted) return;
    setState(() => _loading = false);

    if (res.ok) {
      setState(() => isOtpScreen = true);
      _snack('An OTP has been sent to your email. Check your inbox/spam.'.tr);
    } else {
      _snack(res.message);
    }
  }

  Future<void> verifyOtp() async {
    final email = emailController.text.trim();
    final otp = otpController.text.trim();
    if (otp.length != 6) {
      _snack('Enter the 6-digit OTP'.tr);
      return;
    }

    setState(() => _loading = true);
    final res = await ZxApi.post('/api/verify_otp', {'email': email, 'otp': otp});
    if (!mounted) return;
    setState(() => _loading = false);

    if (res.ok) {
      Session.setFrom(res.map);
      _snack('Account created! 🎉'.tr);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MainShell()),
        (route) => false,
      );
    } else {
      _snack(res.message);
    }
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    otpController.dispose();
    referralController.dispose();
    super.dispose();
  }

  Widget _backButton() {
    return GestureDetector(
      onTap: () {
        if (isOtpScreen) {
          setState(() => isOtpScreen = false);
        } else {
          Navigator.pop(context);
        }
      },
      child: Container(
        width: 46,
        height: 46,
        decoration: ZX.cardDecoration(radius: 23, shadow: false),
        child: const Icon(Icons.arrow_back, color: ZX.ink, size: 22),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZX.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _backButton(),
              const SizedBox(height: 24),
              if (!isOtpScreen) ...[
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: ZX.coral,
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    'Z',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Create account'.tr,
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w600,
                    color: ZX.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Join Zentrixa and chat with your people'.tr,
                  style: TextStyle(fontSize: 15, color: ZX.muted),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: firstNameController,
                  style: const TextStyle(color: ZX.ink),
                  decoration:
                      ZX.input('First name'.tr, icon: Icons.person_outline),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: lastNameController,
                  style: const TextStyle(color: ZX.ink),
                  decoration: ZX.input(
                    'Last name (optional)'.tr,
                    icon: Icons.person_outline,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: ZX.ink),
                  decoration:
                      ZX.input('Email address'.tr, icon: Icons.mail_outline),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: passwordController,
                  obscureText: _hidePassword,
                  style: const TextStyle(color: ZX.ink),
                  decoration: ZX.input(
                    'Password (min 6 characters)'.tr,
                    icon: Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(
                        _hidePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: ZX.muted,
                      ),
                      onPressed: () =>
                          setState(() => _hidePassword = !_hidePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: referralController,
                  style: const TextStyle(color: ZX.ink),
                  decoration: ZX.input(
                    "Invite code (optional) — your friend's username".tr,
                    icon: Icons.card_giftcard,
                  ),
                ),
                const SizedBox(height: 24),
                ZxButton(
                  _loading ? 'Please wait...'.tr : 'Get OTP'.tr,
                  onPressed: _loading ? null : requestOtp,
                ),
                const SizedBox(height: 20),
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text.rich(
                      TextSpan(
                        text: 'Already have an account? '.tr,
                        style: TextStyle(color: ZX.muted, fontSize: 15),
                        children: [
                          TextSpan(
                            text: 'Login'.tr,
                            style: TextStyle(
                              color: ZX.coral,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: const BoxDecoration(
                      color: ZX.coralSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mark_email_read_outlined,
                      color: ZX.coral,
                      size: 44,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'Verify your email'.tr,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w600,
                      color: ZX.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    tx('We sent a 6-digit code to\n{email}'.tr, {'email': emailController.text.trim()}),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, color: ZX.muted),
                  ),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    color: ZX.ink,
                    fontSize: 26,
                    letterSpacing: 8,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: ZX.input('Enter OTP'.tr).copyWith(counterText: ''),
                ),
                const SizedBox(height: 24),
                ZxButton(
                  _loading ? 'Please wait...'.tr : 'Verify & Register'.tr,
                  onPressed: _loading ? null : verifyOtp,
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: _loading ? null : requestOtp,
                    child: Text(
                      "Didn't get the code? Resend".tr,
                      style: TextStyle(color: ZX.muted),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
