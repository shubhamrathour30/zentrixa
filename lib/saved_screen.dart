import 'package:flutter/material.dart';

import 'post_actions.dart';
import 'reels_screen.dart';
import 'zentrixa_theme.dart';
import 'zx_api.dart';
import 'i18n.dart';

/// Saved: jo posts / reels aapne bookmark ki hain.
class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await ZxApi.get('/api/saved');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.ok) _items = res.list.map((e) => Map<String, dynamic>.from(e)).toList();
    });
  }

  bool _isVideo(Map<String, dynamic> p) => (p['video'] ?? '').toString().isNotEmpty;

  Future<void> _open(Map<String, dynamic> p) async {
    if (_isVideo(p)) {
      final videos = _items.where(_isVideo).map((e) => Map<String, dynamic>.from(e)).toList();
      final idx = videos.indexWhere((v) => v['id'] == p['id']);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReelsScreen(
            active: true,
            refreshSignal: ValueNotifier<int>(0),
            items: videos,
            startIndex: idx < 0 ? 0 : idx,
          ),
        ),
      );
      _load(); // wahan unsave kiya ho to list ghat jaye
    } else {
      await showDialog(
        context: context,
        builder: (ctx) => _PostDialog(post: p),
      );
      _load();
    }
  }

  Widget _tile(Map<String, dynamic> p) {
    final image = (p['image'] ?? '').toString();
    final poster = (p['poster'] ?? '').toString();
    final caption = (p['caption'] ?? '').toString();
    Widget content;
    if (image.isNotEmpty) {
      content = Image.network(
        ZxApi.imageUrl(image),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Center(child: Icon(Icons.broken_image_outlined, color: ZX.muted)),
      );
    } else if (_isVideo(p)) {
      content = Stack(
        fit: StackFit.expand,
        children: [
          Container(color: ZX.ink),
          if (poster.startsWith('http'))
            Image.network(poster, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()),
          const Center(child: Icon(Icons.play_circle_outline, color: Colors.white, size: 40)),
        ],
      );
    } else {
      content = Container(
        color: ZX.coralSoft,
        padding: const EdgeInsets.all(10),
        child: Center(
          child: Text(
            caption,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: ZX.ink, fontSize: 13),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: () => _open(p),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ZX.border, width: 1.8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            content,
            const Positioned(
              top: 8,
              right: 8,
              child: Icon(Icons.bookmark, color: ZX.sun, size: 22),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZX.bg,
      appBar: AppBar(
        backgroundColor: ZX.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: ZX.ink),
        title: Text('Saved'.tr,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: ZX.ink)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: ZX.coral))
          : RefreshIndicator(
              color: ZX.coral,
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: 120),
                        Icon(Icons.bookmark_border, size: 56, color: ZX.coral),
                        SizedBox(height: 12),
                        Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'Nothing saved yet. Tap the bookmark on any post or reel to keep it here.'.tr,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: ZX.muted, fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    )
                  : GridView.count(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.78,
                      children: [for (final p in _items) _tile(p)],
                    ),
            ),
    );
  }
}

class _PostDialog extends StatefulWidget {
  final Map<String, dynamic> post;
  const _PostDialog({required this.post});

  @override
  State<_PostDialog> createState() => _PostDialogState();
}

class _PostDialogState extends State<_PostDialog> {
  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final image = (p['image'] ?? '').toString();
    final caption = (p['caption'] ?? '').toString();
    final name = (p['name'] ?? '').toString();
    return AlertDialog(
      contentPadding: const EdgeInsets.all(14),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ZxAvatar(name, radius: 18, photo: (p['avatar'] ?? '').toString()),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: ZX.ink)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (image.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(ZxApi.imageUrl(image), fit: BoxFit.cover),
              ),
            if (caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(caption, style: const TextStyle(color: ZX.ink, fontSize: 16)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await ZxActions.toggleSave(context, p, onChanged: () {
              if (mounted) setState(() {});
            });
            if (context.mounted) Navigator.pop(context);
          },
          child: Text('Remove from saved'.tr, style: TextStyle(color: ZX.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Close'.tr, style: TextStyle(color: ZX.coral, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
