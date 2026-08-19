import SwiftUI

struct StreamModeView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showControls = true

    private var lastReply: String {
        app.activeMessages.last(where: { $0.role == .assistant })?.text ?? ""
    }

    var body: some View {
        ZStack {
            CM.background.ignoresSafeArea(.all)
            Rectangle().fill(CM.orange).frame(height: 2).frame(maxHeight: .infinity, alignment: .top).ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 18)
                CharacterAvatarView(
                    character: app.activeCharacter,
                    size: 220,
                    speaking: app.speaker.isSpeaking,
                    listening: app.recognizer.isListening,
                    speechPulse: app.speaker.speechPulse,
                    audioLevel: app.recognizer.audioLevel
                )
                .padding(.bottom, 16)

                VStack(spacing: 6) {
                    Text(app.activeCharacter.name.uppercased())
                        .font(.system(size: 27, weight: .black, design: .monospaced))
                    Text(runtimeState)
                        .font(.caption.monospaced().bold())
                        .foregroundStyle(runtimeColor)
                }

                Text(lastReply.isEmpty ? "WAITING_FOR_INPUT" : lastReply)
                    .font(.system(size: 18, weight: .medium, design: .default))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(lastReply.isEmpty ? CM.textTertiary : .white)
                    .lineLimit(7)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .animation(.easeOut(duration: 0.12), value: lastReply)

                Spacer(minLength: 20)
                if showControls { controls.transition(.move(edge: .bottom).combined(with: .opacity)) }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }

    private var topBar: some View {
        HStack(spacing: 0) {
            Button { dismiss() } label: {
                Text("EXIT").font(.caption.monospaced().bold()).foregroundStyle(.white).frame(width: 64, height: 44)
            }
            Spacer()
            ModelStatusBadge()
            Spacer()
            Button { withAnimation(.easeOut(duration: 0.15)) { showControls.toggle() } } label: {
                Text(showControls ? "HIDE_UI" : "SHOW_UI").font(.caption.monospaced().bold()).foregroundStyle(CM.orange).frame(width: 80, height: 44)
            }
        }
        .overlay(alignment: .bottom) { Rectangle().fill(CM.strongBorder).frame(height: 1) }
    }

    private var controls: some View {
        HStack(spacing: 0) {
            control("MUTE", icon: "speaker.slash.fill") { app.speaker.stop() }
            control(app.recognizer.isListening ? "STOP" : "TALK", icon: app.recognizer.isListening ? "stop.fill" : "mic.fill", highlighted: true) {
                Task { await app.toggleMicrophone() }
            }
            if app.ai.isGenerating {
                control("CANCEL", icon: "xmark") { app.cancelCurrentResponse() }
            } else {
                control("REPLAY", icon: "arrow.clockwise") {
                    app.speaker.speak(lastReply, settings: app.activeCharacter.voice, locale: app.settings.speechLocale)
                }
            }
        }
        .frame(height: 66)
        .overlay(Rectangle().stroke(CM.strongBorder))
    }

    private func control(_ title: String, icon: String, highlighted: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 17, weight: .bold))
                Text(title).font(.system(size: 9, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(highlighted ? .black : .white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(highlighted ? CM.orange : CM.elevated)
        }.buttonStyle(.plain)
    }

    private var runtimeState: String {
        if app.speaker.isSpeaking { return "TX / SPEAKING" }
        if app.recognizer.isListening { return "RX / LISTENING" }
        if app.ai.isGenerating { return "AI / GENERATING" }
        return "LOCAL / READY"
    }

    private var runtimeColor: Color {
        if app.speaker.isSpeaking { return CM.green }
        if app.recognizer.isListening || app.ai.isGenerating { return CM.orange }
        return CM.textSecondary
    }
}
