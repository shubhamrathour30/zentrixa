import 'package:flutter/material.dart';

import 'i18n.dart';
import 'zentrixa_theme.dart';
import 'zx_api.dart';

class _AiMsg {
  final bool fromUser;
  final String text;
  const _AiMsg(this.fromUser, this.text);
}

/// Zentrixa AI: Gemini jaisa assistant - har sawal ka jawab deta hai (app, padhai, coding, general). Jis language mein pucho, usi mein jawab.
class ZentrixaAiScreen extends StatefulWidget {
  const ZentrixaAiScreen({super.key});

  @override
  State<ZentrixaAiScreen> createState() => _ZentrixaAiScreenState();
}

class _ZentrixaAiScreenState extends State<ZentrixaAiScreen> {
  final List<_AiMsg> _msgs = [];
  final TextEditingController _ctl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _waiting = false;
  bool _started = false; // user ne kuch pucha?

  @override
  void dispose() {
    _ctl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final t = text.trim();
    if (t.isEmpty || _waiting) return;
    _ctl.clear();
    final hist = _msgs
        .map((m) => {'role': m.fromUser ? 'user' : 'ai', 'text': m.text})
        .toList();
    setState(() {
      _msgs.add(_AiMsg(true, t));
      _waiting = true;
      _started = true;
    });
    _toBottom();
    final res = await ZxApi.post('/api/ai/ask', {'message': t, 'history': hist});
    if (!mounted) return;
    String answer;
    if (res.ok) {
      answer = (res.map['answer'] ?? '').toString();
      if (answer.isEmpty) answer = 'Sorry, I could not answer that. Please try again.'.tr;
    } else if (res.error == 'TOO_MANY_ATTEMPTS') {
      answer = 'You are asking very fast! Please wait a minute and try again.'.tr;
    } else {
      answer = 'I cannot reach the server right now. Please try again in a moment.'.tr;
    }
    setState(() {
      _msgs.add(_AiMsg(false, answer));
      _waiting = false;
    });
    _toBottom();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 120,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  /// Chhota markdown: **bold**, `code`, ``` code block ```, "- " bullets, "# " headings.
  List<InlineSpan> _md(String text, Color color) {
    final base = TextStyle(color: color, fontSize: 15, height: 1.4);
    final spans = <InlineSpan>[];
    final inline = RegExp(r'(\*\*[^*\n]+\*\*|`[^`\n]+`)');
    bool inCode = false;
    final lines = text.split('\n');
    for (var li = 0; li < lines.length; li++) {
      var line = lines[li];
      final nl = li == lines.length - 1 ? '' : '\n';
      if (line.trimLeft().startsWith('```')) {
        inCode = !inCode;
        continue;
      }
      if (inCode) {
        spans.add(TextSpan(
          text: line + nl,
          style: base.copyWith(fontFamily: 'monospace', fontSize: 13.5, backgroundColor: const Color(0x14000000)),
        ));
        continue;
      }
      var style = base;
      final head = RegExp(r'^#{1,6}\s+').firstMatch(line);
      if (head != null) {
        line = line.substring(head.end);
        style = base.copyWith(fontWeight: FontWeight.w800);
      }
      final bullet = RegExp(r'^(\s*)[-*]\s+').firstMatch(line);
      if (bullet != null) line = '${bullet.group(1)}\u2022 ${line.substring(bullet.end)}';
      var pos = 0;
      for (final m in inline.allMatches(line)) {
        if (m.start > pos) spans.add(TextSpan(text: line.substring(pos, m.start), style: style));
        final t = m.group(0)!;
        if (t.startsWith('**')) {
          spans.add(TextSpan(text: t.substring(2, t.length - 2), style: style.copyWith(fontWeight: FontWeight.w800)));
        } else {
          spans.add(TextSpan(
            text: t.substring(1, t.length - 1),
            style: style.copyWith(fontFamily: 'monospace', fontSize: 13.5, backgroundColor: const Color(0x14000000)),
          ));
        }
        pos = m.end;
      }
      if (pos < line.length) spans.add(TextSpan(text: line.substring(pos), style: style));
      if (nl.isNotEmpty) spans.add(TextSpan(text: nl, style: style));
    }
    return spans;
  }

  Widget _bubble(_AiMsg m) {
    final mine = m.fromUser;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? ZX.coral : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
          border: Border.all(color: ZX.border, width: ZX.borderWidth),
        ),
        child: mine
            ? SelectableText(
                m.text,
                style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.35),
              )
            : SelectableText.rich(TextSpan(children: _md(m.text, ZX.ink))),
      ),
    );
  }

  Widget _typing() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ZX.border, width: ZX.borderWidth),
        ),
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 3, color: ZX.coral),
        ),
      ),
    );
  }

  Widget _chip(String q) {
    return GestureDetector(
      onTap: () => _send(q),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: ZX.coralSoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ZX.border, width: ZX.borderWidth),
        ),
        child: Text(q, style: const TextStyle(color: ZX.ink, fontWeight: FontWeight.w700, fontSize: 13)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = <String>[
      'Explain black holes in simple words'.tr,
      'Write a short poem about friendship'.tr,
      'Give me 5 study tips for exams'.tr,
      'How do I earn coins?'.tr,
      'How do I watch a movie with a friend?'.tr,
      'Can I play Ludo or Chess with friends?'.tr,
    ];
    return Scaffold(
      backgroundColor: ZX.bg,
      appBar: AppBar(
        backgroundColor: ZX.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: ZX.ink),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: ZX.coral,
                shape: BoxShape.circle,
                border: Border.all(color: ZX.border, width: ZX.borderWidth),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Text('Zentrixa AI'.tr, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ZX.ink)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              children: [
                _bubble(_AiMsg(
                    false,
                    "Hi! I'm Zentrixa AI. Ask me anything - studies, coding, ideas, general questions or help with Zentrixa - in any language you like."
                        .tr)),
                if (!_started)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(spacing: 8, runSpacing: 8, children: [for (final q in suggestions) _chip(q)]),
                  ),
                for (final m in _msgs) _bubble(m),
                if (_waiting) _typing(),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctl,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 4000,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _send,
                      decoration: ZX.input('Ask me anything...'.tr).copyWith(
                        counterText: '',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _send(_ctl.text),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _waiting ? ZX.coralSoft : ZX.coral,
                        shape: BoxShape.circle,
                        border: Border.all(color: ZX.border, width: ZX.borderWidth),
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
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
