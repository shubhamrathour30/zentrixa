import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'i18n.dart';
import 'room_chess.dart';
import 'room_ludo.dart';
import 'room_movie.dart';
import 'zentrixa_theme.dart';
import 'zx_api.dart';

/// Ek Zentrixa Room: 2 dost. Server har 1 second mein poll hota hai (sirf badlav aane par poora data aata hai).
class RoomScreen extends StatefulWidget {
  final String code;
  const RoomScreen({super.key, required this.code});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  Map<String, dynamic>? _room;
  int _ver = 0;
  int _clockOffset = 0; // server ka waqt - apna waqt (ms)
  Timer? _timer;
  bool _busy = false;
  bool _closed = false;
  bool _fullscreen = false;
  String _lastGuest = '';
  final GlobalKey _movieKey = GlobalKey();
  final TextEditingController _chatCtl = TextEditingController();
  final ScrollController _chatScroll = ScrollController();
  List<Map<String, dynamic>> _friends = [];
  final Set<String> _invited = {};
  int _lastMsgCount = 0;

  int _serverNow() => DateTime.now().millisecondsSinceEpoch + _clockOffset;

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _chatCtl.dispose();
    _chatScroll.dispose();
    if (_fullscreen) _applyFullscreen(false);
    super.dispose();
  }

  Future<void> _poll() async {
    if (_busy || _closed) return;
    _busy = true;
    final res = await ZxApi.get('/api/rooms/state', query: {'code': widget.code, 'v': '$_ver'});
    _busy = false;
    if (!mounted || _closed) return;
    if (res.status == 404 || res.status == 403) {
      _roomEnded();
      return;
    }
    if (res.ok) _accept(res.map);
  }

  void _accept(Map<String, dynamic> m) {
    final now = m['now'];
    if (now is num) _clockOffset = now.toInt() - DateTime.now().millisecondsSinceEpoch;
    if (m['changed'] == false || !m.containsKey('code')) return;
    final guest = (m['guest'] ?? '').toString();
    final hadGuest = _lastGuest.isNotEmpty;
    final firstLoad = _room == null;
    setState(() {
      _room = m;
      _ver = ((m['ver'] ?? _ver) as num).toInt();
    });
    if (guest.isNotEmpty && !hadGuest && !firstLoad) {
      _snack(tx('{name} joined the room'.tr, {'name': (m['guestName'] ?? '').toString()}));
    }
    _lastGuest = guest;
    final msgs = m['msgs'];
    if (msgs is List && msgs.length != _lastMsgCount) {
      _lastMsgCount = msgs.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_chatScroll.hasClients) _chatScroll.jumpTo(0);
      });
    }
    if (guest.isEmpty && _friends.isEmpty) _loadFriends();
  }

  void _roomEnded() {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    if (_fullscreen) _applyFullscreen(false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('This room has ended'.tr)));
    Navigator.of(context).maybePop();
  }

  void _snack(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _loadFriends() async {
    final res = await ZxApi.get('/api/friends');
    if (!mounted || !res.ok) return;
    setState(() {
      _friends = res.list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    });
  }

  /// Server ko action bhejo; jawab mein naya room state aata hai.
  Future<void> _act(String path, Map<String, dynamic> body) async {
    final res = await ZxApi.post(path, {'code': widget.code, ...body});
    if (!mounted) return;
    if (res.ok) {
      _accept(res.map);
    } else if (res.error == 'ROOM_NOT_FOUND') {
      _roomEnded();
    } else if (res.error != 'NOT_YOUR_TURN') {
      _snack(_errText(res.error));
    }
  }

  String _errText(String? e) {
    switch (e) {
      case 'WAIT_FOR_FRIEND':
        return 'Wait for your friend to join first'.tr;
      case 'ILLEGAL_MOVE':
        return "That move isn't allowed".tr;
      case 'GAME_OVER':
        return 'The game is over'.tr;
      case 'ROLL_FIRST':
        return 'Roll the dice first'.tr;
      default:
        return ZxApi.friendly(e);
    }
  }

  Future<void> _sendChat() async {
    final t = _chatCtl.text.trim();
    if (t.isEmpty) return;
    _chatCtl.clear();
    await _act('/api/rooms/chat', {'text': t});
  }

  Future<void> _invite(String uid) async {
    final res = await ZxApi.post('/api/rooms/invite', {'code': widget.code, 'user': uid});
    if (!mounted) return;
    if (res.ok) {
      setState(() => _invited.add(uid));
      _snack('Invite sent'.tr);
    } else {
      _snack(_errText(res.error));
    }
  }

  Future<void> _leave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Leave this room?'.tr),
        content: Text('If the host leaves, the room closes for both of you.'.tr),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel'.tr, style: const TextStyle(color: ZX.muted))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Leave'.tr, style: const TextStyle(color: ZX.coral, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok != true) return;
    _closed = true;
    _timer?.cancel();
    await ZxApi.post('/api/rooms/leave', {'code': widget.code});
    if (mounted) Navigator.of(context).maybePop();
  }

  void _applyFullscreen(bool on) {
    if (on) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _toggleFullscreen() {
    final next = !_fullscreen;
    _applyFullscreen(next);
    setState(() => _fullscreen = next);
  }

  // ------------------------------------------------------------------ UI pieces
  String _title(Map<String, dynamic> room) {
    switch ((room['kind'] ?? '').toString()) {
      case 'ludo':
        return 'Ludo'.tr;
      case 'chess':
        return 'Chess'.tr;
      default:
        final m = room['movie'];
        return m is Map ? (m['title'] ?? 'Movie').toString() : 'Movie'.tr;
    }
  }

  Widget _msgBubble(Map<String, dynamic> m) {
    final from = (m['from'] ?? '').toString();
    final text = (m['text'] ?? '').toString();
    final name = (m['name'] ?? '').toString();
    if (text.startsWith('::sys:')) {
      final what = text.substring(6);
      final s = what == 'joined' ? '{name} joined'.tr : (what == 'left' ? '{name} left'.tr : what);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Center(child: Text(tx(s, {'name': name}), style: const TextStyle(color: ZX.muted, fontSize: 12))),
      );
    }
    final mine = from == Session.username;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: mine ? ZX.coral : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ZX.border, width: 1.5),
        ),
        child: Text(text, style: TextStyle(color: mine ? Colors.white : ZX.ink, fontSize: 14)),
      ),
    );
  }

  Widget _chat(Map<String, dynamic> room, {double? height}) {
    final raw = room['msgs'];
    final msgs = raw is List ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList() : <Map<String, dynamic>>[];
    final list = ListView.builder(
      controller: _chatScroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      itemCount: msgs.length,
      itemBuilder: (_, i) => _msgBubble(msgs[msgs.length - 1 - i]),
    );
    final input = Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatCtl,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendChat(),
              maxLength: 300,
              decoration: ZX.input('Say something...'.tr).copyWith(
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendChat,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: ZX.coral,
                shape: BoxShape.circle,
                border: Border.all(color: ZX.border, width: ZX.borderWidth),
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
    final body = Column(children: [Expanded(child: list), input]);
    return height == null ? body : SizedBox(height: height, child: body);
  }

  Widget _invitePanel(Map<String, dynamic> room) {
    final code = (room['code'] ?? widget.code).toString();
    final kind = (room['kind'] ?? '').toString();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: ZX.cardDecoration(color: ZX.coralSoft, radius: 22),
          child: Column(
            children: [
              Text(kind == 'movie' ? 'Invite a friend to watch with you'.tr : 'Invite a friend to play'.tr,
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ZX.ink)),
              const SizedBox(height: 10),
              Text(code, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: 3, color: ZX.ink)),
              const SizedBox(height: 4),
              Text('Your friend can join with this code from the Room screen'.tr,
                  textAlign: TextAlign.center, style: const TextStyle(color: ZX.muted, fontSize: 12)),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  _snack('Copied'.tr);
                },
                icon: const Icon(Icons.copy, size: 18),
                label: Text('Copy'.tr),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ZX.ink,
                  side: const BorderSide(color: ZX.border, width: ZX.borderWidth),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Or invite from people you follow'.tr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ZX.ink)),
        const SizedBox(height: 8),
        if (_friends.isEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('Follow people first to invite them here, or share the code'.tr, style: const TextStyle(color: ZX.muted)),
          ),
        for (final f in _friends)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: ZX.cardDecoration(radius: 18, shadow: false),
            child: Row(
              children: [
                ZxAvatar((f['name'] ?? '').toString(), radius: 20, photo: (f['avatar'] ?? '').toString()),
                const SizedBox(width: 12),
                Expanded(
                  child: Text((f['name'] ?? '').toString(),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, color: ZX.ink)),
                ),
                ElevatedButton(
                  onPressed: _invited.contains((f['uid'] ?? '').toString()) ? null : () => _invite((f['uid'] ?? '').toString()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ZX.coral,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: ZX.coralSoft,
                    disabledForegroundColor: ZX.muted,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: ZX.border, width: ZX.borderWidth),
                    ),
                  ),
                  child: Text(_invited.contains((f['uid'] ?? '').toString()) ? 'Invited'.tr : 'Invite'.tr),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _movie(Map<String, dynamic> room, {required bool fullscreen}) {
    return MovieBody(
      key: _movieKey,
      room: room,
      nowMs: _serverNow,
      fullscreen: fullscreen,
      onToggleFullscreen: _toggleFullscreen,
      onControl: (playing, pos) => _act('/api/rooms/play', {'playing': playing, 'pos': pos}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
    if (room == null) {
      return Scaffold(
        backgroundColor: ZX.bg,
        appBar: AppBar(backgroundColor: ZX.bg, elevation: 0, iconTheme: const IconThemeData(color: ZX.ink)),
        body: const Center(child: CircularProgressIndicator(color: ZX.coral)),
      );
    }
    final kind = (room['kind'] ?? '').toString();
    final guestEmpty = (room['guest'] ?? '').toString().isEmpty;

    if (kind == 'movie' && _fullscreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(child: _movie(room, fullscreen: true)),
            if (!guestEmpty && !_isYt(room))
              Positioned(left: 12, top: 12, width: 260, height: 150, child: _fullscreenChat(room)),
          ],
        ),
      );
    }

    Widget body;
    if (kind == 'movie') {
      body = Column(
        children: [
          _movie(room, fullscreen: false),
          Expanded(child: guestEmpty ? _invitePanel(room) : _chat(room)),
        ],
      );
    } else if (guestEmpty) {
      body = _invitePanel(room);
    } else {
      final Widget game = kind == 'ludo'
          ? LudoBody(
              room: room,
              onRoll: () => _act('/api/rooms/roll', {}),
              onMove: (t) => _act('/api/rooms/move', {'token': t}),
              onResign: () => _act('/api/rooms/resign', {}),
              onRematch: () => _act('/api/rooms/rematch', {}),
            )
          : ChessBody(
              room: room,
              onMove: (f, t) => _act('/api/rooms/chess', {'from': f, 'to': t}),
              onResign: () => _act('/api/rooms/resign', {}),
              onRematch: () => _act('/api/rooms/rematch', {}),
            );
      body = ListView(
        children: [
          game,
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Container(
              decoration: ZX.cardDecoration(color: ZX.card, radius: 18, shadow: false),
              child: _chat(room, height: 230),
            ),
          ),
          const SizedBox(height: 12),
        ],
      );
    }

    return Scaffold(
      backgroundColor: ZX.bg,
      appBar: AppBar(
        backgroundColor: ZX.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: ZX.ink),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_title(room),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ZX.ink)),
            Text(tx('Room {code}'.tr, {'code': (room['code'] ?? widget.code).toString()}),
                style: const TextStyle(fontSize: 12, color: ZX.muted)),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: ZX.ink),
            onSelected: (v) {
              if (v == 'copy') {
                Clipboard.setData(ClipboardData(text: (room['code'] ?? widget.code).toString()));
                _snack('Copied'.tr);
              } else if (v == 'leave') {
                _leave();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'copy', child: Text('Copy room code'.tr)),
              PopupMenuItem(value: 'leave', child: Text('Leave room'.tr)),
            ],
          ),
        ],
      ),
      body: body,
    );
  }

  bool _isYt(Map<String, dynamic> room) {
    final m = room['movie'];
    return m is Map && (m['yt'] ?? '').toString().isNotEmpty;
  }

  /// Full screen mein chat chhoti si transparent patti mein.
  Widget _fullscreenChat(Map<String, dynamic> room) {
    final raw = room['msgs'];
    final msgs = raw is List ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList() : <Map<String, dynamic>>[];
    final recent = msgs.where((m) => !(m['text'] ?? '').toString().startsWith('::sys:')).toList();
    final last = recent.length > 3 ? recent.sublist(recent.length - 3) : recent;
    return IgnorePointer(
      ignoring: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final m in last)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(12)),
              child: Text('${(m['name'] ?? '').toString()}: ${(m['text'] ?? '').toString()}',
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
