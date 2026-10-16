import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'i18n.dart';
import 'zentrixa_theme.dart';
import 'zx_api.dart';

// Bahari raasta: 52 khane (row, col), 15x15 board par, ghadi ki disha mein. Lal ka start = pehla khana.
const List<List<int>> _path = [
  [6, 1], [6, 2], [6, 3], [6, 4], [6, 5],
  [5, 6], [4, 6], [3, 6], [2, 6], [1, 6], [0, 6],
  [0, 7], [0, 8],
  [1, 8], [2, 8], [3, 8], [4, 8], [5, 8],
  [6, 9], [6, 10], [6, 11], [6, 12], [6, 13], [6, 14],
  [7, 14], [8, 14],
  [8, 13], [8, 12], [8, 11], [8, 10], [8, 9],
  [9, 8], [10, 8], [11, 8], [12, 8], [13, 8], [14, 8],
  [14, 7], [14, 6],
  [13, 6], [12, 6], [11, 6], [10, 6], [9, 6],
  [8, 5], [8, 4], [8, 3], [8, 2], [8, 1], [8, 0],
  [7, 0], [6, 0],
];

// Ghar ka raasta (5 khane) har player ke liye: 0 = lal, 1 = neela
const List<List<List<int>>> _home = [
  [[7, 1], [7, 2], [7, 3], [7, 4], [7, 5]],
  [[7, 13], [7, 12], [7, 11], [7, 10], [7, 9]],
];

// Yard ke 4 slot (x, y) cell units mein
const List<List<List<double>>> _yard = [
  [[1.5, 1.5], [4.5, 1.5], [1.5, 4.5], [4.5, 4.5]],
  [[10.5, 10.5], [13.5, 10.5], [10.5, 13.5], [13.5, 13.5]],
];

const Color _red = Color(0xFFE5484D);
const Color _blue = Color(0xFF3B82F6);
const Color _green = Color(0xFF3FA34D);
const Color _yellow = Color(0xFFFFC46B);

const List<int> _safe = [0, 8, 13, 21, 26, 34, 39, 47];

Offset _cellPos(int player, int r, int slot) {
  if (r < 0) {
    final y = _yard[player][slot];
    return Offset(y[0], y[1]);
  }
  if (r <= 50) {
    final c = _path[(r + (player == 0 ? 0 : 26)) % 52];
    return Offset(c[1] + 0.5, c[0] + 0.5);
  }
  if (r <= 55) {
    final c = _home[player][r - 51];
    return Offset(c[1] + 0.5, c[0] + 0.5);
  }
  // pahunch gaye: beech ke khane mein
  return Offset(player == 0 ? 6.5 : 8.5, 7.5 + (slot - 1.5) * 0.22);
}

class _BoardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 15;
    final line = Paint()
      ..color = const Color(0x552A1A14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    Rect cr(int row, int col) => Rect.fromLTWH(col * cell, row * cell, cell, cell);
    void fillCell(int row, int col, Color c) {
      canvas.drawRect(cr(row, col), Paint()..color = c);
      canvas.drawRect(cr(row, col), line);
    }

    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);

    // 4 yard
    void yard(int row0, int col0, Color c, bool active) {
      final a = active ? 1.0 : 0.35;
      final outer = Rect.fromLTWH(col0 * cell, row0 * cell, cell * 6, cell * 6);
      canvas.drawRect(outer, Paint()..color = c.withValues(alpha: a));
      final inner = Rect.fromLTWH((col0 + 1) * cell, (row0 + 1) * cell, cell * 4, cell * 4);
      canvas.drawRRect(RRect.fromRectAndRadius(inner, Radius.circular(cell * 0.5)), Paint()..color = Colors.white);
      for (final p in [
        [col0 + 1.5, row0 + 1.5], [col0 + 4.5, row0 + 1.5], [col0 + 1.5, row0 + 4.5], [col0 + 4.5, row0 + 4.5]
      ]) {
        canvas.drawCircle(Offset(p[0] * cell, p[1] * cell), cell * 0.42,
            Paint()..color = c.withValues(alpha: active ? 0.35 : 0.15));
      }
    }

    yard(0, 0, _red, true);
    yard(0, 9, _green, false);
    yard(9, 9, _blue, true);
    yard(9, 0, _yellow, false);

    // raasta ke khane
    for (final c in _path) {
      fillCell(c[0], c[1], Colors.white);
    }
    // ghar ke raaste
    for (var i = 1; i <= 5; i++) {
      fillCell(7, i, _red.withValues(alpha: 0.75));
      fillCell(7, 14 - i, _blue.withValues(alpha: 0.75));
      fillCell(i, 7, _green.withValues(alpha: 0.35));
      fillCell(14 - i, 7, _yellow.withValues(alpha: 0.5));
    }
    // start khane
    fillCell(6, 1, _red);
    fillCell(1, 8, _green.withValues(alpha: 0.5));
    fillCell(8, 13, _blue);
    fillCell(13, 6, _yellow.withValues(alpha: 0.7));
    // surakshit (star) khane
    for (final i in _safe) {
      final c = _path[i];
      final ctr = Offset((c[1] + 0.5) * cell, (c[0] + 0.5) * cell);
      canvas.drawCircle(
          ctr,
          cell * 0.22,
          Paint()
            ..color = const Color(0xFF2A1A14)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
      canvas.drawCircle(ctr, cell * 0.06, Paint()..color = const Color(0xFF2A1A14));
    }
    // beech ka 3x3
    final c0 = Offset(6 * cell, 6 * cell);
    final c1 = Offset(9 * cell, 6 * cell);
    final c2 = Offset(9 * cell, 9 * cell);
    final c3 = Offset(6 * cell, 9 * cell);
    final mid = Offset(7.5 * cell, 7.5 * cell);
    void tri(Offset a, Offset b, Color col) {
      final p = Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(mid.dx, mid.dy)
        ..close();
      canvas.drawPath(p, Paint()..color = col);
    }

    tri(c0, c3, _red);
    tri(c0, c1, _green.withValues(alpha: 0.5));
    tri(c1, c2, _blue);
    tri(c3, c2, _yellow.withValues(alpha: 0.7));
    canvas.drawRect(
        Rect.fromLTWH(6 * cell, 6 * cell, 3 * cell, 3 * cell),
        Paint()
          ..color = const Color(0xFF2A1A14)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = const Color(0xFF2A1A14)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Dice extends StatelessWidget {
  final int value; // 0 = pata nahi
  final bool faded;
  const _Dice(this.value, {this.faded = false});

  List<Alignment> _pips() {
    const tl = Alignment(-0.55, -0.55);
    const tr = Alignment(0.55, -0.55);
    const ml = Alignment(-0.55, 0);
    const mr = Alignment(0.55, 0);
    const bl = Alignment(-0.55, 0.55);
    const br = Alignment(0.55, 0.55);
    const c = Alignment(0, 0);
    switch (value) {
      case 1:
        return [c];
      case 2:
        return [tl, br];
      case 3:
        return [tl, c, br];
      case 4:
        return [tl, tr, bl, br];
      case 5:
        return [tl, tr, c, bl, br];
      case 6:
        return [tl, tr, ml, mr, bl, br];
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: faded ? 0.45 : 1,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ZX.border, width: ZX.borderWidth),
          boxShadow: const [BoxShadow(color: ZX.border, offset: Offset(0, 3))],
        ),
        child: value == 0
            ? const Center(child: Text('?', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: ZX.muted)))
            : Stack(
                children: [
                  for (final a in _pips())
                    Align(
                      alignment: a,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: const BoxDecoration(color: ZX.ink, shape: BoxShape.circle),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

/// Ludo (2 player). Saari chaal ka niyam server mein hai; yahan sirf board dikhta hai aur tap bheje jate hain.
class LudoBody extends StatefulWidget {
  final Map<String, dynamic> room;
  final Future<void> Function() onRoll;
  final Future<void> Function(int token) onMove;
  final Future<void> Function() onResign;
  final Future<void> Function() onRematch;

  const LudoBody({
    super.key,
    required this.room,
    required this.onRoll,
    required this.onMove,
    required this.onResign,
    required this.onRematch,
  });

  @override
  State<LudoBody> createState() => _LudoBodyState();
}

class _LudoBodyState extends State<LudoBody> {
  bool _rolling = false;
  int _fake = 1;
  Timer? _anim;
  final math.Random _rnd = math.Random();

  @override
  void dispose() {
    _anim?.cancel();
    super.dispose();
  }

  Map<String, dynamic> get _g {
    final g = widget.room['game'];
    return g is Map<String, dynamic> ? g : <String, dynamic>{};
  }

  int get _role => ((widget.room['role'] ?? 0) as num).toInt();
  int _int(String k) => ((_g[k] ?? 0) as num).toInt();

  List<List<int>> get _tokens {
    final t = _g['tokens'];
    if (t is! List) {
      return [
        [-1, -1, -1, -1],
        [-1, -1, -1, -1]
      ];
    }
    return t.map<List<int>>((p) => (p as List).map<int>((e) => (e as num).toInt()).toList()).toList();
  }

  List<int> get _movable {
    final m = _g['movable'];
    if (m is! List) return <int>[];
    return m.map<int>((e) => (e as num).toInt()).toList();
  }

  String _nameOf(int p) {
    final n = ((p == 0 ? widget.room['hostName'] : widget.room['guestName']) ?? '').toString();
    return n.isEmpty ? (p == 0 ? 'Player 1' : 'Player 2') : n;
  }

  Future<void> _roll() async {
    setState(() => _rolling = true);
    _anim = Timer.periodic(const Duration(milliseconds: 90), (_) {
      if (mounted) setState(() => _fake = 1 + _rnd.nextInt(6));
    });
    await Future.wait([
      widget.onRoll(),
      Future<void>.delayed(const Duration(milliseconds: 600)),
    ]);
    _anim?.cancel();
    if (mounted) setState(() => _rolling = false);
  }

  Widget _playerChip(int p) {
    final turn = _int('turn') == p && (_g['status'] ?? '') == 'playing';
    final color = p == 0 ? _red : _blue;
    final photo = ((p == 0 ? widget.room['hostAvatar'] : widget.room['guestAvatar']) ?? '').toString();
    final name = _nameOf(p);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: turn ? ZX.coralSoft : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: turn ? color : ZX.border, width: turn ? 3 : ZX.borderWidth),
        ),
        child: Row(
          children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            ZxAvatar(name, radius: 14, photo: photo),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                p == _role ? 'You'.tr : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, color: ZX.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _noteText() {
    switch ((_g['note'] ?? '').toString()) {
      case 'captured':
        return 'A token was captured!'.tr;
      case 'nomove':
        return 'No move possible, the turn passes'.tr;
      case 'threesixes':
        return 'Three sixes in a row - the turn is lost'.tr;
      case 'home':
        return 'A token reached home!'.tr;
      default:
        return '';
    }
  }

  Widget _board() {
    final tokens = _tokens;
    final movable = _movable;
    final turn = _int('turn');
    final playing = (_g['status'] ?? '') == 'playing';
    final myMove = playing && turn == _role && _int('dice') != 0;
    return LayoutBuilder(builder: (context, cons) {
      final size = cons.maxWidth;
      final cell = size / 15;
      final tok = cell * 0.74;
      // ek hi jagah kai token ho to thoda faila do
      final groups = <String, List<String>>{};
      for (var p = 0; p < 2; p++) {
        for (var i = 0; i < 4; i++) {
          final o = _cellPos(p, tokens[p][i], i);
          groups.putIfAbsent('${o.dx.toStringAsFixed(2)},${o.dy.toStringAsFixed(2)}', () => []).add('$p-$i');
        }
      }
      final children = <Widget>[
        Positioned.fill(child: CustomPaint(painter: _BoardPainter())),
      ];
      for (var p = 0; p < 2; p++) {
        for (var i = 0; i < 4; i++) {
          final r = tokens[p][i];
          final o = _cellPos(p, r, i);
          final key = '${o.dx.toStringAsFixed(2)},${o.dy.toStringAsFixed(2)}';
          final grp = groups[key] ?? <String>[];
          final k = grp.length;
          final idx = grp.indexOf('$p-$i');
          final shift = r >= 0 && k > 1 ? (idx - (k - 1) / 2) * 0.28 : 0.0;
          final canTap = myMove && p == _role && movable.contains(i);
          final color = p == 0 ? _red : _blue;
          children.add(AnimatedPositioned(
            key: ValueKey('tok-$p-$i'),
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            left: (o.dx + shift) * cell - tok / 2,
            top: o.dy * cell - tok / 2,
            width: tok,
            height: tok,
            child: GestureDetector(
              onTap: canTap ? () => widget.onMove(i) : null,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: canTap ? ZX.sun : ZX.border, width: canTap ? 3.5 : 2),
                  boxShadow: canTap
                      ? const [BoxShadow(color: ZX.sun, blurRadius: 8, spreadRadius: 2)]
                      : const [BoxShadow(color: Color(0x55000000), offset: Offset(0, 2), blurRadius: 2)],
                ),
                child: Center(
                  child: Container(
                    width: tok * 0.34,
                    height: tok * 0.34,
                    decoration: const BoxDecoration(color: Color(0x66FFFFFF), shape: BoxShape.circle),
                  ),
                ),
              ),
            ),
          ));
        }
      }
      return SizedBox(width: size, height: size, child: Stack(children: children));
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = (_g['status'] ?? 'playing').toString();
    final playing = status == 'playing';
    final turn = _int('turn');
    final mine = turn == _role;
    final dice = _int('dice');
    final lastDice = _int('lastDice');
    final winner = _int('winner');
    final shownDice = _rolling ? _fake : (dice != 0 ? dice : lastDice);

    String line;
    if (!playing) {
      line = winner == _role ? 'You won the game!'.tr : tx('{name} won the game'.tr, {'name': _nameOf(winner)});
    } else if (mine) {
      line = dice == 0 ? 'Your turn - roll the dice'.tr : 'Tap a glowing token'.tr;
    } else {
      line = tx('Waiting for {name}...'.tr, {'name': _nameOf(turn)});
    }
    final note = _noteText();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        children: [
          Row(children: [_playerChip(0), const SizedBox(width: 10), _playerChip(1)]),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZX.border, width: 2),
            ),
            child: _board(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Dice(shownDice, faded: dice == 0 && !_rolling),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(line, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ZX.ink)),
                    if (note.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(note, style: const TextStyle(fontSize: 13, color: ZX.muted)),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (playing)
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: (mine && dice == 0 && !_rolling) ? _roll : null,
                      icon: const Icon(Icons.casino_outlined),
                      label: Text('Roll dice'.tr, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ZX.coral,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: ZX.coralSoft,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: const BorderSide(color: ZX.border, width: ZX.borderWidth),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: widget.onResign,
                  child: Text('Give up'.tr, style: const TextStyle(color: ZX.muted, fontWeight: FontWeight.w700)),
                ),
              ],
            )
          else
            ZxButton('Play again'.tr, onPressed: widget.onRematch),
        ],
      ),
    );
  }
}
