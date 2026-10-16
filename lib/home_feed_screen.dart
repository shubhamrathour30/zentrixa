import 'package:flutter/material.dart';

import 'comments_sheet.dart';
import 'notifications_screen.dart';
import 'post_actions.dart';
import 'profile_screen.dart';
import 'rooms_hub_screen.dart';
import 'search_screen.dart';
import 'stories.dart';
import 'suggestions.dart';
import 'zentrixa_theme.dart';
import 'zentrixa_ai_screen.dart';
import 'zx_api.dart';
import 'i18n.dart';

/// Home feed: stories row + filter chips + real posts from the server.
class HomeFeedScreen extends StatefulWidget {
  /// Value badalne par feed refresh hota hai (naya post banne ke baad).
  final ValueNotifier<int> refreshSignal;

  /// Unread notifications ki ginti (bell icon ka badge). MainShell isse update karta hai.
  final ValueNotifier<int> unread;
  const HomeFeedScreen({Key? key, required this.refreshSignal, required this.unread})
      : super(key: key);

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  static const _filterKeys = ['all', 'following', 'trending', 'confessions'];
  static const _filterLabels = ['For you', 'Following', 'Trending', 'Confessions'];

  int _filter = 0;
  bool _loading = true;
  List<Map<String, dynamic>> _posts = [];
  List<StoryGroup> _stories = [];

  static const _palette = [
    [Color(0xFFFF9A5C), Color(0xFFFF5733)],
    [Color(0xFFFFC46B), Color(0xFFFF7A45)],
    [Color(0xFFFFB38A), Color(0xFFC23A14)],
  ];

  @override
  void initState() {
    super.initState();
    widget.refreshSignal.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    widget.refreshSignal.removeListener(_load);
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _load() async {
    if (!Session.loggedIn) return;
    final results = await Future.wait([
      ZxApi.get('/api/posts', query: {'filter': _filterKeys[_filter]}),
      ZxApi.get('/api/stories'),
    ]);
    if (!mounted) return;
    setState(() {
      if (results[0].ok) {
        _posts = results[0].list.map((e) => Map<String, dynamic>.from(e)).toList();
      } else if (results[0].error == 'NETWORK') {
        _snack(results[0].message);
      }
      if (results[1].ok) {
        _stories = groupStories(results[1].list);
      }
      _loading = false;
    });
  }

  Future<void> _reloadStories() async {
    final res = await ZxApi.get('/api/stories');
    if (!mounted || !res.ok) return;
    setState(() => _stories = groupStories(res.list));
  }

  Future<void> _addStory() async {
    final done = await addStory(context);
    if (done) {
      _snack('Story shared! It stays visible for 24 hours.'.tr);
      _reloadStories();
    }
  }

  Future<void> _openStories(int groupIndex) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryViewerScreen(groups: _stories, startGroup: groupIndex),
      ),
    );
    _reloadStories();
  }

  void _openProfile(String username) {
    if (username.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileScreen(username: username)),
    );
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    widget.unread.value = 0;
  }

  void _openSearch() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()));
  }

  void _openRooms() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const RoomsHubScreen()));
  }

  void _openAi() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ZentrixaAiScreen()));
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap, String label) {
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: ZX.border, width: ZX.borderWidth),
          ),
          child: Icon(icon, color: ZX.ink, size: 24),
        ),
      ),
    );
  }

  String _compact(num n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '${n.toInt()}';

  Future<void> _toggleLike(Map<String, dynamic> p) async {
    final wasLiked = p['liked'] == true;
    setState(() {
      p['liked'] = !wasLiked;
      p['likes'] = (p['likes'] as num).toInt() + (wasLiked ? -1 : 1);
    });
    final res = await ZxApi.post('/api/posts/like', {'postId': p['id']});
    if (!mounted) return;
    if (res.ok) {
      setState(() {
        p['liked'] = res.map['liked'];
        p['likes'] = res.map['likes'];
      });
    } else {
      setState(() {
        p['liked'] = wasLiked;
        p['likes'] = (p['likes'] as num).toInt() + (wasLiked ? 1 : -1);
      });
      _snack(res.message);
    }
  }

  Future<void> _toggleFollow(Map<String, dynamic> p) async {
    final res = await ZxApi.post('/api/follow', {'username': p['author']});
    if (!mounted) return;
    if (res.ok) {
      setState(() {
        for (final x in _posts) {
          if (x['author'] == p['author']) x['following'] = res.map['following'];
        }
      });
    } else {
      _snack(res.message);
    }
  }

  void _postMenu(Map<String, dynamic> p) {
    ZxActions.postMenu(
      context,
      p,
      onDeleted: () => setState(() => _posts.removeWhere((x) => x['id'] == p['id'])),
      onBlocked: (a) {
        setState(() => _posts.removeWhere((x) => x['author'] == a));
        _reloadStories();
      },
    );
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

  // ---------------------------------------------------------------- widgets

  Widget _chip(IconData icon, String label, {VoidCallback? onTap, bool active = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.16),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: active ? ZX.sun : Colors.white),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _postCard(Map<String, dynamic> p) {
    final colors = _palette[(p['id'] as num).toInt() % _palette.length];
    final image = (p['image'] ?? '').toString();
    final place = (p['place'] ?? '').toString();
    final caption = (p['caption'] ?? '').toString();
    final name = (p['name'] ?? p['author']).toString();
    final author = (p['author'] ?? '').toString();
    final avatar = (p['avatar'] ?? '').toString();
    final anon = p['anon'] == true;
    final mine = p['mine'] == true;
    final liked = p['liked'] == true;
    final following = p['following'] == true;

    return Container(
      height: 360,
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: ZX.border, width: ZX.borderWidth),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
        boxShadow: const [BoxShadow(color: ZX.border, offset: Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            if (image.isNotEmpty)
              Positioned.fill(
                child: Image.network(
                  ZxApi.imageUrl(image),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                  loadingBuilder: (context, child, progress) =>
                      progress == null ? child : const Center(child: CircularProgressIndicator(color: Colors.white)),
                ),
              )
            else
              Positioned(
                top: 70,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 190,
                    height: 190,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), shape: BoxShape.circle),
                    child: Center(
                      child: Container(
                        width: 105,
                        height: 105,
                        decoration: const BoxDecoration(color: Color(0xFFFFE27A), shape: BoxShape.circle),
                      ),
                    ),
                  ),
                ),
              ),
            if (place.isNotEmpty)
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: ZX.ink.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.place, color: Colors.white, size: 15),
                      const SizedBox(width: 4),
                      Text(place, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            if (anon)
              Positioned(
                top: place.isNotEmpty ? 60 : 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: ZX.coral.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility_off, color: Colors.white, size: 15),
                      SizedBox(width: 4),
                      Text('Confession'.tr, style: TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            Positioned(
              top: 10,
              right: 12,
              child: GestureDetector(
                onTap: () => _postMenu(p),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: ZX.ink.withOpacity(0.6), shape: BoxShape.circle),
                  child: const Icon(Icons.more_horiz, color: Colors.white, size: 22),
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ZX.ink.withOpacity(0.78),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: anon ? null : () => _openProfile(author),
                          child: ZxAvatar(anon ? '?' : name, radius: 20, photo: avatar),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: anon ? null : () => _openProfile(author),
                            child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                              Text(
                                timeAgo((p['time'] ?? 0) as num),
                                style: const TextStyle(color: Color(0xFFFFD2C2), fontSize: 12),
                              ),
                            ],
                          ),
                          ),
                        ),
                        if (!mine && !anon)
                          GestureDetector(
                            onTap: () => _toggleFollow(p),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                              decoration: BoxDecoration(
                                color: following ? Colors.transparent : ZX.coral,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: ZX.coral, width: 1.8),
                              ),
                              child: Text(
                                following ? 'Following'.tr : 'Follow'.tr,
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (caption.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        caption,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      runSpacing: 8,
                      children: [
                        _chip(
                          liked ? Icons.favorite : Icons.favorite_border,
                          _compact(p['likes'] as num),
                          active: liked,
                          onTap: () => _toggleLike(p),
                        ),
                        _chip(
                          Icons.chat_bubble_outline,
                          _compact(p['comments'] as num),
                          onTap: () => _openComments(p),
                        ),
                        if (!mine)
                          _chip(
                            Icons.monetization_on_outlined,
                            'Gift'.tr,
                            onTap: () => ZxActions.tip(context, (p['id'] as num).toInt()),
                          ),
                        _chip(
                          p['saved'] == true ? Icons.bookmark : Icons.bookmark_border,
                          p['saved'] == true ? 'Saved'.tr : 'Save'.tr,
                          active: p['saved'] == true,
                          onTap: () => ZxActions.toggleSave(context, p, onChanged: () {
                            if (mounted) setState(() {});
                          }),
                        ),
                        _chip(
                          Icons.share_outlined,
                          'Share'.tr,
                          onTap: () => ZxActions.share(context, p),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final first = Session.name.isNotEmpty ? Session.name.split(' ').first : 'there';

    return Scaffold(
      backgroundColor: ZX.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: ZX.coral,
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx('Hey {name}'.tr, {'name': first}),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFFC25A00), fontSize: 15),
                        ),
                        const FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Zentrixa',
                            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w600, color: ZX.ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _circleBtn(Icons.search, _openSearch, 'Search'.tr),
                  const SizedBox(width: 8),
                  _circleBtn(Icons.sports_esports_outlined, _openRooms, 'Zentrixa Room'.tr),
                  const SizedBox(width: 8),
                  _circleBtn(Icons.auto_awesome, _openAi, 'Zentrixa AI'.tr),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<int>(
                    valueListenable: widget.unread,
                    builder: (context, count, _) => GestureDetector(
                      onTap: _openNotifications,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: ZX.border, width: ZX.borderWidth),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(Icons.notifications_none, color: ZX.ink, size: 24),
                            if (count > 0)
                              Positioned(
                                right: -3,
                                top: -3,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  constraints: const BoxConstraints(minWidth: 19, minHeight: 19),
                                  decoration: BoxDecoration(
                                    color: ZX.coral,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: ZX.border, width: 1.5),
                                  ),
                                  child: Text(
                                    count > 99 ? '99+' : '$count',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              StoriesBar(groups: _stories, onAdd: _addStory, onOpen: _openStories),
              SuggestionsBar(refreshSignal: widget.refreshSignal),
              const SizedBox(height: 8),
              SizedBox(
                height: 46,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _filterLabels.length,
                  itemBuilder: (context, i) {
                    final sel = _filter == i;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _filter = i;
                          _loading = true;
                        });
                        _load();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: sel ? ZX.coral : ZX.coralSoft,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: sel ? ZX.border : Colors.transparent,
                            width: ZX.borderWidth,
                          ),
                        ),
                        child: Text(
                          _filterLabels[i].tr,
                          style: TextStyle(
                            color: sel ? Colors.white : const Color(0xFFC25A00),
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator(color: ZX.coral)),
                )
              else if (_posts.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: ZX.cardDecoration(radius: 28),
                  child: Column(
                    children: [
                      const Icon(Icons.wb_sunny_outlined, size: 44, color: ZX.coral),
                      const SizedBox(height: 12),
                      Text(
                        _filter == 1
                            ? 'No posts from people you follow yet'.tr
                            : (_filter == 3 ? 'No confessions yet'.tr : 'No posts yet'.tr),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ZX.ink),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _filter == 3
                            ? 'Tap + and switch on "Anonymous" to share your thoughts'.tr
                            : 'Tap the yellow + button below to create the first post!'.tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: ZX.muted),
                      ),
                    ],
                  ),
                )
              else
                for (final p in _posts) _postCard(p),
            ],
          ),
        ),
      ),
    );
  }
}
