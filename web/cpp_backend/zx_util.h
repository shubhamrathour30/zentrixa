// zx_util.h - Zentrixa server helpers (hash, JSON, base64, file storage)
// server.cpp ke saath isi folder mein rakho.
#pragma once

#include <algorithm>
#include <cctype>
#include <cstdint>
#include <cstdlib>
#include <ctime>
#include <random>
#include <sstream>
#include <string>
#include <vector>

namespace zx {

// ---------------------------------------------------------------- strings
inline std::string trim(const std::string& s) {
    size_t a = s.find_first_not_of(" \t\r\n");
    if (a == std::string::npos) return "";
    size_t b = s.find_last_not_of(" \t\r\n");
    return s.substr(a, b - a + 1);
}

inline std::string lower(std::string s) {
    std::transform(s.begin(), s.end(), s.begin(),
                   [](unsigned char c) { return (char)std::tolower(c); });
    return s;
}

inline std::string getenvOr(const char* name, const std::string& fallback) {
    const char* v = std::getenv(name);
    return (v && *v) ? std::string(v) : fallback;
}

inline long long nowSec() { return (long long)std::time(nullptr); }

// ------------------------------------------------------------------ random
inline std::string randomHex(size_t bytes) {
    static std::random_device rd;
    std::string out;
    const char* hex = "0123456789abcdef";
    for (size_t i = 0; i < bytes; i++) {
        unsigned v = rd() & 0xFF;
        out += hex[v >> 4];
        out += hex[v & 15];
    }
    return out;
}

// 6 digit OTP
inline std::string randomOtp() {
    static std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<int> dis(100000, 999999);
    return std::to_string(dis(gen));
}

// -------------------------------------------------------------------- SHA-256
namespace detail {
inline uint32_t rotr(uint32_t x, uint32_t n) { return (x >> n) | (x << (32 - n)); }
}

inline std::string sha256(const std::string& data) {
    static const uint32_t k[64] = {
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1,
        0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
        0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
        0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
        0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
        0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
        0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
        0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
        0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2};
    uint32_t h[8] = {0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
                     0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19};

    std::string msg = data;
    uint64_t bitLen = (uint64_t)data.size() * 8;
    msg += (char)0x80;
    while (msg.size() % 64 != 56) msg += (char)0x00;
    for (int i = 7; i >= 0; i--) msg += (char)((bitLen >> (i * 8)) & 0xFF);

    for (size_t off = 0; off < msg.size(); off += 64) {
        uint32_t w[64];
        for (int i = 0; i < 16; i++) {
            w[i] = ((uint32_t)(unsigned char)msg[off + i * 4] << 24) |
                   ((uint32_t)(unsigned char)msg[off + i * 4 + 1] << 16) |
                   ((uint32_t)(unsigned char)msg[off + i * 4 + 2] << 8) |
                   ((uint32_t)(unsigned char)msg[off + i * 4 + 3]);
        }
        for (int i = 16; i < 64; i++) {
            uint32_t s0 = detail::rotr(w[i - 15], 7) ^ detail::rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
            uint32_t s1 = detail::rotr(w[i - 2], 17) ^ detail::rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
            w[i] = w[i - 16] + s0 + w[i - 7] + s1;
        }
        uint32_t a = h[0], b = h[1], c = h[2], d = h[3];
        uint32_t e = h[4], f = h[5], g = h[6], hh = h[7];
        for (int i = 0; i < 64; i++) {
            uint32_t S1 = detail::rotr(e, 6) ^ detail::rotr(e, 11) ^ detail::rotr(e, 25);
            uint32_t ch = (e & f) ^ ((~e) & g);
            uint32_t t1 = hh + S1 + ch + k[i] + w[i];
            uint32_t S0 = detail::rotr(a, 2) ^ detail::rotr(a, 13) ^ detail::rotr(a, 22);
            uint32_t mj = (a & b) ^ (a & c) ^ (b & c);
            uint32_t t2 = S0 + mj;
            hh = g; g = f; f = e; e = d + t1;
            d = c; c = b; b = a; a = t1 + t2;
        }
        h[0] += a; h[1] += b; h[2] += c; h[3] += d;
        h[4] += e; h[5] += f; h[6] += g; h[7] += hh;
    }
    static const char* hex = "0123456789abcdef";
    std::string out;
    for (int i = 0; i < 8; i++)
        for (int j = 7; j >= 0; j--) out += hex[(h[i] >> (j * 4)) & 0xF];
    return out;
}

// Salted + iterated SHA-256 password hash. Format: "salt$hash"
inline std::string hashPasswordWithSalt(const std::string& pw, const std::string& salt) {
    std::string h = sha256(salt + pw);
    for (int i = 0; i < 20000; i++) h = sha256(h + salt + pw);
    return h;
}
inline std::string hashPassword(const std::string& pw) {
    std::string salt = randomHex(16);
    return salt + "$" + hashPasswordWithSalt(pw, salt);
}
inline bool constTimeEq(const std::string& a, const std::string& b) {
    if (a.size() != b.size()) return false;
    unsigned char d = 0;
    for (size_t i = 0; i < a.size(); i++) d |= (unsigned char)(a[i] ^ b[i]);
    return d == 0;
}
inline bool verifyPassword(const std::string& pw, const std::string& stored) {
    size_t p = stored.find('$');
    if (p == std::string::npos) return false;
    return constTimeEq(hashPasswordWithSalt(pw, stored.substr(0, p)), stored.substr(p + 1));
}

// -------------------------------------------------------------------- JSON
// Escape for building JSON strings (quotes, backslash, control chars).
inline std::string jesc(const std::string& s) {
    std::string o;
    for (unsigned char c : s) {
        switch (c) {
            case '"': o += "\\\""; break;
            case '\\': o += "\\\\"; break;
            case '\n': o += "\\n"; break;
            case '\r': o += "\\r"; break;
            case '\t': o += "\\t"; break;
            default:
                if (c < 0x20) {
                    char buf[8];
                    snprintf(buf, sizeof(buf), "\\u%04x", c);
                    o += buf;
                } else {
                    o += (char)c;
                }
        }
    }
    return o;
}
inline std::string jstr(const std::string& s) { return "\"" + jesc(s) + "\""; }

inline void appendUtf8(std::string& out, uint32_t cp) {
    if (cp < 0x80) out += (char)cp;
    else if (cp < 0x800) { out += (char)(0xC0 | (cp >> 6)); out += (char)(0x80 | (cp & 0x3F)); }
    else if (cp < 0x10000) {
        out += (char)(0xE0 | (cp >> 12));
        out += (char)(0x80 | ((cp >> 6) & 0x3F));
        out += (char)(0x80 | (cp & 0x3F));
    } else {
        out += (char)(0xF0 | (cp >> 18));
        out += (char)(0x80 | ((cp >> 12) & 0x3F));
        out += (char)(0x80 | ((cp >> 6) & 0x3F));
        out += (char)(0x80 | (cp & 0x3F));
    }
}

// Reads a top-level field from a flat JSON object. Strings are fully unescaped
// (\" \\ \n \uXXXX incl. surrogate pairs); numbers/booleans come back as raw text.
inline std::string jsonField(const std::string& body, const std::string& field) {
    std::string pat = "\"" + field + "\"";
    size_t pos = 0;
    while (true) {
        pos = body.find(pat, pos);
        if (pos == std::string::npos) return "";
        size_t q = pos + pat.size();
        while (q < body.size() && std::isspace((unsigned char)body[q])) q++;
        if (q < body.size() && body[q] == ':') { pos = q + 1; break; }
        pos += pat.size();  // it was a value, not a key - keep looking
    }
    while (pos < body.size() && std::isspace((unsigned char)body[pos])) pos++;
    if (pos >= body.size()) return "";
    if (body[pos] != '"') {
        size_t e = pos;
        while (e < body.size() && body[e] != ',' && body[e] != '}' && !std::isspace((unsigned char)body[e])) e++;
        return body.substr(pos, e - pos);
    }
    pos++;
    std::string out;
    while (pos < body.size()) {
        char c = body[pos];
        if (c == '"') return out;
        if (c == '\\' && pos + 1 < body.size()) {
            char n = body[pos + 1];
            pos += 2;
            switch (n) {
                case 'n': out += '\n'; break;
                case 't': out += '\t'; break;
                case 'r': out += '\r'; break;
                case 'b': out += '\b'; break;
                case 'f': out += '\f'; break;
                case 'u': {
                    if (pos + 4 > body.size()) return out;
                    uint32_t cp = (uint32_t)std::strtoul(body.substr(pos, 4).c_str(), nullptr, 16);
                    pos += 4;
                    if (cp >= 0xD800 && cp <= 0xDBFF && pos + 6 <= body.size() &&
                        body[pos] == '\\' && body[pos + 1] == 'u') {
                        uint32_t lo = (uint32_t)std::strtoul(body.substr(pos + 2, 4).c_str(), nullptr, 16);
                        if (lo >= 0xDC00 && lo <= 0xDFFF) {
                            cp = 0x10000 + ((cp - 0xD800) << 10) + (lo - 0xDC00);
                            pos += 6;
                        }
                    }
                    appendUtf8(out, cp);
                    break;
                }
                default: out += n;  // \" \\ \/
            }
            continue;
        }
        out += c;
        pos++;
    }
    return out;
}

// ------------------------------------------------------------------ small JSON parser
// Nested JSON (arrays/objects) padhne ke liye - bahari API ke jawab ke liye (jaise Pexels).
struct JVal {
    enum Type { Null, Bool, Num, Str, Arr, Obj } type = Null;
    bool b = false;
    double num = 0;
    std::string str;
    std::vector<JVal> arr;          // Arr
    std::vector<std::string> keys;  // Obj (keys[i] <-> vals[i])
    std::vector<JVal> vals;

    const JVal* get(const std::string& k) const {
        for (size_t i = 0; i < keys.size(); i++) if (keys[i] == k) return &vals[i];
        return nullptr;
    }
    std::string s(const std::string& k) const {
        const JVal* v = get(k);
        return (v && v->type == Str) ? v->str : "";
    }
    double n(const std::string& k, double dflt = 0) const {
        const JVal* v = get(k);
        return (v && v->type == Num) ? v->num : dflt;
    }
};

namespace detail {
inline char jat(const std::string& s, size_t i) { return i < s.size() ? s[i] : '\0'; }
inline void jws(const std::string& s, size_t& i) {
    while (i < s.size() && (s[i] == ' ' || s[i] == '\t' || s[i] == '\n' || s[i] == '\r')) i++;
}
inline bool jstring(const std::string& s, size_t& i, std::string& out) {
    if (jat(s, i) != '"') return false;
    i++;
    while (i < s.size()) {
        char c = s[i];
        if (c == '"') { i++; return true; }
        if (c == '\\') {
            char n = jat(s, i + 1);
            i += 2;
            switch (n) {
                case 'n': out += '\n'; break;
                case 't': out += '\t'; break;
                case 'r': out += '\r'; break;
                case 'b': out += '\b'; break;
                case 'f': out += '\f'; break;
                case 'u': {
                    if (i + 4 > s.size()) return false;
                    uint32_t cp = (uint32_t)std::strtoul(s.substr(i, 4).c_str(), nullptr, 16);
                    i += 4;
                    if (cp >= 0xD800 && cp <= 0xDBFF && jat(s, i) == '\\' && jat(s, i + 1) == 'u' && i + 6 <= s.size()) {
                        uint32_t lo = (uint32_t)std::strtoul(s.substr(i + 2, 4).c_str(), nullptr, 16);
                        if (lo >= 0xDC00 && lo <= 0xDFFF) { cp = 0x10000 + ((cp - 0xD800) << 10) + (lo - 0xDC00); i += 6; }
                    }
                    appendUtf8(out, cp);
                    break;
                }
                default: out += n;
            }
            continue;
        }
        out += c;
        i++;
    }
    return false;
}
inline bool jvalue(const std::string& s, size_t& i, JVal& out, int depth) {
    if (depth > 40) return false;
    jws(s, i);
    char c = jat(s, i);
    if (c == '{') {
        out.type = JVal::Obj;
        i++;
        jws(s, i);
        if (jat(s, i) == '}') { i++; return true; }
        while (true) {
            jws(s, i);
            std::string key;
            if (!jstring(s, i, key)) return false;
            jws(s, i);
            if (jat(s, i) != ':') return false;
            i++;
            JVal v;
            if (!jvalue(s, i, v, depth + 1)) return false;
            out.keys.push_back(key);
            out.vals.push_back(std::move(v));
            jws(s, i);
            if (jat(s, i) == ',') { i++; continue; }
            if (jat(s, i) == '}') { i++; return true; }
            return false;
        }
    }
    if (c == '[') {
        out.type = JVal::Arr;
        i++;
        jws(s, i);
        if (jat(s, i) == ']') { i++; return true; }
        while (true) {
            JVal v;
            if (!jvalue(s, i, v, depth + 1)) return false;
            out.arr.push_back(std::move(v));
            jws(s, i);
            if (jat(s, i) == ',') { i++; continue; }
            if (jat(s, i) == ']') { i++; return true; }
            return false;
        }
    }
    if (c == '"') { out.type = JVal::Str; return jstring(s, i, out.str); }
    if (s.compare(i, 4, "true") == 0) { out.type = JVal::Bool; out.b = true; i += 4; return true; }
    if (s.compare(i, 5, "false") == 0) { out.type = JVal::Bool; out.b = false; i += 5; return true; }
    if (s.compare(i, 4, "null") == 0) { out.type = JVal::Null; i += 4; return true; }
    if (c == '-' || (c >= '0' && c <= '9')) {
        size_t e = i;
        while (e < s.size() && (std::isdigit((unsigned char)s[e]) || s[e] == '-' || s[e] == '+' || s[e] == '.' || s[e] == 'e' || s[e] == 'E')) e++;
        out.type = JVal::Num;
        out.num = std::strtod(s.substr(i, e - i).c_str(), nullptr);
        bool progressed = e > i;
        i = e;
        return progressed;
    }
    return false;
}
}  // namespace detail

inline bool jsonParse(const std::string& text, JVal& out) {
    size_t i = 0;
    out = JVal();
    if (!detail::jvalue(text, i, out, 0)) return false;
    detail::jws(text, i);
    return i == text.size();
}

// ------------------------------------------------------------------ base64
inline std::string base64Decode(const std::string& in) {
    static int T[256];
    static bool init = false;
    if (!init) {
        for (int i = 0; i < 256; i++) T[i] = -1;
        const std::string a = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        for (int i = 0; i < 64; i++) T[(unsigned char)a[i]] = i;
        init = true;
    }
    std::string out;
    int val = 0, bits = -8;
    for (unsigned char c : in) {
        if (c == '=') break;
        if (T[c] == -1) continue;  // skip whitespace / newlines
        val = (val << 6) + T[c];
        bits += 6;
        if (bits >= 0) {
            out += (char)((val >> bits) & 0xFF);
            bits -= 8;
        }
    }
    return out;
}

// Detect image type from magic bytes. Returns "" if not an allowed image.
inline std::string imageExt(const std::string& d) {
    if (d.size() > 3 && (unsigned char)d[0] == 0xFF && (unsigned char)d[1] == 0xD8) return "jpg";
    if (d.size() > 8 && d.compare(1, 3, "PNG") == 0) return "png";
    if (d.size() > 6 && d.compare(0, 3, "GIF") == 0) return "gif";
    if (d.size() > 12 && d.compare(0, 4, "RIFF") == 0 && d.compare(8, 4, "WEBP") == 0) return "webp";
    return "";
}

// Detect video type (mp4/mov = "ftyp" box, webm = EBML header). "" if not video.
inline std::string videoExt(const std::string& d) {
    if (d.size() > 12 && d.compare(4, 4, "ftyp") == 0) return "mp4";
    if (d.size() > 12 && (unsigned char)d[0] == 0x1A && (unsigned char)d[1] == 0x45 &&
        (unsigned char)d[2] == 0xDF && (unsigned char)d[3] == 0xA3)
        return "webm";
    return "";
}

// --------------------------------------------------------------- TSV storage
// One record per line, fields separated by TAB; \t \n \\ are escaped.
inline std::string tsvEsc(const std::string& s) {
    std::string o;
    for (char c : s) {
        if (c == '\\') o += "\\\\";
        else if (c == '\t') o += "\\t";
        else if (c == '\n') o += "\\n";
        else if (c == '\r') o += "\\r";
        else o += c;
    }
    return o;
}
inline std::string tsvUnesc(const std::string& s) {
    std::string o;
    for (size_t i = 0; i < s.size(); i++) {
        if (s[i] == '\\' && i + 1 < s.size()) {
            char n = s[++i];
            o += (n == 't') ? '\t' : (n == 'n') ? '\n' : (n == 'r') ? '\r' : n;
        } else {
            o += s[i];
        }
    }
    return o;
}
inline std::string tsvLine(const std::vector<std::string>& f) {
    std::string o;
    for (size_t i = 0; i < f.size(); i++) {
        if (i) o += '\t';
        o += tsvEsc(f[i]);
    }
    return o;
}
inline std::vector<std::string> tsvSplit(const std::string& line) {
    std::vector<std::string> out;
    std::string cur;
    for (char c : line) {
        if (c == '\t') { out.push_back(tsvUnesc(cur)); cur.clear(); }
        else cur += c;
    }
    out.push_back(tsvUnesc(cur));
    return out;
}

// ------------------------------------------------------------------- misc
inline bool validUsernameChar(char c) {
    return std::isalnum((unsigned char)c) || c == '.' || c == '_';
}
inline std::string slugUsername(const std::string& s) {
    std::string o;
    for (char c : s) {
        char l = (char)std::tolower((unsigned char)c);
        if (validUsernameChar(l)) o += l;
        else if (l == ' ') o += '.';
    }
    if (o.empty()) o = "user";
    return o;
}
inline bool looksLikeEmail(const std::string& e) {
    size_t at = e.find('@');
    if (at == std::string::npos || at == 0) return false;
    size_t dot = e.find('.', at);
    return dot != std::string::npos && dot + 1 < e.size() && e.find(' ') == std::string::npos;
}

}  // namespace zx
