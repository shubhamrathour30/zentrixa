import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'i18n.dart';

/// Is platform par player nahi hai: link copy ho jata hai (YouTube app/browser mein paste karo).
void ytOpenUrl(String url) {
  Clipboard.setData(ClipboardData(text: url));
}

class YtEmbed extends StatelessWidget {
  final String videoId;
  final bool play;
  final bool muted;
  final bool controls;
  final bool loop;
  final int start;
  final double? seekTo;
  final int seekNonce;
  final void Function(double current, double duration)? onTime;

  /// false => player touch/click nahi lega (Reels mein swipe aur hamare buttons screen par kahin bhi chalen).
  final bool interactive;
  const YtEmbed({
    super.key,
    required this.videoId,
    this.play = true,
    this.muted = true,
    this.controls = true,
    this.loop = true,
    this.start = 0,
    this.seekTo,
    this.seekNonce = 0,
    this.onTime,
    this.interactive = true,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: () {
          ytOpenUrl('https://www.youtube.com/shorts/$videoId');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Link copied! Paste it anywhere to share.'.tr)),
          );
        },
        icon: const Icon(Icons.open_in_new, color: Colors.white),
        label: Text('Open on YouTube'.tr, style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}
