import 'package:flutter/widgets.dart';

/// Web / desktop par shell nahi hota.
bool get shellSupported => false;

Widget buildWebShell() => const SizedBox.shrink();
