import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'yt_embed_stub.dart' as stub;

/// YouTube app / browser mein kholo.
void ytOpenUrl(String url) {
  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication).catchError((_) => false);
}

/// Android / iPhone par YouTube ka asli player (WebView mein official iframe player).
/// Web wale YtEmbed jaisa hi kaam karta hai: play / muted badalne par command, seek, aur current time (onTime).
/// Baaki platforms (Windows/Linux) par pehle jaisa "Open on YouTube" card.
class YtEmbed extends StatefulWidget {
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
  State<YtEmbed> createState() => _YtEmbedState();
}

class _YtEmbedState extends State<YtEmbed> {
  YoutubePlayerController? _c;
  StreamSubscription<YoutubeVideoState>? _sub;

  bool get _supported => Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();
    if (!_supported) return;
    final c = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: widget.play,
      startSeconds: widget.start.toDouble(),
      params: YoutubePlayerParams(
        mute: true, // autoplay ke liye pehle mute; awaaz on ho to neeche unMute command jati hai
        showControls: widget.controls,
        showFullscreenButton: false,
        loop: widget.loop,
        playsInline: true,
        enableKeyboard: widget.controls,
        strictRelatedVideos: true,
      ),
    );
    _c = c;
    if (widget.onTime != null) {
      _sub = c.videoStateStream.listen((s) {
        final cur = s.position.inMilliseconds / 1000.0;
        final dur = c.value.metaData.duration.inMilliseconds / 1000.0;
        widget.onTime?.call(cur, dur);
      });
    }
    // Player ko tayyar hone ka thoda time do, phir state laga do (dobara bhi, pakka karne ke liye).
    Future.delayed(const Duration(milliseconds: 900), _apply);
    Future.delayed(const Duration(milliseconds: 2200), _apply);
  }

  void _apply() {
    final c = _c;
    if (!mounted || c == null) return;
    try {
      widget.muted ? c.mute() : c.unMute();
      widget.play ? c.playVideo() : c.pauseVideo();
    } catch (_) {}
  }

  @override
  void didUpdateWidget(YtEmbed old) {
    super.didUpdateWidget(old);
    final c = _c;
    if (c == null) return;
    if (old.muted != widget.muted || old.play != widget.play) _apply();
    if (old.seekNonce != widget.seekNonce && widget.seekTo != null) {
      try {
        c.seekTo(seconds: widget.seekTo!, allowSeekAhead: true);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    final c = _c;
    if (c != null) {
      try {
        c.close();
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) {
      return stub.YtEmbed(videoId: widget.videoId);
    }
    return Container(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, box) {
          final ok = box.maxWidth.isFinite && box.maxHeight.isFinite && box.maxHeight > 0;
          final ratio = ok ? box.maxWidth / box.maxHeight : 9 / 16;
          return YoutubePlayer(controller: c, aspectRatio: ratio);
        },
      ),
    );
  }
}
