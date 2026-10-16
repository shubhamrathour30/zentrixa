import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'comments_sheet.dart';
import 'post_actions.dart';
import 'profile_screen.dart';
import 'zentrixa_theme.dart';
import 'zx_api.dart';
import 'i18n.dart';
import 'yt_embed.dart';

/// Sound on/off - ek hi switch sabhi reels ke liye (app chalne tak yaad rehta hai).
class ZxSound {
  static final ValueNotifier<bool> muted = ValueNotifier<bool>(false);
}

/// Reels: upar-neeche swipe karne wali video feed.
/// `active` true tab hota hai jab ye tab dikh raha ho (warna video pause).
/// `items` diye ho to ye sirf wahi reels dikhata hai (jaise Saved se kholne par).
class ReelsScreen extends StatefulWidget {
  final bool active;
  final ValueNotifier<int> refreshSignal;
  final List<Map<String, dynamic>>? items;
  final int startIndex;
  const ReelsScreen({
    super.key,
    required this.active,
    required this.refreshSignal,
    this.items,
    this.startIndex = 0,
  });

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  // Free stock videos aksar bina awaaz ki hoti hain, isliye unke neeche halka background music chalta hai.
  static const List<String> _musicTracks = [
    'assets/audio/bed1.wav',
    'assets/audio/bed2.wav',
    'assets/audio/bed3.wav',
  ];

  late final PageController _pc;
  final Map<int, VideoPlayerController> _ctrls = {};
  final Set<int> _failed = {};
  final Set<int> _ytPaused = {}; // jin YouTube reels par user ne tap karke pause kiya
  int _heartPage = -1; // double tap like ka dil kis page par dikh raha hai
  List<Map<String, dynamic>> _reels = [];
  bool _loading = true;
  bool _loadedOnce = false;
  int _page = 0;
  // Free videos (server par Pixabay ya Pexels key ho to)
  bool _discoverEnabled = false;
  bool _loadingMore = false;
  int _discoverPage = 0;
  // Background music player
  VideoPlayerController? _music;
  int _musicTrack = -1;
  int _musicGen = 0;

  bool get _viewer => widget.items != null;

  // YouTube Shorts: official embed player (video_player nahi chalta inme)
  bool _isYt(Map<String, dynamic> p) => (p['youtube'] ?? '').toString().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _pc = PageController(initialPage: widget.startIndex);
    ZxSound.muted.addListener(_onMuteChanged);
    if (_viewer) {
      _reels = widget.items!;
      _page = widget.startIndex.clamp(0, _reels.isEmpty ? 0 : _reels.length - 1);
      _loading = false;
      _loadedOnce = true;
    } else {
      widget.refreshSignal.addListener(_reload);
      if (widget.active) _load();
    }
  }

  @override
  void didUpdateWidget(ReelsScreen old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      if (!_loadedOnce) {
        _load();
      } else {
        _playCurrent();
      }
    } else if (!widget.active && old.active) {
      for (final c in _ctrls.values) {
        c.pause();
      }
      _syncMusic();
    }
  }

  @override
  void dispose() {
    ZxSound.muted.removeListener(_onMuteChanged);
    if (!_viewer) widget.refreshSignal.removeListener(_reload);
    _disposeControllers();
    _musicGen++;
    _music?.dispose();
    _music = null;
    _pc.dispose();
    super.dispose();
  }

  void _disposeControllers() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    _ctrls.clear();
    _failed.clear();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _reload() {
    if (_loadedOnce) _load();
  }

  // ---------------------------------------------------------------- sound
  void _applyVolumes() {
    final v = ZxSound.muted.value ? 0.0 : 1.0;
    for (final c in _ctrls.values) {
      c.setVolume(v);
    }
  }

  void _onMuteChanged() {
    _applyVolumes();
    _syncMusic();
    if (mounted) setState(() {});
  }

  // Play karo; browser awaaz ke saath autoplay rok de to muted chala do.
  Future<void> _play(VideoPlayerController c) async {
    try {
      await c.play();
    } catch (_) {
      if (!ZxSound.muted.value) {
        ZxSound.muted.value = true;
        try {
          await c.play();
        } catch (_) {}
        _snack('Tap the speaker icon to turn the sound on'.tr);
      }
    }
    _syncMusic();
  }

  // Background music: sirf free (external) video par, jab video chal rahi ho aur sound on ho.
  Future<void> _syncMusic() async {
    final gen = ++_musicGen;
    final cur = (_page >= 0 && _page < _reels.length) ? _reels[_page] : null;
    final vc = _ctrls[_page];
    final want = widget.active &&
        !ZxSound.muted.value &&
        cur != null &&
        cur['external'] == true &&
        vc != null &&
        vc.value.isInitialized &&
        vc.value.isPlaying;
    if (!want) {
      await _music?.pause();
      return;
    }
    final track = (cur['id'] as num).toInt() % _musicTracks.length;
    if (_music == null || _musicTrack != track) {
      final old = _music;
      _music = null;
      _musicTrack = track;
      await old?.dispose();
      if (gen != _musicGen || !mounted) return;
      final c = VideoPlayerController.asset(_musicTracks[track]);
      try {
        await c.initialize();
        await c.setLooping(true);
        await c.setVolume(0.35);
      } catch (_) {
        await c.dispose();
        _musicTrack = -1;
        return;
      }
      if (gen != _musicGen || !mounted) {
        await c.dispose();
        if (_music == null) _musicTrack = -1;
        return;
      }
      _music = c;
    }
    try {
      await _music!.play();
    } catch (_) {}
  }

  // ---------------------------------------------------------------- data
  // Apni (users ki) reels aur free videos ko mila do: 1 apni, phir 2 free.
  List<Map<String, dynamic>> _mix(List<Map<String, dynamic>> mine, List<Map<String, dynamic>> disc) {
    final out = <Map<String, dynamic>>[];
    int a = 0;
    int b = 0;
    while (a < mine.length || b < disc.length) {
      if (a < mine.length) out.add(mine[a++]);
      for (int k = 0; k < 2 && b < disc.length; k++) {
        out.add(disc[b++]);
      }
    }
    return out;
  }

  Future<void> _load() async {
    _loadedOnce = true;
    final results = await Future.wait([
      ZxApi.get('/api/posts', query: {'filter': 'reels'}),
      ZxApi.get('/api/discover', query: {'page': '1'}),
      ZxApi.get('/api/discover', query: {'page': '2'}),
    ]);
    if (!mounted) return;

    final mine = results[0].ok
        ? results[0].list.map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];
    final disc = <Map<String, dynamic>>[];
    bool enabled = false;
    for (final r in [results[1], results[2]]) {
      if (r.ok && r.map['enabled'] == true) {
        enabled = true;
        final raw = r.map['items'];
        if (raw is List) disc.addAll(raw.map((e) => Map<String, dynamic>.from(e)));
      }
    }

    setState(() {
      _disposeControllers();
      _reels = _mix(mine, disc);
      _discoverEnabled = enabled;
      _discoverPage = 2;
      if (results[0].error == 'NETWORK') _snack(results[0].message);
      if (_page >= _reels.length) _page = 0;
      _loading = false;
    });
  }

  // Aakhri 3 videos ke paas pahunchne par agle free videos mangwao
  Future<void> _maybeLoadMore(int i) async {
    if (_viewer || !_discoverEnabled || _loadingMore || i < _reels.length - 3) return;
    _loadingMore = true;
    final res = await ZxApi.get('/api/discover', query: {'page': '${_discoverPage + 1}'});
    _loadingMore = false;
    if (!mounted || !res.ok) return;
    _discoverPage++;
    final raw = res.map['items'];
    if (raw is! List) return;
    final have = _reels.map((e) => e['id'].toString()).toSet();
    final fresh = raw
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => !have.contains(e['id'].toString()))
        .toList();
    if (fresh.isEmpty) {
      _discoverEnabled = false; // aur nayi videos nahi
      return;
    }
    setState(() => _reels.addAll(fresh));
  }

  // ---------------------------------------------------------------- playback
  VideoPlayerController? _ctrlFor(int i) {
    if (i < 0 || i >= _reels.length || _isYt(_reels[i])) return null;
    return _ctrls.putIfAbsent(i, () {
      final url = ZxApi.imageUrl(_reels[i]['video'].toString());
      final c = VideoPlayerController.networkUrl(Uri.parse(url));
      c.initialize().then((_) {
        if (!mounted || _ctrls[i] != c) return;
        c.setLooping(true);
        c.setVolume(ZxSound.muted.value ? 0.0 : 1.0);
        if (i == _page && widget.active) _play(c);
        setState(() {});
      }).catchError((Object e) {
        if (mounted && _ctrls[i] == c) setState(() => _failed.add(i));
      });
      return c;
    });
  }

  void _playCurrent() {
    for (final entry in _ctrls.entries) {
      final c = entry.value;
      if (!c.value.isInitialized) continue;
      if (entry.key == _page && widget.active) {
        _play(c);
      } else {
        c.pause();
      }
    }
    _syncMusic();
  }

  void _onPage(int i) {
    _ytPaused.clear();
    setState(() => _page = i);
    // Door ke controllers hata do (memory bachane ke liye)
    final far = _ctrls.keys.where((k) => (k - i).abs() > 1).toList();
    for (final k in far) {
      _ctrls[k]?.dispose();
      _ctrls.remove(k);
      _failed.remove(k);
    }
    _ctrlFor(i);
    if (i + 1 < _reels.length) _ctrlFor(i + 1);
    _playCurrent();
    _maybeLoadMore(i);
  }

  void _toggleMute() {
    ZxSound.muted.value = !ZxSound.muted.value;
  }

  void _togglePlay(int i) {
    final c = _ctrls[i];
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      c.pause();
      setState(() {});
      _syncMusic();
    } else {
      _play(c);
      setState(() {});
    }
  }

  // ---------------------------------------------------------------- actions
  String _compact(num n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '${n.toInt()}';

  Future<void> _toggleLike(Map<String, dynamic> p) async {
    final wasLiked = p['liked'] == true;
    setState(() {
      p['liked'] = !wasLiked;
      p['likes'] = (p['likes'] as num).toInt() + (wasLiked ? -1 : 1);
    });
    final res = await ZxApi.post('/api/posts/like', {'postId': p['id']});
    if (!mounted) return;
    setState(() {
      if (res.ok) {
        p['liked'] = res.map['liked'];
        p['likes'] = res.map['likes'];
      } else {
        p['liked'] = wasLiked;
        p['likes'] = (p['likes'] as num).toInt() + (wasLiked ? 1 : -1);
      }
    });
    if (!res.ok) _snack(res.message);
  }

  void _openComments(Map<String, dynamic> p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ZX.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        side: BorderSide(color: ZX.border, width: ZX.borderWidth),
      ),
      builder: (context) => CommentsSheet(
        postId: (p['id'] as num).toInt(),
        onCountChanged: (n) => setState(() => p['comments'] = n),
      ),
    );
  }

  void _removeWhere(bool Function(Map<String, dynamic>) test) {
    setState(() {
      _reels.removeWhere(test);
      _disposeControllers(); // index badal gaye, controllers dobara banenge
      if (_page >= _reels.length) _page = _reels.isEmpty ? 0 : _reels.length - 1;
    });
  }

  Widget _action(IconData icon, String label, VoidCallback onTap, {Color color = Colors.white}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 26),
            ),
            if (label.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(label.tr, style: const TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _video(int i) {
    final c = _ctrlFor(i);
    if (c == null) return const SizedBox.shrink();
    if (_failed.contains(i)) {
      return Center(
        child: Text('Video could not be played'.tr, style: TextStyle(color: Colors.white70)),
      );
    }
    if (!c.value.isInitialized) {
      final poster = (_reels[i]['poster'] ?? '').toString();
      return Stack(
        fit: StackFit.expand,
        children: [
          if (poster.startsWith('http'))
            Image.network(poster, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()),
          const Center(child: CircularProgressIndicator(color: Colors.white)),
        ],
      );
    }
    final size = c.value.size;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _togglePlay(i),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: size.width <= 0 ? 1 : size.width,
              height: size.height <= 0 ? 1 : size.height,
              child: VideoPlayer(c),
            ),
          ),
          if (!c.value.isPlaying)
            const Center(child: Icon(Icons.play_arrow_rounded, color: Colors.white70, size: 84)),
        ],
      ),
    );
  }

  // YouTube Shorts ka page: poori screen par, Instagram jaisa. Upar ek transparent layer hai jo har touch pakadti hai,
  // isliye screen par kahin bhi swipe karo to agli reel aati hai, tap = pause/play, double tap = like.
  Widget _ytPage(int i) {
    final p = _reels[i];
    final id = p['youtube'].toString();
    final name = (p['name'] ?? '').toString();
    final caption = (p['caption'] ?? '').toString();
    final poster = (p['poster'] ?? '').toString();
    final url = (p['sourceUrl'] ?? '').toString();
    final liked = p['liked'] == true;
    final saved = p['saved'] == true;
    final active = i == _page && widget.active;
    final paused = _ytPaused.contains(i);

    // Player: video ki height = screen ki height. Box 16:9 (landscape) rakha hai taaki YouTube apna Shorts wala
    // UI (like/share/Shorts logo) na dikhaye; vertical video beech mein poori screen bharti hai, baaki hissa clip ho jata hai.
    final player = LayoutBuilder(builder: (context, c) {
      final h = c.maxHeight;
      return ClipRect(
        child: OverflowBox(
          maxWidth: h * 16 / 9,
          minWidth: h * 16 / 9,
          maxHeight: h,
          minHeight: h,
          child: active
              ? YtEmbed(
                  key: ValueKey('yt-$id'),
                  videoId: id,
                  play: !paused,
                  muted: ZxSound.muted.value,
                  controls: false,
                  interactive: false,
                )
              : (poster.startsWith('http')
                  ? Image.network(poster, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox())
                  : const SizedBox()),
        ),
      );
    });

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.black),
        player,
        // Touch layer: YouTube ke apne buttons tak touch pahunchta hi nahi, swipe kahin se bhi chalta hai.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() {
              _ytPaused.contains(i) ? _ytPaused.remove(i) : _ytPaused.add(i);
            }),
            onDoubleTap: () {
              if (!liked) _toggleLike(p);
              setState(() => _heartPage = i);
              Future.delayed(const Duration(milliseconds: 700), () {
                if (mounted && _heartPage == i) setState(() => _heartPage = -1);
              });
            },
            child: const SizedBox.expand(),
          ),
        ),
        if (paused)
          const IgnorePointer(
            child: Center(child: Icon(Icons.play_arrow_rounded, color: Colors.white70, size: 84)),
          ),
        if (_heartPage == i)
          const IgnorePointer(
            child: Center(child: Icon(Icons.favorite, color: Colors.white, size: 110)),
          ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 220,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 90,
          bottom: 22,
          child: IgnorePointer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                if (caption.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 14)),
                ],
                const SizedBox(height: 4),
                const Text('YouTube', style: TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
        ),
        Positioned(
          right: 10,
          bottom: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _action(
                liked ? Icons.favorite : Icons.favorite_border,
                _compact((p['likes'] ?? 0) as num),
                () => _toggleLike(p),
                color: liked ? ZX.coral : Colors.white,
              ),
              _action(Icons.chat_bubble_outline, _compact((p['comments'] ?? 0) as num), () => _openComments(p)),
              _action(
                saved ? Icons.bookmark : Icons.bookmark_border,
                saved ? 'Saved'.tr : 'Save'.tr,
                () => ZxActions.toggleSave(context, p, onChanged: () {
                  if (mounted) setState(() {});
                }),
                color: saved ? ZX.sun : Colors.white,
              ),
              _action(Icons.share_outlined, 'Share'.tr, () => ZxActions.share(context, p)),
              Tooltip(
                message: 'Open on YouTube'.tr,
                child: _action(Icons.open_in_new, '', () => ytOpenUrl(url)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reelPage(int i) {
    if (_isYt(_reels[i])) return _ytPage(i);
    final p = _reels[i];
    final ext = p['external'] == true; // Pexels/Pixabay ki free video
    final credit = (p['credit'] ?? 'Pexels').toString();
    final name = (p['name'] ?? p['author'] ?? '').toString();
    final author = (p['author'] ?? '').toString();
    final caption = (p['caption'] ?? '').toString();
    final mine = p['mine'] == true;
    final liked = p['liked'] == true;
    final saved = p['saved'] == true;

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.black),
        _video(i),
        // neeche ka gradient taaki text padh sako
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 220,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 90,
          bottom: 22,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: author.isEmpty
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ProfileScreen(username: author)),
                        ),
                child: Row(
                  children: [
                    ZxAvatar(name, radius: 18, photo: (p['avatar'] ?? '').toString()),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
              if (caption.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  caption,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ],
              const SizedBox(height: 4),
              Text(ext ? tx('Free video · {credit}'.tr, {'credit': credit}) : timeAgo((p['time'] ?? 0) as num),
                  style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ],
          ),
        ),
        Positioned(
          right: 10,
          bottom: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _action(
                liked ? Icons.favorite : Icons.favorite_border,
                _compact((p['likes'] ?? 0) as num),
                () => _toggleLike(p),
                color: liked ? ZX.coral : Colors.white,
              ),
              _action(Icons.chat_bubble_outline, _compact((p['comments'] ?? 0) as num),
                  () => _openComments(p)),
              _action(
                saved ? Icons.bookmark : Icons.bookmark_border,
                saved ? 'Saved'.tr : 'Save'.tr,
                () => ZxActions.toggleSave(context, p, onChanged: () {
                  if (mounted) setState(() {});
                }),
                color: saved ? ZX.sun : Colors.white,
              ),
              _action(Icons.share_outlined, 'Share'.tr, () => ZxActions.share(context, p)),
              if (ext)
                _action(Icons.info_outline, 'Credit'.tr,
                    () => _snack(tx('Video: {name} · {credit} (free licence)'.tr, {'name': name, 'credit': credit})))
              else ...[
                if (!mine)
                  _action(Icons.monetization_on_outlined, 'Gift'.tr,
                      () => ZxActions.tip(context, (p['id'] as num).toInt()),
                      color: ZX.sun),
                _action(Icons.more_horiz, '', () {
                  ZxActions.postMenu(
                    context,
                    p,
                    onDeleted: () => _removeWhere((x) => x['id'] == p['id']),
                    onBlocked: (a) => _removeWhere((x) => x['author'] == a),
                  );
                }),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator(color: Colors.white));
    } else if (_reels.isEmpty) {
      body = Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          padding: const EdgeInsets.all(24),
          decoration: ZX.cardDecoration(color: ZX.card, radius: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.movie_creation_outlined, size: 46, color: ZX.coral),
              SizedBox(height: 12),
              Text('No reels yet'.tr,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ZX.ink)),
              SizedBox(height: 6),
              Text(
                'Tap the yellow + button below, choose "Reel" and upload the first video!\n(For free videos, set a Pixabay key on the server - see SETUP.md)'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(color: ZX.muted),
              ),
            ],
          ),
        ),
      );
    } else {
      // pehle page ka controller bana do
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _ctrls.isEmpty && _reels.isNotEmpty) {
          _ctrlFor(_page);
          if (_page + 1 < _reels.length) _ctrlFor(_page + 1);
        }
      });
      body = PageView.builder(
        scrollDirection: Axis.vertical,
        controller: _pc,
        itemCount: _reels.length,
        onPageChanged: _onPage,
        itemBuilder: (context, i) => _reelPage(i),
      );
    }

    final muted = ZxSound.muted.value;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          body,
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
              child: Row(
                children: [
                  if (_viewer)
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    )
                  else
                    const SizedBox(width: 8),
                  Text('Reels'.tr,
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    tooltip: muted ? 'Sound on'.tr : 'Sound off'.tr,
                    icon: Icon(muted ? Icons.volume_off : Icons.volume_up, color: Colors.white),
                    onPressed: _toggleMute,
                  ),
                  if (!_viewer)
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: _load,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
