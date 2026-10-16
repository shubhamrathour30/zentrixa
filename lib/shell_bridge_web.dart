import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Android shell ka Back button: shell 'zx-back' event bhejta hai, yahan current screen band hoti hai.
/// Agar kuch band karne ko nahi (home par ho) to flag set nahi hota aur shell app band kar deta hai.
void initShellBridge(GlobalKey<NavigatorState> key) {
  web.window.addEventListener(
    'zx-back',
    ((web.Event e) {
      final nav = key.currentState;
      if (nav != null && nav.canPop()) {
        nav.pop();
        globalContext['__zxHandled'] = true.toJS;
      }
    }).toJS,
  );
}
