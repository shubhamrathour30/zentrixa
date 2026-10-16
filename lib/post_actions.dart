import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'zentrixa_theme.dart';
import 'zx_api.dart';
import 'i18n.dart';

/// Posts aur users par common actions: report, block, tip, delete, ⋮ menu.
/// Home feed, Reels, Profile aur Chat sab yahin se use karte hain.
class ZxActions {
  static void snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  static const List<String> reasons = [
    'Spam',
    'Abusive / harassment',
    'Inappropriate content',
    'Fake account / scam',
    'Something else',
  ];

  static Future<String?> _pickReason(BuildContext context, String title) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(title),
        children: [
          for (final r in reasons)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, r),
              child: Text(r.tr, style: const TextStyle(color: ZX.ink, fontSize: 16)),
            ),
        ],
      ),
    );
  }

  /// type = 'post' (target = post id) ya 'user' (target = username)
  static Future<bool> report(
    BuildContext context, {
    required String type,
    required String target,
  }) async {
    final reason = await _pickReason(
        context, type == 'post' ? 'Report this post'.tr : 'Report this user'.tr);
    if (reason == null) return false;
    final res = await ZxApi.post('/api/report', {
      'type': type,
      'target': target,
      'reason': reason,
    });
    if (!context.mounted) return false;
    snack(context, res.ok ? 'Report sent. Thank you!'.tr : res.message);
    return res.ok;
  }

  /// Confirm karke block karta hai. true => ab user blocked hai.
  static Future<bool> block(
    BuildContext context, {
    required String username,
    required String name,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tx('Block {name}?'.tr, {'name': name})),
        content: Text(
          'You will no longer see each other\'s posts, stories or chats, and any follows between you will be removed. You can unblock later from Profile > Blocked users.'.tr,
          style: TextStyle(color: ZX.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'.tr, style: TextStyle(color: ZX.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Block'.tr,
                style: TextStyle(color: ZX.coral, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true) return false;
    final res = await ZxApi.post('/api/block', {'username': username});
    if (!context.mounted) return false;
    if (res.ok) {
      final blocked = res.map['blocked'] == true;
      snack(context, blocked ? tx('{name} blocked'.tr, {'name': name}) : tx('{name} unblocked'.tr, {'name': name}));
      return blocked;
    }
    snack(context, res.message);
    return false;
  }

  /// Post delete (confirm ke saath). true => delete ho gayi.
  static Future<bool> deletePost(BuildContext context, int postId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete this post?'.tr),
        content: Text("This can't be undone.".tr, style: TextStyle(color: ZX.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'.tr, style: TextStyle(color: ZX.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete'.tr,
                style: TextStyle(color: ZX.coral, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true) return false;
    final res = await ZxApi.post('/api/posts/delete', {'postId': postId});
    if (!context.mounted) return false;
    if (!res.ok) snack(context, res.message);
    return res.ok;
  }

  /// Post / reel ko Saved mein daalo ya hatao (bookmark).
  static Future<void> toggleSave(
    BuildContext context,
    Map<String, dynamic> p, {
    VoidCallback? onChanged,
  }) async {
    final was = p['saved'] == true;
    p['saved'] = !was;
    onChanged?.call();
    final res = await ZxApi.post('/api/posts/save', {'postId': p['id']});
    if (res.ok) {
      p['saved'] = res.map['saved'] == true;
    } else {
      p['saved'] = was;
    }
    onChanged?.call();
    if (!context.mounted) return;
    if (res.ok) {
      snack(context, p['saved'] == true ? 'Saved! Find it in Profile > Saved'.tr : 'Removed from Saved'.tr);
    } else {
      snack(context, res.message);
    }
  }

  /// Share: link (ya text) clipboard par copy hota hai, kahin bhi paste karke bhejo.
  static Future<void> share(BuildContext context, Map<String, dynamic> p) async {
    final ext = p['external'] == true;
    final video = (p['video'] ?? '').toString();
    final image = (p['image'] ?? '').toString();
    final caption = (p['caption'] ?? '').toString();
    final name = (p['name'] ?? '').toString();
    String link = '';
    if (ext) {
      link = (p['sourceUrl'] ?? '').toString();
    } else if (video.isNotEmpty) {
      link = ZxApi.imageUrl(video);
    } else if (image.isNotEmpty) {
      link = ZxApi.imageUrl(image);
    }
    final head = caption.isNotEmpty ? caption : (name.isNotEmpty ? tx('By {name} on Zentrixa'.tr, {'name': name}) : 'Zentrixa');
    final text = link.isEmpty ? head : '$head\n$link';
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    snack(context, 'Link copied! Paste it anywhere to share.'.tr);
  }

  /// Post ke author ko coins gift karo.
  static Future<void> tip(BuildContext context, int postId) async {
    final amount = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Gift coins'.tr),
        children: [
          for (final a in const [5, 10, 20, 50])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, a),
              child: Row(
                children: [
                  const Icon(Icons.monetization_on, color: ZX.sun),
                  const SizedBox(width: 10),
                  Text(tx('{n} coins'.tr, {'n': a}),
                      style: const TextStyle(color: ZX.ink, fontSize: 17, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
        ],
      ),
    );
    if (amount == null) return;
    final res = await ZxApi.post('/api/tip', {'postId': postId, 'amount': amount});
    if (!context.mounted) return;
    snack(context, res.ok ? tx('Sent {n} coins! Balance: {balance}'.tr, {'n': amount, 'balance': res.map['coins']}) : res.message);
  }

  /// Post ka ⋮ menu: Delete (apni post) / Report / Block (dusre ki, non-anonymous).
  static Future<void> postMenu(
    BuildContext context,
    Map<String, dynamic> p, {
    required VoidCallback onDeleted,
    required void Function(String author) onBlocked,
  }) async {
    final mine = p['mine'] == true;
    final anon = p['anon'] == true;
    final author = (p['author'] ?? '').toString();
    final name = (p['name'] ?? author).toString();

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: ZX.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        side: BorderSide(color: ZX.border, width: ZX.borderWidth),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            if (mine)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: ZX.coral),
                title: Text('Delete post'.tr, style: TextStyle(color: ZX.ink)),
                onTap: () => Navigator.pop(ctx, 'delete'),
              )
            else ...[
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: ZX.coral),
                title: Text('Report post'.tr, style: TextStyle(color: ZX.ink)),
                onTap: () => Navigator.pop(ctx, 'report'),
              ),
              if (!anon && author.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.block, color: ZX.coral),
                  title: Text(tx('Block {name}'.tr, {'name': name}), style: const TextStyle(color: ZX.ink)),
                  onTap: () => Navigator.pop(ctx, 'block'),
                ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;

    if (choice == 'delete') {
      final deleted = await deletePost(context, (p['id'] as num).toInt());
      if (deleted) onDeleted();
    } else if (choice == 'report') {
      await report(context, type: 'post', target: '${p['id']}');
    } else if (choice == 'block') {
      final blocked = await block(context, username: author, name: name);
      if (blocked) onBlocked(author);
    }
  }
}
