import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'forgot_password_screen.dart';
import 'help_screen.dart';
import 'main_shell.dart';
import 'signup_screen.dart';
import 'zentrixa_theme.dart';
import 'zx_api.dart';
import 'i18n.dart';
import 'language_screen.dart';
import 'server_settings.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _hidePassword = true;
  bool _loading = false;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _handleLogin() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;

    if (identifier.isEmpty || password.isEmpty) {
      _snack('Please enter username/email and password'.tr);
      return;
    }

    setState(() => _loading = true);
    final res = await ZxApi.post('/api/login', {
      'identifier': identifier,
      'password': password,
    });
    if (!mounted) return;
    setState(() => _loading = false);

    if (res.ok) {
      // Server asli username deta hai - chat/friends mein wahi use hota hai
      Session.setFrom(res.map);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainShell()),
      );
    } else {
      _snack(res.message);
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZX.bg,
      body: Stack(
        children: [
          Positioned(
            top: -90,
            right: -90,
            child: Container(
              width: 260,
              height: 260,
              decoration: const BoxDecoration(
                color: ZX.coralSoft,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 50,
            right: 50,
            child: Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                color: ZX.sun,
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LanguageScreen()),
                        ),
                        icon: const Icon(Icons.language, color: ZX.coral, size: 20),
                        label: Text('Language'.tr,
                            style: const TextStyle(color: ZX.coral, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: ZX.coral,
                        shape: BoxShape.circle,
                      ),
                      child: const Text(
                        'Z',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Welcome back'.tr,
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w600,
                        color: ZX.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Log in and chat with your people'.tr,
                      style: TextStyle(fontSize: 16, color: ZX.muted),
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _identifierController,
                      style: const TextStyle(color: ZX.ink),
                      decoration: ZX.input(
                        'Username or email'.tr,
                        icon: Icons.person_outline,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passwordController,
                      obscureText: _hidePassword,
                      onSubmitted: (_) => _handleLogin(),
                      style: const TextStyle(color: ZX.ink),
                      decoration: ZX.input(
                        'Password'.tr,
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
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ForgotPasswordScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'Forgot password?'.tr,
                          style: TextStyle(color: ZX.muted, fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ZxButton(
                      _loading ? 'Please wait...'.tr : 'Login'.tr,
                      onPressed: _loading ? null : _handleLogin,
                    ),
                    const SizedBox(height: 28),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'New to Zentrixa? '.tr,
                            style: TextStyle(color: ZX.muted, fontSize: 15),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SignupScreen(),
                                ),
                              );
                            },
                            child: Text(
                              'Create account'.tr,
                              style: TextStyle(
                                color: ZX.coral,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: TextButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const HelpScreen()),
                        ),
                        icon: const Icon(Icons.help_outline, size: 18, color: ZX.coral),
                        label: const Text('Need help? Contact us',
                            style: TextStyle(color: ZX.coral, fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                    ),
                    if (!kIsWeb) ...[
                      const SizedBox(height: 6),
                      const ServerChip(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
