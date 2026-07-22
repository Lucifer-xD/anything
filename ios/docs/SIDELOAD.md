# Get Nimbus on your iPhone with **no Mac** (free)

Your setup: Windows + Ubuntu + iPhone, no Mac. Plan: a **free cloud Mac**
(GitHub Actions) compiles the app; you **sideload** it from Windows with a
**free Apple ID**. Cost: $0. Limitation: it runs the full app UI + simulated
"Connected" state (no real traffic routing — that still needs the $99 account).

The app that gets built here is the **free, no-extension variant**
(`project-free.yml`), which a free Apple ID can sign.

---

## Step 1 — Put the code on GitHub (from Ubuntu)

You already have the branch as a git bundle. In a terminal:

```bash
git clone https://github.com/Lucifer-xD/anything.git
cd anything
git fetch /path/to/nimbus-vpn-ios.bundle claude/nimbus-vpn-ios-x37uzv:claude/nimbus-vpn-ios-x37uzv
git push -u origin claude/nimbus-vpn-ios-x37uzv
```

(If `git push` asks for auth, use a GitHub personal-access token as the password.)

## Step 2 — Run the build (in the browser)

1. Open your repo on github.com → **Actions** tab.
2. Pick the **“Nimbus iOS”** workflow → **Run workflow** → choose the
   `claude/nimbus-vpn-ios-x37uzv` branch → **Run**.
3. Wait ~5–10 min. Open the finished run → **Artifacts** →
   download **`NimbusVPN-unsigned-ipa`** (a `.zip` containing
   `NimbusVPN-unsigned.ipa`). Unzip it on your Windows PC.

> Free-tier note: macOS runner minutes are free on public repos; on a private
> repo they draw from your monthly free minutes (a build is ~50–100 counted min).
> If you'd rather not use minutes, **Codemagic** has a 500-min/month free macOS
> tier — same idea, upload the repo and grab the artifact.

## Step 3 — Sideload to the iPhone (from Windows)

Easiest tool: **Sideloadly** (Windows/macOS, free — sideloadly.io). AltStore is
an alternative that auto-refreshes over Wi-Fi.

1. Install **iTunes** (Apple's site) and **Sideloadly** on Windows.
2. Plug the iPhone in via USB, unlock it, tap **Trust** on the phone.
3. Open Sideloadly → drag in `NimbusVPN-unsigned.ipa` → enter your **Apple ID**
   (a free one is fine) → **Start**. It re-signs the app with your account and
   installs it.
4. On the iPhone: **Settings → General → VPN & Device Management →** tap your
   Apple ID → **Trust**.
5. Launch **Nimbus** from the home screen. 🎉

## The catches of free sideloading (normal, not app-specific)

- **7-day expiry** — a free Apple ID signature lasts a week. Re-run Sideloadly
  (or let AltStore auto-refresh) to renew. A paid account extends this to a year.
- **3-app limit** per free Apple ID.
- **No real VPN toggle** — this build has no Network Extension (that needs $99),
  so the connect button drives the *simulated* engine: real timer, live
  bandwidth, streaming logs — just not routing your actual internet.

## When you want the real tunnel

Join the **Apple Developer Program ($99/yr)**, then:
- switch the app to `SimulatedTunnelEngine → PacketTunnelEngine` (one line in
  `NimbusVPNApp.swift`),
- wire a native core into `Tunnel/TunnelBridge.swift` (WireGuardKit is the
  easiest first core),
- add your Team ID and run the **release-ipa** CI job (or Xcode Archive) to get a
  signed build you can put on TestFlight.

See `docs/BUILD_IPA.md` for the signed-build details.
