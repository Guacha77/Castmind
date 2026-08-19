import SwiftUI

extension Color {
    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&value)
        switch clean.count {
        case 3:
            self.init(.sRGB, red: Double((value >> 8) & 0xF) / 15, green: Double((value >> 4) & 0xF) / 15, blue: Double(value & 0xF) / 15, opacity: 1)
        default:
            self.init(.sRGB, red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255, opacity: 1)
        }
    }
}

enum CM {
    static let background = Color(hex: "090908")
    static let elevated = Color(hex: "131411")
    static let elevated2 = Color(hex: "1B1C18")
    static let concrete = Color(hex: "C9CBC6")
    static let textSecondary = Color.white.opacity(0.62)
    static let textTertiary = Color.white.opacity(0.36)
    static let border = Color.white.opacity(0.18)
    static let strongBorder = Color.white.opacity(0.45)
    static let orange = Color(hex: "FF4B17")
    static let green = Color(hex: "67D49A")
    static let red = Color(hex: "FF5C55")
    static let purple = orange
    static let cyan = concrete
}

struct CastmindBackground: View {
    var accent: Color = CM.orange
    var body: some View {
        CM.background
            .overlay(alignment: .top) {
                Rectangle().fill(accent).frame(height: 2)
            }
            .ignoresSafeArea(.all)
    }
}

struct CMCard<Content: View>: View {
    var padding: CGFloat = 14
    @ViewBuilder let content: () -> Content
    var body: some View {
        content()
            .padding(padding)
            .background(CM.elevated)
            .overlay(Rectangle().stroke(CM.border, lineWidth: 1))
    }
}

struct CMSectionTitle: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(.system(.caption, design: .monospaced).weight(.bold))
                .tracking(1.1)
                .foregroundStyle(.white)
            if let subtitle {
                Text(subtitle).font(.caption).foregroundStyle(CM.textSecondary)
            }
        }
    }
}

struct CMChip: View {
    let text: String
    var icon: String? = nil
    var accent: Color = CM.orange
    var body: some View {
        HStack(spacing: 5) {
            if let icon { Image(systemName: icon).font(.caption2.weight(.bold)) }
            Text(text.uppercased()).font(.system(.caption2, design: .monospaced).weight(.bold))
        }
        .foregroundStyle(accent)
        .padding(.horizontal, 8).padding(.vertical, 5)
        .overlay(Rectangle().stroke(accent.opacity(0.75), lineWidth: 1))
    }
}

struct CMPrimaryButtonStyle: ButtonStyle {
    var accent: Color = CM.orange
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .monospaced).weight(.bold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(configuration.isPressed ? accent.opacity(0.72) : accent)
            .overlay(Rectangle().stroke(Color.black.opacity(0.8), lineWidth: 1))
    }
}

struct ModelStatusBadge: View {
    @EnvironmentObject private var app: AppState
    var body: some View {
        HStack(spacing: 7) {
            Circle().fill(statusColor).frame(width: 7, height: 7)
            Text(app.modelStatusText.uppercased())
                .font(.system(.caption2, design: .monospaced).weight(.bold))
        }
        .foregroundStyle(CM.textSecondary)
    }
    private var statusColor: Color {
        switch app.ai.phase {
        case .ready: return CM.green
        case .generating, .warming, .loading, .downloading: return CM.orange
        case .failed: return CM.red
        default: return CM.textTertiary
        }
    }
}

struct KeyboardDoneToolbar: ToolbarContent {
    let action: () -> Void
    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Cerrar", action: action)
        }
    }
}
