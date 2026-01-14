import SwiftUI
import UIKit

// Search results list for the dashboard search overlay.
// Displays loading, empty, and results states.
struct DashboardSearchResults: View {
  // Search results to display.
  let results: [SearchResult]
  // Current search query for empty state message.
  let query: String
  // Whether a search is currently in progress.
  let isLoading: Bool
  // Callback when a result is tapped.
  var onResultTapped: (SearchResult) -> Void

  var body: some View {
    Group {
      if isLoading {
        loadingState
      } else if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        emptyQueryState
      } else if results.isEmpty {
        noResultsState
      } else {
        resultsList
      }
    }
  }

  // Loading spinner while search is in progress.
  private var loadingState: some View {
    VStack {
      Spacer()
      ProgressView()
        .tint(Color.inkSubtle)
      Spacer()
    }
    .frame(maxWidth: .infinity)
  }

  // Message shown when no query has been entered.
  private var emptyQueryState: some View {
    VStack {
      Spacer()
      Text("Search your notes")
        .font(.system(size: 15))
        .foregroundColor(Color.inkSubtle)
      Spacer()
    }
    .frame(maxWidth: .infinity)
  }

  // Message shown when query returns no results.
  private var noResultsState: some View {
    VStack {
      Spacer()
      Text("No results for \"\(query)\"")
        .font(.system(size: 15))
        .foregroundColor(Color.inkSubtle)
      Spacer()
    }
    .frame(maxWidth: .infinity)
  }

  // Scrollable list of search results.
  private var resultsList: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        ForEach(results) { result in
          Button {
            onResultTapped(result)
          } label: {
            SearchResultRow(result: result)
          }
          .buttonStyle(.plain)

          // Separator between rows.
          if result.id != results.last?.id {
            Divider()
              .background(Color.rule)
              .padding(.leading, 52)
          }
        }
      }
      .padding(.horizontal, 16)
    }
  }
}

// Single row displaying a search result.
private struct SearchResultRow: View {
  let result: SearchResult

  // Preview thumbnail dimensions.
  // Uses the same aspect ratio as dashboard cards (0.72) for visual consistency.
  private let previewWidth: CGFloat = 44
  private let previewHeight: CGFloat = 61
  private let previewCornerRadius: CGFloat = 6

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      // Preview thumbnail.
      SearchResultPreview(
        previewImageData: result.previewImageData,
        documentType: result.documentType
      )
      .frame(width: previewWidth, height: previewHeight)
      .clipShape(RoundedRectangle(cornerRadius: previewCornerRadius, style: .continuous))
      .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)

      VStack(alignment: .leading, spacing: 4) {
        // Document title.
        Text(result.displayName)
          .font(.system(size: 15, weight: .semibold))
          .foregroundColor(Color.ink)
          .lineLimit(1)

        // Match snippet with highlighted matching text, rendered markdown, and LaTeX.
        SnippetContentView(
          snippet: result.matchSnippet,
          fontSize: 13,
          textColor: Color.inkSubtle,
          highlightColor: Color.ink
        )
        .lineLimit(2)

        // Match source and folder path.
        HStack(spacing: 8) {
          // Match source badge.
          Text(matchSourceLabel)
            .font(.system(size: 11))
            .foregroundColor(Color.inkFaint)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
              Capsule()
                .fill(Color.inkFaint.opacity(0.15))
            )

          // Folder path if present.
          if let folderPath = result.folderPath {
            HStack(spacing: 4) {
              Image(systemName: "folder")
                .font(.system(size: 10))
              Text(folderPath)
                .font(.system(size: 11))
            }
            .foregroundColor(Color.inkFaint)
          }
        }
      }

      Spacer()
    }
    .padding(.vertical, 12)
    .contentShape(Rectangle())
  }

  // Label for match source badge.
  private var matchSourceLabel: String {
    switch result.matchSource {
    case .title:
      return "Title"
    case .handwriting:
      return "Handwriting"
    case .pdfText:
      return "PDF Text"
    case .lessonContent:
      return "Lesson"
    case .folderName:
      return "Folder"
    }
  }

}

// MARK: - Search Result Preview

// Displays a preview thumbnail for a search result.
// Shows the same preview image used in dashboard cards, just smaller.
// Falls back to a document type icon if no preview is available.
private struct SearchResultPreview: View {
  // Preview image data from the search result.
  let previewImageData: Data?
  // Document type for fallback icon selection.
  let documentType: DocumentType

  var body: some View {
    GeometryReader { proxy in
      let width = proxy.size.width
      let height = proxy.size.height

      ZStack {
        // Background color based on document type.
        backgroundColor

        // Preview image or fallback icon.
        if let previewImageData, let uiImage = UIImage(data: previewImageData) {
          Image(uiImage: uiImage)
            .resizable()
            .scaledToFill()
            .frame(width: width, height: height)
            .clipped()
        } else {
          // Fallback icon when no preview is available.
          Image(systemName: placeholderIcon)
            .font(.system(size: 16))
            .foregroundColor(iconColor)
        }
      }
    }
  }

  // Background color based on document type.
  private var backgroundColor: Color {
    switch documentType {
    case .notebook:
      return .white
    case .pdf:
      return Color(.systemGray5)
    case .lesson:
      return .white
    case .folder:
      return Color(.systemGray6)
    }
  }

  // Placeholder icon based on document type.
  private var placeholderIcon: String {
    switch documentType {
    case .notebook:
      return "doc.text"
    case .pdf:
      return "doc.richtext"
    case .lesson:
      return "book.pages"
    case .folder:
      return "folder.fill"
    }
  }

  // Icon color for placeholder.
  private var iconColor: Color {
    switch documentType {
    case .notebook:
      return Color.inkSubtle
    case .pdf:
      return .accentColor
    case .lesson:
      return Color.inkSubtle
    case .folder:
      return .accentColor
    }
  }
}

#if DEBUG
struct DashboardSearchResults_Previews: PreviewProvider {
  static var previews: some View {
    VStack(spacing: 20) {
      // Loading state.
      DashboardSearchResults(
        results: [],
        query: "budget",
        isLoading: true,
        onResultTapped: { _ in }
      )
      .frame(height: 200)
      .background(Color.white)

      // Empty query state.
      DashboardSearchResults(
        results: [],
        query: "",
        isLoading: false,
        onResultTapped: { _ in }
      )
      .frame(height: 200)
      .background(Color.white)

      // No results state.
      DashboardSearchResults(
        results: [],
        query: "xyz",
        isLoading: false,
        onResultTapped: { _ in }
      )
      .frame(height: 200)
      .background(Color.white)
    }
  }
}
#endif
