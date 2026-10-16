import 'package:flutter/material.dart';

import 'zentrixa_theme.dart';

/// Home feed: stories row + filter chips + sunset post cards.
/// Abhi data sample (mock) hai - server ka posts API aane par yahan jod dena.
class HomeFeedScreen extends StatefulWidget {
  final String currentUserId;
  const HomeFeedScreen({Key? key, this.currentUserId = ''}) : super(key: key);

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _Post {
  final String user;
  final String time;
  final String caption;
  final String place;
  final Color top;
  final Color bottom;
  int likes;
  final int comments;
  final int shares;
  bool liked;
  bool following;

  _Post({
    required this.user,
    required this.time,
    required this.caption,
    required this.place,
    required this.top,
    required this.bottom,
    required this.likes,
    required this.comments,
    required this.shares,
    this.liked = false,
    this.following = false,
  });
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  int _filter = 0;
  final List<String> _filters = ['For you', 'Friends', 'Trending'];

  final List<Map<String, dynamic>> _stories = [
    {'name': 'Rahul', 'live': true},
    {'name': 'Purav', 'live': false},
    {'name': 'Varun', 'live': false},
    {'name': 'Avarun', 'live': false},
  ];

  final List<_Post> _posts = [
    _Post(
      user: 'puravminhas38',
      time: '2h ago',
      caption: 'Sunset vibes at the beach',
      place: 'Goa',
      top: const Color(0xFFFF9A5C),
      bottom: const Color(0xFFFF5733),
      likes: 1200,
      comments: 340,
      shares: 84,
    ),
    _Post(
      user: 'rahul.verma',
      time: '5h ago',
      caption: 'Golden hour hits different',
      place: 'Jaipur',
      top: const Color(0xFFFFC46B),
      bottom: const Color(0xFFFF7A45),
      likes: 860,
      comments: 120,
      shares: 40,
    ),
    _Post(
      user: 'va068112',
      time: 'Yesterday',
      caption: 'Photo bhej do sab log',
      place: 'Mumbai',
      top: const Color(0xFFFFB38A),
      bottom: const Color(0xFFC23A14),
      likes: 430,
      comments: 56,
      shares: 12,
    ),
  ];

  String _compact(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';

  Widget _headerButton(IconData icon, {bool dot = false}) {
    return Container(
      width: 46,
      height: 46,
      margin: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: ZX.border, width: ZX.borderWidth),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, color: ZX.ink, size: 22),
          if (dot)
            Positioned(
              right: 11,
              top: 10,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: ZX.coral,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _story(String name, {bool live = false, bool add = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: add ? ZX.coral : (live ? ZX.coral : ZX.sun),
                width: 2.5,
              ),
            ),
            child: add
                ? const Center(
                    child: Icon(Icons.add, color: ZX.coral, size: 28),
                  )
                : Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      ZxAvatar(name, radius: 30),
                      if (live)
                        Positioned(
                          bottom: -6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: ZX.coral,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: const Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: const TextStyle(color: ZX.ink, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String label, {VoidCallback? onTap, bool active = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: active ? ZX.sun : Colors.white),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _postCard(_Post p) {
    return Container(
      height: 330,
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: ZX.border, width: ZX.borderWidth),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.top, p.bottom],
        ),
        boxShadow: const [BoxShadow(color: ZX.border, offset: Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            // Sunset art
            Positioned(
              top: 70,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 105,
                      height: 105,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFE27A),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Place chip
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: ZX.ink.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.place, color: Colors.white, size: 15),
                    const SizedBox(width: 4),
                    Text(
                      p.place,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 14,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ZX.ink.withOpacity(0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.bookmark_border,
                    color: Colors.white, size: 20),
              ),
            ),
            // Glass info panel
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ZX.ink.withOpacity(0.78),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        ZxAvatar(p.user, radius: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.user,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                p.time,
                                style: const TextStyle(
                                  color: Color(0xFFFFD2C2),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () =>
                              setState(() => p.following = !p.following),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: p.following ? Colors.transparent : ZX.coral,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: ZX.coral, width: 1.8),
                            ),
                            child: Text(
                              p.following ? 'Following' : 'Follow',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      p.caption,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _statChip(
                          p.liked ? Icons.favorite : Icons.favorite_border,
                          _compact(p.likes),
                          active: p.liked,
                          onTap: () => setState(() {
                            p.liked = !p.liked;
                            p.likes += p.liked ? 1 : -1;
                          }),
                        ),
                        _statChip(Icons.chat_bubble_outline, _compact(p.comments)),
                        _statChip(Icons.share_outlined, _compact(p.shares)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.currentUserId.isNotEmpty
        ? widget.currentUserId.split('@').first
        : 'there';

    return Scaffold(
      backgroundColor: ZX.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hey $name',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFC25A00),
                          fontSize: 15,
                        ),
                      ),
                      const Text(
                        'Zentrixa',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w600,
                          color: ZX.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                _headerButton(Icons.search),
                _headerButton(Icons.notifications_none, dot: true),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 105,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _story('Add', add: true),
                  for (final s in _stories)
                    _story(s['name'] as String, live: s['live'] as bool),
                ],
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 46,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                itemBuilder: (context, i) {
                  final sel = _filter == i;
                  return GestureDetector(
                    onTap: () => setState(() => _filter = i),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: sel ? ZX.coral : ZX.coralSoft,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: sel ? ZX.border : Colors.transparent,
                          width: ZX.borderWidth,
                        ),
                      ),
                      child: Text(
                        _filters[i],
                        style: TextStyle(
                          color: sel ? Colors.white : const Color(0xFFC25A00),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            for (final p in _posts) _postCard(p),
          ],
        ),
      ),
    );
  }
}
