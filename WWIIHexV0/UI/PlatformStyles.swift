import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum PlatformStyles {
    static var systemBackground: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }

    static var secondarySystemBackground: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemBackground)
        #endif
    }

    static var tertiarySystemBackground: Color {
        #if os(macOS)
        Color(nsColor: .underPageBackgroundColor)
        #else
        Color(uiColor: .tertiarySystemBackground)
        #endif
    }

    static var panelStroke: Color {
        .secondary.opacity(0.28)
    }

    static var selectionTint: Color {
        .yellow.opacity(0.18)
    }
}

enum SanguoDesignTokens {
    static let panelCornerRadius: CGFloat = 8
    static let compactCornerRadius: CGFloat = 6
    static let controlMinHeight: CGFloat = 44

    static var parchmentPanel: Color {
        Color(red: 0.94, green: 0.89, blue: 0.76)
    }

    static var inkText: Color {
        Color(red: 0.13, green: 0.11, blue: 0.09)
    }

    static var mutedInk: Color {
        Color(red: 0.38, green: 0.34, blue: 0.28)
    }

    static var vermilion: Color {
        Color(red: 0.66, green: 0.12, blue: 0.08)
    }

    static var jade: Color {
        Color(red: 0.12, green: 0.42, blue: 0.34)
    }

    static var bronze: Color {
        Color(red: 0.58, green: 0.40, blue: 0.18)
    }

    static var riverBlue: Color {
        Color(red: 0.12, green: 0.43, blue: 0.56)
    }

    static var panelStroke: Color {
        Color(red: 0.38, green: 0.27, blue: 0.15).opacity(0.38)
    }
}
