import SwiftUI
import UIKit

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

// Rounded rectangle with individually rounded corners.
struct RoundedCornerShape: Shape {
  struct Corner: OptionSet {
    let rawValue: Int

    static let topLeft = Corner(rawValue: 1 << 0)
    static let topRight = Corner(rawValue: 1 << 1)
    static let bottomLeft = Corner(rawValue: 1 << 2)
    static let bottomRight = Corner(rawValue: 1 << 3)
  }

  var radius: CGFloat
  let corners: Corner

  var animatableData: CGFloat {
    get { radius }
    set { radius = newValue }
  }

  func path(in rect: CGRect) -> SwiftUI.Path {
    let clampedRadius = min(radius, min(rect.width, rect.height) * 0.5)
    let topLeft = corners.contains(.topLeft) ? clampedRadius : 0
    let topRight = corners.contains(.topRight) ? clampedRadius : 0
    let bottomLeft = corners.contains(.bottomLeft) ? clampedRadius : 0
    let bottomRight = corners.contains(.bottomRight) ? clampedRadius : 0

    var path = SwiftUI.Path()
    path.move(to: CGPoint(x: rect.minX + topLeft, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX - topRight, y: rect.minY))
    if topRight > 0 {
      path.addArc(
        center: CGPoint(x: rect.maxX - topRight, y: rect.minY + topRight),
        radius: topRight,
        startAngle: .degrees(-90),
        endAngle: .degrees(0),
        clockwise: false
      )
    }
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))
    if bottomRight > 0 {
      path.addArc(
        center: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY - bottomRight),
        radius: bottomRight,
        startAngle: .degrees(0),
        endAngle: .degrees(90),
        clockwise: false
      )
    }
    path.addLine(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))
    if bottomLeft > 0 {
      path.addArc(
        center: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY - bottomLeft),
        radius: bottomLeft,
        startAngle: .degrees(90),
        endAngle: .degrees(180),
        clockwise: false
      )
    }
    path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))
    if topLeft > 0 {
      path.addArc(
        center: CGPoint(x: rect.minX + topLeft, y: rect.minY + topLeft),
        radius: topLeft,
        startAngle: .degrees(180),
        endAngle: .degrees(270),
        clockwise: false
      )
    }
    path.closeSubpath()
    return path
  }
}

