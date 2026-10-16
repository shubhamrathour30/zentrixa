import 'package:flutter/material.dart';

import 'app_mode.dart';
import 'zentrixa_theme.dart';
import 'zx_api.dart';

/// Phone (APK) par: login screen ke neeche chhota "Server" button. Laptop ka public link ya WiFi IP yahan daalo.
/// Public link har baar badalta hai to bas yahan naya link paste karo - dobara APK banane ki zaroorat nahi.
class ServerChip extends StatefulWidget {
  const ServerChip({super.key});

  @override
  State<ServerChip> createState() => _ServerChipState();
}

class _ServerChipState extends State<ServerChip> {
  Future<void> _open() async {
    await showServerDialog(context);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: _open,
        icon: const Icon(Icons.dns_outlined, size: 18, color: ZX.muted),
        label: Text(
          'Server: ${ZxApi.serverShown}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: ZX.muted, fontSize: 12),
        ),
      ),
    );
  }
}

Future<void> showServerDialog(BuildContext context) {
  final ctrl = TextEditingController(text: ZxApi.serverShown);
  String status = '';
  bool busy = false;
  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        backgroundColor: ZX.bg,
        title: const Text('Server address', style: TextStyle(color: ZX.ink, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste the link of your Zentrixa server, e.g. https://xxxx.trycloudflare.com or http://192.168.1.5:3000',
              style: TextStyle(color: ZX.muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(hintText: 'https://...'),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () async {
                await AppMode.set(true);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Auto-update mode saved. Close the app completely and open it again.')),
                  );
                }
              },
              child: const Text('Switch to auto-update mode', style: TextStyle(color: ZX.coral, fontSize: 13)),
            ),
            if (status.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(status, style: TextStyle(color: status.startsWith('Connected') ? Colors.green[700] : Colors.red[700], fontSize: 13)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: busy
                ? null
                : () async {
                    setS(() {
                      busy = true;
                      status = 'Checking...';
                    });
                    final ok = await ZxApi.pingServer(ctrl.text);
                    setS(() {
                      busy = false;
                      status = ok ? 'Connected! Server is running.' : 'Could not reach the server. Check the link and that the server is running.';
                    });
                  },
            child: const Text('Test', style: TextStyle(color: ZX.coral)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: ZX.muted)),
          ),
          TextButton(
            onPressed: () async {
              await ZxApi.setServer(ctrl.text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save', style: TextStyle(color: ZX.coral, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ),
  );
}
