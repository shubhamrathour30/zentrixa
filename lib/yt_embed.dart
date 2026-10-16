// YouTube ka official embed player.
// Web par asli iframe player; Android/iPhone par WebView wala official player; baaki platforms par "YouTube par kholo" card.
export 'yt_embed_stub.dart'
    if (dart.library.js_interop) 'yt_embed_web.dart'
    if (dart.library.io) 'yt_embed_mobile.dart';
