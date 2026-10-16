import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

int _seq = 0;

/// YouTube video naye tab mein kholo.
void ytOpenUrl(String url) {
  web.window.open(url, '_blank');
}

/// YouTube ka official iframe player (YouTube ke apne controls ke saath, unke upar kuch nahi lagta).
/// `play` / `muted` badalne par player ko command bheji jati hai.
class YtEmbed extends StatefulWidget {
  final String videoId;
  final bool play;
  final bool muted;

  /// Room ke liye: YouTube ke apne controls band (hum bagal mein apne buttons dikhate hain), loop band.
  final bool controls;
  final bool loop;
  final int start; // shuru karne ka second
  final double? seekTo; // seekNonce badalne par is second par jao
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
  late final String _viewType;
  web.HTMLIFrameElement? _iframe;
  bool _loaded = false;
  JSFunction? _msgFn;

  String _src() {
    final id = Uri.encodeComponent(widget.videoId);
    final origin = Uri.encodeComponent(Uri.base.origin);
    // Autoplay ke liye pehle mute=1; awaaz on ho to load ke baad unMute command jati hai.
    final loopPart = widget.loop ? '&loop=1&playlist=$id' : '';
    final ctl = widget.controls ? 1 : 0;
    final kb = widget.controls ? '' : '&disablekb=1&fs=0&iv_load_policy=3&cc_load_policy=0';
    return 'https://www.youtube.com/embed/$id?enablejsapi=1&autoplay=1&mute=1&playsinline=1'
        '$loopPart&rel=0&modestbranding=1&controls=$ctl$kb&start=${widget.start}&origin=$origin';
  }

  @override
  void initState() {
    super.initState();
    _viewType = 'zx-yt-${widget.videoId}-${_seq++}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final f = web.HTMLIFrameElement();
      f.src = _src();
      f.allow = 'autoplay; encrypted-media; picture-in-picture; fullscreen';
      f.setAttribute('allowfullscreen', 'true');
      f.style.border = 'none';
      f.style.pointerEvents = widget.interactive ? 'auto' : 'none';
      f.style.width = '100%';
      f.style.height = '100%';
      f.addEventListener(
        'load',
        ((web.Event _) {
          _loaded = true;
          _listen();
          // Player ko tayyar hone ka thoda time do, phir state laga do (dobara bhi, pakka karne ke liye).
          Future.delayed(const Duration(milliseconds: 700), _apply);
          Future.delayed(const Duration(milliseconds: 1800), _apply);
        }).toJS,
      );
      _iframe = f;
      return f;
    });
  }

  @override
  void didUpdateWidget(YtEmbed old) {
    super.didUpdateWidget(old);
    if (old.muted != widget.muted || old.play != widget.play) _apply();
    if (old.seekNonce != widget.seekNonce && widget.seekTo != null) {
      _cmd('seekTo', <dynamic>[widget.seekTo, true]);
    }
  }

  @override
  void dispose() {
    final f = _msgFn;
    if (f != null) web.window.removeEventListener('message', f);
    super.dispose();
  }

  // YouTube se current time / duration sunne ke liye (sirf jab onTime diya ho).
  void _listen() {
    if (widget.onTime == null || _msgFn != null) return;
    final f = ((web.MessageEvent e) {
      if (e.origin != 'https://www.youtube.com') return;
      final obj = e.data.dartify();
      if (obj is! String) return;
      try {
        final j = jsonDecode(obj);
        if (j is! Map || j['event'] != 'infoDelivery') return;
        final info = j['info'];
        if (info is! Map) return;
        final cur = info['currentTime'];
        final dur = info['duration'];
        if (cur is num) {
          widget.onTime?.call(cur.toDouble(), dur is num ? dur.toDouble() : 0);
        }
      } catch (_) {}
    }).toJS;
    _msgFn = f;
    web.window.addEventListener('message', f);
    final w = _iframe?.contentWindow;
    if (w != null) {
      w.postMessage(jsonEncode({'event': 'listening', 'id': 1, 'channel': 'widget'}).toJS, 'https://www.youtube.com'.toJS);
    }
  }

  void _cmd(String func, [List<dynamic> args = const <dynamic>[]]) {
    final w = _iframe?.contentWindow;
    if (w == null) return;
    final msg = jsonEncode({'event': 'command', 'func': func, 'args': args});
    w.postMessage(msg.toJS, 'https://www.youtube.com'.toJS);
  }

  void _apply() {
    if (!mounted || !_loaded) return;
    _cmd(widget.muted ? 'mute' : 'unMute');
    _cmd(widget.play ? 'playVideo' : 'pauseVideo');
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(ignoring: !widget.interactive, child: HtmlElementView(viewType: _viewType));
  }
}
