import SwiftUI

extension Color {
    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&value)
        switch clean.count {
        case 3:
            self.init(.sRGB,
                      red: Double((value >> 8) & 0xF) / 15,
                      green: Double((value >> 4) & 0xF) / 15,
                      blue: Double(value & 0xF) / 15,
                      opacity: 1)
        default:
            self.init(.sRGB,
                      red: Double((value >> 16) & 0xFF) / 255,
                      green: Double((value >> 8) & 0xFF) / 255,
                      blue: Double(value & 0xFF) / 255,
                      opacity: 1)
        }
    }
}

enum CM {
    static let background = Color(hex: "090B11")
    static let elevated = Color(hex: "11141D")
    static let elevated2 = Color(hex: "171B27")
    static let textSecondary = Color.white.opacity(0.62)
    static let textTertiary = Color.white.opacity(0.38)
    static let border = Color.white.opacity(0.09)
    static let purple = Color(hex: "9C6BFF")
    static let cyan = Color(hex: "62D8FF")
    static let green = Color(hex: "62E6A8")
    static let orange = Color(hex: "FFAA5C")
    static let red = Color(hex: "FF657D")
}

struct CastmindBackground: View {
    var accent: Color = CM.purple
    var body: some View {
        ZStack {
            CM.background
            RadialGradient(colors: [accent.opacity(0.20), .clear], center: .topLeading, startRadius: 30, endRadius: 480)
            RadialGradient(colors: [CM.cyan.opacity(0.10), .clear], center: .bottomTrailing, startRadius: 10, endRadius: 380)
            LinearGradient(colors: [.clear, Color.black.opacity(0.14)], startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
    }
}

struct CMCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(CM.elevated.opacity(0.86))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(CM.border, lineWidth: 1)
                    )
            )
    }
}

struct CMSectionTitle: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.headline.weight(.semibold))
            if let subtitle { Text(subtitle).font(.caption).foregroundStyle(CM.textSecondary) }
        }
    }
}

struct CMChip: View {
    let text: String
    var icon: String? = nil
    var accent: Color = CM.purple

    var body: some View {
        HStack(spacing: 5) {
            if let icon { Image(systemName: icon).font(.caption2.weight(.bold)) }
            Text(text).font(.caption.weight(.semibold))
        }
        .foregroundStyle(accent)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(accent.opacity(0.12), in: Capsule())
        .overlay(Capsule().stroke(accent.opacity(0.20), lineWidth: 1))
    }
}

struct CMPrimaryButtonStyle: ButtonStyle {
    var accent: Color = CM.purple
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(accent.opacity(configuration.isPressed ? 0.72 : 1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct EmotionMeter: View {
    let title: String
    let value: Double
    let icon: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Image(systemName: icon)
                Text(title).font(.caption.weight(.semibold))
                Spacer()
                Text("\(Int(value))").font(.caption.monospacedDigit().weight(.bold)).foregroundStyle(CM.textSecondary)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.07))
                    Capsule().fill(accent.gradient).frame(width: max(4, proxy.size.width * value / 100))
                }
            }
            .frame(height: 5)
        }
        .foregroundStyle(.white.opacity(0.82))
    }
}

struct ModelStatusBadge: View {
    @EnvironmentObject private var app: AppState
    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(app.ai.isReady ? CM.green : (app.ai.isGenerating ? CM.orange : CM.textTertiary))
                .frame(width: 7, height: 7)
            Text(app.modelStatusText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(CM.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.055), in: Capsule())
    }
}

struct KeyboardDoneToolbar: ToolbarContent {
    var dismiss: () -> Void
    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Cerrar") { dismiss() }
        }
    }
}
