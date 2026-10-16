import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'zentrixa_theme.dart';
import 'zx_api.dart';
import 'i18n.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController otpController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();

  bool isOtpStep = false;
  bool _loading = false;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> sendResetOtp() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      _snack('Enter your registered email'.tr);
      return;
    }
    setState(() => _loading = true);
    final res = await ZxApi.post('/api/forgot_password', {'email': email});
    if (!mounted) return;
    setState(() => _loading = false);

    if (res.ok) {
      setState(() => isOtpStep = true);
      _snack('If this email is registered, an OTP has been sent'.tr);
    } else {
      _snack(res.message);
    }
  }

  Future<void> resetPassword() async {
    final email = emailController.text.trim();
    final otp = otpController.text.trim();
    final newPassword = newPasswordController.text;

    if (otp.length != 6) {
      _snack('Enter the 6-digit OTP'.tr);
      return;
    }
    if (newPassword.length < 6) {
      _snack('Password must be at least 6 characters'.tr);
      return;
    }

    setState(() => _loading = true);
    final res = await ZxApi.post('/api/reset_password', {
      'email': email,
      'otp': otp,
      'newPassword': newPassword,
    });
    if (!mounted) return;
    setState(() => _loading = false);

    if (res.ok) {
      _snack('Password updated! 🎉'.tr);
      Navigator.pop(context); // Login screen par wapas
    } else {
      _snack(res.message);
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    otpController.dispose();
    newPasswordController.dispose();
    super.dispose();
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
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: ZX.cardDecoration(radius: 23, shadow: false),
                  child: const Icon(Icons.arrow_back, color: ZX.ink, size: 22),
                ),
              ),
              const SizedBox(height: 40),
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    color: ZX.coralSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isOtpStep ? Icons.key_outlined : Icons.lock_reset,
                    color: ZX.coral,
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  isOtpStep ? 'Enter OTP & new password'.tr : 'Reset your password'.tr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: ZX.ink,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  isOtpStep
                      ? 'Enter the OTP from your email and a new password'.tr
                      : "Enter your registered email and we'll send you an OTP".tr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, color: ZX.muted),
                ),
              ),
              const SizedBox(height: 28),
              if (!isOtpStep) ...[
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: ZX.ink),
                  decoration:
                      ZX.input('Registered email'.tr, icon: Icons.mail_outline),
                ),
                const SizedBox(height: 20),
                ZxButton(
                  _loading ? 'Please wait...'.tr : 'Send reset OTP'.tr,
                  onPressed: _loading ? null : sendResetOtp,
                ),
              ] else ...[
                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: ZX.ink),
                  decoration: ZX
                      .input('6 digit OTP'.tr, icon: Icons.pin_outlined)
                      .copyWith(counterText: ''),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  style: const TextStyle(color: ZX.ink),
                  decoration: ZX.input('New password (min 6)'.tr,
                      icon: Icons.lock_outline),
                ),
                const SizedBox(height: 20),
                ZxButton(
                  _loading ? 'Please wait...'.tr : 'Update password'.tr,
                  onPressed: _loading ? null : resetPassword,
                ),
              ],
              const SizedBox(height: 18),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Back to login'.tr,
                    style: TextStyle(color: ZX.muted, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
