# Nimbus VPN — Architecture

Nimbus is a **configuration-first iOS tunneling client** in the tradition of HTTP
Injector / HTTP Custom / NPV Tunnel, rebuilt as a modern SwiftUI app. This
document explains how the codebase is organized, the patterns it follows, and —
importantly — the line between what is *fully implemented and tested* and what is
a *documented integration boundary* requiring a native protocol core, Xcode, and
Apple provisioning to become a shipping tunnelling binary.

## Layered / Clean Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│  App  (SwiftUI, MVVM)          — App/                             │
│    • DesignSystem  (theme tokens, components)                     │
│    • AppModel  (@MainActor ObservableObject — the SwiftUI bridge) │
│    • Feature screens  (Library, Detail, Create, Subscriptions,    │
│      Tools, Logs, Statistics, Settings, Servers, Onboarding)      │
│    • Platform impls  (Keychain, LocalAuthentication, URLSession,  │
│      PacketTunnelEngine)                                           │
├──────────────────────────────────────────────────────────────────┤
│  NimbusKit  (Foundation-only core — Sources/NimbusKit/)           │
│    Domain      models, ProtocolKind, dynamic field schema         │
│    Protocols   ProtocolModule per protocol + registry             │
│    Config      URI parsers, serialization, store + persistence    │
│    Services    tunnel controller + engine, statistics, logging,   │
│                servers, cloud sync (+E2E), DNS, security           │
│    DI          AppServices composition root                       │
├──────────────────────────────────────────────────────────────────┤
│  Tunnel  (Network Extension — Tunnel/)                            │
│    PacketTunnelProvider → TunnelBridge → «real core plugs in»     │
└──────────────────────────────────────────────────────────────────┘
```

**Dependency rule:** the App depends on NimbusKit abstractions; NimbusKit depends
on nothing but `Foundation`. Anything Apple-only (CryptoKit, LocalAuthentication,
NetworkExtension, Security, Network) is expressed in NimbusKit as a *protocol*
and implemented in the App/Extension targets. That is what keeps the core
buildable and unit-tested on Linux CI (`swift test`) as well as on device.

## The modular protocol system (the heart)

Every protocol — WireGuard, VLESS+Reality, Hysteria2, TUIC, VMess, Trojan,
Shadowsocks, SSH, OpenVPN, stunnel, SOCKS4/5, HTTP(S) proxy, WebSocket(+TLS),
DNS Tunnel — is an **independent module** conforming to `ProtocolModule`:

```swift
protocol ProtocolModule {
    var kind: ProtocolKind { get }
    var fieldSchema: [FieldSection] { get }          // drives the adaptive editor
    var uriSchemes: [String] { get }                 // e.g. ["vless"]
    func parse(_ uri: ConfigURI) throws -> TunnelConfiguration?
    func exportURI(_ config: TunnelConfiguration) -> String?
    func validate(_ config: TunnelConfiguration) -> [ValidationIssue]
    func makeSessionPlan(_ config: TunnelConfiguration) throws -> SessionPlan
}
```

Modules live in `Sources/NimbusKit/Domain/Protocols/Modules/`. Adding a protocol
is: add one file + register it in `ProtocolRegistry`. Nothing else changes —
the editor, library, import/export, and tunnel planner all key off `ProtocolKind`
and the module.

### One model, dynamic fields

There is a single `TunnelConfiguration` value type for *all* protocols:

```swift
struct TunnelConfiguration {
    var id: UUID
    var kind: ProtocolKind
    var fields: ConfigFields        // dynamic [key: ConfigValue], described by the schema
    var metadata: ConfigMetadata    // folder, tags, favorite/pinned, latency, traffic, timestamps
}
```

`ConfigFields` is a type-tagged bag keyed by schema field keys (`FieldKey`). The
editor (`ProtocolFormView`) iterates `kind.fieldSchema` and binds each field to
`fields[key]`, so the UI adapts automatically. Parsers write into `fields`; the
tunnel planner reads typed values back out. This mirrors the imported design's
`form`/`SCHEMAS` model exactly.

## Data flow (connection lifecycle)

```
User taps Connect
  → AppModel.connect(id)
    → TunnelController.connect                      (Services/Tunnel)
      → ProtocolModule.validate + makeSessionPlan   (per-protocol)
      → StatisticsService.beginSession
      → ConfigurationStore.recordConnection
      → TunnelEngine.start(plan)  → AsyncStream<TunnelEvent>
          ├─ .state(.connecting/.connected/…)  → AppModel.connection
          ├─ .traffic(sample)                  → AppModel.sample + StatisticsService
          └─ .log(entry)                       → LogStore  → Logs screen
  User taps Disconnect
  → TunnelController.disconnect → engine.stop → finalizeSession (StatisticsService.endSession)
```

`TunnelEngine` is the abstraction; `SimulatedTunnelEngine` is the default
implementation (reproduces the full lifecycle, ~1 Hz throughput, handshake logs)
so the entire app is exercised end-to-end without a native core.

## Concurrency model

- Core services that hold mutable state are **actors** (`DefaultConfigurationStore`,
  `TunnelController`, `LogStore`, `StatisticsService`, `ServerRegistry`,
  `LocalMockCloudSyncService`).
- Cross-cutting fan-out uses `AsyncBroadcaster<T>` (multi-subscriber `AsyncStream`).
- The UI layer is a single `@MainActor` `AppModel` that consumes those async
  streams and republishes `@Published` state — no Combine plumbing in views.
- Everything is `async/await`; there are no completion handlers in the core.

## Persistence & sync

- `ConfigurationStore` persists a `StoreSnapshot` via injectable `ConfigPersisting`
  (`FilePersistence` writes atomic JSON to the shared app-group container).
- `StatisticsService` persists session history similarly.
- `CloudSyncService` (protocol) backs up/restores/merges the library. The bundled
  `LocalMockCloudSyncService` emulates the cloud with an encrypted envelope and
  exercises the full path — sign-in, **E2E encryption** (`AESGCMCipher`, HKDF-SHA256
  key derivation), backup/restore, and **conflict resolution** (`ConflictResolver`,
  newer-wins / prefer-local / prefer-remote). Production swaps in a
  `CloudKitSyncService` behind the same protocol.

## The tunnel integration boundary (what's simulated)

Everything above `TunnelEngine` is real and tested. The two implementations are:

| Engine | Where | What it does |
|--------|-------|--------------|
| `SimulatedTunnelEngine` | NimbusKit (default) | Real lifecycle + throughput + logs, no packets |
| `PacketTunnelEngine` | App/Platform | Drives `NETunnelProviderManager`, starts the extension |

Inside the extension, `PacketTunnelProvider` decodes the `SessionPlan` and hands
it to a `TunnelBridge`. The bundled `ReferenceTunnelBridge` applies network
settings and reports a healthy session; a **real** bridge (WireGuardKit / sing-box
`libbox` / Xray `libXray` / OpenVPNAdapter / tun2socks, chosen by `plan.core`) is
where actual packet-carrying is implemented. See `docs/RESEARCH.md §3` for the
per-core embedding notes and the iOS memory-budget constraints. Shipping real
tunnelling additionally requires a paid Apple Developer account, the
`packet-tunnel-provider` entitlement, an app group, and provisioning — none of
which can be produced from source alone.

## Testing

`Tests/NimbusKitTests` (run with `swift test`) covers the load-bearing logic:
parsers for every URI scheme, export↔import round-trips, the WireGuard `.conf`
parser, the import pipeline (single link / base64 subscription / `.conf` /
bundle), the store (CRUD, folders, subscriptions, persistence, change events),
`ConfigQuery` (filter/search/sort/pinned-first/archived), statistics aggregation
(summary/buckets/protocol+server slices), cloud sync + conflict resolution + E2E
cipher, and the tunnel controller lifecycle end-to-end against the simulated
engine. **65 tests, all green.**

## Build

```bash
cd ios
swift test                 # NimbusKit core — runs anywhere Swift runs
brew install xcodegen      # macOS only
xcodegen generate          # produces NimbusVPN.xcodeproj from project.yml
open NimbusVPN.xcodeproj    # build/run the app + extension in Xcode
```
