import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'i18n.dart';
import 'yt_embed.dart';
import 'zentrixa_theme.dart';
import 'zx_api.dart';

String _fmt(double secs) {
  if (secs.isNaN || secs < 0) secs = 0;
  final t = secs.floor();
  final h = t ~/ 3600;
  final m = (t % 3600) ~/ 60;
  final s = t % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

/// Saath movie dekhna: server ka "play / pause / seek / ad" state yahan ki video se milaya jata hai.
/// Video file ho to Flutter ka video_player, YouTube link ho to YouTube ka official embed (sirf web).
class MovieBody extends StatefulWidget {
  final Map<String, dynamic> room;
  final int Function() nowMs; // server ka abhi ka waqt (ms)
  final Future<void> Function(bool playing, double pos) onControl;
  final bool fullscreen;
  final VoidCallback onToggleFullscreen;

  const MovieBody({
    super.key,
    required this.room,
    required this.nowMs,
    required this.onControl,
    required this.fullscreen,
    required this.onToggleFullscreen,
  });

  @override
  State<MovieBody> createState() => _MovieBodyState();
}

class _MovieBodyState extends State<MovieBody> {
  VideoPlayerController? _vc;
  bool _vcReady = false;
  bool _vcError = false;
  bool _muted = false;
  Timer? _tick;
  DateTime _lastSeek = DateTime.fromMillisecondsSinceEpoch(0);
  int _stuck = 0;
  bool _needTap = false;
  double? _drag;
  bool _wasAd = false;

  // YouTube
  double _ytCur = 0;
  double _ytDur = 0;
  bool _ytMuted = true;
  int _ytNonce = 0;
  double? _ytSeek;
  int _ytGen = 0;
  int _ytStart = 0;

  Map<String, dynamic> get _movie {
    final m = widget.room['movie'];
    return m is Map<String, dynamic> ? m : <String, dynamic>{};
  }

  bool get _playing => _movie['playing'] == true;
  double get _basePos => ((_movie['pos'] ?? 0) as num).toDouble();
  int get _at => ((_movie['at'] ?? 0) as num).toInt();
  bool get _isYt => (_movie['yt'] ?? '').toString().isNotEmpty;
  Map<String, dynamic>? get _ad {
    final a = _movie['ad'];
    return a is Map<String, dynamic> && a['active'] == true ? a : null;
  }

  bool get _adActive => _ad != null;
  double get _nextAd => ((_movie['nextAd'] ?? 0) as num).toDouble();
  bool get _adsOn => _movie['adsOn'] == true;

  double _expected() {
    if (!_playing) return _basePos;
    final e = _basePos + (widget.nowMs() - _at) / 1000.0;
    return e < 0 ? 0 : e;
  }

  double get _duration {
    if (_isYt) return _ytDur;
    final c = _vc;
    if (c == null || !_vcReady) return 0;
    return c.value.duration.inMilliseconds / 1000.0;
  }

  @override
  void initState() {
    super.initState();
    _wasAd = _adActive;
    _ytStart = _expected().floor();
    final url = (_movie['url'] ?? '').toString();
    if (!_isYt && url.isNotEmpty) _initVideo(url);
    _tick = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      _onTick();
    });
  }

  Future<void> _initVideo(String url) async {
    final c = VideoPlayerController.networkUrl(Uri.parse(url));
    _vc = c;
    try {
      await c.initialize();
    } catch (_) {
      if (mounted) setState(() => _vcError = true);
      return;
    }
    if (!mounted) return;
    await c.setLooping(false);
    setState(() => _vcReady = true);
    _sync(force: true);
  }

  @override
  void dispose() {
    _tick?.cancel();
    _vc?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MovieBody old) {
    super.didUpdateWidget(old);
    _afterServerChange();
  }

  void _afterServerChange() {
    final nowAd = _adActive;
    if (_wasAd && !nowAd) {
      // Ad khatam: YouTube player naya banta hai aur sahi second se shuru hota hai.
      _ytStart = _expected().floor();
      _ytGen++;
      _ytCur = _ytStart.toDouble();
    }
    _wasAd = nowAd;
    _sync(force: true);
  }

  void _onTick() {
    final c = _vc;
    if (!_isYt && c != null && _vcReady && _playing && !_adActive) {
      final dur = c.value.duration.inMilliseconds / 1000.0;
      final stuck = !c.value.isPlaying && !c.value.isBuffering && _expected() < dur - 1;
      _stuck = stuck ? _stuck + 1 : 0;
      final need = _stuck >= 4;
      if (need != _needTap) _needTap = need;
    } else {
      _stuck = 0;
      _needTap = false;
    }
    _sync();
    setState(() {}); // seek bar / countdown ko chalta rakhne ke liye
  }

  void _sync({bool force = false}) {
    final exp = _expected();
    final since = DateTime.now().difference(_lastSeek).inMilliseconds;
    if (_isYt) {
      if (_adActive || since < 3000 && !force) return;
      final diff = (_ytCur - exp).abs();
      if (_ytDur > 0 && ((_playing && diff > 2.5) || (!_playing && diff > 1.0))) {
        _ytSeek = exp;
        _ytNonce++;
        _lastSeek = DateTime.now();
      }
      return;
    }
    final c = _vc;
    if (c == null || !_vcReady) return;
    if (_adActive) {
      if (c.value.isPlaying) c.pause();
      return;
    }
    final cur = c.value.position.inMilliseconds / 1000.0;
    final dur = c.value.duration.inMilliseconds / 1000.0;
    if (_playing) {
      if (dur > 0 && exp >= dur) {
        if (c.value.isPlaying) c.pause();
        return;
      }
      if ((cur - exp).abs() > 1.5 && (force || since > 3000)) {
        c.seekTo(Duration(milliseconds: (exp * 1000).round()));
        _lastSeek = DateTime.now();
      }
      if (!c.value.isPlaying) _tryPlay(c);
    } else {
      if (c.value.isPlaying) c.pause();
      if ((cur - exp).abs() > 0.7 && (force || since > 1500)) {
        c.seekTo(Duration(milliseconds: (exp * 1000).round()));
        _lastSeek = DateTime.now();
      }
    }
  }

  Future<void> _tryPlay(VideoPlayerController c) async {
    try {
      await c.play();
    } catch (_) {
      // browser ne bina tap ke play rok diya: "Tap to play" dikhega
    }
  }

  double _clampPos(double p) {
    final d = _duration;
    if (p < 0) return 0;
    if (d > 0 && p > d) return d;
    return p;
  }

  Future<void> _togglePlay() async {
    if (_adActive) return;
    await widget.onControl(!_playing, _clampPos(_expected()));
  }

  Future<void> _skip(double delta) async {
    if (_adActive) return;
    await widget.onControl(_playing, _clampPos(_expected() + delta));
  }

  void _toggleMute() {
    setState(() {
      if (_isYt) {
        _ytMuted = !_ytMuted;
      } else {
        _muted = !_muted;
        _vc?.setVolume(_muted ? 0 : 1);
      }
    });
  }

  bool get _soundOff => _isYt ? _ytMuted : _muted;

  // ------------------------------------------------------------------ UI
  Widget _adCard() {
    final ad = _ad!;
    final endsAt = ((ad['endsAt'] ?? 0) as num).toInt();
    final lenMs = ((ad['lenMs'] ?? 15000) as num).toInt();
    var left = endsAt - widget.nowMs();
    if (left < 0) left = 0;
    final secs = (left / 1000).ceil();
    final progress = lenMs <= 0 ? 1.0 : 1 - left / lenMs;
    final title = (ad['title'] ?? '').toString();
    final text = (ad['text'] ?? '').toString();
    final image = (ad['image'] ?? '').toString();
    return Container(
      color: ZX.ink,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: ZX.sun, borderRadius: BorderRadius.circular(10)),
                  child: Text('Ad break'.tr,
                      style: const TextStyle(color: ZX.ink, fontSize: 11, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 8),
                Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                if (text.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(text,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFFE8DED5), fontSize: 13)),
                ],
                const SizedBox(height: 8),
                Text('Both of you are paused. The movie resumes together.'.tr,
                    style: const TextStyle(color: Color(0xFFE8DED5), fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (image.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(image, width: 72, height: 72, fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => const SizedBox(width: 72, height: 72)),
              ),
            ),
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  strokeWidth: 5,
                  color: ZX.coral,
                  backgroundColor: const Color(0xFF4A4039),
                ),
                Text('$secs',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _player() {
    if (_adActive) return _adCard();
    if (_isYt) {
      final id = (_movie['yt'] ?? '').toString();
      return YtEmbed(
        key: ValueKey('room-yt-$id-$_ytGen'),
        videoId: id,
        play: _playing,
        muted: _ytMuted,
        controls: false,
        loop: false,
        start: _ytStart,
        seekTo: _ytSeek,
        seekNonce: _ytNonce,
        onTime: (cur, dur) {
          _ytCur = cur;
          if (dur > 0) _ytDur = dur;
        },
      );
    }
    final c = _vc;
    if (_vcError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text("This video can't be played right now".tr,
              textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
        ),
      );
    }
    if (c == null || !_vcReady) {
      return const Center(child: CircularProgressIndicator(color: ZX.coral));
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: c.value.aspectRatio <= 0 ? 16 / 9 : c.value.aspectRatio,
            child: VideoPlayer(c),
          ),
        ),
        if (_needTap)
          GestureDetector(
            onTap: () => _tryPlay(c),
            child: Container(
              color: Colors.black54,
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: ZX.coral,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: ZX.border, width: ZX.borderWidth),
                ),
                child: Text('Tap to play'.tr,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback? onTap, {double size = 26, Color color = Colors.white}) {
    return IconButton(
      onPressed: onTap,
      iconSize: size,
      color: color,
      disabledColor: Colors.white30,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      icon: Icon(icon),
    );
  }

  Widget _controls({required bool dark}) {
    final dur = _duration;
    final exp = _clampPos(_expected());
    final value = (_drag ?? exp).clamp(0.0, dur > 0 ? dur : 1.0).toDouble();
    final fg = dark ? Colors.white : ZX.ink;
    final until = _nextAd - exp;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: ZX.coral,
            inactiveTrackColor: dark ? Colors.white24 : const Color(0x33000000),
            thumbColor: ZX.coral,
            overlayShape: SliderComponentShape.noOverlay,
          ),
          child: Slider(
            value: value,
            min: 0,
            max: dur > 0 ? dur : 1.0,
            onChanged: dur > 0 && !_adActive ? (v) => setState(() => _drag = v) : null,
            onChangeEnd: dur > 0 && !_adActive
                ? (v) async {
                    final pos = v;
                    await widget.onControl(_playing, pos);
                    if (mounted) setState(() => _drag = null);
                  }
                : null,
          ),
        ),
        Row(
          children: [
            const SizedBox(width: 8),
            Text('${_fmt(value)} / ${_fmt(dur)}', style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
            const Spacer(),
            if (_adsOn && !_adActive && until > 0 && until < 3600)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: ZX.sun, borderRadius: BorderRadius.circular(10)),
                child: Text(tx('Next ad in {t}'.tr, {'t': _fmt(until)}),
                    style: const TextStyle(color: ZX.ink, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            const SizedBox(width: 8),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _iconBtn(Icons.replay_10, _adActive ? null : () => _skip(-10), color: fg),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: ZX.coral,
                shape: BoxShape.circle,
                border: Border.all(color: ZX.border, width: ZX.borderWidth),
              ),
              child: IconButton(
                onPressed: _adActive ? null : _togglePlay,
                iconSize: 30,
                color: Colors.white,
                disabledColor: Colors.white54,
                constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
                icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
              ),
            ),
            const SizedBox(width: 8),
            _iconBtn(Icons.forward_10, _adActive ? null : () => _skip(10), color: fg),
            const SizedBox(width: 12),
            _iconBtn(_soundOff ? Icons.volume_off : Icons.volume_up, _toggleMute, color: fg),
            _iconBtn(widget.fullscreen ? Icons.fullscreen_exit : Icons.fullscreen, widget.onToggleFullscreen, color: fg),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fullscreen) {
      // YouTube ke player ke upar kuch nahi lagta (unki policy): wahan controls neeche ek patli patti mein.
      if (_isYt) {
        return Container(
          color: Colors.black,
          child: Column(
            children: [
              Expanded(child: _player()),
              Container(color: const Color(0xFF1F1A17), child: SafeArea(top: false, child: _controls(dark: true))),
            ],
          ),
        );
      }
      return Container(
        color: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(child: _player()),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xCC000000), Color(0x00000000)],
                  ),
                ),
                child: SafeArea(top: false, child: _controls(dark: true)),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(color: Colors.black, child: _player()),
        ),
        Container(
          color: ZX.card,
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
          child: _controls(dark: false),
        ),
      ],
    );
  }
}
