import SwiftUI
import UIKit

// Shared styling for navigation icon buttons used across Dashboard and Notebook screens.
enum NavigationButtonStyle {
  // Size of the circular button container.
  static let size: CGFloat = 36
  static let cornerRadius: CGFloat = size / 2

  // Font sizing for SF Symbol icons.
  static let iconPointSize: CGFloat = 20
  static let iconWeight: Font.Weight = .semibold

  // Tint and chrome colors shared between SwiftUI and UIKit implementations.
  static let tintUIColor = UIColor(red: 0.20, green: 0.20, blue: 0.20, alpha: 1.0)
  static let backgroundUIColor = UIColor.white
  static let strokeUIColor = UIColor.black.withAlphaComponent(0.10)
  static let shadowUIColor = UIColor.black.withAlphaComponent(0.06)

  static let tintColor = Color(tintUIColor)
  static let backgroundColor = Color(backgroundUIColor)
  static let strokeColor = Color(strokeUIColor)
  static let shadowColor = Color(shadowUIColor)
}
