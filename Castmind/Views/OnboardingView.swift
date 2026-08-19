import SwiftUI
import UIKit

struct OnboardingView: View {
    @EnvironmentObject private var app: AppState
    @State private var page: Int

    init(initialPage: Int = 0) {
        _page = State(initialValue: initialPage)
    }

    var body: some View {
        ZStack {
            CastmindBackground(accent: accent)

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 22)
                    .padding(.top, 18)

                GeometryReader { proxy in
                    ScrollView {
                        pageContent
                            .frame(maxWidth: 520)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, horizontalPadding(for: proxy.size.width))
                            .padding(.top, 18)
                            .padding(.bottom, 18)
                            .frame(minHeight: proxy.size.height, alignment: .center)
                    }
                    .scrollIndicators(.hidden)
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBar
        }
        .animation(.snappy(duration: 0.28), value: page)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("CASTMIND")
                .font(.caption.weight(.black))
                .tracking(3)
                .foregroundStyle(CM.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 12)
            Text("V2.0.1")
                .font(.caption2.weight(.black))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(CM.purple.opacity(0.16), in: Capsule())
                .foregroundStyle(CM.purple)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var pageContent: some View {
        switch page {
        case 0:
            hero
                .transition(.move(edge: .leading).combined(with: .opacity))
        case 1:
            modelChoice
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        default:
            readyPage
                .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }

    private var hero: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(CM.purple.opacity(0.13))
                    .frame(width: 176, height: 176)
                    .blur(radius: 18)
                Image(systemName: "person.crop.circle.badge.sparkles")
                    .font(.system(size: 82, weight: .thin))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(CM.purple)
            }

            VStack(spacing: 10) {
                Text("Personajes que viven en tu iPhone")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Crea personajes independientes con memoria, voz, estados, avatar y personalidad. El cerebro se ejecuta localmente.")
                    .font(.body)
                    .foregroundStyle(CM.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var modelChoice: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("Elige el cerebro")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Puedes cambiarlo después. Todos los personajes comparten el modelo en RAM para cambiar entre ellos al instante.")
                    .font(.callout)
                    .foregroundStyle(CM.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                ForEach(LocalModelChoice.allCases) { choice in
                    ModelChoiceRow(
                        choice: choice,
                        isSelected: choice == app.settings.modelChoice
                    ) {
                        app.settings.modelChoice = choice
                        app.saveSettings()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
            }
        }
    }

    private var readyPage: some View {
        VStack(spacing: 18) {
            CharacterAvatarView(
                character: app.activeCharacter,
                size: 138,
                speaking: app.speaker.isSpeaking,
                listening: app.recognizer.isListening,
                speechPulse: app.speaker.speechPulse,
                audioLevel: app.recognizer.audioLevel
            )

            VStack(spacing: 10) {
                Text(app.ai.isReady ? "Todo listo" : "Prepara Castmind")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                Text(app.ai.isReady ? "El modelo está cargado. A partir de aquí Castmind intentará cargarlo automáticamente al abrir la app." : "La primera carga descarga el modelo. Las siguientes aperturas lo cargarán automáticamente desde el almacenamiento del iPhone.")
                    .font(.callout)
                    .foregroundStyle(CM.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let progress = app.modelProgress {
                VStack(spacing: 8) {
                    ProgressView(value: progress).tint(CM.purple)
                    Text("Descargando · \(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundStyle(CM.textSecondary)
                }
                .padding(.horizontal, 18)
            } else {
                ModelStatusBadge().environmentObject(app)
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 14) {
            pageIndicators

            Button(action: primaryAction) {
                HStack(spacing: 8) {
                    if isWorking { ProgressView().tint(.white) }
                    Text(buttonTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    if !isWorking { Image(systemName: page < 2 ? "arrow.right" : "sparkles") }
                }
            }
            .buttonStyle(CMPrimaryButtonStyle(accent: accent))
            .disabled(isWorking)
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }

    private var pageIndicators: some View {
        HStack(spacing: 7) {
            ForEach(0..<3) { index in
                Capsule()
                    .fill(index == page ? Color.white : Color.white.opacity(0.18))
                    .frame(width: index == page ? 26 : 7, height: 7)
                    .animation(.snappy(duration: 0.22), value: page)
            }
        }
        .accessibilityLabel("Página \(page + 1) de 3")
    }

    private var accent: Color {
        switch page {
        case 1: return CM.cyan
        case 2: return CM.green
        default: return CM.purple
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
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.snappy(duration: 0.28)) { page += 1 }
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

    private func horizontalPadding(for width: CGFloat) -> CGFloat {
        width <= 340 ? 16 : 22
    }
}

private struct ModelChoiceRow: View {
    let choice: LocalModelChoice
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: iconName)
                    .font(.title3.weight(.semibold))
                    .frame(width: 30, height: 30)
                    .foregroundStyle(isSelected ? CM.cyan : CM.textSecondary)

                VStack(alignment: .leading, spacing: 7) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            title
                            badge
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            title
                            badge
                        }
                    }

                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(CM.textSecondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(size)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(CM.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? CM.cyan : CM.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .background(CM.elevated.opacity(0.9), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? CM.cyan.opacity(0.48) : CM.border, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private var title: some View {
        Text(choice.title)
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.9)
    }

    private var badge: some View {
        Text(choice.badge)
            .font(.caption2.weight(.black))
            .foregroundStyle(CM.cyan)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(CM.cyan.opacity(0.12), in: Capsule())
            .fixedSize()
    }

    private var iconName: String {
        switch choice {
        case .fast: return "bolt.fill"
        case .balanced: return "sparkles"
        case .quality: return "brain.head.profile"
        }
    }

    private var detail: String {
        switch choice {
        case .fast: return "Muy ligero · respuestas rápidas"
        case .balanced: return "Mejor equilibrio para iPhone 16"
        case .quality: return "Más capaz · mayor uso de RAM"
        }
    }

    private var size: String {
        switch choice {
        case .fast: return "~335 MB"
        case .balanced: return "~1.7 GB"
        case .quality: return "~2.3 GB"
        }
    }
}

#Preview("Cerebro iPhone 16") {
    OnboardingView(initialPage: 1)
        .environmentObject(AppState())
        .previewLayout(.fixed(width: 393, height: 852))
}

#Preview("Cerebro iPhone SE") {
    OnboardingView(initialPage: 1)
        .environmentObject(AppState())
        .previewLayout(.fixed(width: 375, height: 667))
}

#Preview("Cerebro 320x568") {
    OnboardingView(initialPage: 1)
        .environmentObject(AppState())
        .previewLayout(.fixed(width: 320, height: 568))
}

#Preview("Cerebro Pro Max") {
    OnboardingView(initialPage: 1)
        .environmentObject(AppState())
        .previewLayout(.fixed(width: 430, height: 932))
}

#Preview("Cerebro Dynamic Type") {
    OnboardingView(initialPage: 1)
        .environmentObject(AppState())
        .environment(\.dynamicTypeSize, .accessibility2)
        .previewLayout(.fixed(width: 393, height: 852))
}
