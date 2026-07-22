# Nimbus VPN — iOS

A **premium, configuration-first iOS tunneling client** in the spirit of HTTP
Injector, HTTP Custom and NPV Tunnel — rebuilt from scratch as a modern SwiftUI
app that follows Apple's Human Interface Guidelines while keeping the power and
flexibility advanced tunnelling users expect.

> Nimbus is not a traditional consumer VPN. It is a **tunnel manager**: users
> import, create, edit, export, organize and share custom tunnel configurations
> across many protocols, then connect through any of them.

This directory (`ios/`) is a self-contained iOS project added alongside the
repository's existing Android app — it does not touch that code.

---

## Highlights

- **18 protocol modules**, each independent and self-describing: WireGuard,
  VLESS + Reality, Hysteria2, TUIC, VLESS, VMess, Trojan, Shadowsocks, SSH
  (with SSL/WS/HTTP payload modes), OpenVPN, SSL/TLS (stunnel), SOCKS4/5,
  HTTP(S) proxy, WebSocket(+TLS), and DNS Tunnel / SlowDNS.
- **Adaptive editor** — the form shows *only* the fields relevant to the chosen
  protocol, driven entirely by a per-protocol schema (Required / Advanced /
  Experimental field tiers).
- **Full configuration system** — create, edit, duplicate, delete, export,
  import, share, folders, search, favorites, pinning, tags, archiving.
- **Import from anywhere** — QR, clipboard, URL, file, and base64 subscriptions;
  real parsers for `vmess://`, `vless://` (incl. Reality), `trojan://`, `ss://`
  (SIP002 + legacy), `hysteria2://`/`hy2://`, `tuic://`, WireGuard `.conf`, and
  `.nimbus` bundles.
- **Dashboard** with connection state, live ↑/↓ bandwidth, session timer, public
  IP, ping, traffic usage and quick connect.
- **Statistics** (daily / weekly / monthly, protocol & server usage, averages),
  a **professional log viewer** (levels, filters, search, auto-scroll, export,
  clear), **server management** (categories, favorites, tags, latency tests,
  health), and **cloud sync** with optional **end-to-end encryption** and
  **conflict resolution**.
- **Premium iOS design** — dark / AMOLED / light themes, six accent colors,
  Face ID app-lock, haptics, custom translucent tab bar.

## Project layout

```
ios/
├── Package.swift              # NimbusKit — Foundation-only core (unit-tested)
├── project.yml                # XcodeGen spec for the app + extension + tests
├── Sources/NimbusKit/         # domain, protocols, parsers, store, services, DI
├── Tests/NimbusKitTests/      # 65 XCTest cases (swift test)
├── App/                       # SwiftUI app (MVVM): DesignSystem, AppModel, Features/, Platform/
├── Tunnel/                    # NEPacketTunnelProvider + TunnelBridge (core boundary)
└── docs/                      # RESEARCH.md, ARCHITECTURE.md, DESIGN.md
```

See **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** for the layering, the
modular protocol pattern, the data flow, and the concurrency model, and
**[docs/RESEARCH.md](docs/RESEARCH.md)** for the Phase-1 research that informed
the parsers and the tunnel integration boundary.

## Building

The **core** builds and tests on any platform with a Swift toolchain:

```bash
cd ios
swift test          # 65 tests, all green
```

The **app + extension** require macOS + Xcode:

```bash
brew install xcodegen
cd ios && xcodegen generate
open NimbusVPN.xcodeproj      # set your Team ID in project.yml first
```

## Scope & honesty

Built and verified here:

- The entire **NimbusKit core** compiles (Swift 6.1) and its **65 unit tests
  pass** — parsers, configuration store, statistics, logging, sync + E2E crypto
  + conflict resolution, and the tunnel controller lifecycle.
- The full **SwiftUI app** (design system + every screen) and the **Network
  Extension** are authored to Xcode-build against that core.

Requires a Mac to compile the UI and a native protocol core + Apple provisioning
to carry real traffic:

- The UI and extension use Apple-only frameworks (SwiftUI, NetworkExtension,
  LocalAuthentication, CryptoKit) and therefore build in Xcode, not on Linux CI.
- Actual packet tunnelling plugs a real core (WireGuardKit / sing-box / Xray /
  OpenVPN / tun2socks) into `Tunnel/TunnelBridge.swift`; the default
  `SimulatedTunnelEngine` reproduces the full connection lifecycle so the app is
  demonstrable without one. This boundary is deliberate and documented — see
  `docs/ARCHITECTURE.md` → *The tunnel integration boundary*.

## Design

The UI implements the imported **Nimbus VPN** design (Claude Design project
`f6b704e4…`), with Phase-3 improvements where a more native, HIG-aligned result
was possible (custom tab bar, statistics & server-management screens, adaptive
editor). Color tokens, themes and accents are ported 1:1 — see
[docs/DESIGN.md](docs/DESIGN.md).
