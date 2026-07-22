# Building a `.ipa`

An `.ipa` cannot be produced in this Linux session (no Xcode) or from source
alone (Apple code-signing is required). Here are the realistic paths, from
free-to-run up to a fully signed release.

## Free & cheap: run the app without paying

The **only** hard cost is the VPN entitlement (see below). Everything else is
free, because the app defaults to `SimulatedTunnelEngine` and needs no special
capability to run:

| How | Cost | Needs | Runs |
|-----|------|-------|------|
| **iOS Simulator** | free | a Mac + Xcode, **no Apple account** | Full app UI, all screens, import/edit, sim engine |
| **Real device, free Apple ID** | free | a Mac + Xcode + `project-free.yml` variant | Same, on your iPhone (re-sign every 7 days) |
| **GitHub Actions / Codemagic / Bitrise** free tier | free | just push the repo | Compiles app + runs the 65 tests on a macOS runner |
| **Cheap cloud Mac** (MacinCloud, Scaleway, AWS EC2 mac, MacStadium) | ~$1–5/hr or ~$20/mo | nothing local | Build + Archive |

Use the bundled **no-extension variant** for free-account/simulator builds:

```bash
cd ios
xcodegen generate --spec project-free.yml
open NimbusVPN.xcodeproj      # select your free Apple ID, Run
```

The **one unavoidable cost** is the real VPN: Apple only grants the
`packet-tunnel-provider` entitlement and App Groups to the **paid Apple Developer
Program ($99/yr)**. No free tier, sideload tool (AltStore/Sideloadly), or trick
changes that — a free personal team cannot sign a Network Extension. So the
system-VPN toggle needs the $99 account; the rest of the app does not.

## What you need first (paid / real-tunnel path)

1. **A Mac with Xcode 15/16.**
2. **An Apple Developer Program membership** ($99/yr) — required for the
   NetworkExtension (`packet-tunnel-provider`) entitlement and App Groups. A free
   personal team cannot ship a Packet Tunnel extension.
3. In the Apple Developer portal, create **two App IDs** with the *Network
   Extensions* and *App Groups* capabilities:
   - `net.nimbus.vpn` (app)
   - `net.nimbus.vpn.tunnel` (extension)
   and an App Group `group.net.nimbus.vpn`, then provisioning profiles for each.

> Before shipping *real* tunnelling, a native protocol core (WireGuardKit /
> sing-box / Xray / OpenVPN) must be wired into `Tunnel/TunnelBridge.swift`. The
> default `SimulatedTunnelEngine` builds and demonstrates the full app UX without
> one, so you can produce a runnable `.ipa` today and add cores incrementally.

## Path A — Xcode GUI (simplest)

```bash
cd ios
brew install xcodegen
xcodegen generate
open NimbusVPN.xcodeproj
```
In Xcode: select the **NimbusVPN** target → *Signing & Capabilities* → pick your
Team (repeat for **NimbusTunnel**). Then **Product → Archive → Distribute App**
→ export the `.ipa`.

## Path B — command line

```bash
cd ios && xcodegen generate
xcodebuild -project NimbusVPN.xcodeproj -scheme NimbusVPN \
  -configuration Release -sdk iphoneos \
  -archivePath build/Nimbus.xcarchive DEVELOPMENT_TEAM=YOURTEAMID archive
# edit ExportOptions.plist (teamID + profile names), then:
xcodebuild -exportArchive -archivePath build/Nimbus.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath build/export
# → build/export/NimbusVPN.ipa
```

## Path C — GitHub Actions (automated) ✅ included

`.github/workflows/ios-nimbus-build.yml` already:
- runs the **65 core tests** on Linux,
- compiles the **app + extension** on a macOS runner (unsigned) on every push —
  this is where the SwiftUI actually compiles,
- and, on manual dispatch **with signing secrets set**, archives and uploads a
  signed **`.ipa` artifact**.

Add these repo secrets to enable the signed export: `APPLE_TEAM_ID`,
`BUILD_CERTIFICATE_BASE64`, `P12_PASSWORD`, `APP_PROVISION_BASE64`,
`TUNNEL_PROVISION_BASE64`, `KEYCHAIN_PASSWORD` (see the workflow header for how to
generate each), fill in `ExportOptions.plist`, then run the workflow from the
Actions tab. The `.ipa` appears as a build artifact.
