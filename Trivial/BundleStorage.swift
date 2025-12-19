import Foundation

// Sets up the directory where Bundles are stored on disk.
// Creates the parent folder inside the app's Documents directory if it doesn't exist.
enum BundleStorage {
  // The name of the parent folder where all Bundles are stored.
  private static let bundlesFolderName = "Notebooks"

  // Returns the URL to the folder where Bundles are stored.
  // Creates the folder if it doesn't exist.
  // Throws if the Documents directory cannot be accessed or the folder cannot be created.
  static func bundlesDirectory() async throws -> URL {
    // Get the app's Documents directory.
    let documentsURL = try FileManager.default.url(
      for: .documentDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )

    // Build the path to the Bundles folder.
    let bundlesURL = documentsURL.appendingPathComponent(bundlesFolderName, isDirectory: true)

    // Check if the directory already exists before creating it.
    var isDirectory: ObjCBool = false
    let exists = FileManager.default.fileExists(atPath: bundlesURL.path, isDirectory: &isDirectory)

    // Only create the directory if it doesn't exist or isn't a directory.
    if !exists || !isDirectory.boolValue {
      try FileManager.default.createDirectory(
        at: bundlesURL,
        withIntermediateDirectories: true,
        attributes: nil
      )
    }

    return bundlesURL
  }
}
