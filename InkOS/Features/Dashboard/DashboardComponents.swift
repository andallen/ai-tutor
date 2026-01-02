import SwiftUI
import UIKit

// MARK: - PDF Dashboard Error

// Errors specific to PDF dashboard operations.
// Provides specific cases for different failure modes.
enum PDFDashboardError: LocalizedError, Equatable {
  // The PDFNotes directory could not be accessed.
  case pdfNotesDirectoryNotAccessible(underlyingError: String)

  // A specific document manifest could not be read.
  case manifestReadFailed(documentID: String, reason: String)

  // A specific document manifest could not be decoded.
  case manifestDecodeFailed(documentID: String, reason: String)

  var errorDescription: String? {
    switch self {
    case .pdfNotesDirectoryNotAccessible(let underlyingError):
      return "Could not access PDF documents directory: \(underlyingError)"
    case .manifestReadFailed(let documentID, let reason):
      return "Could not read document \(documentID): \(reason)"
    case .manifestDecodeFailed(let documentID, let reason):
      return "Could not decode document \(documentID): \(reason)"
    }
  }
}

// MARK: - PDF Document Metadata

// Lightweight struct for displaying PDF documents in the Dashboard grid.
// Contains only the information needed for listing and sorting, not editing.
// Mirrors NotebookMetadata pattern for consistency.
struct PDFDocumentMetadata: Identifiable, Sendable, Equatable {
  // Unique identifier for this PDF document.
  let id: String

  // Display name shown to the user.
  let displayName: String

  // Original filename of the imported PDF including extension.
  let sourceFileName: String

  // Timestamp when the document was created from the PDF.
  let createdAt: Date

  // Timestamp when the document was last modified.
  let modifiedAt: Date

  // Total number of pages in the PDF document.
  let pageCount: Int

  // Cached preview image data for the first page of the PDF.
  let previewImageData: Data?
}

// Utility for building PDFDocumentMetadata from NoteDocument.
enum PDFDocumentMetadataBuilder {
  // Builds PDFDocumentMetadata from a NoteDocument and optional preview data.
  static func build(
    from document: NoteDocument,
    previewImageData: Data?
  ) -> PDFDocumentMetadata {
    let pageCount = document.blocks.filter { block in
      if case .pdfPage = block { return true }
      return false
    }.count

    return PDFDocumentMetadata(
      id: document.documentID.uuidString,
      displayName: document.displayName,
      sourceFileName: document.sourceFileName,
      createdAt: document.createdAt,
      modifiedAt: document.modifiedAt,
      pageCount: pageCount,
      previewImageData: previewImageData
    )
  }
}

// MARK: - Notebook Session

// Represents an open notebook editing session.
struct NotebookSession: Identifiable {
  let id: String
  let handle: DocumentHandle
}

// MARK: - Scaling Card Button Style

// Custom button style that scales the card on press.
// Uses ButtonStyle instead of DragGesture to allow ScrollView gestures to work properly.
struct ScalingCardButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 1.07 : 1.0)
      .animation(.spring(response: 0.18, dampingFraction: 0.7), value: configuration.isPressed)
  }
}

// MARK: - Notebook Card Button

// Interactive button wrapper for a notebook card with tactile press effects.
// Displays a highlight sweep animation on long press (context menu trigger).
struct NotebookCardButton: View {
  let notebook: NotebookMetadata
  let action: () -> Void
  // Drives a highlight flash on long press.
  @State private var showHighlight = false
  // Moves a bright sweep across the card on long press.
  @State private var sweepOffset: CGFloat = -1.2
  // Tracks the pending sweep animation work item so it can be cancelled on tap.
  @State private var sweepWorkItem: DispatchWorkItem?

  var body: some View {
    let cardCornerRadius: CGFloat = 10
    Button(action: action) {
      NotebookCard(notebook: notebook)
        .contentShape(Rectangle())
    }
    // Uses custom button style for scale effect. This allows ScrollView to properly
    // intercept scroll gestures, unlike DragGesture which blocks scrolling.
    .buttonStyle(ScalingCardButtonStyle())
    // Adds a highlight sweep on long press.
    .overlay(
      GeometryReader { proxy in
        let sweepDistance = proxy.size.width * 1.2
        ZStack {
          RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
            .fill(Color.white.opacity(showHighlight ? 0.7 : 0.0))
            .blendMode(.screen)
            .animation(.easeOut(duration: 0.28), value: showHighlight)

          RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
            .fill(
              LinearGradient(
                stops: [
                  .init(color: Color.white.opacity(0.0), location: 0.0),
                  .init(color: Color.white.opacity(0.45), location: 0.45),
                  .init(color: Color.white.opacity(0.75), location: 0.55),
                  .init(color: Color.white.opacity(0.0), location: 1.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
              )
            )
            .blendMode(.screen)
            .offset(x: sweepOffset * sweepDistance)
            .opacity(showHighlight ? 1.0 : 0.0)
        }
        // Keeps the sweep confined to this card only.
        .compositingGroup()
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        // Allows touch events to pass through to the button underneath.
        .allowsHitTesting(false)
      }
    )
    // Triggers sweep animation on long press. Uses pressing callback with a delay
    // so taps don't trigger the sweep - only sustained presses do.
    .onLongPressGesture(
      minimumDuration: 0.5,
      pressing: { pressing in
        if pressing {
          // Schedule sweep animation after a delay. If user lifts finger before
          // the delay (a tap), the work item is cancelled and sweep doesn't play.
          let workItem = DispatchWorkItem {
            guard !showHighlight else { return }
            showHighlight = true
            sweepOffset = -1.2
            withAnimation(.easeOut(duration: 0.5)) {
              sweepOffset = 1.2
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
              showHighlight = false
            }
          }
          sweepWorkItem = workItem
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
        } else {
          // User lifted finger - cancel pending sweep if it hasn't fired yet.
          sweepWorkItem?.cancel()
          sweepWorkItem = nil
        }
      },
      perform: {
        // Empty perform - context menu handles the actual action.
      })
  }
}

// MARK: - Notebook Card

// Displays a notebook preview card with title and date.
struct NotebookCard: View {
  let notebook: NotebookMetadata

  // Height reserved for the external title area below the card.
  private let titleAreaHeight: CGFloat = 36

  var body: some View {
    let previewImage = notebook.previewImageData.flatMap { UIImage(data: $0) }
    let cardCornerRadius: CGFloat = 10
    // Keeps a paper-like portrait ratio for the overall container.
    let cardAspectRatio: CGFloat = 0.72

    GeometryReader { proxy in
      let totalWidth = proxy.size.width
      let totalHeight = proxy.size.height
      // Card height is reduced to make room for the title below.
      let cardHeight = totalHeight - titleAreaHeight
      let shape = RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)

      VStack(alignment: .leading, spacing: 4) {
        // The notebook preview card.
        ZStack {
          // Ensures a clean base behind the preview.
          Color.white

          // Draws the preview or placeholder cover.
          if let previewImage {
            Image(uiImage: previewImage)
              .resizable()
              .scaledToFill()
              .frame(width: totalWidth, height: cardHeight)
              .brightness(0.02)
              .contrast(1.0)
          }
        }
        .frame(width: totalWidth, height: cardHeight)
        .clipShape(shape)
        .shadow(color: Color.black.opacity(0.14), radius: 7, x: 0, y: 4)

        // Title and date below the card.
        VStack(alignment: .leading, spacing: 1) {
          Text(notebook.displayName)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.ink)
            .lineLimit(1)
            .truncationMode(.tail)

          if let subtitle = formattedAccessDate {
            Text(subtitle)
              .font(.system(size: 10, weight: .medium))
              .foregroundStyle(Color.inkSubtle)
              .lineLimit(1)
              .truncationMode(.tail)
          }
        }
        .padding(.horizontal, 2)
      }
    }
    .aspectRatio(cardAspectRatio, contentMode: .fit)
  }

  // Formats a short date string for the last access label.
  private var formattedAccessDate: String? {
    guard let lastAccessedAt = notebook.lastAccessedAt else {
      return nil
    }
    return Self.dateFormatter.string(from: lastAccessedAt)
  }

  // Reuses a single formatter for performance.
  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "h:mm a  MM/dd/yy"
    return formatter
  }()
}

// MARK: - PDF Document Card Button

// Interactive button wrapper for a PDF document card with tactile press effects.
// Mirrors NotebookCardButton pattern for visual consistency.
struct PDFDocumentCardButton: View {
  let metadata: PDFDocumentMetadata
  let action: () -> Void
  // Drives a highlight flash on long press.
  @State private var showHighlight = false
  // Moves a bright sweep across the card on long press.
  @State private var sweepOffset: CGFloat = -1.2
  // Tracks the pending sweep animation work item so it can be cancelled on tap.
  @State private var sweepWorkItem: DispatchWorkItem?

  var body: some View {
    let cardCornerRadius: CGFloat = 10
    Button(action: action) {
      PDFDocumentCard(metadata: metadata)
        .contentShape(Rectangle())
    }
    // Uses custom button style for scale effect.
    .buttonStyle(ScalingCardButtonStyle())
    // Adds a highlight sweep on long press.
    .overlay(
      GeometryReader { proxy in
        let sweepDistance = proxy.size.width * 1.2
        ZStack {
          RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
            .fill(Color.white.opacity(showHighlight ? 0.7 : 0.0))
            .blendMode(.screen)
            .animation(.easeOut(duration: 0.28), value: showHighlight)

          RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
            .fill(
              LinearGradient(
                stops: [
                  .init(color: Color.white.opacity(0.0), location: 0.0),
                  .init(color: Color.white.opacity(0.45), location: 0.45),
                  .init(color: Color.white.opacity(0.75), location: 0.55),
                  .init(color: Color.white.opacity(0.0), location: 1.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
              )
            )
            .blendMode(.screen)
            .offset(x: sweepOffset * sweepDistance)
            .opacity(showHighlight ? 1.0 : 0.0)
        }
        .compositingGroup()
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        .allowsHitTesting(false)
      }
    )
    // Triggers sweep animation on long press.
    .onLongPressGesture(
      minimumDuration: 0.5,
      pressing: { pressing in
        if pressing {
          let workItem = DispatchWorkItem {
            guard !showHighlight else { return }
            showHighlight = true
            sweepOffset = -1.2
            withAnimation(.easeOut(duration: 0.5)) {
              sweepOffset = 1.2
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
              showHighlight = false
            }
          }
          sweepWorkItem = workItem
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
        } else {
          sweepWorkItem?.cancel()
          sweepWorkItem = nil
        }
      },
      perform: {
        // Empty perform - context menu handles the actual action.
      })
  }
}

// MARK: - PDF Document Card

// Displays a PDF document preview card with title and page count.
// Mirrors NotebookCard design for visual consistency.
struct PDFDocumentCard: View {
  let metadata: PDFDocumentMetadata

  // Height reserved for the external title area below the card.
  private let titleAreaHeight: CGFloat = 36

  var body: some View {
    let previewImage = metadata.previewImageData.flatMap { UIImage(data: $0) }
    let cardCornerRadius: CGFloat = 10
    // Keeps a paper-like portrait ratio for the overall container.
    let cardAspectRatio: CGFloat = 0.72

    GeometryReader { proxy in
      let totalWidth = proxy.size.width
      let totalHeight = proxy.size.height
      // Card height is reduced to make room for the title below.
      let cardHeight = totalHeight - titleAreaHeight
      let shape = RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)

      VStack(alignment: .leading, spacing: 4) {
        // The PDF preview card.
        ZStack {
          // Background color for the card.
          Color(.systemGray5)

          // Draws the preview or placeholder PDF icon.
          if let previewImage {
            Image(uiImage: previewImage)
              .resizable()
              .scaledToFill()
              .frame(width: totalWidth, height: cardHeight)
          } else {
            // Placeholder PDF icon when no preview is available.
            Image(systemName: "doc.richtext")
              .font(.system(size: 32))
              .foregroundColor(.accentColor)
          }
        }
        .frame(width: totalWidth, height: cardHeight)
        .clipShape(shape)
        .shadow(color: Color.black.opacity(0.14), radius: 7, x: 0, y: 4)

        // Title and page count below the card.
        VStack(alignment: .leading, spacing: 1) {
          Text(metadata.displayName)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.ink)
            .lineLimit(1)
            .truncationMode(.tail)

          Text(pageCountText)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Color.inkSubtle)
            .lineLimit(1)
        }
        .padding(.horizontal, 2)
      }
    }
    .aspectRatio(cardAspectRatio, contentMode: .fit)
  }

  // Formats the page count with correct singular/plural form.
  private var pageCountText: String {
    if metadata.pageCount == 1 {
      return "1 page"
    } else {
      return "\(metadata.pageCount) pages"
    }
  }
}
