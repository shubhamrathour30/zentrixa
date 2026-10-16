import 'package:flutter/material.dart';

import 'i18n.dart';
import 'zentrixa_theme.dart';

/// Language chunne ki screen (Profile aur Login se khulti hai).
class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: L.lang,
      builder: (context, current, _) => Scaffold(
        backgroundColor: ZX.bg,
        appBar: AppBar(
          backgroundColor: ZX.bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: const IconThemeData(color: ZX.ink),
          title: Text('Language'.tr,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: ZX.ink)),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final l in kLanguages)
              GestureDetector(
                onTap: () => L.set(l.code),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: ZX.cardDecoration(
                    color: l.code == current ? ZX.coralSoft : Colors.white,
                    radius: 20,
                    shadow: false,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.native,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 17, color: ZX.ink)),
                            if (l.native != l.english)
                              Text(l.english,
                                  style: const TextStyle(color: ZX.muted, fontSize: 12)),
                          ],
                        ),
                      ),
                      if (l.code == current)
                        const Icon(Icons.check_circle, color: ZX.coral)
                      else
                        const Icon(Icons.radio_button_unchecked, color: ZX.muted),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
