import SwiftUI
import UIKit

// Design tokens for the Alan app following the unified design system.
// Dark, gravity-forward aesthetic with serif typography and restrained motion.

// MARK: - Colors

enum AlanColors {
    // Backgrounds
    static let void = Color(UIColor(white: 0.02, alpha: 1))  // #050505
    static let surface = Color(UIColor(white: 0.04, alpha: 1))  // #0A0A0A
    static let elevated = Color(UIColor(white: 0.08, alpha: 1))  // #141414
    static let doc = Color(UIColor(white: 0.067, alpha: 1))  // #111111

    // Text
    static let textPrimary = Color(UIColor(red: 0.91, green: 0.89, blue: 0.87, alpha: 1))  // #E8E4DF
    static let textSecondary = Color(UIColor(red: 0.60, green: 0.58, blue: 0.56, alpha: 1))  // #9A9590
    static let textTertiary = Color(UIColor(red: 0.36, green: 0.35, blue: 0.33, alpha: 1))  // #5C5955
    static let textInverse = Color(UIColor(white: 0.04, alpha: 1))  // #0A0A0A

    // Accents
    static let accentConfidence = Color(UIColor(red: 0.83, green: 0.77, blue: 0.66, alpha: 1))  // #D4C4A8
    static let accentActive = Color.white

    // Borders
    static let borderSubtle = Color(UIColor(white: 0.12, alpha: 1))  // #1F1F1F
    static let borderFocus = Color(UIColor(white: 0.23, alpha: 1))  // #3A3A3A

    // UIKit versions for use with UIKit components
    enum UIKit {
        static let void = UIColor(white: 0.02, alpha: 1)
        static let surface = UIColor(white: 0.04, alpha: 1)
        static let elevated = UIColor(white: 0.08, alpha: 1)
        static let textPrimary = UIColor(red: 0.91, green: 0.89, blue: 0.87, alpha: 1)
        static let textSecondary = UIColor(red: 0.60, green: 0.58, blue: 0.56, alpha: 1)
        static let textTertiary = UIColor(red: 0.36, green: 0.35, blue: 0.33, alpha: 1)
        static let textInverse = UIColor(white: 0.04, alpha: 1)
    }
}

// MARK: - Spacing

enum AlanSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
    static let xxxl: CGFloat = 64
    static let xxxxl: CGFloat = 96
}

// MARK: - Animation

enum AlanAnimation {
    // Durations
    static let instant: Double = 0.1
    static let fast: Double = 0.2
    static let normal: Double = 0.3
    static let slow: Double = 0.5
    static let deliberate: Double = 0.8

    // Standard easing curve: ease out with slight deceleration
    static func standard(duration: Double = normal) -> Animation {
        .timingCurve(0.4, 0, 0.2, 1, duration: duration)
    }

    // Enter easing: decelerate in
    static func enter(duration: Double = normal) -> Animation {
        .timingCurve(0, 0, 0.2, 1, duration: duration)
    }

    // Exit easing: accelerate out
    static func exit(duration: Double = normal) -> Animation {
        .timingCurve(0.4, 0, 1, 1, duration: duration)
    }
}

// MARK: - Typography

enum AlanTypography {
    // Display font for questions and headings (serif for gravitas)
    static func display(size: CGFloat = 26, weight: Font.Weight = .light) -> Font {
        // Attempt to use Source Serif 4 if available, fall back to system serif
        if let _ = UIFont(name: "SourceSerif4-Light", size: size) {
            return .custom("SourceSerif4-Light", size: size)
        }
        return .system(size: size, weight: weight, design: .serif)
    }

    // Body font for UI text, buttons, labels
    static func body(size: CGFloat = 14, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    // Mono font for code and technical notation
    static func mono(size: CGFloat = 14, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Component Dimensions

enum AlanDimensions {
    // Pill buttons
    static let pillHeight: CGFloat = 64
    static let pillCornerRadius: CGFloat = 32
    static let pillHorizontalPadding: CGFloat = 32

    // Continue button
    static let continueButtonHeight: CGFloat = 72
    static let continueButtonCornerRadius: CGFloat = 36
    static let continueButtonHorizontalPadding: CGFloat = 80

    // Back button
    static let backButtonSize: CGFloat = 56
    static let backButtonCornerRadius: CGFloat = 28

    // Progress bar
    static let progressBarHeight: CGFloat = 4
    static let progressBarCornerRadius: CGFloat = 2
}
