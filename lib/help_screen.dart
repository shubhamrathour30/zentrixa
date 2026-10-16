import 'package:flutter/material.dart';

import 'zentrixa_theme.dart';
import 'zx_api.dart';

/// Help & Support: aam sawalon ke jawab + complaint / query / account problem bhejne ka form.
/// Login ke bina bhi khulta hai (login ki problem wale bhi likh sakein). Message owner ki email par jata hai.
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  static const List<(String, String, IconData)> _cats = [
    ('account', 'Account / login problem', Icons.manage_accounts_outlined),
    ('bug', 'Something is not working', Icons.bug_report_outlined),
    ('report', 'Report a user or post', Icons.flag_outlined),
    ('suggestion', 'Suggestion or feedback', Icons.lightbulb_outline),
    ('other', 'Other', Icons.help_outline),
  ];

  static const List<(String, String)> _faq = [
    ('I forgot my password',
        "On the login screen tap 'Forgot password?', enter your email and we'll send you an OTP code. Then set a new password."),
    ("I didn't get the OTP email",
        'Wait about 30 seconds and ask for a new code. Also check your Spam / Promotions folder and make sure the email is typed correctly.'),
    ('How do I follow someone?',
        "Search for a person or open their profile and tap Follow. People who follow you show up in your Followers list, people you follow in Following. Tap those numbers on your profile to see the lists."),
    ('How do I block or report someone?',
        'Open their profile, tap the three-dot menu and choose Block or Report. Blocked people are listed in Profile > Blocked users.'),
    ('How do I change my password?', 'Go to Profile > Change password.'),
    ('Who can I chat with?',
        'People you follow and people who follow you. Open the Chats tab and start a conversation.'),
    ('I want quick answers about the app',
        'Ask Zentrixa AI (the sparkle button on the Home screen). It explains every feature in your language.'),
  ];

  String _cat = 'account';
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _msg = TextEditingController();
  bool _sending = false;
  String _error = '';
  String _ticket = '';
  String _sentTo = '';

  @override
  void initState() {
    super.initState();
    if (Session.loggedIn) {
      _name.text = Session.name;
      _email.text = Session.email;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _msg.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    final msg = _msg.text.trim();
    final email = _email.text.trim();
    if (msg.length < 10) {
      setState(() => _error = 'Please write at least 10 characters so we can understand the problem.');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Please enter a valid email so we can reply to you.');
      return;
    }
    setState(() {
      _sending = true;
      _error = '';
    });
    final r = await ZxApi.post('/api/support', {
      'category': _cat,
      'name': _name.text.trim(),
      'email': email,
      'message': msg,
    });
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (r.ok) {
        _ticket = (r.map['ticket'] ?? '').toString();
        _sentTo = email;
        _msg.clear();
      } else if (r.error == 'RATE_LIMITED') {
        _error = 'You have sent several messages already. Please try again in an hour.';
      } else if (r.error == 'INVALID_MESSAGE') {
        _error = 'Your message must be between 10 and 2000 characters.';
      } else if (r.error == 'INVALID_EMAIL') {
        _error = 'Please enter a valid email so we can reply to you.';
      } else {
        _error = r.message;
      }
    });
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 10),
        child: Text(t, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ZX.ink)),
      );

  Widget _faqTile((String, String) f) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: ZX.cardDecoration(radius: 18, shadow: false),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          iconColor: ZX.coral,
          collapsedIconColor: ZX.muted,
          title: Text(f.$1, style: const TextStyle(fontWeight: FontWeight.w700, color: ZX.ink, fontSize: 15)),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(f.$2, style: const TextStyle(color: ZX.muted, fontSize: 14, height: 1.4)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _catChip((String, String, IconData) c) {
    final on = _cat == c.$1;
    return GestureDetector(
      onTap: () => setState(() => _cat = c.$1),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: on ? ZX.coral : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ZX.border, width: 1.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(c.$3, size: 16, color: on ? Colors.white : ZX.ink),
            const SizedBox(width: 6),
            Text(c.$2,
                style: TextStyle(
                    color: on ? Colors.white : ZX.ink, fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _sentCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: ZX.cardDecoration(radius: 24),
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: ZX.coral, size: 52),
          const SizedBox(height: 10),
          const Text('Message sent', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ZX.ink)),
          const SizedBox(height: 6),
          if (_ticket.isNotEmpty)
            Text('Ticket #$_ticket', style: const TextStyle(color: ZX.coral, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(
            "Thank you! We'll reply to $_sentTo. Please also check your Spam folder.",
            textAlign: TextAlign.center,
            style: const TextStyle(color: ZX.muted, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 14),
          ZxButton('Send another message', outlined: true, onPressed: () => setState(() => _ticket = '')),
        ],
      ),
    );
  }

  Widget _form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('What is this about?', style: TextStyle(color: ZX.muted, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [for (final c in _cats) _catChip(c)]),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          style: const TextStyle(color: ZX.ink),
          decoration: ZX.input('Your name', icon: Icons.person_outline),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          style: const TextStyle(color: ZX.ink),
          decoration: ZX.input('Your email (we reply here)', icon: Icons.mail_outline),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _msg,
          minLines: 5,
          maxLines: 8,
          maxLength: 2000,
          keyboardType: TextInputType.multiline,
          style: const TextStyle(color: ZX.ink),
          decoration: ZX.input('Tell us what happened. For account problems, include your username.'),
        ),
        if (_error.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(_error, style: TextStyle(color: Colors.red[700], fontSize: 13)),
        ],
        const SizedBox(height: 12),
        ZxButton(_sending ? 'Sending...' : 'Send message', onPressed: _sending ? null : _send),
      ],
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
        iconTheme: const IconThemeData(color: ZX.ink),
        title: const Text('Help & Support',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: ZX.ink)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
          children: [
            const Text(
              'Having a problem with your account or want to tell us something? Check the quick answers below, or send us a message.',
              style: TextStyle(color: ZX.muted, fontSize: 14, height: 1.4),
            ),
            _sectionTitle('Quick answers'),
            for (final f in _faq) _faqTile(f),
            _sectionTitle('Contact us'),
            _ticket.isNotEmpty ? _sentCard() : _form(),
          ],
        ),
      ),
    );
  }
}
