import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'chat_room_screen.dart';
import 'follow_list_screen.dart';
import 'settings_screen.dart';
import 'post_actions.dart';
import 'zentrixa_theme.dart';
import 'zx_api.dart';
import 'i18n.dart';

/// Kisi bhi user ka profile. `username` khali ho to apna profile
/// (Profile tab mein `embedded: true` hota hai, wahan back button nahi).
class ProfileScreen extends StatefulWidget {
  final String username;
  final bool embedded;
  const ProfileScreen({super.key, this.username = '', this.embedded = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic> _p = {};
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  String? _error;

  bool get _isMe => _p['isMe'] == true || (widget.username.isEmpty);

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _load() async {
    final target = widget.username.isEmpty ? Session.username : widget.username;
    final results = await Future.wait([
      ZxApi.get('/api/profile', query: {'username': target}),
      ZxApi.get('/api/posts', query: {'author': target, 'filter': 'all'}),
    ]);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (results[0].ok) {
        _error = null;
        _p = Map<String, dynamic>.from(results[0].map);
        if (_p['isMe'] == true) {
          Session.name = (_p['name'] ?? Session.name).toString();
          Session.avatar = (_p['avatar'] ?? '').toString();
        }
      } else {
        _error = results[0].message;
      }
      if (results[1].ok) {
        _posts = results[1].list.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    });
  }

  // ------------------------------------------------------------ actions

  Future<void> _toggleFollow() async {
    final r = await ZxApi.post('/api/follow', {'username': _p['username']});
    if (!r.ok) _snack(r.message);
    _load();
  }

  Future<void> _openFollowList(int tab) async {
    final username = (_p['username'] ?? '').toString();
    if (username.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FollowListScreen(
          username: username,
          name: (_p['name'] ?? username).toString(),
          initialTab: tab,
        ),
      ),
    );
    if (mounted) _load(); // list mein follow/unfollow kiya ho to ginti badal jaye
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          contactName: (_p['name'] ?? _p['username']).toString(),
          receiverId: _p['username'].toString(),
          currentUserId: Session.username,
          avatar: (_p['avatar'] ?? '').toString(),
        ),
      ),
    );
  }

  Future<void> _menu(String choice) async {
    final username = _p['username'].toString();
    final name = (_p['name'] ?? username).toString();
    if (choice == 'report') {
      await ZxActions.report(context, type: 'user', target: username);
    } else if (choice == 'block') {
      final blocked = await ZxActions.block(context, username: username, name: name);
      if (blocked) _load();
    } else if (choice == 'unblock') {
      final r = await ZxApi.post('/api/block', {'username': username});
      if (r.ok) _snack(tx('{name} unblocked'.tr, {'name': name}));
      _load();
    }
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SettingsScreen(profile: _p, onChanged: _load)),
    );
    if (mounted) _load();
  }

  Future<void> _edit() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditProfileScreen(profile: _p)),
    );
    if (changed == true) _load();
  }

  // ------------------------------------------------------------ widgets

  Widget _pill(String label, IconData icon, VoidCallback? onTap, {bool filled = false}) {
    final active = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: !active ? ZX.coralSoft : (filled ? ZX.coral : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ZX.border, width: ZX.borderWidth),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: !active ? ZX.muted : (filled ? Colors.white : ZX.coral)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: !active ? ZX.muted : (filled ? Colors.white : ZX.coral),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, dynamic value, {VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: ZX.cardDecoration(radius: 18, shadow: false),
        child: Column(
          children: [
            Text('${value ?? 0}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ZX.ink)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 12, color: ZX.muted)),
          ],
        ),
      ),
      ),
    );
  }

  Widget _postTile(Map<String, dynamic> p) {
    final image = (p['image'] ?? '').toString();
    final video = (p['video'] ?? '').toString();
    final caption = (p['caption'] ?? '').toString();
    Widget content;
    if (image.isNotEmpty) {
      content = Image.network(
        ZxApi.imageUrl(image),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, color: ZX.muted)),
      );
    } else if (video.isNotEmpty) {
      content = Container(
        color: ZX.ink,
        child: const Center(child: Icon(Icons.play_circle_outline, color: Colors.white, size: 36)),
      );
    } else {
      content = Container(
        color: ZX.coralSoft,
        padding: const EdgeInsets.all(8),
        child: Center(
          child: Text(
            caption,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: ZX.ink, fontSize: 12),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: () => _openPost(p),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ZX.border, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: content,
      ),
    );
  }

  void _openPost(Map<String, dynamic> p) {
    final image = (p['image'] ?? '').toString();
    final caption = (p['caption'] ?? '').toString();
    final isVideo = (p['video'] ?? '').toString().isNotEmpty;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: const EdgeInsets.all(14),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (image.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(ZxApi.imageUrl(image), fit: BoxFit.cover),
                ),
              if (isVideo)
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('🎬 Reel — watch it in the Reels tab'.tr, style: TextStyle(color: ZX.muted)),
                ),
              if (caption.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(caption, style: const TextStyle(color: ZX.ink, fontSize: 16)),
                ),
              const SizedBox(height: 10),
              Text('❤ ${p['likes'] ?? 0}   💬 ${p['comments'] ?? 0}   ·   ${timeAgo((p['time'] ?? 0) as num)}',
                  style: const TextStyle(color: ZX.muted, fontSize: 13)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close'.tr, style: TextStyle(color: ZX.coral, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _roundBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: ZX.border, width: ZX.borderWidth),
          ),
          child: Icon(icon, color: ZX.ink, size: 21),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: ZX.bg,
        body: Center(child: CircularProgressIndicator(color: ZX.coral)),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: ZX.bg,
        appBar: AppBar(backgroundColor: ZX.bg, elevation: 0, iconTheme: const IconThemeData(color: ZX.ink)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: ZX.muted)),
          ),
        ),
      );
    }

    final name = (_p['name'] ?? '').toString();
    final bio = (_p['bio'] ?? '').toString();
    final avatar = (_p['avatar'] ?? '').toString();
    final blockedByMe = _p['blockedByMe'] == true;
    final isMe = _isMe;
    final iFollow = _p['isFollowing'] == true;
    final followsMe = _p['followsMe'] == true;
    // Instagram jaisa: Follow / Follow back (filled), Following (outlined). Message tab dikhta hai jab koi ek follow karta ho.
    final Widget followBtn = iFollow
        ? _pill('Following'.tr, Icons.check, _toggleFollow)
        : _pill(followsMe ? 'Follow back'.tr : 'Follow'.tr, Icons.person_add_alt_1_outlined, _toggleFollow, filled: true);

    return Scaffold(
      backgroundColor: ZX.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: ZX.coral,
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: [
              Row(
                children: [
                  if (!widget.embedded) _roundBtn(Icons.arrow_back, () => Navigator.pop(context)),
                  if (!widget.embedded) const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isMe ? 'Profile'.tr : '@${_p['username']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: ZX.ink),
                    ),
                  ),
                  if (isMe) _roundBtn(Icons.menu, _openSettings),
                  if (!isMe)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: ZX.ink),
                      color: ZX.card,
                      onSelected: _menu,
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'report', child: Text('Report'.tr)),
                        PopupMenuItem(
                          value: blockedByMe ? 'unblock' : 'block',
                          child: Text(blockedByMe ? 'Unblock'.tr : 'Block'.tr),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Center(child: ZxAvatar(name, radius: 50, photo: avatar)),
              const SizedBox(height: 12),
              Center(
                child: Text(name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: ZX.ink)),
              ),
              Center(child: Text('@${_p['username']}', style: const TextStyle(color: ZX.muted))),
              if (bio.isNotEmpty) ...[
                const SizedBox(height: 10),
                Center(
                  child: Text(bio,
                      textAlign: TextAlign.center, style: const TextStyle(color: ZX.ink, fontSize: 15)),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  _stat('Posts'.tr, _p['posts']),
                  _stat('Followers'.tr, _p['followers'], onTap: () => _openFollowList(0)),
                  _stat('Following'.tr, _p['following'], onTap: () => _openFollowList(1)),
                ],
              ),
              const SizedBox(height: 16),
              if (isMe) ...[
                _pill('Edit profile'.tr, Icons.edit_outlined, _edit, filled: true),
              ] else if (blockedByMe) ...[
                _pill('Unblock'.tr, Icons.lock_open, () => _menu('unblock'), filled: true),
                const SizedBox(height: 14),
                Center(
                  child: Text('You have blocked this user'.tr, style: TextStyle(color: ZX.muted)),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(child: followBtn),
                    if (iFollow || followsMe) ...[
                      const SizedBox(width: 10),
                      Expanded(child: _pill('Message'.tr, Icons.chat_bubble_outline, _openChat)),
                    ],
                  ],
                ),
              ],
              if (!blockedByMe) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.only(bottom: 8),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: ZX.coral, width: 3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.grid_on, color: ZX.coral, size: 20),
                      const SizedBox(width: 8),
                      Text(isMe ? 'My posts'.tr : 'Posts'.tr,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ZX.ink)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (_posts.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: ZX.cardDecoration(radius: 22, shadow: false),
                    child: Center(
                      child: Text('No posts yet'.tr, style: const TextStyle(color: ZX.muted)),
                    ),
                  )
                else
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    children: [for (final p in _posts) _postTile(p)],
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ==================================================================== edit

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _first;
  late final TextEditingController _last;
  late final TextEditingController _bio;
  Uint8List? _newPhoto;
  bool _removePhoto = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _first = TextEditingController(text: (widget.profile['firstName'] ?? '').toString());
    _last = TextEditingController(text: (widget.profile['lastName'] ?? '').toString());
    _bio = TextEditingController(text: (widget.profile['bio'] ?? '').toString());
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _bio.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickPhoto() async {
    try {
      final f = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 85,
      );
      if (f == null) return;
      final bytes = await f.readAsBytes();
      if (bytes.length > 4 * 1024 * 1024) {
        _snack('Photo must be smaller than 4 MB'.tr);
        return;
      }
      setState(() {
        _newPhoto = bytes;
        _removePhoto = false;
      });
    } catch (e) {
      _snack(tx("Couldn't pick the photo: {err}".tr, {'err': e}));
    }
  }

  Future<void> _save() async {
    if (_first.text.trim().isEmpty) {
      _snack('First name cannot be empty'.tr);
      return;
    }
    setState(() => _saving = true);
    final res = await ZxApi.post('/api/profile/update', {
      'firstName': _first.text.trim(),
      'lastName': _last.text.trim(),
      'bio': _bio.text.trim(),
      if (_newPhoto != null) 'avatar': base64Encode(_newPhoto!),
      if (_removePhoto && _newPhoto == null) 'removeAvatar': true,
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (res.ok) {
      Session.name = (res.map['name'] ?? Session.name).toString();
      Session.avatar = (res.map['avatar'] ?? '').toString();
      Navigator.pop(context, true);
    } else {
      _snack(res.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentAvatar = _removePhoto ? '' : (widget.profile['avatar'] ?? '').toString();
    final name = '${_first.text} ${_last.text}'.trim();

    return Scaffold(
      backgroundColor: ZX.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context, false),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: ZX.cardDecoration(radius: 23, shadow: false),
                      child: const Icon(Icons.close, color: ZX.ink, size: 22),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text('Edit profile'.tr,
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: ZX.ink)),
                ],
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _pickPhoto,
                child: Stack(
                  children: [
                    if (_newPhoto != null)
                      CircleAvatar(radius: 56, backgroundImage: MemoryImage(_newPhoto!))
                    else
                      ZxAvatar(name.isEmpty ? 'U' : name, radius: 56, photo: currentAvatar),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: ZX.coral,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              if (_newPhoto != null || currentAvatar.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() {
                    _newPhoto = null;
                    _removePhoto = true;
                  }),
                  child: Text('Remove photo'.tr, style: TextStyle(color: ZX.muted)),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _first,
                maxLength: 40,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: ZX.ink),
                decoration: ZX.input('First name'.tr, icon: Icons.person_outline).copyWith(counterText: ''),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _last,
                maxLength: 40,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: ZX.ink),
                decoration: ZX.input('Surname (optional)'.tr, icon: Icons.badge_outlined).copyWith(counterText: ''),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bio,
                maxLines: 3,
                maxLength: 120,
                style: const TextStyle(color: ZX.ink),
                decoration: ZX.input('Bio — write something about yourself'.tr),
              ),
              const SizedBox(height: 20),
              ZxButton(_saving ? 'Saving...'.tr : 'Save'.tr, onPressed: _saving ? null : _save),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================================================================== blocked

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<Map<String, dynamic>> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await ZxApi.get('/api/blocked');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.ok) _list = res.list.map((e) => Map<String, dynamic>.from(e)).toList();
    });
  }

  Future<void> _unblock(Map<String, dynamic> u) async {
    final res = await ZxApi.post('/api/block', {'username': u['username']});
    if (!mounted) return;
    if (res.ok) {
      setState(() => _list.removeWhere((x) => x['username'] == u['username']));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
    }
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
        title: Text('Blocked users'.tr,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: ZX.ink)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: ZX.coral))
          : _list.isEmpty
              ? Center(child: Text("You haven't blocked anyone".tr, style: TextStyle(color: ZX.muted)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final u in _list)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: ZX.cardDecoration(radius: 20, shadow: false),
                        child: Row(
                          children: [
                            ZxAvatar((u['name'] ?? u['username']).toString(),
                                radius: 22, photo: (u['avatar'] ?? '').toString()),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text((u['name'] ?? u['username']).toString(),
                                      style: const TextStyle(fontWeight: FontWeight.w700, color: ZX.ink)),
                                  Text('@${u['username']}',
                                      style: const TextStyle(color: ZX.muted, fontSize: 12)),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () => _unblock(u),
                              child: Text('Unblock'.tr,
                                  style: TextStyle(color: ZX.coral, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
    );
  }
}
