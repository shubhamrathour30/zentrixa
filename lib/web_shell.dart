import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'app_mode.dart';
import 'zentrixa_theme.dart';
import 'zx_api.dart';

/// Android / iPhone par true.
bool get shellSupported =>
    defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

Widget buildWebShell() => const _ShellApp();

/// Auto-update mode: app ek patla "shell" hai jo aapke server se poora Zentrixa kholta hai.
/// Server (public folder) par naya version rakho => phone par agli baar khulte hi naya app. APK dobara nahi banani.
class _ShellApp extends StatelessWidget {
  const _ShellApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Zentrixa',
      theme: ZX.theme(),
      home: const _ShellPage(),
    );
  }
}

class _ShellPage extends StatefulWidget {
  const _ShellPage();

  @override
  State<_ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<_ShellPage> {
  WebViewController? _c;
  String _url = '';
  bool _loading = true;
  bool _failed = false;
  final TextEditingController _link = TextEditingController();

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    final u = ZxApi.configuredServer;
    if (u.isNotEmpty) _c = _make(u);
  }

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Future<List<String>> _pickFiles() async {
    try {
      final f = await ImagePicker().pickMedia();
      if (f == null) return <String>[];
      return <String>[Uri.file(f.path).toString()];
    } catch (_) {
      return <String>[];
    }
  }

  WebViewController _make(String url) {
    _url = url;
    final c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(ZX.bg)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (e) {
            if (e.isForMainFrame != false && mounted) {
              setState(() {
                _failed = true;
                _loading = false;
              });
            }
          },
          onNavigationRequest: (req) {
            // Dusre sites ke links (YouTube wagairah) phone ke browser / app mein kholo, shell ke andar nahi.
            final u = Uri.tryParse(req.url);
            final base = Uri.tryParse(_url);
            if (req.isMainFrame &&
                u != null &&
                base != null &&
                (u.scheme == 'http' || u.scheme == 'https') &&
                u.host != base.host) {
              launchUrl(u, mode: LaunchMode.externalApplication).catchError((_) => false);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );
    final p = c.platform;
    if (p is AndroidWebViewController) {
      p.setMediaPlaybackRequiresUserGesture(false); // reels / video awaaz ke saath chalein
      p.setOnShowFileSelector((_) => _pickFiles()); // photo / video upload
    }
    c.loadRequest(Uri.parse(url));
    return c;
  }

  Future<void> _openLink() async {
    final text = _link.text.trim();
    if (text.isEmpty) return;
    await ZxApi.setServer(text);
    final u = ZxApi.configuredServer;
    if (u.isEmpty) return;
    setState(() {
      _failed = false;
      _loading = true;
      _c = _make(u);
    });
  }

  void _retry() {
    final c = _c;
    if (c == null) return;
    setState(() {
      _failed = false;
      _loading = true;
    });
    c.loadRequest(Uri.parse(_url));
  }

  void _changeLink() {
    setState(() {
      _link.text = _url;
      _failed = false;
      _c = null;
    });
  }

  Future<void> _classicMode() async {
    await AppMode.set(false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved. Close the app completely and open it again.')),
    );
  }

  // Android Back: pehle web app ki current screen band karo; kuch band karne ko na ho to app band.
  Future<void> _onBack() async {
    final c = _c;
    if (c == null || _failed) {
      SystemNavigator.pop();
      return;
    }
    var handled = false;
    try {
      final r = await c.runJavaScriptReturningResult(
        "(function(){window.__zxHandled=false;window.dispatchEvent(new Event('zx-back'));return window.__zxHandled===true;})()",
      );
      handled = r.toString() == 'true';
    } catch (_) {}
    if (!handled) SystemNavigator.pop();
  }

  Widget _setupView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.link, size: 44, color: ZX.coral),
            const SizedBox(height: 14),
            const Text('Zentrixa link',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: ZX.ink)),
            const SizedBox(height: 8),
            const Text(
              'Paste your Zentrixa server link once, e.g. https://your-name.ts.net. The app will then update itself - no new APK needed.',
              style: TextStyle(color: ZX.muted, fontSize: 14),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _link,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(hintText: 'https://...'),
              onSubmitted: (_) => _openLink(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _openLink,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ZX.coral,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Open Zentrixa', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView() {
    return Container(
      color: ZX.bg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 52, color: ZX.coral),
              const SizedBox(height: 12),
              const Text("Can't reach Zentrixa",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ZX.ink)),
              const SizedBox(height: 8),
              Text(
                'Check your internet and that the server is running on the laptop.\n$_url',
                textAlign: TextAlign.center,
                style: const TextStyle(color: ZX.muted, fontSize: 13),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: _retry,
                style: ElevatedButton.styleFrom(backgroundColor: ZX.coral, foregroundColor: Colors.white),
                child: const Text('Retry'),
              ),
              TextButton(
                onPressed: _changeLink,
                child: const Text('Change link', style: TextStyle(color: ZX.coral)),
              ),
              TextButton(
                onPressed: _classicMode,
                child: const Text('Use classic mode', style: TextStyle(color: ZX.muted)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        backgroundColor: ZX.bg,
        body: SafeArea(
          child: c == null
              ? _setupView()
              : Stack(
                  children: [
                    Positioned.fill(child: WebViewWidget(controller: c)),
                    if (_loading && !_failed)
                      const Align(
                        alignment: Alignment.topCenter,
                        child: LinearProgressIndicator(minHeight: 3, color: ZX.coral, backgroundColor: ZX.coralSoft),
                      ),
                    if (_failed) Positioned.fill(child: _errorView()),
                  ],
                ),
        ),
      ),
    );
  }
}
