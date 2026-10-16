import 'package:flutter/material.dart';

import 'profile_screen.dart';
import 'rooms_hub_screen.dart';
import 'zentrixa_theme.dart';
import 'zx_api.dart';
import 'i18n.dart';

/// Notifications (Instagram jaisi): like, comment, new follower (Follow back button ke saath), coins, group, room invite.
/// Screen khulte hi sab "read" mark ho jaate hain.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  final Set<String> _followBusy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await ZxApi.get('/api/notifications');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.ok) {
        final raw = res.map['items'];
        _items = raw is List ? raw.map((e) => Map<String, dynamic>.from(e)).toList() : [];
      }
    });
    if (_items.any((n) => n['read'] != true)) {
      ZxApi.post('/api/notifications/read', {});
    }
  }

  /// Instagram jaisa "Follow back" / "Following" button. Ek hi user ki saari notifications mein ek saath badalta hai.
  Future<void> _toggleFollow(String uid) async {
    if (_followBusy.contains(uid)) return;
    setState(() => _followBusy.add(uid));
    final r = await ZxApi.post('/api/follow', {'username': uid});
    if (!mounted) return;
    setState(() {
      _followBusy.remove(uid);
      if (r.ok) {
        final now = r.map['following'] == true;
        for (final n in _items) {
          if (n['from'] == uid) n['following'] = now;
        }
      }
    });
    if (!r.ok) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message)));
  }

  Widget _followButton(Map<String, dynamic> n) {
    final uid = (n['from'] ?? '').toString();
    final following = n['following'] == true;
    return GestureDetector(
      onTap: _followBusy.contains(uid) ? null : () => _toggleFollow(uid),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: following ? Colors.white : ZX.coral,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ZX.border, width: 1.8),
        ),
        child: Text(
          following ? 'Following'.tr : 'Follow back'.tr,
          style: TextStyle(color: following ? ZX.ink : Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ),
    );
  }

  IconData _icon(String type) {
    switch (type) {
      case 'like':
        return Icons.favorite;
      case 'comment':
        return Icons.chat_bubble;
      case 'follow':
        return Icons.person_add;
      case 'tip':
        return Icons.monetization_on;
      case 'referral':
        return Icons.card_giftcard;
      case 'group_add':
        return Icons.groups;
      case 'room_invite':
        return Icons.sports_esports;
      default:
        return Icons.notifications;
    }
  }

  // Server English text bhejta hai; yahan type + naam se apni language mein text banate hain.
  String _text(Map<String, dynamic> n) {
    final type = (n['type'] ?? '').toString();
    final raw = (n['text'] ?? '').toString();
    final name = (n['name'] ?? '').toString();
    if (name.isEmpty) return raw;
    switch (type) {
      case 'like':
        return tx('{name} liked your post'.tr, {'name': name});
      case 'comment':
        final i = raw.indexOf(': ');
        return tx('{name} commented: {text}'.tr, {'name': name, 'text': i >= 0 ? raw.substring(i + 2) : ''});
      case 'follow':
        return tx('{name} started following you'.tr, {'name': name});
      case 'tip':
        final m = RegExp(r'\d+').firstMatch(raw);
        return m == null ? raw : tx('{name} gifted you {n} coins'.tr, {'name': name, 'n': m.group(0)});
      case 'referral':
        final m = RegExp(r'\+(\d+)').firstMatch(raw);
        return m == null ? raw : tx('{name} joined with your invite code! +{n} coins'.tr, {'name': name, 'n': m.group(1)});
      case 'group_add':
        final a = raw.indexOf('"');
        final b = raw.lastIndexOf('"');
        final g = (a >= 0 && b > a) ? raw.substring(a + 1, b) : '';
        return tx('{name} added you to the group "{group}"'.tr, {'name': name, 'group': g});
      case 'room_invite':
        final m = RegExp(r'ZX-\d{4}').firstMatch(raw);
        return m == null ? raw : tx('{name} invited you to a Zentrixa Room: {code}'.tr, {'name': name, 'code': m.group(0)});
      default:
        return raw;
    }
  }

  Widget _tile(Map<String, dynamic> n) {
    final unread = n['read'] != true;
    final from = (n['from'] ?? '').toString();
    final name = (n['name'] ?? '').toString();
    return GestureDetector(
      onTap: (n['type'] ?? '').toString() == 'room_invite'
          ? () {
              final m = RegExp(r'ZX-\d{4}').firstMatch((n['text'] ?? '').toString());
              if (m != null) joinRoomWithCode(context, m.group(0)!);
            }
          : from.isEmpty
          ? null
          : () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProfileScreen(username: from)),
              ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: ZX.cardDecoration(
          color: unread ? ZX.coralSoft : Colors.white,
          radius: 20,
          shadow: false,
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ZxAvatar(name.isEmpty ? 'Z' : name, radius: 22, photo: (n['avatar'] ?? '').toString()),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: ZX.coral,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Icon(_icon((n['type'] ?? '').toString()), size: 11, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _text(n),
                    style: TextStyle(
                      color: ZX.ink,
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(timeAgo((n['time'] ?? 0) as num),
                      style: const TextStyle(color: ZX.muted, fontSize: 12)),
                ],
              ),
            ),
            if ((n['type'] ?? '').toString() == 'follow' && from.isNotEmpty && from != Session.username) ...[
              const SizedBox(width: 8),
              _followButton(n),
            ],
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
        title: Text('Notifications'.tr,
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
                        Icon(Icons.notifications_none, size: 56, color: ZX.coral),
                        SizedBox(height: 12),
                        Center(
                          child: Text('No notifications yet'.tr,
                              style: TextStyle(color: ZX.muted, fontSize: 16)),
                        ),
                      ],
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [for (final n in _items) _tile(n)],
                    ),
            ),
    );
  }
}
