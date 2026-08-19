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

    private var activity: Double { min(1, max(speechPulse, audioLevel)) }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(hex: character.accentHex).opacity((speaking || listening) ? 0.22 : 0.08))
                .frame(width: size + 8, height: size + 8)
            avatarContent
                .frame(width: size, height: size)
                .clipped()
                .scaleEffect((speaking || listening) ? 1.0 + activity * 0.025 : 1)
                .offset(y: speaking ? -activity * 2 : 0)
            if speaking {
                Rectangle().stroke(Color(hex: character.accentHex), lineWidth: 2 + activity * 2)
                    .frame(width: size + 4, height: size + 4)
            } else {
                Rectangle().stroke(CM.border, lineWidth: 1).frame(width: size + 4, height: size + 4)
            }
        }
        .frame(width: size + 10, height: size + 10)
        .animation(.easeOut(duration: 0.10), value: activity)
        .accessibilityLabel("Avatar de \(character.name)")
    }

    @ViewBuilder private var avatarContent: some View {
        if let url = app.store.avatarURL(filename: character.avatarFilename), let image = AvatarImageCache.shared.image(at: url) {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            ZStack {
                CM.elevated2
                Text(initials)
                    .font(.system(size: size * 0.28, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(hex: character.accentHex))
            }
        }
    }

    private var initials: String {
        character.name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }
}


private final class AvatarImageCache {
    static let shared = AvatarImageCache()
    private let cache = NSCache<NSString, UIImage>()
    private init() { cache.countLimit = 24; cache.totalCostLimit = 48 * 1024 * 1024 }
    func image(at url: URL) -> UIImage? {
        let key = url.path as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        let cost = Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: key, cost: cost)
        return image
    }
}
