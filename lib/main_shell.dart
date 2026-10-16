import 'dart:async';

import 'package:flutter/material.dart';

import 'chat_list_screen.dart';
import 'chat_room_screen.dart';
import 'create_post_screen.dart';
import 'home_feed_screen.dart';
import 'profile_screen.dart';
import 'reels_screen.dart';
import 'zentrixa_theme.dart';
import 'zx_api.dart';

/// Login ke baad ka main screen: Home / Reels / Create / Chats / Profile
/// dark brown rounded bottom bar ke saath.
class MainShell extends StatefulWidget {
  const MainShell({Key? key}) : super(key: key);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0; // 0 Home, 1 Reels, 2 Chats, 3 Profile
  int _profileVersion = 0; // Profile tab har baar khulne par fresh load ho
  int _msgUnread = 0; // padhe nahi gaye messages (Chats icon ka badge)
  int _lastMsgSeen = -1; // pichhli baar ki ginti; -1 = abhi tak pata nahi (pehli baar banner nahi)
  Map<String, dynamic> _bannerData = {};
  bool _bannerShown = false;
  Timer? _bannerTimer;
  final ValueNotifier<int> _feedRefresh = ValueNotifier<int>(0);
  final ValueNotifier<int> _unread = ValueNotifier<int>(0);
  Timer? _badgeTimer;

  @override
  void initState() {
    super.initState();
    _refreshBadges();
    _badgeTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refreshBadges());
  }

  @override
  void dispose() {
    _badgeTimer?.cancel();
    _bannerTimer?.cancel();
    _feedRefresh.dispose();
    _unread.dispose();
    super.dispose();
  }

  Future<void> _refreshBadges() async {
    if (!Session.loggedIn) return;
    final res = await ZxApi.get('/api/badges');
    if (!mounted || !res.ok) return;
    _unread.value = ((res.map['notifications'] ?? 0) as num).toInt();
    final msgs = ((res.map['messages'] ?? 0) as num).toInt();
    final latest = res.map['latest'];
    if (msgs != _msgUnread) setState(() => _msgUnread = msgs);
    // Naya message aaya aur wo chat abhi khuli nahi hai: upar se banner
    if (latest is Map && _lastMsgSeen >= 0 && msgs > _lastMsgSeen) {
      final from = (latest['from'] ?? '').toString();
      if (from != ChatPresence.peer) _showBanner(Map<String, dynamic>.from(latest));
    }
    _lastMsgSeen = msgs;
  }

  void _showBanner(Map<String, dynamic> data) {
    _bannerTimer?.cancel();
    setState(() {
      _bannerData = data;
      _bannerShown = true;
    });
    _bannerTimer = Timer(const Duration(seconds: 5), _hideBanner);
  }

  void _hideBanner() {
    _bannerTimer?.cancel();
    if (mounted && _bannerShown) setState(() => _bannerShown = false);
  }

  void _openBanner() {
    final d = _bannerData;
    _hideBanner();
    final uid = (d['from'] ?? '').toString();
    if (uid.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          contactName: (d['name'] ?? uid).toString(),
          receiverId: uid,
          currentUserId: Session.username,
          avatar: (d['avatar'] ?? '').toString(),
        ),
      ),
    ).then((_) => _refreshBadges());
  }

  Widget _bannerView() {
    final d = _bannerData;
    final name = (d['name'] ?? '').toString();
    return Positioned(
      left: 12,
      right: 12,
      top: 0,
      child: SafeArea(
        bottom: false,
        child: AnimatedSlide(
          offset: _bannerShown ? Offset.zero : const Offset(0, -1.6),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: _bannerShown ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !_bannerShown,
              child: GestureDetector(
                onTap: _openBanner,
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  decoration: BoxDecoration(
                    color: ZX.ink,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: ZX.coral, width: 2),
                    boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 14, offset: Offset(0, 6))],
                  ),
                  child: Row(
                    children: [
                      ZxAvatar(name.isEmpty ? 'Z' : name, radius: 20, photo: (d['avatar'] ?? '').toString()),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                            const SizedBox(height: 2),
                            Text((d['text'] ?? '').toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Color(0xFFFFD9CB), fontSize: 13)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _hideBanner,
                        icon: const Icon(Icons.close, color: Color(0xFFFFC9B8), size: 20),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createPost() async {
    final posted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreatePostScreen()),
    );
    if (posted == true) {
      _feedRefresh.value++; // Home feed + Reels refresh
    }
  }

  void _select(int index) {
    setState(() {
      _index = index;
      if (index == 3) _profileVersion++;
    });
    _refreshBadges();
  }

  Widget _navItem(IconData icon, int index, {int badge = 0, IconData? selectedIcon}) {
    final sel = _index == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _select(index),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: sel ? ZX.coral : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: AnimatedScale(
              scale: sel ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 220),
              child: Icon(
                sel && selectedIcon != null ? selectedIcon : icon,
                color: sel ? Colors.white : const Color(0xFFFFC9B8),
                size: 25,
              ),
            ),
          ),
          if (badge > 0)
            Positioned(
              right: -6,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                constraints: const BoxConstraints(minWidth: 21, minHeight: 21),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5484D),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: ZX.ink, width: 2),
                ),
                child: Text(
                  badge > 99 ? '99+' : '$badge',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, height: 1.1),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeFeedScreen(refreshSignal: _feedRefresh, unread: _unread),
      ReelsScreen(active: _index == 1, refreshSignal: _feedRefresh),
      const ChatListScreen(),
      ProfileScreen(key: ValueKey(_profileVersion), embedded: true),
    ];

    return Scaffold(
      backgroundColor: ZX.bg,
      body: Stack(children: [IndexedStack(index: _index, children: pages), _bannerView()]),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: ZX.ink,
            borderRadius: BorderRadius.circular(34),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _navItem(Icons.home_outlined, 0, selectedIcon: Icons.home_rounded),
              _navItem(Icons.movie_outlined, 1),
              GestureDetector(
                onTap: _createPost,
                child: Container(
                  width: 54,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB02E),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.add, color: ZX.ink, size: 28),
                ),
              ),
              _navItem(Icons.chat_bubble_outline_rounded, 2, badge: _msgUnread, selectedIcon: Icons.chat_bubble_rounded),
              _navItem(Icons.person_outline_rounded, 3, selectedIcon: Icons.person_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
