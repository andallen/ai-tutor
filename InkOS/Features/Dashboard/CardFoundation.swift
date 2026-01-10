// Shared constants, protocols, and extensions for dashboard cards.
// Centralizes card styling to ensure consistency across all card types.

import SwiftUI

// MARK: - Card Constants

// Design constants shared by all card types (notebook, PDF, folder).
// Change these values once to update all cards consistently.
enum CardConstants {
  // Card dimensions.
  static let cornerRadius: CGFloat = 10
  static let titleAreaHeight: CGFloat = 36
  static let aspectRatio: CGFloat = 0.72

  // Inset to crop thin black line on the right edge of canvas captures.
  static let previewEdgeInset: CGFloat = 2

  // Context menu preview dimensions.
  static let contextMenuPreviewWidth: CGFloat = 160
  static let contextMenuPreviewHeight: CGFloat = 200

  // Shadow styling.
  enum Shadow {
    static let color = Color.black.opacity(0.14)
    static let radius: CGFloat = 7
    static let xOffset: CGFloat = 0
    static let yOffset: CGFloat = 4
  }
}

// MARK: - Card Presentable Protocol

// Protocol for items that can be displayed as dashboard cards.
// Provides a unified interface for notebook and PDF cards.
// FolderMetadata does NOT conform because it uses a different preview (2x2 grid).
protocol CardPresentable: Identifiable, Sendable {
  // Unique identifier for this item.
  var id: String { get }

  // Display name shown to the user.
  var displayName: String { get }

  // Cached preview image data for the card.
  var previewImageData: Data? { get }

  // Subtitle text shown below the title (e.g., date or page count).
  var subtitle: String? { get }

  // SF Symbol name for placeholder icon when no preview is available.
  // Returns nil for items that don't show a placeholder (solid color instead).
  var placeholderIcon: String? { get }

  // Background color for the card preview area.
  var cardBackgroundColor: Color { get }
}

// MARK: - NotebookMetadata Conformance

extension NotebookMetadata: CardPresentable {
  // Formats the last accessed date as "h:mm a  MM/dd/yy".
  var subtitle: String? {
    guard let lastAccessedAt = lastAccessedAt else { return nil }
    return CardDateFormatter.shared.string(from: lastAccessedAt)
  }

  // Notebooks don't show a placeholder icon; they show solid white.
  var placeholderIcon: String? { nil }

  // Notebook cards have a white background.
  var cardBackgroundColor: Color { .white }
}

// MARK: - PDFDocumentMetadata Conformance

extension PDFDocumentMetadata: CardPresentable {
  // Formats the page count with correct singular/plural form.
  var subtitle: String? {
    if pageCount == 1 {
      return "1 page"
    } else {
      return "\(pageCount) pages"
    }
  }

  // PDFs show a document icon when no preview is available.
  var placeholderIcon: String? { "doc.richtext" }

  // PDF cards have a gray background.
  var cardBackgroundColor: Color { Color(.systemGray5) }
}

// MARK: - Card Date Formatter

// Shared date formatter for card subtitles.
// Uses "h:mm a  MM/dd/yy" format (e.g., "3:45 PM  01/07/26").
enum CardDateFormatter {
  static let shared: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "h:mm a  MM/dd/yy"
    return formatter
  }()
}
