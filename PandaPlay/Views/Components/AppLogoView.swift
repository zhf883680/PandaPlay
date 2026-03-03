import SwiftUI

#if canImport(UIKit)
import UIKit
private typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
private typealias PlatformImage = NSImage
#endif

struct AppLogoView: View {
    let size: CGFloat

    private static let candidates = ["AppLogo", "AppIcon", "1024", "180", "120", "60"]

    private var logoImageName: String? {
        Self.candidates.first { name in
            PlatformImage(named: name) != nil
        }
    }

    var body: some View {
        Group {
            if let logoImageName {
                Image(logoImageName)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "play.rectangle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.blue)
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    AppLogoView(size: 64)
}
