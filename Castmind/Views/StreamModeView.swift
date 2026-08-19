import SwiftUI

struct StreamModeView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showControls = true

    private var lastReply: String {
        app.activeMessages.last(where: { $0.role == .assistant })?.text ?? app.activeCharacter.greeting
    }

    var body: some View {
        ZStack {
            CastmindBackground(accent: Color(hex: app.activeCharacter.accentHex))
            VStack(spacing: 18) {
                HStack {
                    Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 42, height: 42).background(Color.white.opacity(0.07), in: Circle()) }
                    Spacer()
                    ModelStatusBadge()
                    Spacer()
                    Button { withAnimation(.snappy) { showControls.toggle() } } label: { Image(systemName: showControls ? "eye.slash" : "eye").frame(width: 42, height: 42).background(Color.white.opacity(0.07), in: Circle()) }
                }

                Spacer()
                CharacterAvatarView(
                    character: app.activeCharacter,
                    size: 240,
                    speaking: app.speaker.isSpeaking,
                    listening: app.recognizer.isListening,
                    speechPulse: app.speaker.speechPulse,
                    audioLevel: app.recognizer.audioLevel
                )
                VStack(spacing: 5) {
                    Text(app.activeCharacter.name).font(.system(size: 32, weight: .black, design: .rounded))
                    Text(app.speaker.isSpeaking ? "HABLANDO" : app.recognizer.isListening ? "ESCUCHANDO" : "LISTO")
                        .font(.caption.weight(.black)).tracking(1.8)
                        .foregroundStyle(app.speaker.isSpeaking ? CM.green : app.recognizer.isListening ? CM.orange : CM.textSecondary)
                }

                Text(lastReply.isEmpty ? "…" : lastReply)
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(6)
                    .padding(.horizontal, 20)
                    .animation(.easeOut(duration: 0.15), value: lastReply)

                Spacer()
                if showControls {
                    HStack(spacing: 18) {
                        Button {
                            app.speaker.stop()
                        } label: {
                            Label("Silencio", systemImage: "speaker.slash.fill").labelStyle(.iconOnly)
                                .frame(width: 54, height: 54).background(Color.white.opacity(0.08), in: Circle())
                        }
                        Button {
                            Task { await app.toggleMicrophone() }
                        } label: {
                            Image(systemName: app.recognizer.isListening ? "stop.fill" : "mic.fill")
                                .font(.title2.weight(.bold))
                                .frame(width: 76, height: 76)
                                .background(app.recognizer.isListening ? CM.red : Color(hex: app.activeCharacter.accentHex), in: Circle())
                                .shadow(color: Color(hex: app.activeCharacter.accentHex).opacity(0.25), radius: 24)
                        }
                        if app.ai.isGenerating {
                            Button { app.cancelCurrentResponse() } label: {
                                Image(systemName: "stop.fill").frame(width: 54, height: 54).background(CM.orange, in: Circle()).foregroundStyle(CM.background)
                            }
                        } else {
                            Button {
                                app.speaker.speak(lastReply, settings: app.activeCharacter.voice, locale: app.settings.speechLocale)
                            } label: {
                                Image(systemName: "arrow.clockwise").frame(width: 54, height: 54).background(Color.white.opacity(0.08), in: Circle())
                            }
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(18)
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }
}
