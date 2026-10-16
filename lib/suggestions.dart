import 'package:flutter/material.dart';

import 'profile_screen.dart';
import 'zentrixa_theme.dart';
import 'zx_api.dart';
import 'i18n.dart';

/// Home par "People you may know": app ke asli users jinhe aap abhi follow nahi karte
/// (jinhe aapke followings follow karte hain wo pehle). Follow dabao to turant follow ho jata hai.
class SuggestionsBar extends StatefulWidget {
  final ValueNotifier<int> refreshSignal;
  const SuggestionsBar({super.key, required this.refreshSignal});

  @override
  State<SuggestionsBar> createState() => _SuggestionsBarState();
}

class _SuggestionsBarState extends State<SuggestionsBar> {
  List<Map<String, dynamic>> _users = [];
  final Set<String> _sent = {};

  @override
  void initState() {
    super.initState();
    widget.refreshSignal.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    widget.refreshSignal.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    if (!Session.loggedIn) return;
    final res = await ZxApi.get('/api/suggestions');
    if (!mounted || !res.ok) return;
    setState(() {
      _users = res.list.map((e) => Map<String, dynamic>.from(e)).toList();
    });
  }

  Future<void> _add(Map<String, dynamic> u) async {
    final uid = u['uid'].toString();
    final res = await ZxApi.post('/api/follow', {'username': uid});
    if (!mounted) return;
    if (res.ok) {
      setState(() => res.map['following'] == true ? _sent.add(uid) : _sent.remove(uid));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
    }
  }

  void _dismiss(Map<String, dynamic> u) {
    setState(() => _users.removeWhere((x) => x['uid'] == u['uid']));
  }

  Widget _card(Map<String, dynamic> u) {
    final uid = u['uid'].toString();
    final name = (u['name'] ?? uid).toString();
    final mutual = ((u['mutual'] ?? 0) as num).toInt();
    final sent = _sent.contains(uid);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProfileScreen(username: uid)),
      ),
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
        decoration: ZX.cardDecoration(radius: 24),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 4),
                ZxAvatar(name, radius: 30, photo: (u['avatar'] ?? '').toString()),
                const SizedBox(height: 8),
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: ZX.ink, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  mutual == 1
                      ? 'Followed by 1 person you follow'.tr
                      : (mutual > 1 ? tx('Followed by {n} people you follow'.tr, {'n': mutual}) : 'New on Zentrixa'.tr),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: ZX.muted, fontSize: 12),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => _add(u),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: sent ? Colors.white : ZX.coral,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ZX.border, width: 1.8),
                    ),
                    child: Text(
                      sent ? 'Following'.tr : 'Follow'.tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: sent ? ZX.ink : Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              right: -4,
              top: -4,
              child: GestureDetector(
                onTap: () => _dismiss(u),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 16, color: ZX.muted),
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
    if (_users.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        Text('People you may know'.tr,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ZX.ink)),
        const SizedBox(height: 10),
        SizedBox(
          height: 196,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: _users.length,
            itemBuilder: (context, i) => _card(_users[i]),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}
