import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'zentrixa_theme.dart';
import 'zx_api.dart';
import 'i18n.dart';

/// Ek user ki saari active stories (purani pehle).
class StoryGroup {
  final String author;
  final String name;
  final String avatar;
  final List<Map<String, dynamic>> items;
  StoryGroup(this.author, this.name, this.avatar, this.items);

  bool get allSeen => items.every((s) => s['seen'] == true);
  bool get mine => author == Session.username;
}

/// Server ki flat list ko users ke hisaab se group karta hai.
/// Order: meri stories, phir unseen, phir seen.
List<StoryGroup> groupStories(List<dynamic> raw) {
  final map = <String, StoryGroup>{};
  final order = <String>[];
  for (final e in raw) {
    final s = Map<String, dynamic>.from(e as Map);
    final a = s['author'].toString();
    if (!map.containsKey(a)) {
      map[a] = StoryGroup(a, (s['name'] ?? a).toString(), (s['avatar'] ?? '').toString(), []);
      order.add(a);
    }
    map[a]!.items.add(s);
  }
  final mine = <StoryGroup>[];
  final unseen = <StoryGroup>[];
  final seen = <StoryGroup>[];
  for (final a in order) {
    final g = map[a]!;
    if (g.mine) {
      mine.add(g);
    } else if (g.allSeen) {
      seen.add(g);
    } else {
      unseen.add(g);
    }
  }
  return [...mine, ...unseen, ...seen];
}

// ==================================================================== bar

/// Home ke upar stories ki row: "Your story" + jinhe follow karte ho unki stories.
class StoriesBar extends StatelessWidget {
  final List<StoryGroup> groups;
  final VoidCallback onAdd;
  final void Function(int groupIndex) onOpen;

  const StoriesBar({
    super.key,
    required this.groups,
    required this.onAdd,
    required this.onOpen,
  });

  Widget _ring({required Widget child, required bool active}) {
    return Container(
      width: 68,
      height: 68,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: active ? ZX.coral : const Color(0xFFD9C3B5), width: 2.5),
      ),
      child: child,
    );
  }

  Widget _label(String text) => SizedBox(
        width: 72,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(color: ZX.ink, fontSize: 12),
        ),
      );

  Widget _yourStory() {
    final hasMine = groups.isNotEmpty && groups.first.mine;
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Column(
        children: [
          GestureDetector(
            onTap: hasMine ? () => onOpen(0) : onAdd,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _ring(
                  active: hasMine,
                  child: ZxAvatar(Session.name, radius: 28, photo: Session.avatar),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: onAdd,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: ZX.coral,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          _label('Your story'.tr),
        ],
      ),
    );
  }

  Widget _bubble(StoryGroup g, int groupIndex) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: GestureDetector(
        onTap: () => onOpen(groupIndex),
        child: Column(
          children: [
            _ring(
              active: !g.allSeen,
              child: ZxAvatar(g.name, radius: 28, photo: g.avatar),
            ),
            const SizedBox(height: 6),
            _label(g.name.split(' ').first),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasMine = groups.isNotEmpty && groups.first.mine;
    final offset = hasMine ? 1 : 0;
    return SizedBox(
      height: 102,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _yourStory(),
          for (int i = offset; i < groups.length; i++) _bubble(groups[i], i),
        ],
      ),
    );
  }
}

// ==================================================================== viewer

/// Full-screen story viewer: tap right = next, tap left = back,
/// dabake rakho = pause. 5 second mein apne aap aage badhta hai.
class StoryViewerScreen extends StatefulWidget {
  final List<StoryGroup> groups;
  final int startGroup;
  const StoryViewerScreen({super.key, required this.groups, required this.startGroup});

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  int _gi = 0;
  int _si = 0;

  @override
  void initState() {
    super.initState();
    _gi = widget.startGroup;
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 5));
    _anim.addStatusListener((status) {
      if (status == AnimationStatus.completed) _next();
    });
    _startStory();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  StoryGroup get _group => widget.groups[_gi];
  Map<String, dynamic> get _story => _group.items[_si];

  void _startStory() {
    _anim.forward(from: 0);
    _markSeen();
  }

  Future<void> _markSeen() async {
    final s = _story;
    if (_group.mine || s['seen'] == true) return;
    s['seen'] = true;
    await ZxApi.post('/api/stories/view', {'storyId': s['id']});
  }

  void _next() {
    if (!mounted) return;
    if (_si < _group.items.length - 1) {
      setState(() => _si++);
      _startStory();
    } else if (_gi < widget.groups.length - 1) {
      setState(() {
        _gi++;
        _si = 0;
      });
      _startStory();
    } else {
      Navigator.pop(context, true);
    }
  }

  void _prev() {
    if (_si > 0) {
      setState(() => _si--);
    } else if (_gi > 0) {
      setState(() {
        _gi--;
        _si = widget.groups[_gi].items.length - 1;
      });
    }
    _startStory();
  }

  Future<void> _openViewers() async {
    _anim.stop();
    final res = await ZxApi.get('/api/stories/viewers', query: {'storyId': '${_story['id']}'});
    if (!mounted) return;
    final list = res.list;
    await showModalBottomSheet(
      context: context,
      backgroundColor: ZX.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        side: BorderSide(color: ZX.border, width: ZX.borderWidth),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Text(
                tx('Seen by {n}'.tr, {'n': list.length}),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ZX.ink),
              ),
              const SizedBox(height: 8),
              if (list.isEmpty)
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Nobody has seen it yet'.tr, style: TextStyle(color: ZX.muted)),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final v in list)
                        ListTile(
                          leading: ZxAvatar(
                            (v['name'] ?? v['username']).toString(),
                            radius: 20,
                            photo: (v['avatar'] ?? '').toString(),
                          ),
                          title: Text((v['name'] ?? v['username']).toString(),
                              style: const TextStyle(color: ZX.ink, fontWeight: FontWeight.w600)),
                          subtitle: Text('@${v['username']}', style: const TextStyle(color: ZX.muted)),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
    if (mounted) _anim.forward();
  }

  Future<void> _delete() async {
    _anim.stop();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete this story?'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'.tr, style: TextStyle(color: ZX.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete'.tr, style: TextStyle(color: ZX.coral, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (ok != true) {
      _anim.forward();
      return;
    }
    final res = await ZxApi.post('/api/stories/delete', {'storyId': _story['id']});
    if (!mounted) return;
    if (res.ok) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
      _anim.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = _group;
    final s = _story;
    final caption = (s['caption'] ?? '').toString();
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) {
                  if (d.localPosition.dx < width / 3) {
                    _prev();
                  } else {
                    _next();
                  }
                },
                onLongPressStart: (_) => _anim.stop(),
                onLongPressEnd: (_) => _anim.forward(),
                child: Image.network(
                  ZxApi.imageUrl((s['image'] ?? '').toString()),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
                  ),
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : const Center(child: CircularProgressIndicator(color: Colors.white)),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 10,
              right: 10,
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _anim,
                    builder: (context, _) => Row(
                      children: [
                        for (int i = 0; i < g.items.length; i++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: i < _si ? 1.0 : (i == _si ? _anim.value : 0.0),
                                  minHeight: 3,
                                  backgroundColor: Colors.white30,
                                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ZxAvatar(g.name, radius: 18, photo: g.avatar),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${g.mine ? 'Your story'.tr : g.name} · ${timeAgo((s['time'] ?? 0) as num)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context, true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (caption.isNotEmpty)
              Positioned(
                left: 16,
                right: 16,
                bottom: g.mine ? 80 : 30,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    caption,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            if (g.mine)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: _openViewers,
                      icon: const Icon(Icons.visibility_outlined, color: Colors.white),
                      label: Text('Seen by'.tr, style: TextStyle(color: Colors.white)),
                    ),
                    TextButton.icon(
                      onPressed: _delete,
                      icon: const Icon(Icons.delete_outline, color: Colors.white),
                      label: Text('Delete'.tr, style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ==================================================================== compose

/// Photo chun kar story banata hai. true => story upload ho gayi.
Future<bool> addStory(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: ZX.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      side: BorderSide(color: ZX.border, width: ZX.borderWidth),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined, color: ZX.coral),
            title: Text('Choose from gallery'.tr, style: TextStyle(color: ZX.ink)),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined, color: ZX.coral),
            title: Text('Take with camera'.tr, style: TextStyle(color: ZX.ink)),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return false;

  try {
    final file = await ImagePicker().pickImage(source: source, maxWidth: 1440, imageQuality: 85);
    if (file == null) return false;
    final bytes = await file.readAsBytes();
    if (!context.mounted) return false;
    if (bytes.length > 8 * 1024 * 1024) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Photo must be smaller than 8 MB'.tr)));
      return false;
    }
    final done = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => StoryComposeScreen(bytes: bytes)),
    );
    return done == true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tx("Couldn't get the photo: {err}".tr, {'err': e}))));
    }
    return false;
  }
}

class StoryComposeScreen extends StatefulWidget {
  final Uint8List bytes;
  const StoryComposeScreen({super.key, required this.bytes});

  @override
  State<StoryComposeScreen> createState() => _StoryComposeScreenState();
}

class _StoryComposeScreenState extends State<StoryComposeScreen> {
  final TextEditingController _caption = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    final res = await ZxApi.post('/api/stories', {
      'image': base64Encode(widget.bytes),
      'caption': _caption.text.trim(),
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.ok) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context, false),
              ),
            ),
            Expanded(child: Image.memory(widget.bytes, fit: BoxFit.contain)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Column(
                children: [
                  TextField(
                    controller: _caption,
                    maxLength: 300,
                    style: const TextStyle(color: ZX.ink),
                    decoration: ZX.input('Write a caption (optional)'.tr).copyWith(counterText: ''),
                  ),
                  const SizedBox(height: 12),
                  ZxButton(_busy ? 'Sharing...'.tr : 'Share story (24 hours)'.tr,
                      onPressed: _busy ? null : _share),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
