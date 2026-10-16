# Zentrixa

A full-stack social and chat app I built from scratch: a **Flutter** client (Android and Web) talking to a **C++17** REST server. It has posts, stories, reels, real-time chat, a follow system, an AI assistant, watch-together and board games, and a built-in admin dashboard.

> Status: personal project, actively developed. The server runs on my own machine and is exposed with Tailscale Funnel, so there is no public demo link.

## Screenshots

<table>
  <tr>
    <td align="center"><img src="docs/screenshots/reels.jpg" width="200"><br><sub>Reels</sub></td>
    <td align="center"><img src="docs/screenshots/chat.jpg" width="200"><br><sub>Chats</sub></td>
    <td align="center"><img src="docs/screenshots/profile.jpg" width="200"><br><sub>Profile</sub></td>
    <td align="center"><img src="docs/screenshots/ai.jpg" width="200"><br><sub>Zentrixa AI</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/screenshots/new-post.jpg" width="200"><br><sub>New post</sub></td>
    <td align="center"><img src="docs/screenshots/room.jpg" width="200"><br><sub>Zentrixa Room</sub></td>
    <td align="center"><img src="docs/screenshots/settings.jpg" width="200"><br><sub>Settings</sub></td>
  </tr>
</table>

## Features

**Social**
- Posts (photo and text), anonymous confessions, stories (24h), comments, likes, saves
- Reels: vertical full-screen video feed with swipe, like, comment, save and share. Own uploads plus free stock and YouTube Shorts
- Instagram-style follow system with follower/following lists and notifications
- Search for people, posts and reels; profile page with a post grid
- Block and report users and posts; reported content can be reviewed by the owner

**Chat**
- One-to-one chat and group chat, unread badges and an in-app message banner

**Zentrixa AI**
- Assistant powered by the Gemini API (with web search) that answers questions in the user's own language, and knows the app itself

**Zentrixa Room**
- Watch a movie together, play Ludo or Chess with friends

**Accounts and growth**
- Email OTP signup (Brevo), persistent login, password reset and change
- Coins, daily bonus and invite codes
- 18 languages (including Hindi, Hinglish, Tamil, Telugu, Urdu, Arabic and more)
- Help and Support form that emails the owner

**Owner tools**
- `/admin` dashboard protected by a secret key: counts, reported content with delete/dismiss, support tickets. Private chats and passwords are never shown

## Tech stack

| Part | Technology |
| --- | --- |
| Client | Flutter / Dart (Android + Web), WebView shell APK that loads the web build so updates need no reinstall |
| Server | C++17, [cpp-httplib](https://github.com/yhirose/cpp-httplib), libcurl |
| Storage | Plain TSV files in `data/` (no database server needed) |
| Auth | Token sessions (hashed on disk), slow salted password hashing, rate limits |
| Email | Brevo API |
| AI | Google Gemini API |
| Hosting | Tailscale Funnel (stable HTTPS link to a laptop server) |

## Project layout

```
lib/                    Flutter app source
web/cpp_backend/        C++ server (server.cpp) and helper headers
android/                Android project
*.bat                   Windows helper scripts (build, update, go online)
```

## Run it yourself

You need Flutter, and a C++17 compiler (g++) with libcurl.

1. **Server**
   ```
   cd web/cpp_backend
   g++ -std=c++17 -O2 server.cpp -o server.exe -lcurl -lws2_32
   server.exe
   ```
   It listens on port 3000. Optional key files placed next to `server.cpp` (never commit them): `brevo_key.txt` (OTP email), `gemini_key.txt` (AI), `pixabay_key.txt` (free reels), `admin_key.txt` (admin page).
2. **App**
   ```
   flutter pub get
   flutter run -d chrome
   ```
   The Firebase config files are not in this repo. Add your own `android/app/google-services.json` and `lib/firebase_options.dart` (see `flutterfire configure`).
3. **Android app that updates itself**: `build_apk.bat` builds a WebView shell APK, and `update_app.bat` rebuilds the web app and publishes it to the server.

## What I learned

- Designing a REST API and file-based storage in C++ with proper locking
- Auth, rate limiting and abuse protection (OTP, login lockout, report auto-hide)
- Flutter on web inside a WebView, including platform-view touch handling for embedded video
- Keeping secrets and user data out of version control

## Author

Shubham Rathour
