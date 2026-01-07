import Foundation

// Implements FolderLookupProtocol using BundleManager to resolve folder IDs to display names.
// Used by SearchService to enrich search results with folder path information.
actor BundleManagerFolderLookup: FolderLookupProtocol {
  // The BundleManager instance to query for folder information.
  private let bundleManager: BundleManager

  // Cache of folder ID to display name mappings for performance.
  private var folderCache: [String: String] = [:]

  // Creates a lookup backed by the given BundleManager.
  init(bundleManager: BundleManager) {
    self.bundleManager = bundleManager
  }

  // Resolves a folder ID to its display name.
  // Returns nil if the folder does not exist or an error occurs.
  // Caches results for subsequent lookups.
  func getFolderDisplayName(folderID: String) async -> String? {
    // Check cache first.
    if let cached = folderCache[folderID] {
      return cached
    }

    // Query BundleManager for all folders.
    guard let folders = try? await bundleManager.listFolders() else {
      return nil
    }

    // Find the folder with matching ID.
    if let folder = folders.first(where: { $0.id == folderID }) {
      folderCache[folderID] = folder.displayName
      return folder.displayName
    }

    return nil
  }

  // Clears the folder cache. Call when folders are modified.
  func invalidateCache() {
    folderCache.removeAll()
  }
}
