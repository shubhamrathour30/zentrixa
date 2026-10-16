import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'i18n.dart';
import 'room_screen.dart';
import 'zentrixa_theme.dart';
import 'zx_api.dart';

/// Code se kisi room mein jao (notification ya "Join" button se). Chal gaya to room khulta hai.
Future<void> joinRoomWithCode(BuildContext context, String code) async {
  final nav = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final res = await ZxApi.post('/api/rooms/join', {'code': code});
  if (!res.ok) {
    String msg;
    switch (res.error) {
      case 'ROOM_NOT_FOUND':
        msg = "No room with this code (it may have ended)".tr;
        break;
      case 'ROOM_FULL':
        msg = 'This room already has two people'.tr;
        break;
      default:
        msg = res.message;
    }
    messenger.showSnackBar(SnackBar(content: Text(msg)));
    return;
  }
  final real = (res.map['code'] ?? code).toString();
  nav.push(MaterialPageRoute(builder: (_) => RoomScreen(code: real)));
}

/// Zentrixa Room ka dwaar: movie ya game chuno, room banao, ya code se judo.
class RoomsHubScreen extends StatefulWidget {
  const RoomsHubScreen({super.key});

  @override
  State<RoomsHubScreen> createState() => _RoomsHubScreenState();
}

class _RoomsHubScreenState extends State<RoomsHubScreen> {
  int _tab = 0; // 0 = movie, 1 = game
  List<Map<String, dynamic>> _movies = [];
  List<Map<String, dynamic>> _mine = [];
  bool _loading = true;
  bool _creating = false;
  final TextEditingController _codeCtl = TextEditingController();

  static const List<List<Color>> _posterColors = [
    [Color(0xFF5B2A4A), Color(0xFF1F1A17)],
    [Color(0xFF2F5D62), Color(0xFF1F1A17)],
    [Color(0xFF8A3B12), Color(0xFF1F1A17)],
    [Color(0xFF3A3F6B), Color(0xFF1F1A17)],
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _codeCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final a = await ZxApi.get('/api/rooms/movies');
    final b = await ZxApi.get('/api/rooms/mine');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (a.ok) _movies = a.list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (b.ok) _mine = b.list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    });
  }

  void _snack(String t) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  }

  Future<void> _create(String kind, {String title = '', String url = '', String yt = ''}) async {
    if (_creating) return;
    setState(() => _creating = true);
    final res = await ZxApi.post('/api/rooms/create', {
      'kind': kind,
      if (title.isNotEmpty) 'title': title,
      if (url.isNotEmpty) 'url': url,
      if (yt.isNotEmpty) 'yt': yt,
    });
    if (!mounted) return;
    setState(() => _creating = false);
    if (!res.ok) {
      _snack(res.error == 'INVALID_MOVIE' ? "That link doesn't look right".tr : res.message);
      return;
    }
    final code = (res.map['code'] ?? '').toString();
    await Navigator.push(context, MaterialPageRoute(builder: (_) => RoomScreen(code: code)));
    _load();
  }

  Future<void> _join() async {
    final code = _codeCtl.text.trim();
    if (code.isEmpty) return;
    await joinRoomWithCode(context, code);
    _codeCtl.clear();
    _load();
  }

  Future<void> _linkDialog() async {
    final ctl = TextEditingController();
    final link = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Paste a link'.tr),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: ZX.input('YouTube or video link'.tr, icon: Icons.link),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel'.tr, style: const TextStyle(color: ZX.muted))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
              child: Text('Start'.tr, style: const TextStyle(color: ZX.coral, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (link == null || link.isEmpty) return;
    final isYt = link.contains('youtube.com') || link.contains('youtu.be');
    if (isYt) {
      if (!kIsWeb) {
        _snack('YouTube links work in the web version for now'.tr);
        return;
      }
      await _create('movie', title: 'YouTube', yt: link);
    } else {
      await _create('movie', title: 'Video', url: link);
    }
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 10),
        child: Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ZX.ink)),
      );

  Widget _tabBtn(String label, IconData icon, int i) {
    final on = _tab == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = i),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: on ? ZX.coral : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: on ? Border.all(color: ZX.border, width: ZX.borderWidth) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: on ? Colors.white : ZX.ink),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: on ? Colors.white : ZX.ink)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _movieCard(Map<String, dynamic> m, int i) {
    final cols = _posterColors[i % _posterColors.length];
    return GestureDetector(
      onTap: () => _create('movie', title: (m['title'] ?? '').toString(), url: (m['url'] ?? '').toString()),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ZX.border, width: ZX.borderWidth),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: cols),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: ZX.sun, borderRadius: BorderRadius.circular(10)),
              child: Text('Free'.tr, style: const TextStyle(color: ZX.ink, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
            const Spacer(),
            Text((m['title'] ?? '').toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, height: 1.1)),
            const SizedBox(height: 4),
            Text((m['info'] ?? '').toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFE8DED5), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _movieTab() {
    final items = <Widget>[
      for (var i = 0; i < _movies.length; i++) _movieCard(_movies[i], i),
      GestureDetector(
        onTap: _linkDialog,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ZX.border, width: ZX.borderWidth),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: ZX.coral,
                  shape: BoxShape.circle,
                  border: Border.all(color: ZX.border, width: ZX.borderWidth),
                ),
                child: const Icon(Icons.add_link, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('Paste a YouTube or video link'.tr,
                    textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, color: ZX.ink)),
              ),
            ],
          ),
        ),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Watch together'.tr),
        Text('Pick a movie, invite a friend, and watch in sync from your own homes. Short ad breaks play for both of you at the same time.'.tr,
            style: const TextStyle(color: ZX.muted, fontSize: 13)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.9,
          children: items,
        ),
      ],
    );
  }

  Widget _gameCard(String title, String sub, Widget art, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: ZX.cardDecoration(radius: 22),
        child: Row(
          children: [
            SizedBox(width: 72, height: 72, child: art),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ZX.ink)),
                  const SizedBox(height: 2),
                  Text(sub, style: const TextStyle(color: ZX.muted, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: ZX.ink),
          ],
        ),
      ),
    );
  }

  Widget _gameTab() {
    final ludoArt = Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ZX.border, width: ZX.borderWidth),
        color: ZX.bg,
      ),
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (final c in const [Color(0xFFE5484D), Color(0xFF3FA34D), Color(0xFF3B82F6), Color(0xFFFFC46B)])
            Container(
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ZX.border, width: 2),
              ),
            ),
        ],
      ),
    );
    final chessArt = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ZX.border, width: ZX.borderWidth),
        color: ZX.bg,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: GridView.count(
          crossAxisCount: 4,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var i = 0; i < 16; i++)
              Container(color: ((i ~/ 4) + (i % 4)) % 2 == 0 ? const Color(0xFFFFF0D8) : const Color(0xFFD9A57B)),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Play together'.tr),
        Text('Two players, turn by turn. Free to play - no money is involved.'.tr, style: const TextStyle(color: ZX.muted, fontSize: 13)),
        const SizedBox(height: 12),
        _gameCard('Ludo'.tr, 'Roll, race your 4 tokens home'.tr, ludoArt, () => _create('ludo')),
        _gameCard('Chess'.tr, 'The classic game for two'.tr, chessArt, () => _create('chess')),
      ],
    );
  }

  String _kindLabel(String k) => k == 'ludo' ? 'Ludo'.tr : (k == 'chess' ? 'Chess'.tr : 'Movie'.tr);

  Widget _mineList() {
    if (_mine.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Your open rooms'.tr),
        for (final r in _mine)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: ZX.cardDecoration(radius: 18, shadow: false),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_kindLabel((r['kind'] ?? '').toString())} · ${(r['code'] ?? '').toString()}',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: ZX.ink)),
                      Text(
                        (r['other'] ?? '').toString().isEmpty ? 'Waiting for a friend'.tr : tx('With {name}'.tr, {'name': (r['other'] ?? '').toString()}),
                        style: const TextStyle(color: ZX.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await Navigator.push(
                        context, MaterialPageRoute(builder: (_) => RoomScreen(code: (r['code'] ?? '').toString())));
                    _load();
                  },
                  child: Text('Open'.tr, style: const TextStyle(color: ZX.coral, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
      ],
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
        title: Text('Zentrixa Room'.tr, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: ZX.ink)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: ZX.coral))
          : RefreshIndicator(
              color: ZX.coral,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: ZX.cardDecoration(color: ZX.coralSoft, radius: 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Join your friend's room".tr,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ZX.ink)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _codeCtl,
                                textCapitalization: TextCapitalization.characters,
                                onSubmitted: (_) => _join(),
                                decoration: ZX.input('Room code, like ZX-4821'.tr).copyWith(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _join,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ZX.coral,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    side: const BorderSide(color: ZX.border, width: ZX.borderWidth),
                                  ),
                                ),
                                child: Text('Join'.tr, style: const TextStyle(fontWeight: FontWeight.w800)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _mineList(),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: ZX.border, width: ZX.borderWidth),
                    ),
                    child: Row(
                      children: [
                        _tabBtn('Movie'.tr, Icons.movie_outlined, 0),
                        _tabBtn('Game'.tr, Icons.sports_esports_outlined, 1),
                      ],
                    ),
                  ),
                  if (_creating)
                    const Padding(
                      padding: EdgeInsets.only(top: 14),
                      child: LinearProgressIndicator(color: ZX.coral, backgroundColor: ZX.coralSoft),
                    ),
                  if (_tab == 0) _movieTab() else _gameTab(),
                ],
              ),
            ),
    );
  }
}
