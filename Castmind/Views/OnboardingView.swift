import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var app: AppState
    @State private var page = 0

    var body: some View {
        ZStack {
            CastmindBackground(accent: CM.purple)
            VStack(spacing: 24) {
                HStack {
                    Text("CASTMIND").font(.caption.weight(.black)).tracking(3).foregroundStyle(CM.textSecondary)
                    Spacer()
                    Text("V2").font(.caption2.weight(.black)).padding(.horizontal, 8).padding(.vertical, 5).background(CM.purple.opacity(0.16), in: Capsule()).foregroundStyle(CM.purple)
                }

                Spacer()
                if page == 0 {
                    hero
                } else if page == 1 {
                    modelChoice
                } else {
                    readyPage
                }
                Spacer()

                Button(action: primaryAction) {
                    HStack(spacing: 8) {
                        if isWorking { ProgressView().tint(.white) }
                        Text(buttonTitle)
                        if !isWorking { Image(systemName: page < 2 ? "arrow.right" : "sparkles") }
                    }
                }
                .buttonStyle(CMPrimaryButtonStyle())
                .disabled(isWorking)

                HStack(spacing: 7) {
                    ForEach(0..<3) { index in
                        Capsule()
                            .fill(index == page ? Color.white : Color.white.opacity(0.18))
                            .frame(width: index == page ? 26 : 7, height: 7)
                    }
                }
            }
            .padding(22)
        }
    }

    private var hero: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle().fill(CM.purple.opacity(0.13)).frame(width: 210, height: 210).blur(radius: 22)
                Image(systemName: "person.crop.circle.badge.sparkles")
                    .font(.system(size: 96, weight: .thin))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(CM.purple)
            }
            Text("Personajes que viven\nen tu iPhone")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            Text("Crea personajes independientes con memoria, voz, estados, avatar y personalidad. El cerebro se ejecuta localmente.")
                .font(.body).foregroundStyle(CM.textSecondary).multilineTextAlignment(.center)
        }
    }

    private var modelChoice: some View {
        VStack(spacing: 18) {
            Text("Elige el cerebro")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text("Puedes cambiarlo después. Todos los personajes comparten el modelo en RAM para cambiar entre ellos al instante.")
                .foregroundStyle(CM.textSecondary).multilineTextAlignment(.center)
            VStack(spacing: 10) {
                ForEach(LocalModelChoice.allCases) { choice in
                    Button {
                        app.settings.modelChoice = choice
                        app.saveSettings()
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: choice == .fast ? "bolt.fill" : choice == .balanced ? "sparkles" : "brain.head.profile")
                                .font(.title3).frame(width: 30).foregroundStyle(choice == app.settings.modelChoice ? CM.purple : CM.textSecondary)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack { Text(choice.title).font(.headline); Text(choice.badge).font(.caption2.weight(.black)).foregroundStyle(CM.purple) }
                                Text(choice.subtitle).font(.caption).foregroundStyle(CM.textSecondary)
                            }
                            Spacer()
                            Image(systemName: choice == app.settings.modelChoice ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(choice == app.settings.modelChoice ? CM.purple : CM.textTertiary)
                        }
                        .padding(16)
                        .background(CM.elevated.opacity(0.9), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(choice == app.settings.modelChoice ? CM.purple.opacity(0.45) : CM.border))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var readyPage: some View {
        VStack(spacing: 20) {
            CharacterAvatarView(character: app.activeCharacter, size: 154, speaking: app.speaker.isSpeaking, listening: app.recognizer.isListening, speechPulse: app.speaker.speechPulse, audioLevel: app.recognizer.audioLevel)
            Text(app.ai.isReady ? "Todo listo" : "Prepara Castmind")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text(app.ai.isReady ? "El modelo está cargado. A partir de aquí Castmind intentará cargarlo automáticamente al abrir la app." : "La primera carga descarga el modelo. Las siguientes aperturas lo cargarán automáticamente desde el almacenamiento del iPhone.")
                .foregroundStyle(CM.textSecondary).multilineTextAlignment(.center)
            if let progress = app.modelProgress {
                VStack(spacing: 8) {
                    ProgressView(value: progress).tint(CM.purple)
                    Text("Descargando · \(Int(progress * 100))%").font(.caption).foregroundStyle(CM.textSecondary)
                }
                .padding(.horizontal, 18)
            } else {
                ModelStatusBadge().environmentObject(app)
            }
        }
    }

    private var isWorking: Bool {
        switch app.ai.phase {
        case .downloading, .loading, .warming, .generating: return true
        default: return false
        }
    }

    private var buttonTitle: String {
        if page < 2 { return "Continuar" }
        return app.ai.isReady ? "Entrar en Castmind" : "Descargar y preparar"
    }

    private func primaryAction() {
        if page < 2 {
            withAnimation(.snappy) { page += 1 }
            return
        }
        if app.ai.isReady {
            app.completeOnboarding()
            return
        }
        Task {
            await app.preloadModel()
            if app.ai.isReady { app.completeOnboarding() }
        }
    }
}
