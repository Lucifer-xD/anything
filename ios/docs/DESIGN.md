# Nimbus VPN — Design

The UI is the implementation of the imported **Nimbus VPN** design
(`claude.ai/design` project `f6b704e4-52c3-4eb3-8081-152604f7a9e4`, file
`Nimbus VPN.dc.html`), translated to native SwiftUI and extended where a more
HIG-aligned result was possible (Phase 3).

## Color tokens

Ported 1:1 from the design's CSS custom properties into `NimbusPalette`
(`App/DesignSystem/Theme.swift`). Every view reads these via `@Environment(\.palette)`.

| Token | Dark | AMOLED | Light |
|-------|------|--------|-------|
| `bg` | `#0b0b0d` | `#000000` | `#eef0f4` |
| `elev1` | `#151517` | `white 4.5%` | `#ffffff` |
| `elev2` | `#1d1d20` | `white 8%` | `#ffffff` |
| `border` | `white 9%` | `white 8%` | `black 7%` |
| `divider` | `white 6%` | `white 5%` | `black 5.5%` |
| `text` | `#ffffff` | `#ffffff` | `#1c1c1e` |
| `text2` | `#ebebf5 60%` | — | `#3c3c43 62%` |
| `text3` | `#ebebf5 32%` | — | `#3c3c43 32%` |
| `console` | `#08080a` | `#000000` | `#16161a` |

Fixed status colors across all themes: success `#30D158`, warning `#FF9F0A`,
danger `#FF453A`.

## Accents

Six accent options (`AppAccent`): blue `#0A84FF` (default), indigo `#5E5CE6`,
green `#30D158`, purple `#BF5AF2`, teal `#64D2FF`, orange `#FF9F0A`.

## Protocol palette

Each `ProtocolKind` carries a tint used for its chip and cards (see
`ProtocolMetadata`): WireGuard `#30D158`, Reality/VLESS `#0A84FF`, Hysteria2/purple
`#BF5AF2`, VMess/SSH `#FF9F0A`, Trojan `#FF453A`, Shadowsocks/stunnel `#64D2FF`,
OpenVPN `#FFD60A`, etc.

## Screen ↔ design-section map

| Screen (file) | Design section |
|---------------|----------------|
| `Onboarding/OnboardingFlow.swift` | SPLASH · ONBOARDING · PERMISSIONS · LOGIN |
| `Library/LibraryScreen.swift` + `DashboardConnectionCard` + `ConfigCardView` | HOME · CONFIG LIBRARY |
| `Detail/ConfigDetailScreen.swift` | CONFIG DETAIL |
| `Create/CreateWizardView.swift` | CREATE WIZARD |
| `Subscriptions/SubscriptionsScreen.swift` | SUBSCRIPTIONS |
| `Tools/ToolsScreen.swift` + Speed/DNS/IP | TOOLS · SPEED TEST · DNS LEAK · IP LOOKUP |
| `Logs/LogsScreen.swift` | LOGS |
| `Settings/SettingsScreen.swift` + `SecurityScreen` | SETTINGS · APPEARANCE · SECURITY |
| `Statistics/StatisticsScreen.swift` | *(Phase 3 addition)* |
| `Servers/ServersScreen.swift` | *(Phase 3 addition — spec: Server Management)* |
| `RootView.swift` → `NimbusTabBar` | TAB BAR |

## Phase-3 improvements over the imported design

- **Native custom tab bar** with a raised gradient Create button, built with
  SwiftUI materials instead of the mocked chrome.
- **Adaptive editor** (`ProtocolFormView`) generated from each protocol's schema,
  with Required/Advanced/Experimental field tiers — one component for every
  protocol.
- **Statistics** and **Server Management** screens the prototype only implied.
- Full **theme + accent** theming wired through the environment so every surface,
  including the tab bar and console, recolors live.
- Standard iOS affordances: context menus, swipe actions, share sheets, Face ID.

## Reusable components

`App/DesignSystem/Components.swift`: `SectionLabel`, `PrimaryButton`,
`GhostButton`, `ProtocolChip`, `LevelBadge`, `LatencyPill`, `TagChip`,
`ChoiceChip`, `SearchField`, `ScreenTitle`, `BackButton`, and the `.nimbusCard()`
surface modifier — used consistently across every screen.
