import SwiftUI

// Shared UI components used across multiple features.

// Background view with white color and subtle gradients.
struct BackgroundWhite: View {
  var body: some View {
    ZStack {
      Color.white

      RadialGradient(
        colors: [Color.black.opacity(0.06), Color.clear],
        center: .topTrailing,
        startRadius: 40,
        endRadius: 520
      )
      .blendMode(.multiply)

      RadialGradient(
        colors: [Color.black.opacity(0.04), Color.clear],
        center: .bottomLeading,
        startRadius: 60,
        endRadius: 620
      )
      .blendMode(.multiply)
    }
  }
}

// View modifier that applies a glass background effect.
extension View {
  func glassBackground(cornerRadius: CGFloat) -> some View {
    Group {
      if #available(iOS 18.0, *) {
        self
          .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
          .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
              .stroke(Color.rule, lineWidth: 1)
          )
      } else {
        let opacity: Double = cornerRadius == 18 ? 0.82 : (cornerRadius == 12 ? 0.86 : 0.92)
        self
          .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
              .fill(Color.white.opacity(opacity))
          )
          .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
              .stroke(Color.rule, lineWidth: 1)
          )
      }
    }
  }
}

// Shared color definitions.
extension Color {
  static let rule = Color.black.opacity(0.10)
  static let separator = Color.black.opacity(0.14)

  // Matches the navigation bar icon tint.
  static let offBlack = Color(red: 0.20, green: 0.20, blue: 0.20)

  static let ink = Color.black.opacity(0.88)
  static let inkSubtle = Color.black.opacity(0.62)
  static let inkFaint = Color.black.opacity(0.40)
}
