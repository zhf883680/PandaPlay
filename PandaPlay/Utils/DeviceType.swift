//
//  DeviceType.swift
//  PandaPlay
//
//  Created on 2026-03-03.
//

import SwiftUI
import UIKit

enum DeviceType {
    case iPhone
    case iPad
    case tvOS

    static var current: DeviceType {
        #if os(tvOS)
        return .tvOS
        #else
        let size = UIScreen.main.bounds.size
        let scale = UIScreen.main.scale

        // iPad detection
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .iPad
        }
        return .iPhone
        #endif
    }

    var isCompact: Bool {
        self == .iPhone
    }

    var isIPad: Bool {
        self == .iPad
    }

    var isTV: Bool {
        self == .tvOS
    }
}

// MARK: - View Modifier for Platform-Specific Layout
struct PlatformLayout: ViewModifier {
    let iPhone: CGFloat
    let iPad: CGFloat
    let tvOS: CGFloat

    func body(content: Content) -> some View {
        switch DeviceType.current {
        case .iPhone:
            content
        case .iPad:
            content
        case .tvOS:
            content
        }
    }
}

// MARK: - Padding Values
struct PlatformPadding {
    static var horizontal: CGFloat {
        switch DeviceType.current {
        case .iPhone:
            return 16
        case .iPad:
            return 40
        case .tvOS:
            return 80
        }
    }

    static var vertical: CGFloat {
        switch DeviceType.current {
        case .iPhone:
            return 12
        case .iPad:
            return 24
        case .tvOS:
            return 60
        }
    }

    static var sectionSpacing: CGFloat {
        switch DeviceType.current {
        case .iPhone:
            return 20
        case .iPad:
            return 32
        case .tvOS:
            return 60
        }
    }

    static var itemSpacing: CGFloat {
        switch DeviceType.current {
        case .iPhone:
            return 12
        case .iPad:
            return 20
        case .tvOS:
            return 40
        }
    }
}

// MARK: - Size Values
struct PlatformSize {
    static var posterWidth: CGFloat {
        switch DeviceType.current {
        case .iPhone:
            return 120
        case .iPad:
            return 180
        case .tvOS:
            return 250
        }
    }

    static var posterHeight: CGFloat {
        switch DeviceType.current {
        case .iPhone:
            return 180
        case .iPad:
            return 270
        case .tvOS:
            return 375
        }
    }

    static var backdropHeight: CGFloat {
        switch DeviceType.current {
        case .iPhone:
            return 220
        case .iPad:
            return 350
        case .tvOS:
            return 450
        }
    }

    static var seasonCardWidth: CGFloat {
        switch DeviceType.current {
        case .iPhone:
            return 100
        case .iPad:
            return 130
        case .tvOS:
            return 150
        }
    }

    static var seasonCardHeight: CGFloat {
        switch DeviceType.current {
        case .iPhone:
            return 150
        case .iPad:
            return 195
        case .tvOS:
            return 225
        }
    }

    static var episodeCardHeight: CGFloat {
        switch DeviceType.current {
        case .iPhone:
            return 80
        case .iPad:
            return 100
        case .tvOS:
            return 110
        }
    }

    static var iconSize: CGFloat {
        switch DeviceType.current {
        case .iPhone:
            return 50
        case .iPad:
            return 70
        case .tvOS:
            return 80
        }
    }
}

// MARK: - View Extension for Conditional Modifiers
extension View {
    @ViewBuilder
    func ifPhone<Content: View>(_ content: () -> Content) -> some View {
        if DeviceType.current == .iPhone {
            content()
        } else {
            self
        }
    }

    @ViewBuilder
    func ifTV<Content: View>(_ content: (Self) -> Content) -> some View {
        if DeviceType.current == .tvOS {
            content(self)
        } else {
            self
        }
    }

    @ViewBuilder
    func ifIPad<Content: View>(_ content: (Self) -> Content) -> some View {
        if DeviceType.current == .iPad {
            content(self)
        } else {
            self
        }
    }
}
