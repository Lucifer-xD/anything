# Nimbus VPN — Research (Phase 1)

> Compiled by a parallel multi-source research pass (HTTP Injector, HTTP Custom, NPV Tunnel, proxy config-URI formats, iOS NetworkExtension). Reviewed and used to drive the parser field reference and the tunnel integration boundary in this codebase. Compiled 2026-07-22.

*Authoritative research compilation for building a premium iOS tunneling client inspired by HTTP Injector, HTTP Custom, and NPV Tunnel.*

---

## 1. Reference apps

The three reference apps share one conceptual model: a userspace tunnel client that (a) injects a crafted HTTP payload and/or spoofs the TLS SNI to fool carrier DPI ("bug host" trick), (b) carries the real VPN inside an SSH / SSL / DNS / V2Ray transport, and (c) distributes ready-to-run connection profiles as encrypted, lockable config files so resellers can share configs without exposing server credentials. All three are **Android-first tools ported (or half-ported) to iOS**.

### 1.1 HTTP Injector (Evozi)

**Identity.** Package `com.evozi.injector`, current version 6.4.0 (Oct 2025), developer Evozi. iOS build published via MWM (`id1659992827`, iOS 15+, ~3.9★). Used primarily to bypass carrier/ISP filtering ("free internet") and secondarily as a general VPN.

**Architecture.** Userspace tunnel client, no root required. Two capture modes:
- **VPN Service mode** (default, Android 4.0+/iOS): uses the OS `VpnService`/NetworkExtension API to create a `tun` interface; all (or app-filtered) traffic is pulled into a userspace TCP/IP stack and forwarded.
- **Legacy iptables/root mode** (older Android): redirects ports 80/443 via iptables into the local proxy.

**Local proxy hop.** Captured traffic is handed to a **local proxy on `127.0.0.1:8989`** (HTTP/SOCKS) — also the integration point for external clients (e.g. OpenVPN with `http-proxy 127.0.0.1 8989`, or Psiphon). An **App Filter** selects which installed apps route into the tunnel.

**Tunnel establishment (the "injection" trick):**
1. Open a raw TCP socket to the **bug host / remote proxy** (or a TLS endpoint for SSL mode) — a domain/IP the carrier does not bill or does not block.
2. Send a **custom HTTP payload** (crafted `CONNECT`/`GET`, see §2.8) so the carrier's transparent proxy / DPI sees an allowed destination and forwards the socket, while the request actually asks to reach the real backend (`[host_port]`).
3. Once the socket reaches the backend, **upgrade to the chosen transport** (SSH channel, stunnel TLS, WebSocket, V2Ray stream, etc.) and **authenticate**.
4. Multiplex all `tun` traffic over that single encrypted channel; demux return packets back into the tun stack.

**SSL/TLS mode** moves the deception to the TLS layer: the real backend is contacted while the **SNI field in the ClientHello advertises the allowed bug host**, defeating SNI-based DPI. Optional **zlib compression** can be applied over the channel.

**Tunnel modes (v6.4.0):**
- **Direct / Custom server** — plain connection, optional payload
- **SSH** — built-in SSH client; SSH channel can ride plain TCP, HTTP proxy + payload, or TLS/stunnel; zlib compression
- **SSL/TLS (stunnel)** — TLS wrapper, SNI-based bug host, usually SSL/TLS **+ SSH** for dual layer
- **HTTP Proxy** — remote/upstream proxy (Squid, carrier APN) + custom payload
- **DNS Tunnel — DNSTT / SlowDNS** — traffic inside DNS queries/responses
- **Shadowsocks** — incl. **SS 2022** and obfs variants (HTTP-obfs / TLS-obfs / plain)
- **V2Ray / Xray** — **VMess, VLESS, Trojan, SOCKS**; **XHTTP** transport
- **Hysteria** — QUIC/UDP based, incl. **SlowUDP**
- **WireGuard** — built-in client
- **Provider Mode** — not a transport; the locked/encrypted config distribution mode

**Supporting tools:** Host Checker & **IP Hunter** (validate bug hosts), **CDN Finder**, **Response Checker**, DNS Changer, App Filter (per-app routing), **Hotshare** (tether/hotspot unlock), data compression.

**Connection lifecycle (observable state machine):**
1. Disconnected / Idle
2. Connecting / Starting — request VPN permission, build `tun`, open socket to bug host/proxy
3. Payload / Handshake — send injection payload, expect HTTP `200`/`101`, or complete TLS handshake
4. Authenticating — SSH/proxy/transport auth
5. Connected — tunnel up; status-bar **key icon** appears; timers/counters start
6. Stopping → Disconnected
7. Error / "Connection Lost" — optional auto-reconnect

**Logging & stats.** A **Log tab** streams every step verbatim (payload bytes sent, `Status: 200 (OK)`, "VPN Capability", auth, DNS); **Debug mode** increases verbosity. Live **upload/download counters**, **current speed**, **session duration**, **compression ratio**.

**DNS.** DNS Changer offers **Google DNS (8.8.8.8 / 8.8.4.4)** or a custom resolver. In VPN Service mode, `tun` DNS queries are resolved through the tunnel (leak prevention) or via the configured resolver. DNS Tunnel (DNSTT/SlowDNS) uses DNS itself as transport.

### 1.2 HTTP Custom (Easypro)

**Identity.** "HTTP Custom - AIO Tunnel VPN", package `xyz.easypro.httpcustom`, developer Easypro. **Android-only** (800k+ downloads, 4.3★). *Caveat:* the App Store "HTTP Custom – Tunnel" (`id6754261236`, AHAMMAM BRAHIM, 3.7★) is an unrelated minimal app that does not support config files — HTTP Custom's UX is evaluated from its Android reference build. Positioned as a lighter "all-in-one" with a simpler UI and fewer knobs than HTTP Injector.

**Transport model.** Payload/SNI/SSL are obfuscation wrappers around an SSH tunnel that carries the actual VPN. SSH account is entered in a single combined field: **`IP:Port@User:Pass`** (e.g. `sni.com:443@user:12345`).

**Tunnel modes:**
- **Direct SSH** (SSH over TCP/HTTP)
- **SSH + Proxy** (upstream HTTP proxy + payload)
- **SSH + Payload** (HTTP header injection to a bug host)
- **SSH SSL/TLS (SNI)** — TLS-wrapped, SNI spoofing (usually port 443)
- **SSH SSL (SNI) + Payload** — TLS + WebSocket (WSS) payload combo, reads as normal HTTPS
- **DNS / SlowDNS** (DNSTT-style)
- **UDP Custom** (UDP transport with buffer/TX/RX tuning)
- **V2Ray** (VMess/VLESS over WebSocket, TLS and non-TLS; layerable as "V2Ray + Slow DNS")
- **Psiphon** (bundled circumvention transport)

The reference open-source reimplementation exposes modes **0–3**: plain SSH → SSH+payload → SSH+SNI → SSH+payload+SNI.

**DNS (SlowDNS/DNSTT).** Enabled via a **"Slow DNS"** checkbox; **Slow DNS Settings** require three fields: **DNS** (resolver), **NS** (delegated nameserver/domain), **Public Key**. SSH credentials sit underneath as the payload carried over the DNS channel.

**UDP Custom.** Uses the SSH `ip:port@user:pass` field plus a UDP tweak panel: **Buffer Size**, **TX=1**, **RX=1**.

**Layering example (SSH SSL(SNI)+Payload):** SSH → inside SSL/TLS → disguised with a WebSocket payload → carried on port 443 with a spoofed SNI.

**Connection lifecycle.** Configure/import → **Apply** each pane (SSH account, payload, SNI, proxy, DNS, mode) → **Connect** (requests VPN permission on first run; payload sent → bug/SNI handshake → SSH auth → interface up) → **Monitor** (live log/console, timer, traffic counters) → **Disconnect**. Extras: custom request header, DNS changer, tether/hotspot sharing.

### 1.3 NPV Tunnel (NapsternetV / Vonmatrix)

**Identity.** App Store "NPV Tunnel" (`id1629465476`); Google Play "Npv Tunnel V2ray/SSH" (`com.napsternetlabs.napsternetv`), successor branding to **NapsternetV**. Developer **VONMATRIX CO. LTD**. Platforms: Android 6.0+, iOS 15.0+, Windows. The V2Ray engine is a bundled **Xray core** (e.g. Xray 25.10.15 shipped in iOS v56.2, Oct 2025). Official site `napsternetv.vonmatrix.com`; Telegram `t.me/napsternetv`. Strong config engine, weak native-iOS polish; ads reportedly force a reconnect ~every 5 minutes.

**Supported protocols:**
- **V2Ray / Xray core:** `vmess`, `vless`, `trojan`, `shadowsocks`, `socks`. Transports: **WebSocket (ws)**, tcp, quic; **TLS** optional; **Mux** supported. Common ports **443 (SSL/WebSocket)** and **81**.
- **SSH:** all common SSH tunnel types, plus **SSH over TLS / "SSH-SSL"** (added v13.9) with **selectable TLS version in SSH mode**. SSH subprotocols/modes include **payload/HTTP-injector-style** headers, **proxy**, and **dnstt**.
- **DNS tunneling:** **dnstt** and **SlowDNS**-style (nameserver + public key + underlying SSH host/user/pass).
- **Psiphon** mode.
- **SSL/TLS** tunneling as a wrapping layer.
- **UDP support** across SSH, Psiphon, and V2Ray modes.
- **Custom DNS** servers app-wide.

**Subscription / server-list handling.** V2Ray **subscription URLs** supported (paste/import a link, app pulls the server list). v122 added better subscription organization; earlier releases fixed subscription-import bugs. Built around managing multiple server profiles in a list with automatic internal normalization of imported V2Ray configs.

**Import / export.** Tap **"+" (top-right)**: Import `.npv4` file (password prompt if locked); Import from Clipboard → V2Ray Config (parses `vmess://`/`vless://`/`trojan://`/`ss://`); QR-code import; Add config manually (SSH host/port/user/pass). Export any user config as `.npv4`, optionally **password-locked**. Configs are cross-platform (same `.npv4` on Android/iOS/Windows).

**Lifecycle & UX.** Select config → tap **power icon** to bring the tunnel up (VPN-service/TUN interface); a fix ensures immediate disconnect when stopped. Exposes connection/generated-V2Ray-config **logs**; live upload/download **stats**; **per-app proxy / split tunneling** (v122); **VPN hotspot** sharing; optional **data-limit** guard to stop the tunnel before burning a mobile allowance; **TLS-version picker** in SSH mode.

### 1.4 Config file formats (comparison)

| Aspect | HTTP Injector `.ehi` | HTTP Custom `.hc` | NPV Tunnel `.npv4` |
|---|---|---|---|
| Developer / package | Evozi (`com.evozi.injector`) | Easypro (`xyz.easypro.httpcustom`) | Vonmatrix (`com.napsternetlabs.napsternetv`) |
| Nature | Encrypted/encoded binary blob; opaque outside the app | Proprietary encrypted/obfuscated binary blob (~2–53 KB) | Nominally text-based; supports encryption/obfuscation |
| Encryption | Reverse-engineered as **AES-CBC (symmetric)** + Base64 envelope, key embedded in app binary (version-specific) | Proprietary, not publicly documented | **Encryption algorithm changed in v9.6** (the version that introduced `.npv4`, replacing `.npv2`/`.npv3`); companion `.inpv` import form referenced |
| Locking | Per-section lock flags: **Lock config**, **Prevent editing / Lock all options below**, optional password, expiry, root-lock, torrent block, custom message | Locked to the app; embedded creds/payload/proxy not readable in a text editor | Export as **"locked" / password-protected**; app prompts for password on import |
| Cross-compat | Not cross-compatible with `.hc` | Not cross-compatible with `.ehi` | Cross-platform within NPV builds |

**`.ehi` logical contents.** `Payload` (raw injection string with tokens, §2.8); `RemoteProxy` (bug host/proxy `host:port`); `SNI`/bug host; transport block (**SSH** host/port/user/password/passphrase; and/or **SSL/stunnel**, **Shadowsocks**, **V2Ray/Xray** address/port/UUID/alterId/encryption/network-stream, **WireGuard**); **DNS** settings; **lock flags** (per-section locked/hidden/prevent-editing); provider metadata (creator/custom message, expiration date, root-lock, torrent block). Created via **file icon → Export Config** ("Provider Mode"), ticking sections to include (General, Secure Shell, V2Ray, Shadowsocks, Extra). Imported via **file icon → Import Config** (typically under `Documents/HTTP Injector`) or by opening the file.

*Parser implication for `.ehi`:* expect an outer Base64/AES-CBC envelope; after decrypt, a serialized key/value (XML/plist-like) record plus a lock bitmask. Handle both plaintext (older/unlocked) and encrypted-locked variants; the embedded key is version-dependent.

**`.hc` fields (from app UI):** Remarks/profile name; Connection mode/method; SSH account (`IP:Port@User:Pass`); Payload; SNI/host; Proxy (host:port, optional); SlowDNS params (DNS resolver, NS nameserver, Public Key); DNS/VPN forwarding (custom DNS, app filter); UDP tweak (Buffer Size, TX, RX); V2Ray (VMess/VLESS URI — UUID, address, port, WS path/host, TLS/SNI).

**`.npv4` fields (from format docs + guides):** Server address/host, port; Protocol/mode selector (V2Ray vmess/vless/trojan/shadowsocks/socks, SSH, Psiphon, DNS); encryption/security + credentials (SSH user/pass; V2Ray UUID); V2Ray-specific — **UUID**, **alterId**, **security/encryption**, **network/transport** (ws/tcp/quic), **path**, **Request Host**, **SNI**, **TLS on/off**, **Enable Mux**, remark/name; custom DNS; data-limit/cap. **Format nuance:** as of **v7.4 "Request Host" is decoupled from "SNI"** — set both correctly (the bug-host trick uses a whitelisted SNI/host that differs from the real request host; mismatches silently break the config).

*Source-reliability caveat:* none of the three vendors publishes a formal binary schema. `.ehi`/`.hc`/`.npv4` field detail is triangulated from file-format registries, app-store descriptions, community config-creation guides, and version-pinned decrypt scripts, and should be treated as community-reported rather than officially documented.

---

## 2. Protocol & config-URI parser reference

A field-by-field spec for the seven share-link formats used by V2Ray/Xray, Shadowsocks, Trojan, Hysteria2, and TUIC clients, plus the subscription container. Written as an implementation spec for a Swift parser. Principle: **lenient on input, strict on output.**

### 2.0 General parsing rules (apply to every format)

- **Base64 flavors.** Two alphabets in the wild: standard (`+` `/`) and URL-safe (`-` `_`). Padding (`=`) is frequently omitted. Try URL-safe first, fall back to standard, and re-pad to a length multiple of 4 before decoding. **Never reject on missing padding.**
- **Percent-encoding.** All URI-form values (`vless`, `trojan`, `ss` SIP002, `hysteria2`, `tuic`) are produced with `encodeURIComponent`. Decode every query value and the fragment. The fragment (`#name`) is the human-readable label, percent-decoded, may contain Unicode/emoji.
- **IPv6 hosts.** Must be bracketed: `[2001:db8::1]:443`. Strip brackets before use; port follows the closing bracket.
- **Duplicate query keys** are prohibited but occur — take the first occurrence.
- **Case.** Scheme is lowercase. Query parameter names and enum constants are case-sensitive (`type=ws`, not `WS`).

### 2.1 `vmess://` — Base64-encoded JSON

No RFC; the de-facto standard is the v2rayN "share link ver 2" JSON object. (An alternate RFC3986 URI form was proposed but never adopted for VMess — only VLESS uses the URI form.)

**Grammar:** `vmess://` = `"vmess://" base64( json-object )`. Standard base64 with padding is most common, but accept URL-safe and unpadded.

| Key | Type | Meaning | Default / notes |
|-----|------|---------|-----------------|
| `v` | string/int | Format version | `"2"` current. Absent ⇒ treat as v1 (fields still present). Parse leniently. |
| `ps` | string | Remark / display label | Empty allowed. Plain text (already decoded), may be Unicode. |
| `add` | string | Server address (IP/domain) | Required. |
| `port` | string/int | Server port | Required. **May be JSON string** (`"443"`) or number — coerce to Int. Range 1–65535. |
| `id` | string | User UUID | Required. |
| `aid` | string/int | AlterId | Default `0`. VMess-AEAD requires `0`; non-zero ⇒ legacy MD5-auth. Coerce string→Int. |
| `scy` | string | Cipher | `auto` (default), `aes-128-gcm`, `chacha20-poly1305`, `none`, `zero`. Older links used key **`security`** — accept both. |
| `net` | string | Transport | `tcp` (default), `kcp`, `ws`, `h2`/`http`, `quic`, `grpc`, `httpupgrade`, `xhttp`/`splithttp`. |
| `type` | string | Header/obfuscation type — **meaning depends on `net`** | Default `none`. |
| `host` | string | Host header (ws/h2/httpupgrade) or masquerade domain (tcp+http) | Empty ⇒ falls back to `add`. For `h2`/`http` may be comma-separated. |
| `path` | string | ws/h2/httpupgrade/xhttp path; QUIC key; **gRPC serviceName** when `net=grpc` | Default `/`. |
| `tls` | string | TLS layer | `""` (disabled — empty string, **not** the word "none"), `tls`, or `reality`. Treat `""`/`none`/absent as disabled. |
| `sni` | string | TLS SNI | Empty ⇒ falls back to `host`, then `add`. |
| `alpn` | string | ALPN list | Comma-separated, e.g. `h2,http/1.1`. Empty allowed. |
| `fp` | string | uTLS fingerprint | `chrome`, `firefox`, `safari`, `ios`, `android`, `edge`, `360`, `qq`, `random`, `randomized`. Empty allowed. |

**`type` semantics per `net`:**
- `net=tcp`: `none` (raw) or `http` (HTTP/1.1 masquerade; `host`+`path` as fake HTTP headers).
- `net=kcp`/`net=quic`: header obfuscation — `none`, `srtp`, `utp`, `wechat-video`, `dtls`, `wireguard`.
- `net=grpc`: some clients overload `type` for gRPC mode (`gun`/`multi`); `path` carries serviceName.
- `net=ws`/`h2`/`httpupgrade`: `type` generally ignored; `host`+`path` meaningful.

**Edge cases.** Coerce `port`/`aid` from JSON strings. Missing `v`,`scy`,`aid`,`sni`,`alpn`,`fp` are normal — apply defaults. Ignore unknown extra keys (e.g. `allowInsecure`). `tls` disabled is the empty string — do not test only for literal `"none"`.

### 2.2 `vless://` — URI form

Canonical: XTLS "VMessAEAD / VLESS sharing standard" (Xray-core Discussion #716). VLESS has **no built-in transport encryption** — security is entirely the `security` (TLS/REALITY) layer.

**Grammar:** `vless://` = `"vless://" uuid "@" host ":" port "?" query [ "#" name ]`. `uuid` in userinfo (no password); `host` = domain/IPv4/`[IPv6]`; `port` 1–65535 required; `query` = `&`-joined `key=value`, every value `encodeURIComponent`-escaped.

| Param | Meaning | Allowed values | Default / notes |
|-------|---------|----------------|-----------------|
| `type` | Transport (→ streamSettings.network) | `tcp`, `kcp`, `ws`, `http`(=h2), `grpc`, `httpupgrade`, `xhttp`, `quic` | `tcp` |
| `security` | Transport security layer | `none`, `tls`, `reality` | `none` |
| `encryption` | VLESS protocol encryption | `none` (and newer post-quantum values, e.g. `mlkem768x25519plus…`) | `none`. Almost always `none`; must not be empty. |
| `flow` | Flow control | `xtls-rprx-vision`, `xtls-rprx-vision-udp443`, empty | Empty = no flow. Valid only with `security=tls`/`reality`, typically `type=tcp`. |
| `sni` | TLS SNI | hostname | Falls back to `host`. Must not be empty string if present. |
| `fp` | uTLS fingerprint | same set as VLESS above | `chrome`. **Required for REALITY.** |
| `pbk` | REALITY public key | X25519 base64 | Required when `security=reality`. |
| `sid` | REALITY shortId | hex, 0–16 chars | Optional; may be empty. |
| `spx` | REALITY SpiderX | URL-encoded path, starts `/` | Optional; may be empty. |
| `path` | Path for ws/httpupgrade/xhttp/h2 | URL-encoded | `/` |
| `host` | Host header for ws/httpupgrade/xhttp/h2 | URL-encoded | Falls back to `sni`/server host. |
| `headerType` | TCP/KCP header masquerade | `none`, `http` (and KCP header types) | `none` |
| `serviceName` | gRPC service name | URL-encoded | Required for `type=grpc`. |
| `alpn` | ALPN list | comma-separated, URL-encoded (e.g. `h2%2Chttp%2F1.1`) | Empty allowed. |
| `mode` | gRPC / xHTTP mode | gRPC: `gun` (default), `multi`, `guna`. xHTTP: `auto`, `packet-up`, `stream-up`, `stream-one` | Cannot be empty. |

**Also tolerate** (newer Xray): `pqv` (REALITY ML-DSA-65 pubkey), `authority` (gRPC), `ech` (Encrypted Client Hello, base64), `pcs` (pinned peer-cert SHA-256), `vcn` (cert verify name), `mtu`/`tti` (mKCP). Unknown params → ignore.

**Edge cases.** `flow` with non-TLS security is invalid but appears — keep it, let the config builder decide. For `type=grpc`, `serviceName` is meaningful, not `path`. REALITY requires `pbk` and (by convention) `fp`; `sid`/`spx` optional.

### 2.3 `trojan://` — URI form

Two lineages share the scheme: plain **trojan-gfw** (TLS-only, minimal) and **trojan-go** (adds transports). TLS is always on; there is no `security=none`.

**Grammar:** `trojan://` = `"trojan://" password "@" host ":" port [ "/" ] [ "?" query ] [ "#" name ]`. `password` in userinfo, `encodeURIComponent`-escaped, non-empty; `host` non-empty, `[IPv6]` bracketed; `port` 1–65535 (trojan-go defaults to `443`).

| Param | Meaning | Values | Default / notes |
|-------|---------|--------|-----------------|
| `sni` | TLS SNI | hostname | Falls back to `host`. |
| `peer` | Older alias for `sni` | hostname | Treat as `sni` if `sni` absent. |
| `allowInsecure` | Skip cert verification | `0`/`1` (sometimes `true`/`false`) | `0`. |
| `type` | Transport (trojan-go) | `original`/`tcp` (default), `ws`, `grpc`, `h2`, `h2+ws` | `original`. |
| `security` | TLS layer selector (some clients) | `tls`, `xtls` | `tls`. |
| `host` | WS/H2 Host header | string | Falls back to `sni`/server host. |
| `path` | WS/H2 path | URL-encoded, starts `/` | Required when `type=ws`/`h2`. |
| `serviceName` | gRPC service name | string | For `type=grpc`. |
| `mode` | gRPC mode | `gun`, `multi` | `gun`. |
| `fp` | uTLS fingerprint | same set as VLESS | Client extension. |
| `alpn` | ALPN list | comma-separated | Empty allowed. |
| `encryption` | trojan-go Shadowsocks-over-trojan | `ss;method:password` | `none`. |
| `plugin` | Reserved (trojan-go) | string | May be omitted; not empty. |

**Edge cases.** Bare `trojan://password@host:port` is fully valid (trojan-gfw); all query params optional. The trojan-gfw draft defines none of the extras — `sni`/`allowInsecure`/`fp`/`alpn` are client (v2rayN/Clash) conventions; parse them best-effort. Prefer `sni`, fall back to `peer`.

### 2.4 `ss://` — Shadowsocks (SIP002 + legacy)

Two encodings coexist; a parser MUST handle both.

**2.4a SIP002 (current):**
```
SS-URI = "ss://" userinfo "@" hostname ":" port [ "/" ] [ "?" plugin ] [ "#" tag ]
userinfo = websafe-base64( method ":" password )  /  method ":" password   (percent-encoded)
```
- **userinfo encoding:** Stream/AEAD (SIP004) ciphers → base64url of `method:password` recommended but optional. **AEAD-2022 (SIP022, methods `2022-blake3-*`): userinfo MUST NOT be base64** — literal `method:password` with each part percent-encoded. Decode strategy: if userinfo contains `:` after percent-decoding, treat as plaintext `method:password`; otherwise base64url-decode then split on the first `:`.
- **hostname/port** — plain, `[IPv6]` bracketed, port 1–65535.
- **`plugin` query param** — entire value `encodeURIComponent`-escaped. After decoding it is a `TOR_PT_SERVER_TRANSPORT_OPTIONS`-style string: `pluginname;opt1=val1;opt2=val2`; literal `:` `;` `=` `\` are backslash-escaped inside. First token = plugin binary name (e.g. `obfs-local`, `v2ray-plugin`); rest are `key=value` (`obfs=http`, `obfs-host=example.com`).
- **`tag`** — fragment, percent-decoded display name.
- Unknown extra query args MUST be ignored.

**2.4b Legacy (SIP001):**
```
ss:// = "ss://" base64( method ":" password "@" hostname ":" port ) [ "#" tag ]
```
The **entire** `method:password@host:port` is base64-encoded (standard or URL-safe, padding often absent). A `#tag` may be appended after the base64 (not part of it). Detection: if the text between `ss://` and `#`/`?` contains `@`, it's SIP002; if it looks like pure base64 (no `@`), decode first then parse as legacy. Always split on `#` before base64-decoding.

**Cipher methods (validation, non-exhaustive):** AEAD — `aes-256-gcm`, `aes-128-gcm`, `chacha20-ietf-poly1305`, `xchacha20-ietf-poly1305`. AEAD-2022 — `2022-blake3-aes-128-gcm`, `2022-blake3-aes-256-gcm`, `2022-blake3-chacha20-poly1305`. Legacy stream (deprecated) — `rc4-md5`, `aes-256-cfb`, etc.

**Examples:**
```
ss://YWVzLTEyOC1nY206dGVzdA@192.168.100.1:8888#Example1
ss://cmM0LW1kNTpwYXNzd2Q@192.168.100.1:8888/?plugin=obfs-local%3Bobfs%3Dhttp#Example2
ss://2022-blake3-aes-256-gcm:YctPZ6U7...%3D@192.168.100.1:8888#Example3   (SIP022, plaintext userinfo)
```

### 2.5 `hysteria2://` (alias `hy2://`)

Canonical: hysteria.network v2 URI-Scheme doc. UDP/QUIC-based.

**Grammar:** `hysteria2://[auth@]hostname[:port]/?[key=value&...][#name]` (and `hy2://…`). `auth` = credential in userinfo, percent-encoded; for `userpass` server auth formatted `username:password`, otherwise a single opaque token. `hostname` = server host, `[IPv6]` bracketed. `port` **defaults to `443` if omitted**; may be a port-hopping spec (range/list).

| Param | Meaning | Values | Default |
|-------|---------|--------|---------|
| `sni` | TLS SNI | hostname | server host |
| `insecure` | Skip cert verification | `1`=true, `0`=false | `0` |
| `obfs` | Obfuscation type | `salamander` (only value currently supported) | none |
| `obfs-password` | Salamander password | string | required if `obfs=salamander` |
| `pinSHA256` | Pinned cert SHA-256 fingerprint | hex/colon string | — |
| `ech` | Encrypted Client Hello config list | base64 | — |

**Bandwidth caveat.** The official v2 URI spec **deliberately excludes bandwidth** (client-side, local setting). But Hysteria **v1** URIs used `upmbps`/`downmbps` (integers, Mbps), and several third-party clients still accept `up`/`down` on hysteria2 links (integers with optional `mbps`/`gbps` suffix). Read `up`/`down`/`upmbps`/`downmbps` if present (store them), but never require them and never fail a link that omits them.

**Edge cases.** Parse the port field tolerantly (may be `443`, `2000-3000`, or `443,2000-3000` for port-hopping). A `hysteria2+realm://` variant exists (relay/rendezvous, extra params `auth`/`stun`/`lport`) — out of scope but must not crash the parser.

### 2.6 `tuic://` — TUIC v5

Canonical: TUIC project / daeuniverse. QUIC-based; v5 uses UUID+password auth (v4 used token — different scheme, not covered).

**Grammar:** `tuic://` = `"tuic://" uuid ":" password "@" host ":" port "?" query [ "#" name ]`. `uuid` and `password` both in userinfo, split on the **first** `:`, each percent-decoded independently (password may contain encoded `:`). `host`/`port` standard, `[IPv6]` bracketed, port required.

| Param | Meaning | Values | Default |
|-------|---------|--------|---------|
| `congestion_control` | Congestion algorithm | `cubic`, `bbr`, `new_reno` | `cubic` |
| `udp_relay_mode` | UDP relay transport | `native`, `quic` | `native` |
| `alpn` | ALPN list | comma-separated (e.g. `h3`, `h3,spdy/3.1`) — must match server | commonly `h3` |
| `sni` | TLS SNI | hostname | server host |
| `allow_insecure` | Skip cert verification | `0`/`1` | `0` |
| `disable_sni` | Omit SNI in handshake | `0`/`1` | `0` |

**Also parse if present, else ignore:** `reduce_rtt`/`zero_rtt_handshake` (`0`/`1`), `heartbeat` (e.g. `10s`), `udp_over_stream` (`0`/`1`).

**Example:**
```
tuic://uuid:password@example.com:443?congestion_control=cubic&alpn=h3,spdy/3.1&sni=example.com&allow_insecure=0&disable_sni=0&udp_relay_mode=native#Name
```

**Edge cases.** If userinfo has no `:`, it is likely TUIC v4 (token auth) — flag/reject for a v5-only parser. ALPN mismatch is a runtime failure, not a parse failure.

### 2.7 Subscription format

A subscription is a document containing many share links.

**Grammar:** `subscription = base64( link *( "\n" link ) )`, where each `link` is any scheme above.

**Parsing algorithm:**
1. Fetch the body (HTTP). Trim surrounding whitespace.
2. **Detect encoding:** attempt base64 decode (URL-safe first, re-padded). If the decoded result is printable text containing `://`, use it. If the *raw* body already contains `://`, skip decoding (plaintext subscriptions exist — dual detection required).
3. Split decoded text on `\n` (handle `\r\n` and bare `\r`).
4. Trim each line; skip blank lines; skip lines that don't start with a known `scheme://`.
5. Parse each surviving line with the matching scheme parser.

**Edge cases.** Base64 may be standard/URL-safe, padded/not. A single subscription commonly mixes protocols. **SIP008** is a separate JSON Shadowsocks subscription format (`{"version":1,"servers":[…]}`) — detect a leading `{` and branch to a JSON path if supporting it. Some providers wrap the base64 with header/metadata lines (`STATUS=…`, `profile-update-interval`) that appear after decoding — ignore them as non-link lines.

### 2.8 HTTP-injection payload grammar (bug-host layer)

Used by HTTP Injector and HTTP Custom to build the raw request sent to the bug host (§1.1 step 2). The **Payload Generator** takes a **bug host** (HTTP method) or **SNI host** (SSL/TLS method), an HTTP method (`CONNECT`/`GET`/`POST`), an injection method, extra headers, and optional split.

**Tokens (substituted at connect time):**
- `[host]` — target/backend host
- `[port]` — target port
- `[host_port]` — `host:port` of the real backend (SSH/proxy)
- `[protocol]` — HTTP version (`HTTP/1.0`/`HTTP/1.1`)
- `[cr]` `[lf]` `[crlf]` `[lfcr]` — line terminators (`\r`, `\n`, `\r\n`, `\n\r`)
- `[split]` — inserts a payload/TCP fragmentation break (send in two segments), usually before the `Host:` header, to defeat DPI reassembly (`[split][crlf]`)
- `[netData]` — raw connect data placeholder
- `[ssh]` — SSH banner/data
- `[ua]` — User-Agent value

**Injection methods (exact templates):**
- **Normal:** `CONNECT [host_port] HTTP/1.1[crlf]Host: <bughost>[crlf][crlf]`
- **Front Inject:** `GET http://<bughost>/ HTTP/1.1[crlf]Host: <bughost>[crlf][crlf]CONNECT [host_port] HTTP/1.1[crlf][crlf]` (decoy GET before the CONNECT)
- **Back Inject:** `CONNECT [host_port] HTTP/1.1[crlf][crlf]GET http://<bughost>/ HTTP/1.1[crlf]Host: <bughost>[crlf][crlf]` (decoy GET after)
- **Front Query:** `CONNECT <bughost>@[host_port] HTTP/1.1[crlf][crlf]` (bughost prepended with `@`)
- **Back Query:** `CONNECT [host_port]@<bughost> HTTP/1.1[crlf][crlf]` (bughost appended with `@`)
- **WebSocket:** adds `Upgrade: websocket[crlf]Connection: Upgrade` headers to a CONNECT
- **SNI:** structurally like Normal, but the deception is delegated to the TLS layer — the SNI/bug host goes in the TLS ClientHello SNI extension (no plaintext HTTP payload needed for pure SNI mode)

**Common toggled headers:** `X-Online-Host`, `X-Forward-Host`/Forward Host, `Keep-Alive`, custom `User-Agent`, plus a "Raw" mode. **Example (HTTP Custom shape):** `GET / HTTP/1.1[crlf]Host: bug.host.com[crlf]X-Online-Host: [host_port][crlf]Connection: Keep-Alive[crlf][crlf]`.

*Parser caveat:* the exact `.ehi` cipher key is embedded per app version and not published; open-source decrypt scripts are version-pinned. Plan for AES-CBC + Base64 envelope with a version-selectable key and both locked and plaintext variants.

---

## 3. iOS tunnel architecture & integration boundary

### 3.1 The two-process NetworkExtension model

A config-based VPN on iOS splits across two binaries in one `.ipa`:
- **Container app** — UI, config management, install/start/stop the VPN profile. Never touches packets.
- **Packet Tunnel Provider app extension** — a separate, differently-sandboxed process **launched by the system** (not by the app) when the tunnel activates. Its principal class subclasses `NEPacketTunnelProvider`. iOS forbids launching a VPN "binary" from app code — everything funnels through this extension.

### 3.2 Extension lifecycle (`NEPacketTunnelProvider`)

- `startTunnel(options:completionHandler:)` — entry point. Read config from `self.protocolConfiguration as! NETunnelProviderProtocol`, dial the server, then **must** call `setTunnelNetworkSettings(_:)` with an `NEPacketTunnelNetworkSettings`, and only then call `completionHandler(nil)` — the signal that the virtual interface (`utun0`) is ready.
- `stopTunnel(with:completionHandler:)` — teardown.
- `handleAppMessage(_:completionHandler:)` — receives IPC from the app.
- `sleep()`/`wake()` — the OS suspends the extension aggressively; cores keep an auto-wake timer to survive (sing-box's `Pause()` sets a one-minute wake timer).

### 3.3 Moving packets: `NEPacketTunnelFlow`

The virtual interface is drained/filled via `self.packetFlow`:
- **Read (outbound):** `packetFlow.readPacketObjects { packets in … }` (or `readPackets`) hands you raw **IP packets** to encapsulate/forward.
- **Write (inbound):** `packetFlow.writePackets([Data], withProtocols: [NSNumber])` injects decapsulated IP packets back into the stack.

The boundary is **Layer 3 (IP datagrams)**, not sockets — proxy-only cores (SOCKS/HTTP/SSH) need a userspace TCP/IP stack (tun2socks) to bridge L3↔L4.

### 3.4 `NEPacketTunnelNetworkSettings` — configuring `utun0`

Set before signalling readiness. Carries `NEIPv4Settings`/`NEIPv6Settings` (tunnel addresses + `includedRoutes`/`excludedRoutes` — the *only* iOS routing knob for a consumer app), `dnsSettings` (`NEDNSSettings` — resolver IPs + `matchDomains`), `mtu`, `tunnelOverheadBytes`.

### 3.5 App side: `NETunnelProviderManager`

Container app uses `NETunnelProviderManager` to create/save/load/enumerate the VPN profile (`loadAllFromPreferences`, `saveToPreferences`, `removeFromPreferences`). Its `protocolConfiguration` is an **`NETunnelProviderProtocol`** holding `serverAddress` (display string), `providerBundleIdentifier` (which extension to launch), `providerConfiguration: [String: Any]` (vendor dict passed as-is to the extension at start — keep the real config in the app group and pass only a pointer, since the dict is small and one-way), and `username`/`passwordReference` (keychain). Start/stop/status come from `connection` (`NETunnelProviderSession`): `startVPNTunnel(options:)`, `stopVPNTunnel()`, `connection.status` via KVO.

### 3.6 App↔extension communication (three channels)

1. **Config push (app → extension, at start):** the `providerConfiguration` dictionary — **read-only from the extension side**.
2. **Live messaging (app ↔ extension, running):** `session.sendProviderMessage(_:responseHandler:)` → `handleAppMessage(_:)`. Used for on-the-fly commands (rotate config, query stats, ping); sending a message can launch a stopped extension.
3. **Shared state (both directions, persistent):** an **App Group** shared container (`com.apple.security.application-groups`) — shared file/`UserDefaults(suiteName:)` — plus a **shared keychain access group** for secrets. This carries large configs, logs, live byte counters, and geoip/geosite files.

### 3.7 Entitlements & Info.plist

- **Network Extension** on *both* targets: `com.apple.developer.networking.networkextension` containing `packet-tunnel-provider` (managed capability, requires Apple approval on the App ID).
- **Personal VPN** on the app: `com.apple.developer.networking.vpn.api = [allow-vpn]` — required to save a VPN profile.
- **App Groups**: `com.apple.security.application-groups` on both targets, same group ID.
- **Extension Info.plist:** `NSExtensionPointIdentifier = com.apple.networkextension.packet-tunnel`, `NSExtensionPrincipalClass = <YourProviderSubclass>`. The extension bundle ID **must** be prefixed by the app's bundle ID.

### 3.8 The hard memory limit (the single biggest constraint)

The Packet Tunnel Provider runs under a **hard per-process memory cap**: ~5 MB originally → **15 MB (iOS 10)** → **50 MiB (iOS 15+)**. (App Proxy providers stay at 15 MiB.) Exceeding it → the OS jetsams the process with a `per-process-limit` reason. This is why Go cores loading large `geoip.db`/`geosite.db` crash mid-browsing (sing-box #3976, Xray-core #4422), and why memory-lean design matters. It applies to the **combined** SSH client + tun2socks + netstack buffers.

### 3.9 Embeddable cores

The extension owns the `utun` fd (via `packetFlow`); each core terminates/forwards traffic. Two families: **native packet cores** (consume IP directly) and **proxy cores** (speak SOCKS/HTTP, need tun2socks glue).

**WireGuardKit / `wireguard-apple` (native, official reference).** App-side **`TunnelsManager`** (create/edit/delete/activate, KVO status, persistence); **`WireGuardAdapter`** inside the extension (resolves peer `Endpoint` hostnames — wireguard-go does no DNS — builds `NEPacketTunnelNetworkSettings`, drives the core); **wireguard-go C bridge** (`api-apple.go`: `wgTurnOn`/`turnOn` from a tun fd, `wgSetConfig`, `wgTurnOff`, network-change reasserts). Parses **wg-quick** text into `TunnelConfiguration` (`InterfaceConfiguration` + `[PeerConfiguration]`); private keys → keychain. SwiftPM: NE target depends on `WireGuardKitGo` (Go compiled to static archive) + `WireGuardKitC`. `AllowedIPs` → `includedRoutes`; `Address`/`DNS`/`MTU` → network settings. Used by the official app, Mullvad, Streisand.

**sing-box / `libbox` (`sing-box-for-apple`) — multi-protocol workhorse.** Go core compiled with **gomobile** into **`Libbox.xcframework`** (Obj-C/Swift API: `BoxService`, plus a `CommandServer`/`CommandClient` gRPC-style in-process IPC for stats/logs/group selection). The provider implements a **platform interface** giving libbox the tun fd + settings; libbox provides an unprivileged TUN implementation through NetworkExtension and runs the full routing/DNS/outbound engine. Ships as App Extension (SFI, iOS) / System Extension (SFM, macOS). Config is sing-box **JSON** in the app-group container. Coverage: VLESS/Reality, VMess, Trojan, Shadowsocks, **Hysteria2**, TUIC, WireGuard, SSH, ShadowTLS, etc. — one embed covers most needs. Geo-file memory pressure is the main iOS risk.

**Xray-core via `libXray` / gomobile (native + tun2socks).** **`libXray`** (XTLS/libXray) wraps Xray-core, builds an **`.xcframework`** via `python3 build/main.py apple gomobile` (or `apple go`); exposes `RunXray`/`StopXray`, config test, geo-data loaders. iOS uses the same utun packet format as macOS but the fd comes from NetworkExtension; the core is told which fd via env var **`xray.tun.fd`** (set from Swift/Obj-C or a gomobile Go setter). In practice a **tun2socks** shim reads packets from `packetFlow` and dials Xray's SOCKS inbound. Consumers: FoXray, Shadowrocket-style clients, Streisand; some use the `MatsuriDayo/Xray-core` fork.

**hysteria (proxy core; needs tun2socks).** Hysteria2 is QUIC/UDP-based and exposes only **SOCKS5/HTTP** — no packet tunnel of its own. Pair with tun2socks inside the NE, or (most common) get Hysteria2 "for free" as a **sing-box outbound**.

**tun2socks (universal L3↔proxy glue).** Libraries: `xjasonlyu/tun2socks`, `eycorsican/go-tun2socks` (Outline), the Rust **`leaf`** — all build on **gVisor's userspace netstack**. Flow: `packetFlow.readPackets` → gVisor → per-flow TCP/UDP connections → dialed out via SOCKS5/Shadowsocks to the proxy core → responses re-framed into IP packets → `writePackets`. Mandatory for any SOCKS/HTTP-only core (Xray SOCKS inbound, hysteria, SSH `-D`); also where the 50 MB budget is most easily blown.

**Rule of thumb:** WireGuard and sing-box terminate packets natively; Xray/hysteria/SSH are proxy cores requiring tun2socks to become a whole-device VPN.

### 3.10 DNS (including DoH/DoT)

- **In-tunnel DNS:** `NEPacketTunnelNetworkSettings.dnsSettings = NEDNSSettings(servers:)` with `matchDomains`. `matchDomains = [""]` (single empty string) routes **all** DNS into the tunnel; listing a domain matches it **and all subdomains** (implicit wildcard).
- **Encrypted DNS:** iOS 14+ supports **DoH** (`NEDNSOverHTTPSSettings`, `serverURL`) and **DoT** (`NEDNSOverTLSSettings`, `serverName`), installable system-wide via `NEDNSSettingsManager` or scoped in-tunnel. A config-based client usually points the tunnel's `dnsSettings` at a **fake in-tunnel resolver IP** and lets the core (sing-box/Xray) perform the real DoH/DoT/DoQ upstream resolution under its own routing rules.
- **iOS 16+ leak risk:** even when the VPN declares cleartext DNS, iOS may **auto-upgrade** queries to DoH/DoT via network-advertised discovery; and `NEPacketTunnelProvider` intermittently "stops keeping DNS packets flowing." Both are known correctness/leak concerns to test for.

### 3.11 Kill switch — no official API

Two supported approximations:
1. **`NEVPNProtocol.includeAllNetworks = true`** (iOS 14+): the tunnel claims the full default route at the NE layer, so off-tunnel traffic is blocked when the tunnel is down. Caveats are serious — Apple changed docs from "all" to "**most**" traffic; certain Apple/system services, captive-portal, and cellular paths can leak (**IVPN removed their iOS kill switch** over an Apple IP-leak; **Mullvad publicly explains why they still don't use it**). Companion flags: `excludeLocalNetworks` (let LAN/AirDrop/AirPlay bypass) — and when `includeAllNetworks` is on, `excludedRoutes` are **ignored**. iOS 17 introduced a bug where the internet stays blocked after disconnect until reboot.
2. **Always-on via on-demand:** an on-demand `NEOnDemandRuleConnect` matching all interfaces makes iOS re-establish the VPN whenever a network appears; combined with the NE blocking traffic, this is the pragmatic "kill switch" Mullvad/WireGuard iOS actually ship.

### 3.12 On-demand

`NETunnelProviderManager.isOnDemandEnabled = true` + `onDemandRules: [NEOnDemandRule…]`: `NEOnDemandRuleConnect`, `NEOnDemandRuleDisconnect`, `NEOnDemandRuleEvaluateConnection`, `NEOnDemandRuleIgnore`, each with `interfaceTypeMatch` (wifi/cellular), `ssidMatch`, `dnsSearchDomainMatch`. `disconnectOnSleep` **fights on-demand** (OS disconnects on sleep, on-demand immediately reconnects — a documented loop).

### 3.13 Split tunneling / per-app — the actual iOS limits

- **Destination-IP split only (consumer apps):** for a device-wide packet tunnel you get `includedRoutes`/`excludedRoutes` on `NEIPv4Settings`/`NEIPv6Settings`. **IP/CIDR-based only** — **no app awareness, no domain awareness** at the iOS layer.
- **Per-app VPN is MDM-only:** routing specific apps requires a **supervised/managed device** and an MDM-pushed **Per-App VPN payload** (`VPNType = PerApp`, associated bundle IDs). **Not available to App Store consumer apps.** On a per-app VPN, `includedRoutes`/`excludedRoutes` are **ignored** — the mapped app's traffic goes entirely into the tunnel.
- **Consequence:** you can only split by **IP/CIDR** at the OS boundary. Any "route Netflix direct / route this domain via proxy" behavior must be done **inside the core** (sing-box/Xray `route` rules with geoip/geosite/domain matchers) *after* everything is already inside the tunnel. `excludeLocalNetworks`/`enforceRoutes` handle the LAN carve-out.

### 3.14 WireGuard `.conf` (wg-quick) fields

INI-style: `[Interface]` + one or more `[Peer]`. Distinction between **core `wg(8)`** keys and **`wg-quick(8)` convenience** keys matters on iOS.

**`[Interface]`:** `PrivateKey` (required, base64, core); `ListenPort`, `FwMark` (core); `Address` (CIDR(s), wg-quick ext → tunnel's `NEIPv4Settings.addresses`); `DNS` (wg-quick ext; IP entries = resolvers, non-IP = search domains → `NEDNSSettings`); `MTU`, `Table` (wg-quick ext); `PreUp`/`PostUp`/`PreDown`/`PostDown` (wg-quick ext, **unsupported on iOS** — no shell; adapter ignores).

**`[Peer]`:** `PublicKey` (required, core); `PresharedKey` (optional symmetric, core); `AllowedIPs` (CIDR list, core; `0.0.0.0/0, ::/0` = full-tunnel default route → `includedRoutes`); `Endpoint` (`host:port`; the **adapter resolves the hostname** on iOS); `PersistentKeepalive` (seconds; holds NAT/firewall mappings open for roaming clients). Multiple `[Peer]` blocks supported.

### 3.15 SSH-over-NEPacketTunnel considerations

SSH gives a **byte-stream** (local/remote/dynamic `-D` = SOCKS forwarding), not a packet interface, so wrapping it in an iOS VPN has specific pitfalls:
- **Still need tun2socks.** The NE hands IP packets; SSH forwards TCP streams. Run a userspace stack (gVisor tun2socks / `leaf`) that terminates each flow and pushes it through the SSH client's SOCKS. The SSH client is typically Go `crypto/ssh` via gomobile, or libssh2. References: **PrettyTunnel** (SSH → standalone SOCKS5 on iOS), the "SSH Tunnel — SOCKS5" App Store app, **Streisand** (SSH outbound via sing-box).
- **TCP-over-TCP meltdown.** SSH runs over TCP; tunneling app TCP inside stacks two retransmission/congestion controllers, collapsing throughput on lossy links — the dominant reason SSH-VPN underperforms WireGuard/QUIC cores.
- **No UDP.** SSH channels carry no datagrams — QUIC/HTTP3, some VoIP, and UDP DNS break unless the core proxies UDP over a side mechanism. A hard functional gap.
- **Single-connection head-of-line blocking** unless multiplexed; add SSH keepalives so the OS/NAT doesn't drop the long-lived socket.
- **The 50 MiB NE cap** applies to SSH client + tun2socks + netstack buffers combined.
- **iOS has no system SOCKS setting** — PAC-file tricks only cover apps that honor Wi-Fi proxy config; whole-device coverage requires the full tun2socks NE.
- **Fingerprinting:** raw SSH on :22 is trivially DPI-detected/blocked; production stealth wraps it (ShadowTLS/obfs) or prefers VLESS-Reality/Hysteria2.

---

## 4. Feature & UX synthesis

### 4.1 Platform reality (read first)

The three reference clients dominate the free-internet / bug-host / config-sharing scene but are **not** equally native to iOS:
- **HTTP Injector (iOS)** — genuine app, `id1659992827`, iOS 15+, ~3.9★. The most feature-complete of the three on iOS, but noticeably behind its own Android build.
- **HTTP Custom** — the famous app is **Android-only**; the App Store namesake (`id6754261236`) is unrelated and minimal (doesn't support config files). Evaluated from its Android reference build.
- **NPV Tunnel** — genuine cross-platform (iOS `id1629465476` + Android), active (Xray core updated through late 2025). Strong config engine, weak native-iOS polish.

**Headline finding:** all three are **Android-first tools ported (or half-ported) to iOS.** None delivers a truly premium, HIG-native experience — the opening for a modern SwiftUI client.

### 4.2 Feature matrix

| Dimension | HTTP Injector (iOS) | HTTP Custom (Android ref.) | NPV Tunnel (iOS) |
|---|---|---|---|
| **Protocols** | SSH, SSL/TLS, VMess, VLESS (Reality/flow), SOCKS, Shadowsocks, DNSTT/SlowDNS, Hysteria2, WireGuard, WebSocket | SSH, SSL, DNS tunnel, Payload/SNI header injection, custom DNS | VLESS, VMess, Shadowsocks, Trojan, SOCKS, SSH, DNSTT/SlowDNS, Psiphon, UDP modes |
| **Dashboard stats** | Connection state, basic session info; **no rich data-usage graph on iOS** | Home shows connect state + **real-time up/down speed + data counter** | Connect state + **stats monitoring** screen |
| **Live bandwidth** | Limited on iOS | Yes (live speed readout) | Yes (throughput) |
| **Live logging** | Diagnostic/log view, host checker, response checker | Verbose log console | Activity/log screen |
| **Server/config mgmt** | Import/export, free & Pro server list, Payload Generator, Host Checker, IP Hunter, CDN Finder | Import/export `.hc`, config list, DNS changer, SNI/payload editor | Import (file + **QR**), manual builder, ~200-server lists, subscription import |
| **Folders / tags / favorites** | Flat list | Flat list | Partial: subscription grouping; no true favorites/tags |
| **Latency / ping test** | None (users requesting "ping") | None | None built-in — **top user request** |
| **Statistics (D/W/M)** | No historical charts on iOS | Session-only | Session-only |
| **Cloud sync / backup** | Cloud Config import via link/key (`ehi.link`); no true account sync on iOS | `.hc` file sharing only | Subscription URL refresh; no full backup/restore |
| **Config locking** | EHI lock config / prevent editing / lock all options | Locked `.hc` | Config lock |
| **Expiry lock** | Yes | Varies | Yes |
| **HWID / device binding** | Yes (Hardware-ID lock) | Community-locked configs | Header/HWID-style limits via config |
| **Jailbreak detection** | Not surfaced | n/a (Android root) | Not surfaced |
| **Biometric app lock** | None | None | None |
| **Monetization** | Free + Pro servers | Ads / free | **Ads — reportedly force reconnect ~every 5 min** |

### 4.3 Dimension detail

- **Dashboard stats.** HTTP Custom (Android) has the strongest at-a-glance home: big connect toggle with live download/upload speed + data-usage counter front-and-center. Injector's iOS build lacks the rich data-usage dashboard its Android sibling has; NPV has a dedicated stats-monitoring view.
- **Live bandwidth & logging.** All three treat the **log console as a primary surface** (bug-host debugging habit). None offers structured/filterable logs — raw scrolling consoles.
- **Config management.** Import paths: Injector = `.ehi` + Cloud Config link/key; HTTP Custom = `.hc`; NPV = file, manual builder, **QR**, subscription URLs. **Organization is the universal weak spot** — all present a flat list, no folders/tags/color labels. NPV's subscription grouping is the closest thing but it's group-by-source, not user-defined. Injector's discovery tools (Payload Generator, Host Checker, IP Hunter, CDN Finder) are a genuine power-user strength.
- **Statistics.** Biggest collective gap: **none offers historical analytics on iOS** — no per-day/week/month totals, no per-protocol/per-server breakdown, no uptime history. Stats reset on disconnect.
- **Cloud sync.** Injector "Cloud Config" = config distribution, not personal cross-device sync; HTTP Custom = file-based `.hc` only; NPV = subscription-URL refresh. No app offers a true **encrypted account backup + multi-device restore** of the user's own library.
- **Security model.** All three support config locking, expiry lock, and HWID/device binding — but this is entirely **seller-centric** (protect the config from the user). Essentially **nothing user-centric**: none offers Face ID / Touch ID / passcode app-lock, none surfaces jailbreak detection.

### 4.4 User pain points

- **HTTP Injector (iOS):** crashes, connection failures, device heating; protocol regressions (Hysteria "connects but no traffic passes"; Reality/xray import failures); features removed without warning (import-v2ray-config button); iOS lags Android parity; canned developer replies erode trust.
- **HTTP Custom:** real app isn't on iOS; the App Store namesake doesn't support config files and has no documentation; even on Android relies on locked community configs that break as carriers patch bug-hosts.
- **NPV Tunnel:** **no built-in real ping/delay test** (the single most-requested feature — "bulk URL/real-delay test and sort by result"); **ads force a reconnect ~every 5 minutes**; no per-site traffic rules.
- **Shared across all three:** flat unsearchable server lists, raw log dumps, no history/stats, cryptic error states, Android-port aesthetics (dense forms, non-native controls, poor Dynamic Type / dark-mode fidelity), manual tedious server testing.

### 4.5 What to build (recommendations for a SwiftUI/HIG client)

1. **HIG-native home with a hero state + live glanceable stats.** One large state-colored animated connect control, live up/down throughput + session data beneath (HTTP Custom's best idea, rebuilt with SF Symbols, Dynamic Type, plus a **Live Activity + Lock Screen widget**).
2. **Real, automatic latency & health testing.** One-tap and background **TCP/real-delay ping** across the whole server list, color-coded latency badge, auto-sort by result, periodic health check flagging dead configs. Directly answers NPV's #1 request.
3. **A proper config library, not a flat list.** User-defined **folders, favorites (swipe-to-star), color tags, full-text search**; group by protocol/source/subscription/custom tag. `List` sections, `.searchable`, swipe actions, context menus.
4. **Persistent statistics with daily/weekly/monthly rollups.** Store sessions in SwiftData/Core Data; render **Swift Charts** — data used per day/week/month, per-protocol and per-server breakdowns, uptime/reconnect history. Category-defining differentiator.
5. **Structured, filterable logging.** Severity levels, per-connection grouping, filter/search, copy/share a **redacted** log bundle (auto-scrub credentials), human-readable error explanations ("handshake failed: SNI rejected by host") instead of stack traces.
6. **User-centric security layer (the missing half).** **Face ID / Touch ID / passcode app lock**, store SSH passwords + config secrets in the **Keychain** (Secure Enclave-backed), optional lock-on-launch/lock-on-background, jailbreak detection with a clear warning. Keep seller-side config locking, but finally protect the user too.
7. **True encrypted backup & multi-device sync via iCloud.** CloudKit sync of library, folders, tags, preferences, plus an **encrypted, passphrase-protected export bundle** for migration — replacing "paste a link"/"share a file" hacks.
8. **First-class import UX.** Support `.ehi`/`.hc`/v2ray URIs, **QR scan**, share-sheet import, clipboard auto-detect, subscription URLs with scheduled auto-refresh and per-subscription grouping — with a clear **diff preview** ("12 new, 3 removed") instead of silent overwrites.
9. **Honest, actionable connection states.** Real reachability probe post-handshake: a distinct **"Connected · No Internet"** state, retry guidance, inline diagnostic runner (DNS, SNI, host reachability) — learning from Injector's Hysteria complaints.
10. **Per-app / per-domain split tunneling with a visual rule builder.** Expose it as a clear on/off list of apps and domain rules, respecting iOS Network Extension constraints (§3.13 — domain/app splitting must happen inside the core, not at the OS boundary).
11. **Respectful monetization.** Never interrupt an active tunnel (NPV's forced 5-minute reconnect is the anti-pattern). Prefer a clean free tier + non-intrusive Pro (StoreKit 2) unlocking stats history, unlimited favorites, premium servers.
12. **Platform polish.** Full dark-mode fidelity, Dynamic Type, VoiceOver labels on every control, haptics on connect/disconnect, smooth SwiftUI transitions, Shortcuts/App Intents ("Connect to *Fastest JP*"), Control Center / Home-Screen widget.

**Priority stack** (fastest way to leapfrog the field — four things *all three* competitors lack, each achievable with standard SwiftUI/SwiftData/Swift Charts): (2) automatic latency testing, (3) organized searchable library, (4) persistent Swift Charts stats, (6) biometric + Keychain security.

---

## 5. Consolidated sources

**HTTP Injector (`.ehi`, payloads, features):**
- https://apps.evozi.com/httpinjector/ — official app page
- https://www.apkmirror.com/apk/evozi/http-injector/http-injector-6-4-0-release/ — current protocol list
- https://play.google.com/store/apps/details?id=com.evozi.injector — Play listing
- https://www.thaript.com/2021/12/all-settings-of-http-injector-and-their.html — settings, payload keywords, injection methods, VPN/iptables modes, port 8989, lock config
- https://fileinfo.com/extension/ehi · https://whatext.com/file/ehi · https://serptools.github.io/files/ehi/ · https://filext.com/file-extension/EHI — `.ehi` definition/contents
- https://convert.guru/ehi-converter — `.ehi` fields, encryption/lock notes
- https://www.aimtuto.com/2021/08/how-to-create-http-injector-ehi-config-file.html — config fields, payload generator, lock/export/import
- https://blog.fastssh.com/servers/useful-tool/http-injector/how-to-create-a-ehi-configuration-file-for-http-injector/ — `.ehi` = payload + remote proxy + SSH creds
- https://github.com/hndko/payload-injector-generator — exact payload templates and tokens
- https://snihost.com/blog/create-http-injector-files-using-ssl-tls — SNI bug host, SSL/TLS + SSH
- https://snihost.com/payload-generator/about — payload types incl. split/custom headers
- https://github.com/noobconner21/Http-Injector-Decrypt-Script — community `.ehi` decrypt (AES-CBC symmetric)
- https://www.servershttpinjector.com/desencriptar-servidores-ehi/ — `.ehi` AES-CBC reference
- https://evozi-injector.andro.io/ — feature listing mirror
- https://apps.apple.com/us/app/http-injector/id1659992827 (+ reviews) — iOS build & ratings
- https://mwm.ai/apps/http-injector/1659992827 · https://httpinjector.com/ — iOS publisher / official site

**HTTP Custom (`.hc`, features):**
- https://basicutils.com/learn/http-custom/http-custom-app · /http-injector-vs-http-custom · /httpcustom/httpcustom-tutorial-guide · /http-custom/http-custom-review
- https://convert.guru/hc-converter — `.hc` file format analysis
- https://play.google.com/store/apps/details?id=xyz.easypro.httpcustom — Play listing
- https://http-custom.en.uptodown.com/android — Android-only, features
- https://app.kofnet.co.za/set-up-ssl-tls-on-http-custom-for-free-internet/ — SSL/TLS setup
- https://zivpn-ssh.web.app/howto/ssh-ssl-sni_payload.html — SSH SSL(SNI) + Payload
- https://snihost.com/blog/Create-HTTP-Custom-Files-Using-UDP — UDP Custom
- https://udpcustom.online/how-to-setup-http-custom-vpn-with-slowdns/ — SlowDNS setup
- https://udpcustom.online/create-custom-http-payloads-with-our-payload-generator/ — placeholders/injection methods
- https://www.aimtuto.com/2021/09/http-custom-config-files.html — import steps
- https://www.techtutorialshub.com/2024/01/http-custom-config-files-updated-today.html — config import UI
- https://github.com/abdoxfox/HTTP-CUSTOM-HEADERS-VPN — connection modes 0–3
- https://apps.apple.com/us/app/http-custom-tunnel/id6754261236 — unrelated iOS namesake

**NPV Tunnel (`.npv4`, features):**
- https://fileinfo.com/extension/npv4 · https://filext.com/file-extension/NPV4 — `.npv4` file
- https://play.google.com/store/apps/details?id=com.napsternetlabs.napsternetv — Play listing
- https://apps.apple.com/us/app/npv-tunnel/id1629465476 — App Store
- https://napsternetv.en.uptodown.com/android — protocols/features
- https://napsternetv.vonmatrix.com/ — official site
- http://napsternetv-v2ray-vpn-client.apk.watch/123.0 — changelog/versions
- https://snihost.com/blog/Create-NPV-Tunnel-Files-Using-V2Ray — V2Ray config
- https://pinoytechsaga.blogspot.com/2021/02/napsternetv-how-to-create-v2ray-config.html — V2Ray config in NapsternetV
- https://udpcustom.online/download-free-slowdns-files-of-npv-tunnel-vpn/ — SlowDNS/SSH files
- https://apkhome.io/napsternetv-apk/ — npv4 config
- https://www.aimtuto.com/2021/09/sniff-locked-config-files.html — locked config behavior

**Proxy URI / share-link formats:**
- https://github.com/XTLS/Xray-core/discussions/716 — canonical vless:// & vmess:// URI standard
- https://liolok.com/v2ray-subscription-parse/ (+ raw source) — vmess JSON keys + subscription base64
- https://github.com/boypt/vmess2json/blob/master/vmess2json.py — vmess JSON field parsing
- https://github.com/shadowsocks/shadowsocks-org/wiki/SIP002-URI-Scheme · https://shadowsocks.org/doc/sip002.html — SIP002
- https://github.com/shadowsocks/shadowsocks-org/issues/196 — SIP022 (userinfo must not be base64)
- https://v2.hysteria.network/docs/developers/URI-Scheme/ — Hysteria 2 URI
- https://v1.hysteria.network/docs/uri-scheme/ — legacy `upmbps`/`downmbps`
- https://azadzadeh.github.io/trojan-go/en/developer/url/ · https://github.com/trojan-gfw/trojan-url — Trojan URL
- https://github.com/daeuniverse/dae/discussions/182 · https://sing-box.sagernet.org/configuration/outbound/tuic/ · https://wiki.metacubex.one/en/config/inbound/listeners/tuic-v5/ — TUIC v5

**iOS NetworkExtension, cores, DNS, kill switch, split tunnel:**
- https://developer.apple.com/documentation/networkextension/nepackettunnelprovider · /packet-tunnel-provider · /netunnelprovidermanager · /netunnelproviderprotocol · /netunnelprovidersession/sendprovidermessage(_:responsehandler:) · /neondemandrule · /neondemandruledisconnect
- https://kean.blog/post/vpn-configuration-manager · https://kean.blog/post/packet-tunnel-provider
- https://antongubarenko.substack.com/p/ios-personal-vpn-and-network-extensions
- https://deepwiki.com/WireGuard/wireguard-apple · https://github.com/WireGuard/wireguard-apple/blob/master/Sources/WireGuardNetworkExtension/PacketTunnelProvider.swift · .../Sources/Shared/Model/NETunnelProviderProtocol+Extension.swift
- https://sing-box.sagernet.org/clients/apple/ · /clients/apple/features/ · https://deepwiki.com/SagerNet/sing-box/6.3-libbox-command-system · https://github.com/SagerNet/sing-box/issues/3976
- https://github.com/XTLS/libxray · https://github.com/XTLS/Xray-core/blob/main/proxy/tun/README.md · https://github.com/XTLS/Xray-core/issues/4422
- https://v2.hysteria.network/ · https://github.com/xjasonlyu/tun2socks/
- https://github.com/StreisandEffect/streisand · https://apps.apple.com/tj/app/streisand/id6450534064
- https://github.com/twotreeszf/PrettyTunnel · https://developer.apple.com/forums/thread/697691 (mentions `leaf`)
- https://developer.apple.com/forums/thread/73148 · /763586 · http://www.openradar.appspot.com/27660401 — NE memory limits
- https://developer.apple.com/forums/thread/658322 · /111062 · /700075 — split tunnel / per-app
- https://mullvad.net/en/blog/why-we-still-dont-use-includeallnetworks · https://www.ivpn.net/blog/removal-of-kill-switch-from-our-ios-app-due-to-apple-ip-leak-issue/ · https://zionboggan.com/mullvad-ios-killswitch — kill switch
- https://developer.apple.com/videos/play/wwdc2020/10047/ · https://developer.apple.com/forums/thread/720428 · /727012 · /775849 — DNS
- https://manpages.debian.org/testing/wireguard-tools/wg-quick.8.en.html · https://www.wireguard.com/quickstart/ · https://github.com/pirate/wireguard-docs — wg-quick

**UX / security best-practice:**
- https://www.blackfog.com/cybersecurity-101/hwid-lock/ — HWID lock concept
- https://mobisoftinfotech.com/resources/blog/app-security/ios-app-security-checklist-best-practices — iOS security checklist 2025

**Reliability caveats.** No vendor publishes a formal binary schema for `.ehi`/`.hc`/`.npv4`; those field details are triangulated from registries, store descriptions, community guides, and version-pinned decrypt scripts. `.ehi` crypto (AES-CBC + Base64, version-embedded key) is corroborated across secondary sources, not a primary spec. NPV format-behavior claims (encryption change v9.6, SNI/host decoupling v7.4, SSH-SSL v13.9, per-app proxy + subscription org v122) are community-reported changelog items. HTTP Custom UX is assessed from its Android reference build (no equivalent official iOS app). Where the URI ecosystem disagrees, the parser must be lenient on input and strict on output.
