import 'dart:async';

import 'package:flutter/material.dart';

import 'i18n.dart';
import 'profile_screen.dart';
import 'reels_screen.dart';
import 'zentrixa_theme.dart';
import 'zx_api.dart';

/// Instagram jaisa Search / Explore: upar search bar (log + posts + reels), khali ho to neeche explore ka grid.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _q = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _debounce;
  int _seq = 0; // purane jawab naye ke upar na aa jayein

  List<Map<String, dynamic>> _explore = []; // reels + posts (explore grid)
  bool _exploreLoading = true;
  List<Map<String, dynamic>> _people = [];
  bool _searching = false;

  String get _query => _q.text.trim();

  @override
  void initState() {
    super.initState();
    _loadExplore();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadExplore() async {
    final results = await Future.wait([
      ZxApi.get('/api/posts', query: {'filter': 'reels'}),
      ZxApi.get('/api/posts', query: {'filter': 'trending'}),
    ]);
    if (!mounted) return;
    final reels = results[0].ok ? results[0].list.map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];
    final posts = results[1].ok ? results[1].list.map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];
    // reels aur posts milakar (ek reel, ek post ...)
    final mixed = <Map<String, dynamic>>[];
    for (var i = 0; i < reels.length || i < posts.length; i++) {
      if (i < reels.length) mixed.add(reels[i]);
      if (i < posts.length) mixed.add(posts[i]);
    }
    setState(() {
      _explore = mixed;
      _exploreLoading = false;
    });
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    if (_query.isEmpty) {
      setState(() {
        _people = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 300), _searchPeople);
  }

  Future<void> _searchPeople() async {
    final q = _query;
    if (q.isEmpty) return;
    final my = ++_seq;
    final r = await ZxApi.get('/api/search_users', query: {'query': q});
    if (!mounted || my != _seq) return;
    setState(() {
      _searching = false;
      _people = r.ok ? r.list.map((e) => Map<String, dynamic>.from(e)).toList() : [];
    });
  }

  bool _isVideo(Map<String, dynamic> p) => (p['video'] ?? '').toString().isNotEmpty;

  void _openItem(Map<String, dynamic> p, List<Map<String, dynamic>> pool) {
    FocusScope.of(context).unfocus();
    if (_isVideo(p)) {
      final videos = pool.where(_isVideo).map((e) => Map<String, dynamic>.from(e)).toList();
      final idx = videos.indexWhere((v) => v['id'] == p['id']);
      Navigator.push(
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
      return;
    }
    final image = (p['image'] ?? '').toString();
    final caption = (p['caption'] ?? '').toString();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: const EdgeInsets.all(14),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('@${p['author'] ?? ''}', style: const TextStyle(color: ZX.muted, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
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
              const SizedBox(height: 10),
              Text('❤ ${p['likes'] ?? 0}   💬 ${p['comments'] ?? 0}',
                  style: const TextStyle(color: ZX.muted, fontSize: 13)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close'.tr, style: const TextStyle(color: ZX.coral, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _openProfile(String uid) {
    FocusScope.of(context).unfocus();
    Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(username: uid)));
  }

  // ------------------------------------------------------------ widgets

  Widget _tile(Map<String, dynamic> p, List<Map<String, dynamic>> pool) {
    final image = (p['image'] ?? '').toString();
    final poster = (p['poster'] ?? '').toString();
    final caption = (p['caption'] ?? '').toString();
    final video = _isVideo(p) || (p['youtube'] ?? '').toString().isNotEmpty;
    Widget content;
    if (image.isNotEmpty) {
      content = Image.network(
        ZxApi.imageUrl(image),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, color: ZX.muted)),
      );
    } else if (poster.startsWith('http')) {
      content = Image.network(poster, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: ZX.ink));
    } else if (video) {
      content = Container(color: ZX.ink);
    } else {
      content = Container(
        color: ZX.coralSoft,
        padding: const EdgeInsets.all(8),
        child: Center(
          child: Text(caption,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: ZX.ink, fontSize: 12)),
        ),
      );
    }
    return GestureDetector(
      onTap: () => _openItem(p, pool),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(6), child: content),
          if (video)
            const Positioned(
              top: 6,
              right: 6,
              child: Icon(Icons.movie_outlined, color: Colors.white, size: 18, shadows: [Shadow(blurRadius: 4)]),
            ),
        ],
      ),
    );
  }

  Widget _grid(List<Map<String, dynamic>> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _tile(items[i], items),
    );
  }

  Widget _personRow(Map<String, dynamic> u) {
    final uid = (u['uid'] ?? '').toString();
    final name = (u['name'] ?? uid).toString();
    final rel = (u['relation'] ?? '').toString();
    String tag = '';
    if (rel == 'friends' || rel == 'friend') {
      tag = 'Friends'.tr;
    } else if (rel == 'following') {
      tag = 'Following'.tr;
    } else if (u['followsMe'] == true) {
      tag = 'Follows you'.tr;
    }
    return InkWell(
      onTap: () => _openProfile(uid),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            ZxAvatar(name, radius: 26, photo: (u['avatar'] ?? '').toString()),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: ZX.ink, fontWeight: FontWeight.w700, fontSize: 16)),
                  Text('@$uid', style: const TextStyle(color: ZX.muted, fontSize: 13)),
                ],
              ),
            ),
            if (tag.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: ZX.coralSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(tag, style: const TextStyle(color: ZX.coral, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
        child: Text(t, style: const TextStyle(color: ZX.ink, fontWeight: FontWeight.w800, fontSize: 16)),
      );

  Widget _body() {
    final q = _query.toLowerCase();
    if (q.isEmpty) {
      if (_exploreLoading) {
        return const Padding(
          padding: EdgeInsets.only(top: 60),
          child: Center(child: CircularProgressIndicator(color: ZX.coral)),
        );
      }
      if (_explore.isEmpty) {
        return Padding(
          padding: const EdgeInsets.only(top: 60),
          child: Center(
            child: Text('Search for people, posts and reels'.tr, style: const TextStyle(color: ZX.muted)),
          ),
        );
      }
      return _grid(_explore);
    }
    final matches = _explore.where((p) {
      final text = '${p['caption'] ?? ''} ${p['name'] ?? ''} ${p['author'] ?? ''}'.toLowerCase();
      return text.contains(q);
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('People'.tr),
        if (_searching && _people.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(color: ZX.coral)),
          )
        else if (_people.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            child: Text('No people found'.tr, style: const TextStyle(color: ZX.muted)),
          )
        else
          for (final u in _people) _personRow(u),
        if (matches.isNotEmpty) ...[
          _sectionTitle('Posts and reels'.tr),
          _grid(matches),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZX.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 14, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: ZX.ink),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(23),
                        border: Border.all(color: ZX.border, width: ZX.borderWidth),
                      ),
                      child: TextField(
                        controller: _q,
                        focusNode: _focus,
                        onChanged: _onChanged,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _searchPeople(),
                        style: const TextStyle(color: ZX.ink, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'Search'.tr,
                          hintStyle: const TextStyle(color: ZX.muted),
                          prefixIcon: const Icon(Icons.search, color: ZX.muted),
                          suffixIcon: _q.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.close, color: ZX.muted, size: 20),
                                  onPressed: () {
                                    _q.clear();
                                    _onChanged('');
                                  },
                                ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: ZX.coral,
                onRefresh: _loadExplore,
                child: ListView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                  children: [_body()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
