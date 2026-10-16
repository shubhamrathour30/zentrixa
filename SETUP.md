# Zentrixa v2 - naye features aur setup

## Install (sabse aasaan)
1. Zip ko kahin extract karo (jaise Desktop par).
2. Us folder mein PowerShell kholo (folder mein Shift + Right click > "Open PowerShell window here") aur chalao:
   ```
   powershell -ExecutionPolicy Bypass -File .\install.ps1
   ```
   Ye script: purana server band karta hai, Flutter files `C:\my_app\lib` mein, server files `C:\my_app\web\cpp_backend` mein copy karta hai, server compile karta hai aur `flutter pub get` chalata hai.
3. Server chalao: `cd C:\my_app\web\cpp_backend` phir `.\server.exe`
   Dikhna chahiye: `Zentrixa Server running on port 3000...`
4. App chalao: `cd C:\my_app` phir `flutter run -d chrome --web-browser-flag="--disable-web-security"`

Script na chale to haath se: `lib\*.dart` -> `C:\my_app\lib`, `pubspec.yaml` -> `C:\my_app`, `cpp_backend\*` -> `C:\my_app\web\cpp_backend`, phir
`g++ -std=c++17 -O2 server.cpp -o server.exe -lcurl -lws2_32` (link error aaye to end mein `-lcrypt32` jodo) aur `flutter pub get`.

Purana data (users, posts) chalta rahega. Bilkul saaf shuruaat chahiye to server band karke `data` folder delete kar do.

## Kya naya hai
| Feature | Kahan hai |
|---|---|
| **Profile**: photo, bio, naam badalna, followers/following/posts ginti (Followers ya Following dabao to list khulti hai) | Neeche last tab (person icon). Kisi ka bhi naam/photo dabao to uska profile |
| **Stories** (24 ghante, aapke followers ko dikhti hain, kisne dekhi ye bhi dikhta hai) | Home ke upar "Your story" |
| **Notifications** (like, comment, naya follower with "Follow back" button, coins, group, room invite) + badge | Home par bell icon |
| **Reels** (video upload + upar-neeche swipe) | Reels tab. Upload: + dabao, "Reel" chuno |
| **Confessions / Anonymous post** (naam kisi ko nahi dikhta) | + dabao, "Anonymous" switch on karo. Home par "Confessions" filter |
| **Block / Report** | Post ke `...` menu mein, kisi ke profile ke `...` menu mein, chat ke `...` menu mein |
| **Coins**: daily bonus (+5), dost ko invite code (+20 aapko, +10 dost ko), post par coins gift | Profile tab; post par "Gift" |
| Naya signup field: **Invite code** | Signup screen (optional) |

Block karne par: dono ek doosre ki posts/stories/profile/search/chat nahi dekhte, aur dono taraf ke follows hat jate hain.
Report: 3 alag logon ke report karne par post sabke feed se chhup jati hai. Saare reports server ke `data\reports.tsv` mein jama hote hain (aap khud dekh kar action le sakte ho).

## Test kaise karein (2 accounts)
1. Chrome window 1: signup (OTP server ki black window mein dikhta hai). Window 2 (Incognito): doosra account.
   Doosre signup par pehle account ka **username** (profile mein `@...`) invite code mein daalo -> pehle ko +20 coins notification milega.
2. Window 1: Chats tab > person+ icon se dusre ko dhoondo > Follow. Window 2: bell mein "started following you" aayega, wahin se "Follow back" dabao.
3. Dono mein Profile tab > Edit profile > photo + bio daalo.
4. Window 1: Home > Your story > photo chuno > Share. Window 2: Home par ring wala avatar dikhega.
5. Window 1: + > Reel > chhoti MP4 video (12 MB tak) > upload. Window 2: Reels tab. (Browser mein pehle video mute hoti hai - upar speaker icon dabao.)
6. Window 1: + > Post > Anonymous on > likho > Post. Window 2: Home > Confessions: "Anonymous" dikhega.
7. Window 2: post par like/comment/Gift karo. Window 1: bell par badge aayega.
8. Window 2: profile ke `...` > Block. Dono ek doosre ko search mein nahi dikhte.

## Reels mein random achi videos (Pixabay ya Pexels - free)
Reels mein aapke users ki videos ke saath free stock videos bhi aati hain (nature, travel, food, fitness...), neeche scroll karne par aur aati rehti hain.
1. **Pixabay (abhi ye use karo - Pexels ne naye keys band kar rakhe hain):** pixabay.com par free account banao, phir https://pixabay.com/api/docs/ kholo - login ke baad key wahin upar dikhti hai. Copy karo.
2. `C:\my_app\web\cpp_backend\start_server.bat` par double-click karo. Pehli baar key paste karne ko bolega (`pixabay_key.txt` mein save hoti hai), phir server compile karke chala deta hai. Agli baar se bas isi par double-click.
   Key badalni ho to `pixabay_key.txt` Notepad se edit karo. Pexels ki key ho to `pexels_key.txt` mein daalo (wo pehle use hoti hai).
   Bina key ke Reels mein sirf users ki upload ki hui videos dikhengi.
- Videos par "Free video - Pixabay/Pexels" likha aata hai, Credit button se video banane wale ka naam dikhta hai.
- Pixabay ki videos zyadatar landscape hoti hain, app unhe screen par fill kar deta hai (side se thoda kat sakti hain).
- Pixabay ke rule: har result 24 ghante cache hona chahiye - server ye khud karta hai. Limit 100 requests/minute hai.
- Instagram/YouTube/TikTok ki videos legally use nahi kar sakte, isliye free library li hai.

## Naya (v3): awaaz, like/comment/save/share, groups, language
1. `flutter pub get` zaroor chalao (naya package `shared_preferences` aur `assets/audio/` pubspec mein jud gaye hain). Server dobara compile/restart karo (`start_server.bat`).
2. **Reels ki awaaz:** aapke upload ki hui videos apni asli awaaz ke saath chalti hain. Free stock videos (Pixabay/Pexels) mein asli awaaz hoti hi nahi, isliye unke neeche halka background music chalta hai. Upar speaker icon se sab jagah awaaz on/off hoti hai. Browser pehle awaaz rok sakta hai - ek baar speaker dabao.
3. **Har reel par:** Like, Comment, Save, Share (link copy), Gift. Free stock videos par bhi ye sab chalte hain. Save ki hui cheezein Profile > Saved mein.
4. **Home par "People you may know":** app ke asli registered users (jinke saath mutual friends zyada, wo pehle). "Follow" dabao to turant follow ho jata hai.
5. **Group chat:** Chats tab > "New group" > naam + dost chuno > Create. Group ke andar members add/remove (sirf admin), leave, aur "X added Y" jaise system messages. Max 100 members.
6. **Language:** poori app English mein hai. Profile > Language (ya Login screen ke upar "Language") se chuno: English, Hinglish, Hindi, Bengali, Marathi, Gujarati, Tamil, Telugu, Urdu, Spanish, French, German, Portuguese, Russian, Arabic, Indonesian, Chinese, Japanese. Urdu/Arabic right-to-left dikhte hain. Chuni hui language yaad rehti hai. Jo text translate nahi hua wo English mein dikhta hai. Nayi language jodni ho to `lib/i18n_data.dart` mein ek aur block jodo aur `lib/i18n.dart` ki list mein naam.
7. Users ka likha content (posts, comments, chat) translate nahi hota - wo jaisa likha gaya waisa dikhta hai.

## Login yaad rehta hai
- Ek baar login karne ke baad app khud login rakhti hai jab tak aap Profile > Log out na dabao. Server restart par bhi login nahi jaata (tokens `data/tokens.tsv` mein hash karke save hote hain, 90 din chalte hain, ek user ke max 10 devices).
- **Chrome mein chalate waqt:** `flutter run -d chrome` har baar naya temporary Chrome kholta hai, isliye login bhool jata hai. Iske bajay `run_app.bat` chalao (ya `flutter run -d web-server --web-port 5000`) aur apne normal Chrome mein http://localhost:5000 kholo. Port hamesha 5000 hi rakho, port badla to login alag se maanga jayega.
- Phone/emulator par ye problem nahi hoti.

## Public link (dusron ko dikhane ke liye)
1. `C:\my_app\share_app.bat` double-click karo. Ye website build karta hai, server ko website bhi serve karwata hai, aur Cloudflare tunnel se `https://....trycloudflare.com` link deta hai (pehli baar `cloudflared` winget se install hota hai).
2. Link ek hi hota hai (app + server dono), kisi ko bhi bhej sakte ho. Link tab tak chalta hai jab tak aapka laptop on hai aur dono windows khuli hain. Har baar naya link banta hai.
3. Dusre log signup karenge to unhe OTP email chahiye: bat file Brevo API key maangti hai (nayi key, purani leak wali nahi). Bina key ke OTP sirf server window mein dikhta hai.
4. Pakka (24x7) link chahiye to Render/Railway/Fly par `cpp_backend/Dockerfile` se deploy karna padega (persistent disk `/app/data` par lagana, warna restart par data jaata hai).

## OTP email (Brevo) theek karna
`C:\my_app\setup_email.bat` chalao: ye Brevo key aur sender email `web\cpp_backend\brevo_key.txt` / `sender_email.txt` mein save karta hai (env variable ki zaroorat nahi). Phir server restart karo. Agar OTP phir bhi na aaye to server window mein "Email send failed" ke neeche "FIX:" line padho:
- 401 + IP: Brevo > Security > Authorised IPs > Deactivate blocking.
- 401: API key galat/purani, nayi banao.
- 400 sender: sender email Brevo mein verify nahi hai.
Free plan mein roz 300 email ki limit hai. Gmail sender kabhi kabhi spam mein jaata hai - Spam folder dekho.

## YouTube Shorts (Reels mein asli viral videos) - bina key, bina card
1. `cpp_backend` folder (jahan server.cpp hai) mein `youtube_links.txt` file hai - usme 87 YouTube Shorts links pehle se daale hain (funny, dance, food, cricket, music...). Koi API key / Google Cloud / card nahi chahiye.
2. Server dobara chalao (`start_server.bat`), `flutter pub get` karo, `run_app.bat` se app kholo, Reels tab. Pehle ye links aate hain (title + channel ka naam YouTube ke oEmbed se aata hai), uske baad Pixabay/Pexels wali videos.
3. Naye links jodne ke liye `youtube_links.txt` kholo aur nayi lines paste karo (youtube.com/shorts/..., youtu.be/..., watch?v=... - sab chalte hain). Server restart nahi chahiye.
4. Jis video ka owner embed band rakhta hai, ya jo private/delete ho gayi, wo apne aap skip ho jaati hai.
5. (Optional) Agar baad mein YouTube Data API key lena ho to `setup_youtube.bat` - tab links ke baad API se bhi naye shorts aayenge. Zaroori nahi.
6. YouTube ke rules ki wajah se player ke upar koi button nahi lagta - buttons uske bagal mein hain. Video par swipe karne se page nahi badalta (video ka touch YouTube ka hai): bagal ke ▲ ▼ buttons use karo.
7. Abhi ye sirf web version mein chalta hai. Phone app (Android/iOS) ke liye alag player package lagana padega.
8. Awaaz speaker icon se on/off; browser kabhi pehle awaaz rok sakta hai - speaker ek baar dabao.
9. Public app mein YouTube dikhane par YouTube ki Terms of Service aur Google Privacy Policy ka link app/website par dena hota hai (policy page banate waqt).

## Followers / Following (friend request hata di gayi)
- Ab Instagram jaisa hai: kisi ko search karke ya profile kholkar **Follow** dabao - approval nahi chahiye. Jisne aapko follow kiya wo aapki **Followers** list mein, jise aapne follow kiya wo **Following** list mein. Profile par Followers / Following number dabao to list khulti hai (usi list se Follow / Following / Follow back bhi kar sakte ho).
- Koi follow kare to bell mein "X started following you" notification aati hai, **Follow back** button ke saath. Baar baar follow/unfollow karne par notification spam nahi hota (24 ghante mein ek hi).
- Chat unke saath hoti hai jinhe aap follow karte ho **ya** jo aapko follow karte hain. Group aur Room invite mein bhi yahi log dikhte hain. Stories wo dekhte hain jo aapko follow karte hain. Home feed ka "Friends" filter ab **Following** hai.
- **Purane users:** pehle jo dost the wo server start hote hi apne aap ek-doosre ko follow karne lagte hain (chats nahi jaati); pending requests bhejne wale ka follow ban gayi. Purani file `data\requests_migrated.tsv` mein backup rehti hai.
- **Zentrixa AI** se koi pooche "tujhe kisne banaya" / "who made you" to wo Shubham Rathour batata hai (usi language mein).

## Message badge aur notification
- Neeche **Chats icon** ab gol bubble hai (select hone par bhara hua, halka zoom). Naya message aane par uspar laal badge mein ginti aati hai: 1 message to 1, 2 to 2 (99 se zyada par 99+).
- Chats list mein har chat ke saamne bhi us chat ke unread messages ki ginti dikhti hai, aur last message bold ho jata hai. Chat kholte hi wo padhe hue ho jate hain.
- App khuli ho aur naya message aaye (aur wahi chat khuli na ho) to upar se ek **banner** utarta hai: naam + message. Banner dabao to seedha chat khulti hai. 5 second mein khud hat jata hai.
- Ye sab app ke andar chalta hai (har 5 second mein check). App band hone par phone/browser notification ke liye Firebase push chahiye, wo abhi nahi hai. Group chat ka unread abhi nahi ginta.
- Purani chats pehli baar server chalne par "padhi hui" maani jati hain, isliye purane messages ka badge nahi aata. Data `data\chat_reads.tsv` mein rehta hai.

## Zentrixa Room (dost ke saath movie / Ludo / Chess) + Zentrixa AI
Home page par upar notification (bell) ke bagal mein 2 naye button hain: **gamepad = Zentrixa Room**, **sitara = Zentrixa AI**.

**Update lagane ke steps:** purana server band karo -> `web\cpp_backend\start_server.bat` double-click (naya `zx_games.h` bhi wahin hai, wahi compile ho jata hai) -> `C:\my_app` mein `flutter pub get` -> `run_app.bat`.

### Movie saath dekhna
1. Home > gamepad > **Movie** tab. Koi free movie chuno ya "Paste a YouTube or video link" se apna link daalo. Room ban jata hai aur code milta hai (jaise `ZX-4821`).
2. Dost ko bulao: room ke andar apni followers/following list se "Invite" dabao (usko notification milta hai, dabate hi room khul jata hai) ya code bhejo (dost gamepad > "Join your friend's room" mein code daale).
3. Play/pause/seek dono ke liye ek saath chalta hai (server har cheez ka waqt rakhta hai, app 1 second mein check karti hai). Neeche side-chat hai. Fullscreen button dabane par phone landscape mein ghoom jata hai, chat chhoti patti mein upar-left dikhti hai (YouTube video mein chat patti nahi, YouTube ki policy ki wajah se).
4. **Ads:** movie ke beech mein short ad break aata hai, **dono ke liye ek hi waqt par**, dono ki video ruk jati hai aur break ke baad wahin se chalti hai. Pehla ad 60 second baad, phir har 5 minute mein, 15 second ka. Badalne ke liye environment variable: `ROOM_AD_FIRST`, `ROOM_AD_EVERY`, `ROOM_AD_LEN` (seconds), band karne ke liye `ROOM_ADS=off`.
5. **Ads ka content:** `cpp_backend\ads.txt` mein har line: `Title | Message | Link | ImageURL` (link aur image optional). Ye aapke apne sponsors ke ads hain - jis dukaan/brand se paise tay karo, uska ad yahan daalo. Ye AdSense/AdMob nahi hai. Asli ad network (AdMob) ke liye alag account aur Android/iOS app chahiye. **YouTube link ke saath dhyan:** YouTube ki Terms of Service embed player ke saath paise kamane (ads bechne) par pabandi lagati hain - paise kamane ke liye apni/free-licence wali direct video (`movies.txt` ya .mp4 link) use karo. YouTube link dostana dekhne ke liye theek hai, par usse kamai karne se pehle YouTube ke rules khud padh lo.
6. **Free movies list:** `cpp_backend\movies.txt` mein har line: `Title | Info | VideoURL | PosterURL`. File khali ho to 4 free Blender movies (Big Buck Bunny, Sintel, Elephants Dream, Tears of Steel) aati hain. Sirf wahi video daalo jiske aap rights ke maalik ho ya jo free/CC license ki ho - Netflix/Hotstar/pirated movie mat daalna.
7. **YouTube link:** abhi sirf web version mein chalta hai (phone app mein YouTube player ke liye alag package lagana padega). Direct video link (.mp4) web aur phone dono par chalta hai.
8. iPhone Safari mein browser fullscreen/rotate kabhi kabhi khud se rok deta hai - wahan landscape ke liye phone ghumao.

### Ludo aur Chess (free, paise nahi)
- Gamepad > **Game** tab > Ludo ya Chess. Room banao, dost ko invite karo, khelo. Saari chaal ke niyam server pe chalte hain (dice bhi server fenkta hai), isliye koi cheating nahi kar sakta.
- Ludo: 2 player, 4-4 goti, 6 par dobara chance, teen 6 par chance gayi, goti kaatna, surakshit star khane. Chess: poore niyam (castling, en passant, promotion - auto Queen, check/checkmate/draw).
- **Paise lagake khelna (bet) nahi banaya:** India mein real-money games par Promotion and Regulation of Online Gaming Act 2025 ke tahat rok hai, isliye ye sirf free hai.
- Free Fire / PUBG isme nahi chalte (unke servers alag hain, app ke andar nahi khulte).

### Zentrixa AI
- Sirf Zentrixa ke baare mein dost ki tarah batata hai; jis language mein pucho usi mein jawab deta hai. Zentrixa se bahar ke sawal par politely mana karta hai.
- **Behtar jawab ke liye (free):** https://aistudio.google.com/apikey se Gemini key banao, phir `C:\my_app\setup_ai.bat` chalao aur key paste karo (`web\cpp_backend\gemini_key.txt` mein save hoti hai). Server restart karo. Bina key ke bhi AI chalta hai, par tab sirf andar bani FAQ (English / Hindi / Hinglish) se jawab deta hai.
- Model badalna ho to `gemini_model.txt` mein model ka naam likho. Ek user ek minute mein limit tak hi sawal pooch sakta hai (spam se bachne ke liye).
- Dhyan: Gemini key lagane par user ka likha sawal Google ko jata hai - privacy policy mein ye likhna.

## Jo abhi NAHI hai (sach-sach)
- **Asli push notifications** (phone band hone par bhi): iske liye Firebase Cloud Messaging ka setup aur server-side key chahiye. Abhi notifications app ke andar aate hain (har 15 second mein check).
- **Voice message**: nahi bana.
- **Asli ad network (AdMob/AdSense), premium subscription, paise se coins khareedna / coins ko cash karna**: iske liye AdMob / Google Play Billing / payment gateway ke account chahiye. Room ke ad break abhi aapke apne sponsor ads (`ads.txt`) dikhate hain. Coins sirf app ke andar hain aur unki koi paisa-value nahi hai.
- **Video limit**: 12 MB tak (lagbhag 15-20 second). Badi video ke liye server ko cloud storage (S3 jaisa) par lagana padega.
- Server file-based hai (chhote app ke liye theek). Hazaaron users ke liye database (PostgreSQL) chahiye.
- Internet par daalne ke liye HTTPS aur persistent disk zaroori hai (Dockerfile diya hua hai, `/app/data` par disk lagao).
- Play Store/App Store ke liye: Privacy Policy, account delete karne ka option, aur Android/iOS mein photo/video/camera ki permission settings chahiye.

## Zaroori suraksha
Purani Brevo API key jo pehle code mein thi leak ho chuki hai - Brevo dashboard se use delete karke nayi banao, aur sirf environment variable (`$env:BREVO_API_KEY`) mein rakho.

Zentrixa Room abhi memory mein rehte hain: server restart par chalte hue rooms band ho jate hain (dost ko dobara naya room banana padega).

## Phone ke liye APK banana (Android)
1. `C:\my_app\build_apk.bat` double-click karo (ya PowerShell mein `cd C:\my_app` phir `.\build_apk.bat`). Pehli baar ye Java + Android tools khud install karta hai (10-15 min), phir APK banata hai (10-20 min).
2. Beech mein "Server link" puchta hai: `share_app.bat` wala public link (`https://....trycloudflare.com`) ya laptop ka WiFi IP (`http://192.168.x.x:3000`, phone usi WiFi par ho). Enter dabaoge to baad mein bhi daal sakte ho.
3. Taiyar APK: `C:\my_app\Zentrixa.apk`. Phone mein bhejo, kholo, "Install unknown apps" Allow karo.
4. Public link har baar badalta hai: app ke Login screen ke neeche **Server: ...** dabao, naya link paste karo, Test, Save. APK dobara banane ki zaroorat nahi. Laptop on aur server chalta hona chahiye.
5. Phone par YouTube Shorts / Room movie ab asli player (WebView) mein chalte hain. Agar kisi video par "Video unavailable" dikhe to wo video YouTube ne embed block kiya hai - agla reel dekho ya "Open on YouTube" (YouTube app khulta hai). Push notification app band hone par nahi aati.

## Auto-update (Instagram jaisa): APK ek baar, baaki sab server se
Phone ka app ab "shell" hai: wo aapke server se poora Zentrixa khol leta hai. Aap server par naya version rakho to phone par agli baar khulte hi naya app dikhta hai - APK / link dobara nahi.

**Ek baar ka setup (aakhri baar):**
1. Server chalu rakho: `web\cpp_backend\start_server.bat`.
2. `.\go_online.bat` - Tailscale install + login + **fixed link** (`https://....ts.net`, kabhi nahi badalta). Agar login.tailscale.com wala link aaye to browser mein kholo, Enable dabao, script dobara chalao.
3. `.\update_app.bat` - website build karke server ke `public` folder mein daalta hai (3-5 min). Server pehle `public` ke bina chala tha to `start_server.bat` ek baar dobara chalao.
4. `.\build_apk.bat` - "Server link" par fixed link daalo. `Zentrixa.apk` phone mein install karo.

**Roz ka kaam (kuch bhi badlo):** sirf `.\update_app.bat`. Server ka code (`server.cpp`) badla ho to `start_server.bat` bhi. Phone par app band karke dobara kholo - naya app aa jata hai.

Dhyan: laptop on + server chalta hona chahiye (24x7 chahiye to cloud server alag se). App mein "Can't reach Zentrixa" aaye to Retry / Change link / "Use classic mode" (purana native app, update ke liye naya APK chahiye). Back button: pehle screen band hoti hai, home par app band.

## Help & Support (complaint / query / account problem)
- App mein: Profile > **Help & Support**, aur Login screen par **Need help? Contact us** (login na ho paye tab bhi). Quick answers (FAQ) + form (category, naam, email, message).
- Har message `web\cpp_backend\data\support.tsv` mein save hota hai (ticket `ZX-S1001`, ...) aur aapki email par aata hai (Brevo se). Us email par **Reply** dabao to seedha user ko jata hai.
- Email kis address par aaye: default wahi jo `sender_email.txt` mein hai. Alag chahiye to `web\cpp_backend\support_email.txt` banao, usme sirf wo email likho. Brevo key na ho to complaint server window mein print hoti hai.
- Spam se bachav: ek insaan se ghante mein 5 message, poori app se 60.
- Update lagane ke liye: `start_server.bat` (server badla) + `update_app.bat`.
