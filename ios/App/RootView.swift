import SwiftUI
import NimbusKit

/// The app root: onboarding gate → main tabbed experience with the custom
/// bottom bar (four tabs + a raised center Create button) and the App-Lock
/// overlay. Each tab hosts its own `NavigationStack`.
struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.palette) private var palette
    @State private var showingCreate = false

    var body: some View {
        Group {
            if !model.hasCompletedOnboarding {
                OnboardingFlow()
            } else {
                main
            }
        }
        .nimbusPalette(model.palette)
        .animation(.easeInOut(duration: 0.25), value: model.hasCompletedOnboarding)
    }

    private var main: some View {
        ZStack(alignment: .bottom) {
            palette.bg.ignoresSafeArea()

            // Active tab content.
            Group {
                switch model.tab {
                case .library: LibraryScreen()
                case .subscriptions: SubscriptionsScreen()
                case .tools: ToolsScreen()
                case .settings: SettingsScreen()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            NimbusTabBar(selected: $model.tab) { showingCreate = true }
        }
        .sheet(isPresented: $showingCreate) {
            CreateWizardView(app: model)
                .nimbusPalette(model.palette)
        }
        .overlay {
            if model.isLocked {
                LockScreen()
            }
        }
    }
}

/// The custom translucent tab bar with the raised gradient create button.
struct NimbusTabBar: View {
    @Environment(\.palette) private var palette
    @Binding var selected: AppTab
    let onCreate: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            tab(.library)
            tab(.subscriptions)
            createButton
            tab(.tools)
            tab(.settings)
        }
        .padding(.top, 8)
        .padding(.horizontal, 12)
        .padding(.bottom, 26)
        .background(.ultraThinMaterial)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(palette.border), alignment: .top)
    }

    private func tab(_ item: AppTab) -> some View {
        let isSelected = selected == item
        return Button {
            selected = item
        } label: {
            VStack(spacing: 4) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 20, weight: .regular))
                Text(item.title).font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(isSelected ? palette.accent : Color(hex: "#7a7a80"))
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
        }
        .buttonStyle(.plain)
    }

    private var createButton: some View {
        Button(action: onCreate) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(
                    LinearGradient(colors: [palette.accent, palette.accent.mix(with: Color(hex: "#5E5CE6"), amount: 0.6)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: palette.accent.opacity(0.55), radius: 16, x: 0, y: 8)
                .offset(y: -6)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}
