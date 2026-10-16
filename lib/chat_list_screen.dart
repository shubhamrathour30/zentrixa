import 'dart:async';

import 'package:flutter/material.dart';

import 'chat_room_screen.dart';
import 'groups.dart';
import 'zentrixa_theme.dart';
import 'zx_api.dart';
import 'i18n.dart';

/// Chats tab: jinhe aap follow karte ho aur jo aapko follow karte hain, unki chats (server /api/chat_summary se).
/// Naye log dhoondh kar Follow karne ke liye person+ icon.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<Map<String, dynamic>> _chats = [];
  List<Map<String, dynamic>> _groups = [];
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!Session.loggedIn) return;
    final results = await Future.wait([
      ZxApi.get('/api/chat_summary'),
      ZxApi.get('/api/groups'),
    ]);
    if (!mounted) return;
    setState(() {
      if (results[0].ok) {
        _chats = results[0].list.map((e) => Map<String, dynamic>.from(e)).toList();
        _chats.sort((a, b) {
          final t = ((b['time'] ?? 0) as num).compareTo((a['time'] ?? 0) as num);
          return t != 0 ? t : (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString());
        });
      }
      if (results[1].ok) {
        _groups = results[1].list.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      _loading = false;
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _openChat(String uid, String name, [String avatar = '']) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatRoomScreen(
          contactName: name,
          receiverId: uid,
          currentUserId: Session.username,
          avatar: avatar,
        ),
      ),
    ).then((_) => _refresh(silent: true));
  }

  void _openGroup(int id, String name) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => GroupRoomScreen(groupId: id, groupName: name)),
    ).then((_) => _refresh(silent: true));
  }

  Future<void> _newGroup() async {
    final g = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
    );
    _refresh(silent: true);
    if (g != null && mounted) {
      _openGroup((g['id'] as num).toInt(), (g['name'] ?? '').toString());
    }
  }

  // ---------------------------------------------------------- UI helpers

  Widget _roundIconButton(IconData icon, VoidCallback onTap, {int badge = 0}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        margin: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: ZX.border, width: ZX.borderWidth),
        ),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Icon(icon, color: ZX.ink, size: 21),
            if (badge > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  decoration: BoxDecoration(
                    color: ZX.coral,
                    shape: BoxShape.circle,
                    border: Border.all(color: ZX.border, width: 1.5),
                  ),
                  child: Text(
                    '$badge',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _smallButton(String label, VoidCallback? onTap, {bool outlined = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: onTap == null
              ? ZX.coralSoft
              : (outlined ? Colors.white : ZX.coral),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ZX.border, width: 1.8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: onTap == null
                ? ZX.muted
                : (outlined ? ZX.coral : Colors.white),
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _closeButton(BuildContext context) => TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(
          'Close'.tr,
          style: TextStyle(color: ZX.coral, fontWeight: FontWeight.w700),
        ),
      );

  Widget _personRow(String name, String uid, Widget trailing, {String photo = ''}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: ZX.cardDecoration(radius: 20, shadow: false),
      child: Row(
        children: [
          ZxAvatar(name, radius: 20, photo: photo),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: ZX.ink),
                ),
                Text(
                  '@$uid',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: ZX.muted),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  // ---------------------------------------------------------- dialogs

  void _showSearchDialog() {
    final controller = TextEditingController();
    List<Map<String, dynamic>> results = [];
    bool searching = false;
    bool searched = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModal) {
          Future<void> search() async {
            final q = controller.text.trim();
            if (q.isEmpty) return;
            setModal(() => searching = true);
            final res = await ZxApi.get('/api/search_users', query: {'query': q});
            setModal(() {
              searching = false;
              searched = true;
              results = res.list.map((e) => Map<String, dynamic>.from(e)).toList();
            });
          }

          Widget action(Map<String, dynamic> u) {
            final uid = u['uid'].toString();
            final name = u['name'].toString();
            final iFollow = u['relation'] == 'following';
            final followsMe = u['followsMe'] == true;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _smallButton(
                  iFollow ? 'Following'.tr : (followsMe ? 'Follow back'.tr : 'Follow'.tr),
                  () async {
                    final r = await ZxApi.post('/api/follow', {'username': uid});
                    if (r.ok) {
                      setModal(() => u['relation'] = r.map['following'] == true ? 'following' : 'none');
                      _refresh(silent: true);
                    } else {
                      _snack(r.message);
                    }
                  },
                  outlined: iFollow,
                ),
                if (iFollow || followsMe) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _openChat(uid, name, (u['avatar'] ?? '').toString());
                    },
                    child: const Icon(Icons.chat_bubble_outline, color: ZX.coral, size: 22),
                  ),
                ],
              ],
            );
          }

          return AlertDialog(
            title: Text('Find people'.tr),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    onSubmitted: (_) => search(),
                    style: const TextStyle(color: ZX.ink),
                    decoration: ZX.input(
                      'Name or username'.tr,
                      icon: Icons.search,
                      suffix: IconButton(
                        icon: const Icon(Icons.arrow_forward, color: ZX.coral),
                        onPressed: search,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (searching)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(color: ZX.coral),
                    )
                  else if (searched && results.isEmpty)
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No users found'.tr, style: TextStyle(color: ZX.muted)),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 260),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final u in results)
                            _personRow(u['name'].toString(), u['uid'].toString(), action(u),
                                photo: (u['avatar'] ?? '').toString()),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            actions: [_closeButton(context)],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final first = Session.name.isNotEmpty ? Session.name.split(' ').first : 'there';

    return Scaffold(
      backgroundColor: ZX.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: ZX.coral,
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
                        Text(
                          'Your chats'.tr,
                          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: ZX.ink),
                        ),
                      ],
                    ),
                  ),
                  _roundIconButton(Icons.group_add_outlined, _newGroup),
                  _roundIconButton(Icons.person_add_alt_1_outlined, _showSearchDialog),
                ],
              ),
              const SizedBox(height: 18),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator(color: ZX.coral)),
                )
              else if (_chats.isEmpty && _groups.isEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 24),
                  padding: const EdgeInsets.all(24),
                  decoration: ZX.cardDecoration(radius: 28),
                  child: Column(
                    children: [
                      const Icon(Icons.forum_outlined, size: 44, color: ZX.coral),
                      const SizedBox(height: 12),
                      Text(
                        'No chats yet'.tr,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ZX.ink),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Use the person+ icon above to find people and follow them. You can chat with people you follow and people who follow you.'.tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: ZX.muted),
                      ),
                      const SizedBox(height: 16),
                      ZxButton('Find people'.tr, onPressed: _showSearchDialog),
                    ],
                  ),
                )
              else ...[
                for (final g in _groups) _groupTile(g),
                for (final c in _chats) _chatTile(c),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _groupTile(Map<String, dynamic> g) {
    final id = (g['id'] as num).toInt();
    final name = (g['name'] ?? '').toString();
    final raw = (g['lastMessage'] ?? '').toString();
    final from = (g['lastFrom'] ?? '').toString();
    final fromName = (g['lastFromName'] ?? '').toString();
    final time = (g['time'] ?? 0) as num;
    String last;
    if (raw.startsWith('::sys:')) {
      last = groupSysText(raw, from, fromName);
    } else if (raw.isEmpty) {
      last = '';
    } else {
      last = from == Session.username ? tx('You: {text}'.tr, {'text': raw}) : '$fromName: $raw';
    }
    final members = ((g['members'] ?? 0) as num).toInt();

    return GestureDetector(
      onTap: () => _openGroup(id, name),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: ZX.cardDecoration(color: ZX.coralSoft, radius: 26),
        child: Row(
          children: [
            GroupAvatar(name, radius: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: ZX.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    last.isEmpty ? tx('{n} members'.tr, {'n': members}) : last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFC23A14),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.groups, color: ZX.muted, size: 20),
            if (time > 0) ...[
              const SizedBox(width: 6),
              Text(timeAgo(time), style: const TextStyle(color: ZX.muted, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chatTile(Map<String, dynamic> c) {
    final uid = c['peerId'].toString();
    final name = (c['name'] ?? uid).toString();
    final last = (c['lastMessage'] ?? '').toString();
    final time = (c['time'] ?? 0) as num;
    final hasMsg = last.isNotEmpty;
    final unread = ((c['unread'] ?? 0) as num).toInt();

    return GestureDetector(
      onTap: () => _openChat(uid, name, (c['avatar'] ?? '').toString()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: ZX.cardDecoration(color: hasMsg ? ZX.coralSoft : Colors.white, radius: 26),
        child: Row(
          children: [
            ZxAvatar(name, radius: 26, photo: (c['avatar'] ?? '').toString()),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: ZX.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasMsg ? last : 'Tap to chat'.tr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hasMsg ? const Color(0xFFC23A14) : ZX.muted,
                      fontWeight: unread > 0 ? FontWeight.w800 : (hasMsg ? FontWeight.w600 : FontWeight.normal),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (hasMsg)
                  Text(timeAgo(time), style: const TextStyle(color: ZX.muted, fontSize: 12)),
                if (unread > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ZX.coral,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: ZX.border, width: 1.5),
                    ),
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
