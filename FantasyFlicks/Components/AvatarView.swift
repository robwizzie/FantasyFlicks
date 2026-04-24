//
//  AvatarView.swift
//  FantasyFlicks
//
//  Unified avatar rendering. Prefers, in order:
//  1. Uploaded photo (avatarBase64 — a JPEG blob stored on the user doc)
//  2. SF Symbol icon (avatarIcon)
//  3. First letter of display name on a gold gradient circle
//

import SwiftUI

struct AvatarView: View {
    let size: CGFloat
    let displayName: String
    var avatarBase64: String? = nil
    var avatarIcon: String? = nil

    var body: some View {
        ZStack {
            if let image = decodedImage {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(FFColors.goldGradient)
                    .frame(width: size, height: size)

                if let icon = avatarIcon {
                    Image(systemName: icon)
                        .font(.system(size: size * 0.42))
                        .foregroundColor(FFColors.backgroundDark)
                } else {
                    Text(String(displayName.prefix(1)).uppercased())
                        .font(.system(size: size * 0.45, weight: .bold, design: .rounded))
                        .foregroundColor(FFColors.backgroundDark)
                }
            }
        }
    }

    /// Convenience init that reads all three sources off an FFUser.
    init(user: FFUser, size: CGFloat) {
        self.size = size
        self.displayName = user.displayName
        self.avatarBase64 = user.avatarBase64
        self.avatarIcon = user.avatarIcon
    }

    /// Init when you have the pieces directly (e.g. a CachedMovie etc.).
    init(size: CGFloat, displayName: String, avatarBase64: String? = nil, avatarIcon: String? = nil) {
        self.size = size
        self.displayName = displayName
        self.avatarBase64 = avatarBase64
        self.avatarIcon = avatarIcon
    }

    private var decodedImage: Image? {
        guard let b64 = avatarBase64,
              let data = Data(base64Encoded: b64),
              let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
    }
}
