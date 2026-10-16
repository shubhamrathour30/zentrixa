import 'package:flutter/material.dart';

import 'zentrixa_theme.dart';
import 'zx_api.dart';
import 'i18n.dart';

/// Post ke comments ka bottom sheet (Home aur Reels dono use karte hain).
class CommentsSheet extends StatefulWidget {
  final int postId;
  final void Function(int count) onCountChanged;
  const CommentsSheet({super.key, required this.postId, required this.onCountChanged});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  List<dynamic> _comments = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final res = await ZxApi.get('/api/posts/comments', query: {'postId': '${widget.postId}'});
    if (!mounted) return;
    setState(() {
      if (res.ok) _comments = res.list;
      _loading = false;
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final res = await ZxApi.post('/api/posts/comment', {'postId': widget.postId, 'text': text});
    if (!mounted) return;
    setState(() => _sending = false);
    if (res.ok) {
      _controller.clear();
      widget.onCountChanged((res.map['comments'] as num).toInt());
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            const SizedBox(height: 14),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(color: ZX.border, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(height: 14),
            Text('Comments'.tr,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ZX.ink)),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: ZX.coral))
                  : _comments.isEmpty
                      ? Center(
                          child: Text('Be the first to comment'.tr, style: TextStyle(color: ZX.muted)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _comments.length,
                          itemBuilder: (context, i) {
                            final c = _comments[i];
                            final name = (c['name'] ?? c['user']).toString();
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ZxAvatar(name, radius: 18, photo: (c['avatar'] ?? '').toString()),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$name · ${timeAgo((c['time'] ?? 0) as num)}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700, color: ZX.ink, fontSize: 13),
                                        ),
                                        Text((c['text'] ?? '').toString(),
                                            style: const TextStyle(color: ZX.ink)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              padding: const EdgeInsets.only(left: 18, right: 6, top: 4, bottom: 4),
              decoration: ZX.cardDecoration(radius: 30),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _send(),
                      style: const TextStyle(color: ZX.ink),
                      decoration: InputDecoration(
                        hintText: 'Add a comment...'.tr,
                        hintStyle: TextStyle(color: ZX.muted),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(color: ZX.coral, shape: BoxShape.circle),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 18),
                      onPressed: _sending ? null : _send,
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
}
