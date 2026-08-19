import SwiftUI
import UIKit

struct RootView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if app.settings.hasCompletedOnboarding {
                TabView(selection: $app.selectedTab) {
                    NavigationStack { CharacterLibraryView() }
                        .tabItem { Label("Personajes", systemImage: "person.2.fill") }
                        .tag(AppState.RootTab.characters)

                    NavigationStack { ChatView() }
                        .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right.fill") }
                        .tag(AppState.RootTab.chat)

                    NavigationStack { RoomsView() }
                        .tabItem { Label("Salas", systemImage: "person.3.fill") }
                        .tag(AppState.RootTab.rooms)

                    NavigationStack { SettingsView() }
                        .tabItem { Label("Ajustes", systemImage: "slider.horizontal.3") }
                        .tag(AppState.RootTab.settings)
                }
                .tint(Color(hex: app.activeCharacter.accentHex))
            } else {
                OnboardingView()
            }
        }
        .task { await app.bootstrap() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active,
                  app.settings.hasCompletedOnboarding,
                  app.settings.autoLoadModel,
                  !app.ai.isReady,
                  !app.ai.isGenerating else { return }
            Task { await app.preloadModel() }
        }
        .alert("Castmind", isPresented: Binding(
            get: { app.errorMessage != nil },
            set: { if !$0 { app.errorMessage = nil } }
        )) {
            Button("Cerrar", role: .cancel) { app.errorMessage = nil }
        } message: {
            Text(app.errorMessage ?? "")
        }
        .sheet(isPresented: Binding(
            get: { app.shareURL != nil },
            set: { if !$0 { app.shareURL = nil } }
        )) {
            if let url = app.shareURL { ShareSheet(items: [url]) }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
