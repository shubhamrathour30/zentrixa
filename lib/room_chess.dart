import 'package:flutter/material.dart';

import 'i18n.dart';
import 'zentrixa_theme.dart';

const String _symbolFont = 'Noto Sans Symbols 2';
const List<String> _symbolFallback = [
  'Noto Sans Symbols 2',
  'Noto Sans Symbols',
  'Segoe UI Symbol',
  'Apple Symbols',
  'DejaVu Sans',
];

// Dono taraf ke liye wahi "bhare hue" nishaan; rang se pata chalta hai kaun kiska hai.
String _glyph(String piece) {
  switch (piece.toUpperCase()) {
    case 'K':
      return '♚︎';
    case 'Q':
      return '♛︎';
    case 'R':
      return '♜︎';
    case 'B':
      return '♝︎';
    case 'N':
      return '♞︎';
    default:
      return '♟︎';
  }
}

String _sqName(int row, int col) => String.fromCharCode(97 + col) + (8 - row).toString();

/// Shatranj (2 player). Chaal ke niyam server mein hain; yahan board dikhta hai, tap se chaal jati hai.
class ChessBody extends StatefulWidget {
  final Map<String, dynamic> room;
  final Future<void> Function(String from, String to) onMove;
  final Future<void> Function() onResign;
  final Future<void> Function() onRematch;

  const ChessBody({
    super.key,
    required this.room,
    required this.onMove,
    required this.onResign,
    required this.onRematch,
  });

  @override
  State<ChessBody> createState() => _ChessBodyState();
}

class _ChessBodyState extends State<ChessBody> {
  String? _sel; // chuna hua khana jaise "e2"
  bool _sending = false;

  Map<String, dynamic> get _g {
    final g = widget.room['game'];
    return g is Map<String, dynamic> ? g : <String, dynamic>{};
  }

  int get _role => ((widget.room['role'] ?? 0) as num).toInt(); // 0 = safed (host), 1 = kaala
  bool get _iAmWhite => _role == 0;
  String get _board => (_g['board'] ?? '.' * 64).toString();
  String get _turn => (_g['turn'] ?? 'w').toString();
  bool get _myTurn => (_turn == 'w') == _iAmWhite;
  String get _status => (_g['status'] ?? 'playing').toString();
  String get _last => (_g['last'] ?? '').toString();

  List<String> get _legal {
    final l = _g['legal'];
    if (l is! List) return <String>[];
    return l.map((e) => e.toString()).toList();
  }

  bool _isMine(String p) {
    if (p == '.' || p.isEmpty) return false;
    final white = p == p.toUpperCase();
    return white == _iAmWhite;
  }

  String _name(bool white) {
    final n = ((white ? widget.room['hostName'] : widget.room['guestName']) ?? '').toString();
    return n.isEmpty ? (white ? 'White'.tr : 'Black'.tr) : n;
  }

  Future<void> _tap(int row, int col) async {
    if (_status != 'playing' || !_myTurn || _sending) return;
    final sq = _sqName(row, col);
    final piece = _board[row * 8 + col];
    final sel = _sel;
    if (sel != null && _legal.contains(sel + sq)) {
      setState(() {
        _sending = true;
        _sel = null;
      });
      await widget.onMove(sel, sq);
      if (mounted) setState(() => _sending = false);
      return;
    }
    if (_isMine(piece) && _legal.any((m) => m.startsWith(sq))) {
      setState(() => _sel = sq);
    } else {
      setState(() => _sel = null);
    }
  }

  Widget _piece(String p) {
    final white = p == p.toUpperCase();
    final fill = TextStyle(
      fontSize: 34,
      height: 1.0,
      fontFamily: _symbolFont,
      fontFamilyFallback: _symbolFallback,
      color: white ? Colors.white : const Color(0xFF1F1A17),
    );
    final outline = TextStyle(
      fontSize: 34,
      height: 1.0,
      fontFamily: _symbolFont,
      fontFamilyFallback: _symbolFallback,
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = white ? const Color(0xFF1F1A17) : Colors.white70,
    );
    final g = _glyph(p);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(g, style: outline),
          Text(g, style: fill),
        ],
      ),
    );
  }

  Widget _boardView() {
    final legal = _legal;
    final sel = _sel;
    final checkSq = (_g['check'] == true) ? _kingSquare(_turn == 'w') : null;
    final lastFrom = _last.length == 4 ? _last.substring(0, 2) : '';
    final lastTo = _last.length == 4 ? _last.substring(2, 4) : '';
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: ZX.border, width: 3),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            for (var vr = 0; vr < 8; vr++)
              Expanded(
                child: Row(
                  children: [
                    for (var vc = 0; vc < 8; vc++)
                      Expanded(
                        child: _square(
                          // black ke liye board ulta dikhta hai taaki uske mohre neeche rahein
                          _iAmWhite ? vr : 7 - vr,
                          _iAmWhite ? vc : 7 - vc,
                          legal,
                          sel,
                          checkSq,
                          lastFrom,
                          lastTo,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String? _kingSquare(bool white) {
    final k = white ? 'K' : 'k';
    final i = _board.indexOf(k);
    if (i < 0) return null;
    return _sqName(i ~/ 8, i % 8);
  }

  Widget _square(int row, int col, List<String> legal, String? sel, String? checkSq, String lastFrom, String lastTo) {
    final sq = _sqName(row, col);
    final piece = _board[row * 8 + col];
    final dark = (row + col) % 2 == 1;
    Color bg = dark ? const Color(0xFFD9A57B) : const Color(0xFFFFF0D8);
    if (sq == lastFrom || sq == lastTo) bg = const Color(0xFFFFD36B);
    if (sq == sel) bg = const Color(0xFFFF9F7F);
    if (sq == checkSq) bg = const Color(0xFFFF6B6B);
    final isTarget = sel != null && legal.contains(sel + sq);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _tap(row, col),
      child: Container(
        color: bg,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (piece != '.') Padding(padding: const EdgeInsets.all(2), child: _piece(piece)),
            if (isTarget)
              piece == '.'
                  ? Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(color: Color(0x992A1A14), shape: BoxShape.circle),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xCCFF5733), width: 3),
                      ),
                    ),
          ],
        ),
      ),
    );
  }

  Widget _playerRow(bool white) {
    final turn = _status == 'playing' && ((_turn == 'w') == white);
    final photo = ((white ? widget.room['hostAvatar'] : widget.room['guestAvatar']) ?? '').toString();
    final name = _name(white);
    final me = white == _iAmWhite;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: turn ? ZX.coralSoft : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: turn ? ZX.coral : ZX.border, width: turn ? 3 : ZX.borderWidth),
      ),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: white ? Colors.white : const Color(0xFF1F1A17),
              shape: BoxShape.circle,
              border: Border.all(color: ZX.border, width: 1.5),
            ),
          ),
          const SizedBox(width: 8),
          ZxAvatar(name, radius: 14, photo: photo),
          const SizedBox(width: 8),
          Expanded(
            child: Text(me ? 'You'.tr : name,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, color: ZX.ink)),
          ),
          if (turn) Text('To move'.tr, style: const TextStyle(color: ZX.coral, fontWeight: FontWeight.w800, fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _confirmResign() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Give up this game?'.tr),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel'.tr, style: const TextStyle(color: ZX.muted))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Give up'.tr, style: const TextStyle(color: ZX.coral, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok == true) await widget.onResign();
  }

  @override
  Widget build(BuildContext context) {
    final playing = _status == 'playing';
    final winner = (_g['winner'] ?? '').toString();
    String line;
    if (playing) {
      if (_g['check'] == true) {
        line = _myTurn ? 'Check! Protect your king'.tr : 'Check!'.tr;
      } else {
        line = _myTurn ? 'Your move'.tr : tx('Waiting for {name}...'.tr, {'name': _name(_turn == 'w')});
      }
    } else if (_status == 'stalemate' || _status == 'draw') {
      line = 'Draw'.tr;
    } else {
      final iWon = (winner == 'w') == _iAmWhite;
      if (_status == 'resigned') {
        line = iWon ? 'Your friend gave up - you won!'.tr : 'You gave up'.tr;
      } else {
        line = iWon ? 'Checkmate - you won!'.tr : 'Checkmate - you lost'.tr;
      }
    }
    // upar dusre player ki patti, neeche apni
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        children: [
          _playerRow(!_iAmWhite),
          const SizedBox(height: 8),
          _boardView(),
          const SizedBox(height: 8),
          _playerRow(_iAmWhite),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(line, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ZX.ink)),
          ),
          const SizedBox(height: 8),
          if (playing)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _confirmResign,
                child: Text('Give up'.tr, style: const TextStyle(color: ZX.muted, fontWeight: FontWeight.w700)),
              ),
            )
          else
            ZxButton('Play again'.tr, onPressed: widget.onRematch),
        ],
      ),
    );
  }
}
