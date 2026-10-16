// Zentrixa Room ke games: Chess (poore rules) aur Ludo (2 player). Ye file server se alag test ho sakti hai.
#pragma once
#include <cstdlib>
#include <string>
#include <vector>

namespace zxg {

// ============================================================ CHESS
// Board: b[r*8+c], r=0 => rank 8 (upar), c=0 => file a. Bade akshar = white, chhote = black, '.' = khali.
struct CMove {
    int from = 0, to = 0;
    char promo = 0;
};

struct Chess {
    char b[64];
    bool whiteTurn = true;
    bool castle[4] = {true, true, true, true};  // K Q k q
    int ep = -1;                                // en passant ka target square
    int halfmove = 0, fullmove = 1;
    std::string status = "playing";             // playing | checkmate | stalemate | draw | resigned
    std::string winner;                         // "w" | "b" | ""
    std::string lastMove;                       // "e2e4"
    bool allPromo = false;                      // sirf test: chaaron promotion banao (normal mein auto-queen)

    Chess() { reset(); }

    void reset() {
        const char* start = "rnbqkbnrpppppppp................................PPPPPPPPRNBQKBNR";
        for (int i = 0; i < 64; i++) b[i] = start[i];
        whiteTurn = true;
        for (bool& c : castle) c = true;
        ep = -1;
        halfmove = 0;
        fullmove = 1;
        status = "playing";
        winner.clear();
        lastMove.clear();
    }

    static bool isWhite(char p) { return p >= 'A' && p <= 'Z'; }
    static bool isBlack(char p) { return p >= 'a' && p <= 'z'; }
    static char up(char p) { return (p >= 'a' && p <= 'z') ? (char)(p - 32) : p; }
    static int rowOf(int s) { return s / 8; }
    static int colOf(int s) { return s % 8; }
    static bool inb(int r, int c) { return r >= 0 && r < 8 && c >= 0 && c < 8; }

    static std::string sqName(int s) {
        std::string n;
        n += (char)('a' + colOf(s));
        n += (char)('0' + (8 - rowOf(s)));
        return n;
    }
    static int sqFrom(const std::string& n) {
        if (n.size() != 2 || n[0] < 'a' || n[0] > 'h' || n[1] < '1' || n[1] > '8') return -1;
        return (8 - (n[1] - '0')) * 8 + (n[0] - 'a');
    }

    // Kya square `sq` ko `byWhite` ka koi mohra maar sakta hai?
    bool attacked(int sq, bool byWhite) const {
        int r = rowOf(sq), c = colOf(sq);
        // pawn
        int pr = byWhite ? r + 1 : r - 1;
        for (int dc = -1; dc <= 1; dc += 2) {
            if (inb(pr, c + dc) && b[pr * 8 + c + dc] == (byWhite ? 'P' : 'p')) return true;
        }
        // knight
        static const int kn[8][2] = {{-2, -1}, {-2, 1}, {-1, -2}, {-1, 2}, {1, -2}, {1, 2}, {2, -1}, {2, 1}};
        for (auto& d : kn) {
            int rr = r + d[0], cc = c + d[1];
            if (inb(rr, cc) && b[rr * 8 + cc] == (byWhite ? 'N' : 'n')) return true;
        }
        // king
        for (int dr = -1; dr <= 1; dr++)
            for (int dc = -1; dc <= 1; dc++) {
                if (!dr && !dc) continue;
                int rr = r + dr, cc = c + dc;
                if (inb(rr, cc) && b[rr * 8 + cc] == (byWhite ? 'K' : 'k')) return true;
            }
        // sliding: rook/queen (seedhe), bishop/queen (tirchhe)
        static const int dirs[8][2] = {{-1, 0}, {1, 0}, {0, -1}, {0, 1}, {-1, -1}, {-1, 1}, {1, -1}, {1, 1}};
        for (int k = 0; k < 8; k++) {
            bool straight = k < 4;
            int rr = r + dirs[k][0], cc = c + dirs[k][1];
            while (inb(rr, cc)) {
                char p = b[rr * 8 + cc];
                if (p != '.') {
                    if (byWhite ? isWhite(p) : isBlack(p)) {
                        char u = up(p);
                        if (u == 'Q' || (straight && u == 'R') || (!straight && u == 'B')) return true;
                    }
                    break;
                }
                rr += dirs[k][0];
                cc += dirs[k][1];
            }
        }
        return false;
    }

    int kingSq(bool white) const {
        char k = white ? 'K' : 'k';
        for (int i = 0; i < 64; i++) if (b[i] == k) return i;
        return -1;
    }
    bool inCheck(bool white) const {
        int k = kingSq(white);
        return k >= 0 && attacked(k, !white);
    }

    void pseudo(std::vector<CMove>& out) const {
        const bool w = whiteTurn;
        for (int s = 0; s < 64; s++) {
            char p = b[s];
            if (p == '.' || (w ? !isWhite(p) : !isBlack(p))) continue;
            int r = rowOf(s), c = colOf(s);
            char u = up(p);
            auto add = [&](int to, char promo = 0) {
                CMove m;
                m.from = s;
                m.to = to;
                m.promo = promo;
                out.push_back(m);
            };
            auto addP = [&](int to) {
                if (allPromo) { add(to, 'q'); add(to, 'r'); add(to, 'b'); add(to, 'n'); }
                else add(to, 'q');
            };
            if (u == 'P') {
                int dir = w ? -1 : 1;
                int startRow = w ? 6 : 1;
                int lastRow = w ? 0 : 7;
                int r1 = r + dir;
                if (inb(r1, c) && b[r1 * 8 + c] == '.') {
                    if (r1 == lastRow) addP(r1 * 8 + c);
                    else add(r1 * 8 + c);
                    int r2 = r + 2 * dir;
                    if (r == startRow && b[r2 * 8 + c] == '.') add(r2 * 8 + c);
                }
                for (int dc = -1; dc <= 1; dc += 2) {
                    int cc = c + dc;
                    if (!inb(r1, cc)) continue;
                    int t = r1 * 8 + cc;
                    char tp = b[t];
                    bool enemy = tp != '.' && (w ? isBlack(tp) : isWhite(tp));
                    if (enemy) {
                        if (r1 == lastRow) addP(t);
                        else add(t);
                    } else if (t == ep) {
                        add(t);
                    }
                }
            } else if (u == 'N') {
                static const int kn[8][2] = {{-2, -1}, {-2, 1}, {-1, -2}, {-1, 2}, {1, -2}, {1, 2}, {2, -1}, {2, 1}};
                for (auto& d : kn) {
                    int rr = r + d[0], cc = c + d[1];
                    if (!inb(rr, cc)) continue;
                    char tp = b[rr * 8 + cc];
                    if (tp == '.' || (w ? isBlack(tp) : isWhite(tp))) add(rr * 8 + cc);
                }
            } else if (u == 'K') {
                for (int dr = -1; dr <= 1; dr++)
                    for (int dc = -1; dc <= 1; dc++) {
                        if (!dr && !dc) continue;
                        int rr = r + dr, cc = c + dc;
                        if (!inb(rr, cc)) continue;
                        char tp = b[rr * 8 + cc];
                        if (tp == '.' || (w ? isBlack(tp) : isWhite(tp))) add(rr * 8 + cc);
                    }
                // castling
                if (w && s == 60 && !attacked(60, false)) {
                    if (castle[0] && b[63] == 'R' && b[61] == '.' && b[62] == '.' && !attacked(61, false) && !attacked(62, false)) add(62);
                    if (castle[1] && b[56] == 'R' && b[57] == '.' && b[58] == '.' && b[59] == '.' && !attacked(59, false) && !attacked(58, false)) add(58);
                }
                if (!w && s == 4 && !attacked(4, true)) {
                    if (castle[2] && b[7] == 'r' && b[5] == '.' && b[6] == '.' && !attacked(5, true) && !attacked(6, true)) add(6);
                    if (castle[3] && b[0] == 'r' && b[1] == '.' && b[2] == '.' && b[3] == '.' && !attacked(3, true) && !attacked(2, true)) add(2);
                }
            } else {
                static const int dirs[8][2] = {{-1, 0}, {1, 0}, {0, -1}, {0, 1}, {-1, -1}, {-1, 1}, {1, -1}, {1, 1}};
                int k0 = (u == 'B') ? 4 : 0;
                int k1 = (u == 'R') ? 4 : 8;
                for (int k = k0; k < k1; k++) {
                    int rr = r + dirs[k][0], cc = c + dirs[k][1];
                    while (inb(rr, cc)) {
                        char tp = b[rr * 8 + cc];
                        if (tp == '.') {
                            add(rr * 8 + cc);
                        } else {
                            if (w ? isBlack(tp) : isWhite(tp)) add(rr * 8 + cc);
                            break;
                        }
                        rr += dirs[k][0];
                        cc += dirs[k][1];
                    }
                }
            }
        }
    }

    // Chaal chalao (legal hone ki jaanch bahar hoti hai).
    void applyMove(const CMove& m) {
        char p = b[m.from];
        char target = b[m.to];
        char u = up(p);
        bool white = isWhite(p);
        bool capture = target != '.';
        // en passant
        if (u == 'P' && m.to == ep && target == '.' && colOf(m.from) != colOf(m.to)) {
            b[(rowOf(m.from)) * 8 + colOf(m.to)] = '.';
            capture = true;
        }
        b[m.to] = p;
        b[m.from] = '.';
        // promotion
        if (u == 'P' && (rowOf(m.to) == 0 || rowOf(m.to) == 7)) {
            char pr = m.promo ? up(m.promo) : 'Q';
            if (pr != 'Q' && pr != 'R' && pr != 'B' && pr != 'N') pr = 'Q';
            b[m.to] = white ? pr : (char)(pr + 32);
        }
        // castling: rook bhi chalao
        if (u == 'K' && colOf(m.from) == 4 && (colOf(m.to) == 6 || colOf(m.to) == 2)) {
            int row = rowOf(m.from);
            if (colOf(m.to) == 6) { b[row * 8 + 5] = b[row * 8 + 7]; b[row * 8 + 7] = '.'; }
            else { b[row * 8 + 3] = b[row * 8 + 0]; b[row * 8 + 0] = '.'; }
        }
        // castling rights
        if (u == 'K') { if (white) { castle[0] = castle[1] = false; } else { castle[2] = castle[3] = false; } }
        if (m.from == 63 || m.to == 63) castle[0] = false;
        if (m.from == 56 || m.to == 56) castle[1] = false;
        if (m.from == 7 || m.to == 7) castle[2] = false;
        if (m.from == 0 || m.to == 0) castle[3] = false;
        // en passant target
        ep = -1;
        if (u == 'P' && (m.to - m.from == 16 || m.from - m.to == 16)) ep = (m.from + m.to) / 2;
        halfmove = (u == 'P' || capture) ? 0 : halfmove + 1;
        if (!white) fullmove++;
        whiteTurn = !whiteTurn;
    }

    std::vector<CMove> legal() const {
        std::vector<CMove> ps, out;
        pseudo(ps);
        for (auto& m : ps) {
            Chess c = *this;
            c.applyMove(m);
            if (!c.inCheck(whiteTurn)) out.push_back(m);
        }
        return out;
    }

    bool insufficient() const {
        int minors = 0;
        for (int i = 0; i < 64; i++) {
            char u = up(b[i]);
            if (u == 'P' || u == 'R' || u == 'Q') return false;
            if (u == 'N' || u == 'B') minors++;
        }
        return minors <= 1;
    }

    void updateStatus() {
        if (status != "playing") return;
        std::vector<CMove> mv = legal();
        if (mv.empty()) {
            if (inCheck(whiteTurn)) { status = "checkmate"; winner = whiteTurn ? "b" : "w"; }
            else { status = "stalemate"; winner.clear(); }
        } else if (insufficient() || halfmove >= 100) {
            status = "draw";
            winner.clear();
        }
    }

    // "" => ok, warna error code
    std::string tryMove(const std::string& from, const std::string& to, char promo, bool byWhite) {
        if (status != "playing") return "GAME_OVER";
        if (byWhite != whiteTurn) return "NOT_YOUR_TURN";
        int f = sqFrom(from), t = sqFrom(to);
        if (f < 0 || t < 0) return "INVALID_MOVE";
        for (auto& m : legal()) {
            if (m.from == f && m.to == t) {
                CMove mm = m;
                if (promo) mm.promo = promo;
                applyMove(mm);
                lastMove = from + to;
                updateStatus();
                return "";
            }
        }
        return "ILLEGAL_MOVE";
    }

    void resign(bool whiteResigns) {
        if (status != "playing") return;
        status = "resigned";
        winner = whiteResigns ? "b" : "w";
    }

    std::string boardStr() const { return std::string(b, 64); }

    // JSON: {"board":"...","turn":"w","check":false,"status":"playing","winner":"","last":"e2e4","legal":["e2e4",...]}
    std::string toJson() const {
        std::string j = "{\"board\":\"" + boardStr() + "\",\"turn\":\"" + (whiteTurn ? "w" : "b") +
                        "\",\"check\":" + (inCheck(whiteTurn) ? "true" : "false") + ",\"status\":\"" + status +
                        "\",\"winner\":\"" + winner + "\",\"last\":\"" + lastMove + "\",\"legal\":[";
        if (status == "playing") {
            bool first = true;
            std::string seen;
            for (auto& m : legal()) {
                std::string s = sqName(m.from) + sqName(m.to);
                if (seen.find(s) != std::string::npos) continue;
                seen += s + ",";
                if (!first) j += ",";
                first = false;
                j += "\"" + s + "\"";
            }
        }
        return j + "]}";
    }
};

// ============================================================ LUDO (2 player: 0 = lal (host), 1 = neela (guest))
// Token ki position: -1 = ghar (yard), 0..50 = bahari raasta, 51..55 = ghar ka raasta, 56 = pahunch gaya.
struct Ludo {
    int tok[2][4];
    int turn = 0;
    int dice = 0;    // 0 = abhi dice phenkna hai, 1..6 = phenka hua, token chalana hai
    int sixes = 0;   // lagataar kitne 6 aaye
    std::string status = "playing";  // playing | finished
    int winner = -1;
    std::string note;  // "captured" | "nomove" | "threesixes" | "finished" | ""
    int lastPlayer = -1, lastToken = -1, lastFrom = 0, lastTo = 0;
    int lastDice = 0;  // sabse aakhri phenka hua dice (nomove par bhi dikhane ke liye)

    Ludo() { reset(); }
    void reset() {
        for (auto& p : tok) for (int& t : p) t = -1;
        turn = 0; dice = 0; sixes = 0; status = "playing"; winner = -1; note.clear();
        lastPlayer = -1; lastToken = -1; lastFrom = lastTo = 0; lastDice = 0;
    }

    static int offset(int p) { return p == 0 ? 0 : 26; }
    static int absPos(int p, int r) { return (r + offset(p)) % 52; }
    static bool safeAbs(int a) {
        return a == 0 || a == 8 || a == 13 || a == 21 || a == 26 || a == 34 || a == 39 || a == 47;
    }

    bool canMove(int p, int i, int d) const {
        int t = tok[p][i];
        if (t == 56) return false;
        if (t == -1) return d == 6;
        return t + d <= 56;
    }
    std::vector<int> movable(int p, int d) const {
        std::vector<int> v;
        for (int i = 0; i < 4; i++) if (canMove(p, i, d)) v.push_back(i);
        return v;
    }
    void passTurn() { turn = 1 - turn; dice = 0; sixes = 0; }

    // d = dice ki value (1..6, caller random deta hai). "" => ok.
    std::string roll(int player, int d) {
        if (status != "playing") return "GAME_OVER";
        if (player != turn) return "NOT_YOUR_TURN";
        if (dice != 0) return "ALREADY_ROLLED";
        if (d < 1 || d > 6) return "INVALID_DICE";
        note.clear();
        dice = d;
        lastDice = d;
        if (d == 6) sixes++;
        if (d == 6 && sixes >= 3) {  // teen 6 lagataar: chaal khatam
            note = "threesixes";
            passTurn();
            return "";
        }
        if (movable(player, d).empty()) {
            note = "nomove";
            passTurn();
        }
        return "";
    }

    std::string move(int player, int i) {
        if (status != "playing") return "GAME_OVER";
        if (player != turn) return "NOT_YOUR_TURN";
        if (dice == 0) return "ROLL_FIRST";
        if (i < 0 || i > 3 || !canMove(player, i, dice)) return "ILLEGAL_MOVE";
        note.clear();
        int d = dice;
        int from = tok[player][i];
        int to = (from == -1) ? 0 : from + d;
        tok[player][i] = to;
        lastPlayer = player; lastToken = i; lastFrom = from; lastTo = to;
        bool extra = (d == 6);
        if (to <= 50) {
            int a = absPos(player, to);
            if (!safeAbs(a)) {
                int o = 1 - player;
                for (int k = 0; k < 4; k++) {
                    int ot = tok[o][k];
                    if (ot >= 0 && ot <= 50 && absPos(o, ot) == a) {
                        tok[o][k] = -1;
                        note = "captured";
                        extra = true;
                    }
                }
            }
        }
        if (to == 56) {
            extra = true;
            if (note.empty()) note = "home";
        }
        bool all = true;
        for (int k = 0; k < 4; k++) if (tok[player][k] != 56) all = false;
        dice = 0;
        if (all) {
            status = "finished";
            winner = player;
            note = "finished";
            return "";
        }
        if (!extra) passTurn();
        return "";
    }

    void forfeit(int player) {
        if (status != "playing") return;
        status = "finished";
        winner = 1 - player;
        note = "resigned";
    }

    std::string toJson() const {
        std::string j = "{\"tokens\":[";
        for (int p = 0; p < 2; p++) {
            if (p) j += ",";
            j += "[";
            for (int i = 0; i < 4; i++) {
                if (i) j += ",";
                j += std::to_string(tok[p][i]);
            }
            j += "]";
        }
        j += "],\"turn\":" + std::to_string(turn) + ",\"dice\":" + std::to_string(dice) + ",\"status\":\"" + status +
             "\",\"winner\":" + std::to_string(winner) + ",\"note\":\"" + note + "\",\"last\":[" + std::to_string(lastPlayer) +
             "," + std::to_string(lastToken) + "," + std::to_string(lastFrom) + "," + std::to_string(lastTo) + "],\"lastDice\":" + std::to_string(lastDice) + ",\"movable\":[";
        if (status == "playing" && dice != 0) {
            bool first = true;
            for (int i : movable(turn, dice)) {
                if (!first) j += ",";
                first = false;
                j += std::to_string(i);
            }
        }
        return j + "]}";
    }
};

}  // namespace zxg
