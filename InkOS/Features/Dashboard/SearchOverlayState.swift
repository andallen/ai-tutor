import Combine

// Shared state for the dashboard search overlay.
final class SearchOverlayState: ObservableObject {
  // Controls whether the overlay is visible.
  @Published var isExpanded: Bool = false
  // Text entered in the search bar.
  @Published var searchText: String = ""
  // Search results for the current query.
  @Published var searchResults: [SearchResult] = []
  // Whether a search request is in progress.
  @Published var isSearching: Bool = false
  // Focus state for the search text field.
  @Published var isSearchFieldFocused: Bool = false
}
