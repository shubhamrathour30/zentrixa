import 'dart:async';

import 'package:flutter/material.dart';

import 'post_actions.dart';
import 'profile_screen.dart';
import 'zentrixa_theme.dart';
import 'zx_api.dart';
import 'i18n.dart';

class ChatRoomScreen extends StatefulWidget {
  final String contactName;
  final String receiverId; // dusre user ka username
  final String currentUserId; // mera username (Session.username)
  final String avatar; // dusre ki profile photo ka server path ('' = letter)

  const ChatRoomScreen({
    super.key,
    required this.contactName,
    required this.receiverId,
    required this.currentUserId,
    this.avatar = '',
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();

  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _sending = false;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    ChatPresence.peer = widget.receiverId;
    _fetchMessages();
    // Har 2 second mein naye messages check karo
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) => _fetchMessages());
  }

  @override
  void dispose() {
    if (ChatPresence.peer == widget.receiverId) ChatPresence.peer = '';
    _pollingTimer?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages() async {
    final res = await ZxApi.get('/api/messages', query: {'peer': widget.receiverId});
    if (!mounted || !res.ok) return;
    final data = res.list;
    final changed = data.length != _messages.length || _isLoading;
    if (changed) {
      setState(() {
        _messages = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    final res = await ZxApi.post('/api/send_message', {
      'receiverId': widget.receiverId,
      'message': text,
    });
    if (!mounted) return;
    setState(() => _sending = false);

    if (res.ok) {
      _messageController.clear();
      _fetchMessages();
    } else {
      // Message box mein hi rehne do taaki dobara try kar sako
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
    }
  }

  String _clock(num epoch) {
    final d = DateTime.fromMillisecondsSinceEpoch(epoch.toInt() * 1000);
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  void _showProfileInfo() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileScreen(username: widget.receiverId)),
    );
  }

  Future<void> _menu(String choice) async {
    if (choice == 'profile') {
      _showProfileInfo();
    } else if (choice == 'report') {
      await ZxActions.report(context, type: 'user', target: widget.receiverId);
    } else if (choice == 'block') {
      final blocked =
          await ZxActions.block(context, username: widget.receiverId, name: widget.contactName);
      if (blocked && mounted) Navigator.pop(context); // chat band, friendship hat gayi
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
            GestureDetector(
              onTap: _showProfileInfo,
              child: ZxAvatar(widget.contactName, radius: 19, photo: widget.avatar),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: _showProfileInfo,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.contactName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17, color: ZX.ink, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '@${widget.receiverId}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: ZX.muted),
                    ),
                  ],
                ),
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: ZX.ink),
              color: ZX.card,
              onSelected: _menu,
              itemBuilder: (_) => [
                PopupMenuItem(value: 'profile', child: Text('View profile'.tr)),
                PopupMenuItem(value: 'report', child: Text('Report'.tr)),
                PopupMenuItem(value: 'block', child: Text('Block'.tr)),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: ZX.coral))
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          'No messages yet. Say hello! 👋'.tr,
                          style: TextStyle(color: ZX.muted),
                        ),
                      )
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(14),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final m = _messages[_messages.length - 1 - index];
                          final isMe = m['senderId'] == widget.currentUserId;

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.75,
                              ),
                              margin: const EdgeInsets.symmetric(vertical: 5),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMe ? ZX.coral : Colors.white,
                                border: Border.all(color: ZX.border, width: ZX.borderWidth),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(20),
                                  topRight: const Radius.circular(20),
                                  bottomLeft: Radius.circular(isMe ? 20 : 4),
                                  bottomRight: Radius.circular(isMe ? 4 : 20),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    (m['message'] ?? '').toString(),
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: isMe ? Colors.white : ZX.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _clock((m['time'] ?? 0) as num),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isMe ? const Color(0xFFFFE1D8) : ZX.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
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
                      controller: _messageController,
                      onSubmitted: (_) => _sendMessage(),
                      textInputAction: TextInputAction.send,
                      style: const TextStyle(color: ZX.ink),
                      decoration: InputDecoration(
                        hintText: 'Message'.tr,
                        hintStyle: TextStyle(color: ZX.muted),
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
                      onPressed: _sending ? null : _sendMessage,
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
