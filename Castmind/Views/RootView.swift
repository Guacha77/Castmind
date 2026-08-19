import SwiftUI
import UIKit

struct RootView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.scenePhase) private var scenePhase
    @State private var keyboardVisible = false

    var body: some View {
        ZStack {
            CM.background.ignoresSafeArea(.all)
            if app.settings.hasCompletedOnboarding {
                NavigationStack { activeTab }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        if !keyboardVisible { industrialTabBar }
                    }
            } else {
                OnboardingView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await app.bootstrap() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, app.settings.hasCompletedOnboarding, app.settings.autoLoadModel, !app.ai.isReady, !app.ai.isGenerating else { return }
            Task { await app.preloadModel() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeOut(duration: 0.16)) { keyboardVisible = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.16)) { keyboardVisible = false }
        }
        .alert("Castmind", isPresented: Binding(get: { app.errorMessage != nil }, set: { if !$0 { app.errorMessage=nil } })) {
            Button("Cerrar", role:.cancel) { app.errorMessage=nil }
        } message: { Text(app.errorMessage ?? "") }
        .sheet(isPresented: Binding(get:{app.shareURL != nil}, set:{if !$0{app.shareURL=nil}})) { if let url=app.shareURL { ShareSheet(items:[url]) } }
    }

    @ViewBuilder private var activeTab: some View {
        switch app.selectedTab {
        case .characters: CharacterLibraryView()
        case .chat: ChatView()
        case .rooms: RoomsView()
        case .settings: SettingsView()
        }
    }

    private var industrialTabBar: some View {
        HStack(spacing: 0) {
            tab(.characters, "CHAR", "person.2")
            tab(.chat, "CHAT", "bubble.left")
            tab(.rooms, "ROOM", "person.3")
            tab(.settings, "CFG", "slider.horizontal.3")
        }
        .frame(height: 54)
        .background(CM.background)
        .overlay(alignment:.top){Rectangle().fill(CM.strongBorder).frame(height:1)}
    }

    private func tab(_ value: AppState.RootTab, _ label: String, _ icon: String) -> some View {
        Button { app.selectedTab=value } label: {
            VStack(spacing:4) {
                Image(systemName:icon).font(.system(size:16, weight:.semibold))
                Text(label).font(.system(size:9, weight:.bold, design:.monospaced))
            }
            .foregroundStyle(app.selectedTab == value ? CM.orange : CM.textSecondary)
            .frame(maxWidth:.infinity, maxHeight:.infinity)
            .background(app.selectedTab == value ? CM.elevated : .clear)
        }.buttonStyle(.plain)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items:[Any]
    func makeUIViewController(context:Context)->UIActivityViewController { UIActivityViewController(activityItems:items, applicationActivities:nil) }
    func updateUIViewController(_ uiViewController:UIActivityViewController, context:Context){}
}
