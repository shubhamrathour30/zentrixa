import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'help_screen.dart';
import 'i18n.dart';
import 'language_screen.dart';
import 'login_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'saved_screen.dart';
import 'zentrixa_theme.dart';
import 'zx_api.dart';

/// Instagram jaisa "Settings and activity" page - profile ke upar kone ke 3-line button se khulta hai.
/// Profile ki saari purani cheezein (coins, invite, saved, language, blocked, help, password, logout) ab yahan hain.
class SettingsScreen extends StatelessWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onChanged; // koi cheez badli to profile dobara load ho
  const SettingsScreen({super.key, required this.profile, required this.onChanged});

  void _go(BuildContext context, Widget page, {bool refresh = false}) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (refresh) onChanged();
  }

  void _logout(BuildContext context) {
    ZxApi.post('/api/logout', {}); // server par is device ka token band
    Session.clear();
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Log out'.tr),
        content: Text('Do you want to log out of Zentrixa?'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'.tr, style: const TextStyle(color: ZX.muted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _logout(context);
            },
            child: Text('Log out'.tr, style: const TextStyle(color: ZX.coral, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _changePassword(BuildContext context) {
    final oldC = TextEditingController();
    final newC = TextEditingController();
    void snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Change password'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldC,
              obscureText: true,
              style: const TextStyle(color: ZX.ink),
              decoration: ZX.input('Old password'.tr, icon: Icons.lock_outline),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newC,
              obscureText: true,
              style: const TextStyle(color: ZX.ink),
              decoration: ZX.input('New password (min 6)'.tr, icon: Icons.lock_reset),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'.tr, style: const TextStyle(color: ZX.muted)),
          ),
          TextButton(
            onPressed: () async {
              if (oldC.text.isEmpty || newC.text.length < 6) {
                snack('Enter your old password and a new one (min 6 characters)'.tr);
                return;
              }
              final res = await ZxApi.post('/api/change_password', {
                'oldPassword': oldC.text,
                'newPassword': newC.text,
              });
              if (!ctx.mounted) return;
              if (res.ok) {
                Navigator.pop(ctx);
                snack('Password changed!'.tr);
              } else {
                snack(res.message);
              }
            },
            child: Text('Update'.tr, style: const TextStyle(color: ZX.coral, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ widgets

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 18, 6, 8),
        child: Text(text,
            style: const TextStyle(color: ZX.muted, fontSize: 14, fontWeight: FontWeight.w600)),
      );

  Widget _row(IconData icon, String label, VoidCallback onTap, {String? value, Color? color, bool last = false}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          border: last ? null : const Border(bottom: BorderSide(color: Color(0x1F000000), width: 1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color ?? ZX.ink, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: TextStyle(color: color ?? ZX.ink, fontWeight: FontWeight.w600, fontSize: 16)),
            ),
            if (value != null && value.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(value, style: const TextStyle(color: ZX.muted, fontSize: 14)),
              ),
            if (color == null) const Icon(Icons.chevron_right, color: ZX.muted),
          ],
        ),
      ),
    );
  }

  Widget _group(List<Widget> rows) => Container(
        decoration: ZX.cardDecoration(radius: 20, shadow: false),
        clipBehavior: Clip.antiAlias,
        child: Column(children: rows),
      );

  @override
  Widget build(BuildContext context) {
    final langName = kLanguages
        .firstWhere((l) => l.code == L.lang.value, orElse: () => kLanguages.first)
        .native;
    return Scaffold(
      backgroundColor: ZX.bg,
      appBar: AppBar(
        backgroundColor: ZX.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: ZX.ink),
        titleSpacing: 0,
        title: Text('Settings and activity'.tr,
            style: const TextStyle(color: ZX.ink, fontWeight: FontWeight.w700, fontSize: 22)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
        children: [
          _header('Your account'.tr),
          _group([
            _row(Icons.person_outline, 'Edit profile'.tr, () async {
              final changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => EditProfileScreen(profile: profile)),
              );
              if (changed == true) onChanged();
            }),
            _row(Icons.lock_outline, 'Change password'.tr, () => _changePassword(context), last: true),
          ]),
          _header('How you use Zentrixa'.tr),
          _group([
            _row(Icons.bookmark_border, 'Saved'.tr, () => _go(context, const SavedScreen())),
            _row(Icons.notifications_none, 'Notifications'.tr, () => _go(context, const NotificationsScreen())),
            _row(Icons.language, 'Language'.tr, () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const LanguageScreen()));
              onChanged();
            }, value: langName, last: true),
          ]),
          _header('Coins and rewards'.tr),
          _group([
            _row(Icons.monetization_on_outlined, 'Coins & daily bonus'.tr,
                () => _go(context, CoinsRewardsScreen(profile: profile), refresh: true),
                value: '${profile['coins'] ?? 0}'),
            _row(Icons.group_add_outlined, 'Invite your friends'.tr,
                () => _go(context, CoinsRewardsScreen(profile: profile), refresh: true),
                last: true),
          ]),
          _header('Who can see your content'.tr),
          _group([
            _row(Icons.block, 'Blocked users'.tr,
                () => _go(context, const BlockedUsersScreen(), refresh: true),
                last: true),
          ]),
          _header('More info and support'.tr),
          _group([
            _row(Icons.help_outline, 'Help & Support', () => _go(context, const HelpScreen()), last: true),
          ]),
          _header('Login'.tr),
          _group([
            _row(Icons.logout, 'Log out'.tr, () => _confirmLogout(context), color: ZX.coral, last: true),
          ]),
        ],
      ),
    );
  }
}

// ============================================================ coins + invite

class CoinsRewardsScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  const CoinsRewardsScreen({super.key, required this.profile});

  @override
  State<CoinsRewardsScreen> createState() => _CoinsRewardsScreenState();
}

class _CoinsRewardsScreenState extends State<CoinsRewardsScreen> {
  late Map<String, dynamic> _p;

  @override
  void initState() {
    super.initState();
    _p = Map<String, dynamic>.from(widget.profile);
    _reload();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _reload() async {
    final r = await ZxApi.get('/api/profile', query: {'username': Session.username});
    if (!mounted || !r.ok) return;
    setState(() => _p = Map<String, dynamic>.from(r.map));
  }

  Future<void> _claimBonus() async {
    final r = await ZxApi.post('/api/daily_bonus', {});
    if (!mounted) return;
    if (!r.ok) {
      _snack(r.message);
      return;
    }
    if (r.map['claimed'] == true) {
      _snack(tx('You got +{n} coins!'.tr, {'n': r.map['added']}));
    } else {
      final wait = (r.map['waitSeconds'] ?? 0) as num;
      final h = wait.toInt() ~/ 3600;
      final m = (wait.toInt() % 3600) ~/ 60;
      _snack(tx("You already claimed today's bonus. Next one in {h}h {m}m.".tr, {'h': h, 'm': m}));
    }
    _reload();
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: (_p['inviteCode'] ?? Session.username).toString()));
    _snack('Invite code copied!'.tr);
  }

  Widget _pill(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: ZX.coral,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ZX.border, width: ZX.borderWidth),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final code = (_p['inviteCode'] ?? Session.username).toString();
    return Scaffold(
      backgroundColor: ZX.bg,
      appBar: AppBar(
        backgroundColor: ZX.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: ZX.ink),
        titleSpacing: 0,
        title: Text('Coins and rewards'.tr,
            style: const TextStyle(color: ZX.ink, fontWeight: FontWeight.w700, fontSize: 22)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: ZX.cardDecoration(color: const Color(0xFFFFF0D0), radius: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.monetization_on, color: Color(0xFFE59A00), size: 34),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tx('{n} coins'.tr, {'n': _p['coins'] ?? 0}),
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: ZX.ink)),
                          Text('Gift others on great posts'.tr,
                              style: const TextStyle(color: ZX.muted, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _pill('Claim daily bonus (+5)'.tr, Icons.card_giftcard, _claimBonus),
                const SizedBox(height: 8),
                Text(
                  'Coins can only be gifted inside the app for now. Cash-out is not available yet.'.tr,
                  style: const TextStyle(color: ZX.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: ZX.cardDecoration(color: ZX.coralSoft, radius: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Invite your friends'.tr,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ZX.ink)),
                const SizedBox(height: 4),
                Text(
                  'Your friend enters this code at signup: you get +20 and they get +10 coins.'.tr,
                  style: const TextStyle(color: ZX.muted, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: ZX.border, width: ZX.borderWidth),
                        ),
                        child: Text(code,
                            style: const TextStyle(fontWeight: FontWeight.w700, color: ZX.ink, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _copyCode,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        decoration: BoxDecoration(
                          color: ZX.coral,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: ZX.border, width: ZX.borderWidth),
                        ),
                        child: Text('Copy'.tr,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(tx('Friends invited so far: {n}'.tr, {'n': _p['invited'] ?? 0}),
                    style: const TextStyle(color: ZX.muted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
