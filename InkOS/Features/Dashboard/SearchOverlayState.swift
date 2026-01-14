import Combine

// Shared state for the dashboard search overlay.
final class SearchOverlayState: ObservableObject {
  // Controls whether the overlay is visible.
  @Published var isExpanded: Bool = false {
    didSet {
      print("[SearchOverlayState] isExpanded changed: \(oldValue) -> \(isExpanded)")
    }
  }
  // Text entered in the search bar.
  @Published var searchText: String = "" {
    didSet {
      print("[SearchOverlayState] searchText changed: '\(oldValue)' -> '\(searchText)'")
    }
  }
  // Search results for the current query.
  @Published var searchResults: [SearchResult] = [] {
    didSet {
      print("[SearchOverlayState] searchResults changed: \(oldValue.count) -> \(searchResults.count) items")
      for (index, result) in searchResults.enumerated() {
        print("[SearchOverlayState]   result[\(index)] id=\(result.documentID), name='\(result.displayName)'")
      }
    }
  }
  // Whether a search request is in progress.
  @Published var isSearching: Bool = false {
    didSet {
      print("[SearchOverlayState] isSearching changed: \(oldValue) -> \(isSearching)")
    }
  }
  // Focus state for the search text field.
  @Published var isSearchFieldFocused: Bool = false
}
