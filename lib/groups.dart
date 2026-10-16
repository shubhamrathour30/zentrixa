import 'dart:async';

import 'package:flutter/material.dart';

import 'zentrixa_theme.dart';
import 'zx_api.dart';
import 'i18n.dart';

/// Group chat: banao, message bhejo, member add/remove, leave.

/// System message ("::sys:created", "::sys:added:<uid>", ...) ko text mein badalta hai.
/// `names` = username -> display name (agar maloom ho).
String groupSysText(String raw, String actorUid, String actorName, [Map<String, String> names = const {}]) {
  final body = raw.startsWith('::sys:') ? raw.substring(6) : raw;
  final actor = actorUid == Session.username ? 'You'.tr : (actorName.isEmpty ? '@$actorUid' : actorName);
  String target(String uid) => uid == Session.username ? 'you'.tr : (names[uid] ?? '@$uid');
  if (body == 'created') return tx('{actor} created the group'.tr, {'actor': actor});
  if (body == 'left') return tx('{actor} left the group'.tr, {'actor': actor});
  if (body.startsWith('added:')) return tx('{actor} added {target}'.tr, {'actor': actor, 'target': target(body.substring(6))});
  if (body.startsWith('removed:')) return tx('{actor} removed {target}'.tr, {'actor': actor, 'target': target(body.substring(8))});
  return body;
}

/// Group ka round icon.
class GroupAvatar extends StatelessWidget {
  final String name;
  final double radius;
  const GroupAvatar(this.name, {super.key, this.radius = 24});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: ZX.avatarColor(name),
      child: Icon(Icons.groups, color: ZX.ink, size: radius * 1.05),
    );
  }
}

// ==================================================================== create

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _name = TextEditingController();
  List<Map<String, dynamic>> _friends = [];
  final Set<String> _selected = {};
  bool _loading = true;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _load() async {
    final res = await ZxApi.get('/api/friends');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.ok) _friends = res.list.map((e) => Map<String, dynamic>.from(e)).toList();
    });
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _snack('Give your group a name'.tr);
      return;
    }
    if (_selected.isEmpty) {
      _snack('Select at least one person'.tr);
      return;
    }
    setState(() => _creating = true);
    final res = await ZxApi.post('/api/groups/create', {
      'name': name,
      'members': _selected.toList(),
    });
    if (!mounted) return;
    setState(() => _creating = false);
    if (res.ok) {
      Navigator.pop(context, Map<String, dynamic>.from(res.map));
    } else {
      _snack(res.message);
    }
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
        title: Text('New group'.tr,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: ZX.ink)),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          children: [
            TextField(
              controller: _name,
              maxLength: 60,
              style: const TextStyle(color: ZX.ink),
              decoration: ZX.input('Group name'.tr, icon: Icons.groups_outlined).copyWith(counterText: ''),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(tx('Add people ({n} selected)'.tr, {'n': _selected.length}),
                  style: const TextStyle(fontWeight: FontWeight.w700, color: ZX.ink)),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: ZX.coral))
                  : _friends.isEmpty
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Follow some people first. Search them in the Chats tab and tap Follow.'.tr,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: ZX.muted),
                            ),
                          ),
                        )
                      : ListView(
                          children: [
                            for (final f in _friends)
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: ZX.cardDecoration(radius: 18, shadow: false),
                                child: CheckboxListTile(
                                  value: _selected.contains(f['uid'].toString()),
                                  activeColor: ZX.coral,
                                  onChanged: (v) => setState(() {
                                    final id = f['uid'].toString();
                                    if (v == true) {
                                      _selected.add(id);
                                    } else {
                                      _selected.remove(id);
                                    }
                                  }),
                                  secondary: ZxAvatar((f['name'] ?? f['uid']).toString(),
                                      radius: 20, photo: (f['avatar'] ?? '').toString()),
                                  title: Text((f['name'] ?? f['uid']).toString(),
                                      style: const TextStyle(fontWeight: FontWeight.w700, color: ZX.ink)),
                                  subtitle: Text('@${f['uid']}',
                                      style: const TextStyle(color: ZX.muted, fontSize: 12)),
                                ),
                              ),
                          ],
                        ),
            ),
            const SizedBox(height: 8),
            ZxButton(_creating ? 'Creating...'.tr : 'Create group'.tr,
                onPressed: _creating ? null : _create),
          ],
        ),
      ),
    );
  }
}

// ==================================================================== room

class GroupRoomScreen extends StatefulWidget {
  final int groupId;
  final String groupName;
  const GroupRoomScreen({super.key, required this.groupId, required this.groupName});

  @override
  State<GroupRoomScreen> createState() => _GroupRoomScreenState();
}

class _GroupRoomScreenState extends State<GroupRoomScreen> {
  final TextEditingController _controller = TextEditingController();
  List<dynamic> _messages = [];
  Map<String, String> _names = {};
  String _title = '';
  int _memberCount = 0;
  bool _loading = true;
  bool _sending = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _title = widget.groupName;
    _fetch();
    _loadMembers();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _fetch());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    final res = await ZxApi.get('/api/groups/members', query: {'groupId': '${widget.groupId}'});
    if (!mounted || !res.ok) return;
    final list = res.map['members'];
    setState(() {
      _title = (res.map['name'] ?? _title).toString();
      if (list is List) {
        _memberCount = list.length;
        _names = {for (final m in list) m['uid'].toString(): (m['name'] ?? m['uid']).toString()};
      }
    });
  }

  Future<void> _fetch() async {
    final res = await ZxApi.get('/api/groups/messages', query: {'groupId': '${widget.groupId}'});
    if (!mounted) return;
    if (res.status == 404) {
      // group nahi raha ya aap member nahi rahe
      _timer?.cancel();
      Navigator.pop(context, true);
      return;
    }
    if (!res.ok) return;
    final data = res.list;
    if (data.length != _messages.length || _loading) {
      setState(() {
        final grew = data.length > _messages.length;
        _messages = data;
        _loading = false;
        if (grew) _loadMembersSoon();
      });
    }
  }

  void _loadMembersSoon() {
    Future.microtask(_loadMembers);
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final res = await ZxApi.post('/api/groups/send', {'groupId': widget.groupId, 'message': text});
    if (!mounted) return;
    setState(() => _sending = false);
    if (res.ok) {
      _controller.clear();
      _fetch();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
    }
  }

  String _clock(num epoch) {
    final d = DateTime.fromMillisecondsSinceEpoch(epoch.toInt() * 1000);
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  Future<void> _openInfo() async {
    final left = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => GroupInfoScreen(groupId: widget.groupId)),
    );
    if (!mounted) return;
    if (left == true) {
      Navigator.pop(context, true);
    } else {
      _loadMembers();
      _fetch();
    }
  }

  Widget _roundButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: ZX.border, width: ZX.borderWidth),
        ),
        child: Icon(icon, color: ZX.ink, size: 20),
      ),
    );
  }

  Widget _bubble(Map<String, dynamic> m) {
    final from = (m['senderId'] ?? '').toString();
    final text = (m['message'] ?? '').toString();
    if (text.startsWith('::sys:')) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(color: ZX.coralSoft, borderRadius: BorderRadius.circular(14)),
          child: Text(groupSysText(text, from, (m['name'] ?? '').toString(), _names),
              textAlign: TextAlign.center, style: const TextStyle(color: ZX.muted, fontSize: 12)),
        ),
      );
    }
    final isMe = from == Session.username;
    final name = (m['name'] ?? from).toString();
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            ZxAvatar(name, radius: 14, photo: (m['avatar'] ?? '').toString()),
            const SizedBox(width: 6),
          ],
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isMe ? ZX.coral : Colors.white,
              border: Border.all(color: ZX.border, width: ZX.borderWidth),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMe ? 18 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 18),
              ),
            ),
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isMe)
                  Text(name,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFC23A14))),
                Text(text, style: TextStyle(fontSize: 15, color: isMe ? Colors.white : ZX.ink)),
                const SizedBox(height: 3),
                Text(_clock((m['time'] ?? 0) as num),
                    style: TextStyle(
                        fontSize: 10, color: isMe ? const Color(0xFFFFE1D8) : ZX.muted)),
              ],
            ),
          ),
        ],
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
        automaticallyImplyLeading: false,
        titleSpacing: 12,
        title: Row(
          children: [
            _roundButton(Icons.arrow_back, () => Navigator.pop(context)),
            const SizedBox(width: 10),
            GestureDetector(onTap: _openInfo, child: GroupAvatar(_title, radius: 19)),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: _openInfo,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 17, color: ZX.ink, fontWeight: FontWeight.w700)),
                    Text(_memberCount > 0 ? tx('{n} members'.tr, {'n': _memberCount}) : 'Group'.tr,
                        style: const TextStyle(fontSize: 12, color: ZX.muted)),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.info_outline, color: ZX.ink),
              onPressed: _openInfo,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: ZX.coral))
                : _messages.isEmpty
                    ? Center(
                        child: Text('No messages yet. Say hello! 👋'.tr, style: TextStyle(color: ZX.muted)),
                      )
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(14),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) => _bubble(
                            Map<String, dynamic>.from(_messages[_messages.length - 1 - index])),
                      ),
          ),
          SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              padding: const EdgeInsets.only(left: 18, right: 6, top: 6, bottom: 6),
              decoration: ZX.cardDecoration(radius: 32),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _send(),
                      textInputAction: TextInputAction.send,
                      style: const TextStyle(color: ZX.ink),
                      decoration: InputDecoration(
                        hintText: 'Message'.tr,
                        hintStyle: const TextStyle(color: ZX.muted),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(color: ZX.coral, shape: BoxShape.circle),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _sending ? null : _send,
                    ),
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

// ==================================================================== info

class GroupInfoScreen extends StatefulWidget {
  final int groupId;
  const GroupInfoScreen({super.key, required this.groupId});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  String _name = '';
  String _creator = '';
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;

  bool get _admin => _creator == Session.username;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _load() async {
    final res = await ZxApi.get('/api/groups/members', query: {'groupId': '${widget.groupId}'});
    if (!mounted) return;
    if (res.status == 404) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _loading = false;
      if (res.ok) {
        _name = (res.map['name'] ?? '').toString();
        _creator = (res.map['creator'] ?? '').toString();
        final list = res.map['members'];
        _members = list is List ? list.map((e) => Map<String, dynamic>.from(e)).toList() : [];
      }
    });
  }

  Future<void> _addMember() async {
    final fr = await ZxApi.get('/api/friends');
    if (!mounted || !fr.ok) return;
    final inGroup = _members.map((m) => m['uid'].toString()).toSet();
    final candidates = fr.list
        .map((e) => Map<String, dynamic>.from(e))
        .where((f) => !inGroup.contains(f['uid'].toString()))
        .toList();
    if (candidates.isEmpty) {
      _snack('Everyone you follow is already in this group'.tr);
      return;
    }
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Add member'.tr),
        children: [
          for (final f in candidates)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, f['uid'].toString()),
              child: Row(
                children: [
                  ZxAvatar((f['name'] ?? f['uid']).toString(),
                      radius: 18, photo: (f['avatar'] ?? '').toString()),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text((f['name'] ?? f['uid']).toString(),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: ZX.ink, fontSize: 16)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    if (picked == null) return;
    final res = await ZxApi.post('/api/groups/add', {'groupId': widget.groupId, 'username': picked});
    if (!mounted) return;
    if (res.ok) {
      _load();
    } else {
      _snack(res.message);
    }
  }

  Future<void> _remove(Map<String, dynamic> m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tx('Remove {name}?'.tr, {'name': m['name']})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'.tr, style: TextStyle(color: ZX.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove'.tr, style: TextStyle(color: ZX.coral, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final res = await ZxApi.post(
        '/api/groups/remove', {'groupId': widget.groupId, 'username': m['uid']});
    if (!mounted) return;
    if (res.ok) {
      _load();
    } else {
      _snack(res.message);
    }
  }

  Future<void> _leave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Leave this group?'.tr),
        content: Text('You will stop receiving its messages.'.tr,
            style: TextStyle(color: ZX.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'.tr, style: TextStyle(color: ZX.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Leave'.tr, style: TextStyle(color: ZX.coral, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final res = await ZxApi.post('/api/groups/leave', {'groupId': widget.groupId});
    if (!mounted) return;
    if (res.ok) {
      Navigator.pop(context, true);
    } else {
      _snack(res.message);
    }
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
        title: Text('Group info'.tr,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: ZX.ink)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: ZX.coral))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(child: GroupAvatar(_name, radius: 44)),
                const SizedBox(height: 10),
                Center(
                  child: Text(_name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: ZX.ink)),
                ),
                Center(
                  child: Text(tx('{n} members'.tr, {'n': _members.length}),
                      style: const TextStyle(color: ZX.muted)),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _addMember,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: ZX.cardDecoration(color: ZX.coralSoft, radius: 20, shadow: false),
                    child: Row(
                      children: [
                        Icon(Icons.person_add_alt_1, color: ZX.coral),
                        SizedBox(width: 12),
                        Text('Add member'.tr,
                            style: TextStyle(color: ZX.ink, fontWeight: FontWeight.w700, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
                for (final m in _members)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: ZX.cardDecoration(radius: 18, shadow: false),
                    child: Row(
                      children: [
                        ZxAvatar((m['name'] ?? m['uid']).toString(),
                            radius: 20, photo: (m['avatar'] ?? '').toString()),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m['uid'] == Session.username
                                    ? tx('{name} (You)'.tr, {'name': m['name']})
                                    : (m['name'] ?? m['uid']).toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700, color: ZX.ink),
                              ),
                              Text('@${m['uid']}',
                                  style: const TextStyle(color: ZX.muted, fontSize: 12)),
                            ],
                          ),
                        ),
                        if (m['uid'] == _creator)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                                color: ZX.sun, borderRadius: BorderRadius.circular(12)),
                            child: Text('Admin'.tr,
                                style: TextStyle(
                                    color: ZX.ink, fontSize: 12, fontWeight: FontWeight.w700)),
                          )
                        else if (_admin)
                          IconButton(
                            icon: const Icon(Icons.close, color: ZX.muted),
                            onPressed: () => _remove(m),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                ZxButton('Leave group'.tr, outlined: true, onPressed: _leave),
              ],
            ),
    );
  }
}
