import SwiftUI
import UIKit

struct CharacterAvatarView: View {
    let character: CharacterProfile
    var size: CGFloat = 160
    var speaking: Bool = false
    var listening: Bool = false
    var speechPulse: Double = 0
    var audioLevel: Double = 0

    @EnvironmentObject private var app: AppState

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let active = speaking || listening
            let wave = speaking ? speechPulse : (listening ? audioLevel : 0)
            let breathe = sin(t * 1.6) * 0.008
            let talkScale = active ? wave * 0.035 : 0
            let bob = active ? sin(t * 7.8) * (2.0 + wave * 2.5) : sin(t * 1.25) * 1.2
            let tilt = active ? sin(t * 4.6) * (0.7 + wave * 0.9) : sin(t * 0.8) * 0.25
            let accent = Color(hex: character.accentHex)

            ZStack {
                Circle()
                    .fill(accent.opacity(active ? 0.22 : 0.12))
                    .frame(width: size * 1.12, height: size * 1.12)
                    .blur(radius: size * 0.13)
                    .scaleEffect(1 + wave * 0.06)

                avatarContent(accent: accent)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 1))
                    .shadow(color: accent.opacity(active ? 0.32 : 0.16), radius: active ? 26 : 14)
                    .scaleEffect(1 + breathe + talkScale)
                    .rotationEffect(.degrees(tilt))
                    .offset(y: bob)

                if speaking {
                    Circle()
                        .trim(from: 0.05, to: 0.78)
                        .stroke(accent.opacity(0.72), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: size * 1.08, height: size * 1.08)
                        .rotationEffect(.degrees(t * 28))
                }
            }
            .frame(width: size * 1.22, height: size * 1.22)
            .animation(.spring(response: 0.25, dampingFraction: 0.72), value: active)
        }
        .accessibilityLabel("Avatar de \(character.name)")
    }

    @ViewBuilder
    private func avatarContent(accent: Color) -> some View {
        if let url = app.store.avatarURL(filename: character.avatarFilename), let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                LinearGradient(colors: [accent.opacity(0.95), CM.cyan.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Text(initials)
                    .font(.system(size: size * 0.32, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
    }

    private var initials: String {
        let words = character.name.split(separator: " ")
        return words.prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }
}
