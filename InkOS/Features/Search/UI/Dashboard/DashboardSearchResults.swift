import SwiftUI

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

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      // Document type icon.
      Image(systemName: iconName)
        .font(.system(size: 20))
        .foregroundColor(Color.offBlack)
        .frame(width: 24)

      VStack(alignment: .leading, spacing: 4) {
        // Document title.
        Text(result.displayName)
          .font(.system(size: 15, weight: .semibold))
          .foregroundColor(Color.ink)
          .lineLimit(1)

        // Match snippet.
        Text(result.matchSnippet)
          .font(.system(size: 13))
          .foregroundColor(Color.inkSubtle)
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

  // Icon based on document type.
  private var iconName: String {
    switch result.documentType {
    case .notebook:
      return "doc.text"
    case .pdf:
      return "doc.richtext"
    }
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
