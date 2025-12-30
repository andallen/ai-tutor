import Foundation

/// Protocol defining the contract for BundleStorage.
///
/// BundleStorage is a utility enum (not instantiable) that provides a centralized way to:
/// - Determine where notebook bundles are stored on disk
/// - Ensure the storage directory exists
/// - Handle directory creation failures
///
/// # Storage Location
/// All notebook bundles are stored in:
/// `Documents/Notebooks/`
///
/// Where Documents is the app's sandboxed Documents directory.
///
/// # Why an Enum?
/// Using an enum (not a class or struct) prevents instantiation.
/// This is appropriate for a namespace of utility functions that don't need state.
///
/// # Thread Safety
/// The bundlesDirectory() method is async to allow actor-isolated callers to use it,
/// but it doesn't perform async operations internally. It can be called from any context.
protocol BundleStorageProtocol {

  /// Returns the URL to the directory where all notebook bundles are stored.
  ///
  /// This method:
  /// 1. Gets the app's Documents directory
  /// 2. Appends "Notebooks" as a subdirectory
  /// 3. Checks if the directory exists
  /// 4. If not, creates it with intermediate directories
  /// 5. Returns the URL
  ///
  /// # Return Value
  /// Returns a URL pointing to the Notebooks directory.
  /// Example: file:///Users/.../Documents/Notebooks/
  ///
  /// # Directory Creation
  /// If the directory doesn't exist, creates it with:
  /// ```
  /// FileManager.createDirectory(
  ///   at: bundlesURL,
  ///   withIntermediateDirectories: true,
  ///   attributes: nil
  /// )
  /// ```
  ///
  /// The withIntermediateDirectories: true ensures that if Documents doesn't exist,
  /// it is created too (though this should never happen in a sandboxed app).
  ///
  /// # Idempotency
  /// This method is safe to call multiple times:
  /// - First call: Creates the directory if needed
  /// - Subsequent calls: Returns the existing directory
  ///
  /// # Existence Check
  /// Before creating, the method checks:
  /// 1. Does a file/directory exist at this path?
  /// 2. If yes, is it a directory (not a file)?
  ///
  /// Creates only if:
  /// - Nothing exists at the path, OR
  /// - A file (not directory) exists at the path
  ///
  /// If a file exists at Notebooks/, the method will fail when trying to create
  /// the directory. This is an error condition that should never occur in normal use.
  ///
  /// # Throws
  /// - File system errors if:
  ///   * Documents directory cannot be accessed
  ///   * Directory cannot be created (permissions, disk full, etc.)
  ///   * A file exists at the Notebooks path (name collision)
  ///
  /// # Thread Safety
  /// This is marked async but doesn't do async work. It's async to allow:
  /// - Actor-isolated callers to await it
  /// - Future async file operations if needed
  ///
  /// Internally, it uses FileManager which is thread-safe for read operations.
  /// The directory creation uses a file system lock, making it safe if called
  /// concurrently (though the actor system prevents this in normal use).
  ///
  /// # Error Recovery
  /// If this method throws, the app cannot function (no place to store notebooks).
  /// Callers should treat this as a fatal error and notify the user.
  ///
  /// # Example Usage
  /// ```swift
  /// actor BundleManager {
  ///   func listBundles() async throws -> [NotebookMetadata] {
  ///     let bundlesDir = try await BundleStorage.bundlesDirectory()
  ///     // ... enumerate contents of bundlesDir ...
  ///   }
  /// }
  /// ```
  static func bundlesDirectory() async throws -> URL
}
