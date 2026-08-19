import SwiftUI

@main
struct CastmindApp: App {
    @StateObject private var store = CastmindStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .task {
                    await store.bootstrap()
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: CastmindStore

    var body: some View {
        if store.profile.hasCompletedOnboarding {
            MainView()
        } else {
            OnboardingView()
        }
    }
}

struct OnboardingView: View {
    @EnvironmentObject private var store: CastmindStore

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Spacer(minLength: 24)

            VStack(alignment: .leading, spacing: 10) {
                Text("Castmind")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                Text("IA local, personaje editable y voz del sistema. Sin API keys, sin servicios de pago.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 14) {
                Label("Qwen se descarga bajo demanda", systemImage: "arrow.down.circle")
                Label("Tus chats y memoria viven en el iPhone", systemImage: "lock")
                Label("Dictado y lectura en voz alta usan iOS", systemImage: "waveform")
            }
            .font(.headline)

            Spacer()

            Button {
                store.profile.hasCompletedOnboarding = true
                store.saveProfile()
            } label: {
                Text("Entrar")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(24)
        .background(CastmindTheme.background.ignoresSafeArea())
    }
}

struct MainView: View {
    @EnvironmentObject private var store: CastmindStore
    @State private var selection: CastmindTab = .chat

    var body: some View {
        TabView(selection: $selection) {
            ChatView()
                .tabItem { Label("Chat", systemImage: "message") }
                .tag(CastmindTab.chat)

            ModelView()
                .tabItem { Label("Modelo", systemImage: "cpu") }
                .tag(CastmindTab.model)

            CharacterView()
                .tabItem { Label("Personaje", systemImage: "person.crop.circle") }
                .tag(CastmindTab.character)

            SettingsView()
                .tabItem { Label("Ajustes", systemImage: "slider.horizontal.3") }
                .tag(CastmindTab.settings)
        }
    }
}

enum CastmindTab {
    case chat
    case model
    case character
    case settings
}

enum CastmindTheme {
    static let background = LinearGradient(
        colors: [Color(red: 0.06, green: 0.07, blue: 0.08), Color(red: 0.09, green: 0.12, blue: 0.11)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
