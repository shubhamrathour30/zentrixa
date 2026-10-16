import 'package:flutter/material.dart';

import 'i18n.dart';
import 'profile_screen.dart';
import 'zentrixa_theme.dart';
import 'zx_api.dart';

/// Kisi ki Followers / Following list (Instagram jaisi). `initialTab`: 0 = Followers, 1 = Following.
/// Jisne ise follow kiya wo Followers mein, jise ye follow karta hai wo Following mein.
class FollowListScreen extends StatefulWidget {
  final String username;
  final String name;
  final int initialTab;
  const FollowListScreen({super.key, required this.username, required this.name, this.initialTab = 0});

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<Map<String, dynamic>> _followers = [];
  List<Map<String, dynamic>> _following = [];
  bool _loading = true;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this, initialIndex: widget.initialTab.clamp(0, 1));
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _rows(ApiResult r) =>
      r.list.map((e) => Map<String, dynamic>.from(e as Map)).toList();

  Future<void> _load() async {
    final results = await Future.wait([
      ZxApi.get('/api/follow_list', query: {'username': widget.username, 'type': 'followers'}),
      ZxApi.get('/api/follow_list', query: {'username': widget.username, 'type': 'following'}),
    ]);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (results[0].ok) _followers = _rows(results[0]);
      if (results[1].ok) _following = _rows(results[1]);
    });
  }

  /// Ek hi user dono list mein ho to dono jagah button ek saath badle.
  void _setFollowing(String uid, bool value) {
    for (final l in [_followers, _following]) {
      for (final u in l) {
        if (u['uid'] == uid) u['isFollowing'] = value;
      }
    }
  }

  Future<void> _toggle(Map<String, dynamic> u) async {
    final uid = u['uid'].toString();
    if (_busy.contains(uid)) return;
    setState(() => _busy.add(uid));
    final r = await ZxApi.post('/api/follow', {'username': uid});
    if (!mounted) return;
    setState(() {
      _busy.remove(uid);
      if (r.ok) _setFollowing(uid, r.map['following'] == true);
    });
    if (!r.ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message)));
    }
  }

  Widget _button(Map<String, dynamic> u) {
    final iFollow = u['isFollowing'] == true;
    final followsMe = u['followsMe'] == true;
    final busy = _busy.contains(u['uid'].toString());
    final label = iFollow ? 'Following'.tr : (followsMe ? 'Follow back'.tr : 'Follow'.tr);
    return GestureDetector(
      onTap: busy ? null : () => _toggle(u),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: iFollow ? Colors.white : ZX.coral,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ZX.border, width: 1.8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: iFollow ? ZX.ink : Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _row(Map<String, dynamic> u) {
    final uid = u['uid'].toString();
    final name = (u['name'] ?? uid).toString();
    return GestureDetector(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(username: uid)));
        if (mounted) _load();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: ZX.cardDecoration(radius: 20, shadow: false),
        child: Row(
          children: [
            ZxAvatar(name, radius: 22, photo: (u['avatar'] ?? '').toString()),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: ZX.ink)),
                  Text('@$uid',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: ZX.muted)),
                ],
              ),
            ),
            if (u['isMe'] != true) _button(u),
          ],
        ),
      ),
    );
  }

  Widget _list(List<Map<String, dynamic>> items, String emptyText) {
    return RefreshIndicator(
      color: ZX.coral,
      onRefresh: _load,
      child: items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 80),
                const Icon(Icons.people_outline, size: 52, color: ZX.coral),
                const SizedBox(height: 10),
                Center(child: Text(emptyText, style: const TextStyle(color: ZX.muted, fontSize: 16))),
              ],
            )
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [for (final u in items) _row(u)],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.username == Session.username;
    return Scaffold(
      backgroundColor: ZX.bg,
      appBar: AppBar(
        backgroundColor: ZX.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: ZX.ink),
        title: Text(isMe ? 'My network'.tr : widget.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ZX.ink)),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: ZX.coral,
          labelColor: ZX.coral,
          unselectedLabelColor: ZX.muted,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800),
          tabs: [
            Tab(text: tx('{n} Followers'.tr, {'n': _followers.length})),
            Tab(text: tx('{n} Following'.tr, {'n': _following.length})),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: ZX.coral))
          : TabBarView(
              controller: _tabs,
              children: [
                _list(_followers, isMe ? 'No followers yet'.tr : 'No followers'.tr),
                _list(_following, isMe ? "You aren't following anyone yet".tr : 'Not following anyone'.tr),
              ],
            ),
    );
  }
}
