import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'app_mode.dart';
import 'i18n.dart';
import 'login_screen.dart';
import 'main_shell.dart';
import 'zentrixa_theme.dart';
import 'shell_bridge_stub.dart' if (dart.library.js_interop) 'shell_bridge_web.dart';
import 'web_shell_stub.dart' if (dart.library.io) 'web_shell.dart';
import 'zx_api.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // Flutter binding ensure karna zaroori hai
  WidgetsFlutterBinding.ensureInitialized();

  // Pehle se chuni hui language wapas lao
  await L.load();

  // Phone (APK) par chuna hua server address wapas lao
  await ZxApi.loadServer();

  // Web build ke andar: Android shell ka Back button isi se kaam karta hai
  initShellBridge(navigatorKey);

  // Phone (APK) par default "auto-update" mode: app server se Zentrixa kholta hai (server par update = phone par update)
  if (!kIsWeb && shellSupported && await AppMode.isShell()) {
    runApp(buildWebShell());
    return;
  }

  // Pichla login yaad ho to seedha app khulegi (Log out karne tak)
  final loggedIn = await Session.restore();

  // Session expire (401) hone par automatically login screen par bhejo
  ZxApi.onUnauthorized = () {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  };

  runApp(MyApp(startLoggedIn: loggedIn));
}

class MyApp extends StatelessWidget {
  final bool startLoggedIn;
  const MyApp({super.key, this.startLoggedIn = false});

  @override
  Widget build(BuildContext context) {
    // Language badalne par poori app dobara bane; Urdu/Arabic mein right-to-left.
    return ValueListenableBuilder<String>(
      valueListenable: L.lang,
      builder: (context, code, _) => MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'Zentrixa',
        theme: ZX.theme(),
        builder: (context, child) => Directionality(
          textDirection: L.rtl ? TextDirection.rtl : TextDirection.ltr,
          child: child ?? const SizedBox.shrink(),
        ),
        home: startLoggedIn ? const MainShell() : const LoginScreen(),
      ),
    );
  }
}
