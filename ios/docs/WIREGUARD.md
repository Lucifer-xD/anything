# Real WireGuard core — integration notes

The Packet Tunnel provider is already coded to run a real WireGuard tunnel: see
`Tunnel/PacketTunnelProvider.swift` (guarded by `#if canImport(WireGuardKit)`),
which rebuilds a `wg-quick` config from the `SessionPlan` and drives
`WireGuardAdapter`. What's left is *building* `WireGuardKit` into the app — and
that can't be done in plain GitHub-Actions `xcodebuild`, for two concrete reasons:

1. **`wireguard-apple`'s SwiftPM manifest is broken for modern SwiftPM.** Every
   current ref (incl. tag `1.0.16-27`) declares `// swift-tools-version:5.3` yet
   uses `.iOS(.v15)` / `.macOS(.v12)`, which require 5.5+. Xcode 16 rejects it
   during package resolution.
2. **The `wireguard-go` bridge builds via a `Makefile`** (`WireGuardKitGo`,
   `linkerSettings: [.linkedLibrary("wg-go")]`). Plain `xcodebuild` package
   resolution does not run that Makefile, so the Go library is never produced.

So WireGuardKit must be integrated as a **git submodule + Xcode subproject**, in a
build environment that runs the Go bridge build phase — i.e. **Xcode Cloud** (free
with the paid Apple Developer account) or a **Mac with Xcode**.

## Integration steps (on Xcode Cloud / a Mac)

```bash
cd ios
git submodule add https://github.com/WireGuard/wireguard-apple Vendor/wireguard-apple
```

Then, in `project.yml`, reference WireGuardKit as a subproject target instead of a
package, and add the Go toolchain to the build:

```yaml
targets:
  NimbusTunnel:
    dependencies:
      - package: NimbusKit
      - framework: Vendor/wireguard-apple/...   # or add WireGuardKit.xcodeproj as a subproject
```

Xcode Cloud runs a `ci_scripts/ci_post_clone.sh` before building — install Go there:

```bash
#!/bin/sh
# ci_scripts/ci_post_clone.sh
brew install go
git submodule update --init --recursive
```

Xcode then builds `WireGuardKitGo` (the Makefile runs as a build phase), links
`wg-go`, and `#if canImport(WireGuardKit)` activates the real tunnel path.

## Why Xcode Cloud is the right tool here

- It's **Apple's own CI on real Macs with Xcode** — the Go-bridge build phase just
  works, unlike a generic runner.
- It's **included with the $99 account** (25 compute-hours/month free).
- It **signs and ships to TestFlight** in the same run, so you install/update the
  real VPN on your iPhone over-the-air (no cable, 90-day builds).

## After it builds

1. Add a **WireGuard config** in the app (paste a `.conf` / `wg://`, or scan a QR).
   The `WireGuardModule` + `WireGuardConfParser` already parse it into a session.
2. Set your **Team ID** in `project.yml` (`DEVELOPMENT_TEAM`).
3. Ensure the App IDs `net.nimbus.vpn` and `net.nimbus.vpn.tunnel` have the
   **Network Extensions** + **App Groups** capabilities, and the App Group
   `group.net.nimbus.vpn` exists.
4. Build → TestFlight → install → add config → **Connect** = real traffic.

Other cores (VLESS/Reality/VMess/Trojan via sing-box or Xray) follow the same
pattern: add the core, implement a `TunnelBridge`, switch on `plan.core`.
