import Foundation

/// Protocol defining the contract for the BundleManager actor.
///
/// The BundleManager is the sole authority for performing file system operations on notebook bundles.
/// All notebook persistence operations must go through this manager to ensure data integrity and prevent
/// race conditions. The manager operates as an actor to serialize all file system access.
///
/// # Bundle Structure
/// Each notebook is stored as a "bundle" - a directory containing:
/// - manifest.json: Metadata file with notebook info (name, timestamps, viewport state)
/// - content.iink: MyScript package file containing the actual ink strokes and content
/// - preview.png: Optional cached thumbnail image for the dashboard
///
/// # Thread Safety
/// This protocol represents an actor. All methods are async and must be called with `await`.
/// The actor ensures that concurrent operations on the same bundle or file system are properly serialized.
///
/// # Error Handling
/// Methods throw errors for:
/// - Missing bundles or manifests
/// - File system access failures
/// - JSON decoding/encoding errors
/// - Invalid or corrupted manifests
/// - MyScript package creation/deletion failures
///
/// Callers should handle these errors and present appropriate messages to users.

protocol BundleManagerProtocol: Actor {

  /// Lists all existing notebook bundles in the storage directory.
  ///
  /// This method scans the bundles directory and returns metadata for each valid bundle.
  /// A bundle is considered valid if it:
  /// - Is a directory (not a file)
  /// - Contains a manifest.json file
  /// - Has a manifest that can be successfully decoded
  ///
  /// # Behavior
  /// - Skips hidden files and directories (those starting with ".")
  /// - Skips bundles without a manifest.json file
  /// - Skips bundles where manifest.json cannot be decoded (corrupted or invalid JSON)
  /// - Loads preview image data if preview.png exists, otherwise sets it to nil
  /// - Uses lastAccessedAt if available, falls back to modifiedAt for sorting
  ///
  /// # Return Value
  /// Returns an array of NotebookMetadata, one for each valid bundle found.
  /// The array may be empty if no valid bundles exist.
  /// Order of results is filesystem-dependent (not guaranteed to be sorted).
  ///
  /// # Throws
  /// - Throws if the bundles directory cannot be accessed
  /// - Throws if directory contents cannot be enumerated
  /// - Does NOT throw for individual bundle errors (those are silently skipped)
  ///
  /// # Performance
  /// This method performs I/O for each bundle (reading manifest.json and optionally preview.png).
  /// Performance scales linearly with the number of bundles. For large numbers of bundles,
  /// consider caching or pagination strategies.
  func listBundles() async throws -> [NotebookMetadata]

  /// Creates a new notebook bundle with the specified display name.
  ///
  /// This method performs several operations atomically:
  /// 1. Generates a new UUID for the notebook identifier
  /// 2. Creates a new directory using the UUID as the folder name
  /// 3. Creates an initial manifest.json with the display name and current timestamp
  /// 4. Creates a MyScript .iink package file
  /// 5. Adds an initial "Drawing" part to the package
  /// 6. Saves the package to disk
  ///
  /// # Parameters
  /// - displayName: The human-readable name for the notebook (e.g., "Math Notes").
  ///                Must not be empty. No length restrictions enforced.
  ///                May contain any valid Unicode characters.
  ///
  /// # Return Value
  /// Returns NotebookMetadata for the newly created bundle, containing:
  /// - id: The generated UUID
  /// - displayName: The provided name
  /// - previewImageData: nil (no preview exists yet)
  /// - lastAccessedAt: Set to creation time
  ///
  /// # Manifest Initialization
  /// The created manifest will have:
  /// - version: Set to ManifestVersion.current (currently 1)
  /// - createdAt: Current timestamp
  /// - modifiedAt: Current timestamp (same as createdAt)
  /// - lastAccessedAt: Current timestamp (same as createdAt)
  /// - viewportState: nil (no saved viewport yet)
  ///
  /// # Throws
  /// - BundleError.packageCreationFailed if MyScript package cannot be created
  /// - File system errors if directory or manifest cannot be created
  /// - JSON encoding errors if manifest cannot be serialized
  ///
  /// # MyScript Engine Dependency
  /// This method requires EngineProvider.sharedInstance.engine to be available.
  /// If the engine is nil or package creation fails, throws packageCreationFailed error.
  ///
  /// # Atomicity
  /// If any step fails after directory creation, the bundle directory may be left in an
  /// incomplete state. Callers should handle errors and potentially clean up failed bundles.
  func createBundle(displayName: String) async throws -> NotebookMetadata

  /// Renames an existing notebook by updating its manifest display name.
  ///
  /// This method:
  /// 1. Validates that the bundle exists
  /// 2. Loads the current manifest
  /// 3. Updates the displayName field
  /// 4. Updates the modifiedAt timestamp to the current time
  /// 5. Writes the updated manifest back to disk atomically
  ///
  /// # Parameters
  /// - notebookID: The unique identifier of the notebook to rename.
  ///               Must be a valid UUID that corresponds to an existing bundle directory.
  /// - newDisplayName: The new human-readable name for the notebook.
  ///                   Must not be empty. No length restrictions enforced.
  ///                   May contain any valid Unicode characters.
  ///
  /// # Behavior
  /// - Only updates the manifest.json file; does not touch the .iink package
  /// - Preserves all other manifest fields (version, createdAt, notebookID, viewportState, etc.)
  /// - Uses atomic write (writes to temp file, then moves) to prevent corruption
  ///
  /// # Throws
  /// - BundleError.bundleNotFound if no directory exists with the given notebookID
  /// - BundleError.bundleNotFound if the notebookID path exists but is not a directory
  /// - BundleError.manifestNotFound if the bundle directory exists but has no manifest.json
  /// - JSON decoding errors if the existing manifest cannot be parsed
  /// - JSON encoding errors if the updated manifest cannot be serialized
  /// - File system errors if the manifest cannot be written
  ///
  /// # Thread Safety
  /// As an actor method, this serializes with other operations on the same bundle.
  /// However, external processes modifying the file system could cause race conditions.
  func renameBundle(notebookID: String, newDisplayName: String) async throws

  /// Deletes a notebook bundle and all its contents from disk.
  ///
  /// This method:
  /// 1. Validates that the bundle exists and is a directory
  /// 2. Attempts to delete the .iink package using MyScript engine (if available)
  /// 3. Deletes the entire bundle directory and all its contents
  ///
  /// # Parameters
  /// - notebookID: The unique identifier of the notebook to delete.
  ///               Must be a valid UUID that corresponds to an existing bundle directory.
  ///
  /// # Behavior
  /// - Deletes the entire bundle directory recursively
  /// - All files in the bundle are permanently removed:
  ///   * manifest.json
  ///   * content.iink
  ///   * preview.png (if exists)
  ///   * Any other files that may have been added
  /// - If MyScript engine is available, attempts to delete the package through the engine first
  /// - If engine deletion fails, still proceeds to delete the directory
  /// - Operation is NOT reversible - there is no undo
  ///
  /// # Throws
  /// - BundleError.bundleNotFound if no directory exists with the given notebookID
  /// - BundleError.bundleNotFound if the notebookID path exists but is not a directory
  /// - File system errors if the directory cannot be removed (e.g., permission issues)
  ///
  /// # MyScript Package Deletion
  /// If the MyScript engine is available, the method first attempts engine.deletePackage().
  /// This allows the MyScript SDK to clean up any internal state or temporary files.
  /// If engine deletion fails or engine is unavailable, the method continues and deletes
  /// the directory anyway, ensuring the bundle is removed from the file system.
  ///
  /// # Important Warning
  /// This operation is destructive and permanent. All notebook content will be lost.
  /// Callers should confirm user intent before calling this method.
  func deleteBundle(notebookID: String) async throws

  /// Opens a notebook bundle and returns a DocumentHandle for safe access.
  ///
  /// This method performs comprehensive validation before opening:
  /// 1. Validates that the bundle directory exists
  /// 2. Validates that manifest.json exists and can be decoded
  /// 3. Validates that the manifest version is supported
  /// 4. Validates that required manifest fields (notebookID, displayName) are non-empty
  /// 5. Updates the lastAccessedAt timestamp
  /// 6. Creates and returns a DocumentHandle that opens the MyScript package
  ///
  /// # Parameters
  /// - id: The unique identifier (notebookID) of the notebook to open.
  ///       Must correspond to an existing bundle directory.
  ///
  /// # Return Value
  /// Returns a DocumentHandle that provides safe, actor-isolated access to:
  /// - The notebook's manifest data
  /// - The MyScript package for reading/writing ink content
  /// - Methods for saving changes and managing the package lifecycle
  ///
  /// # Validation Steps
  /// 1. Bundle Existence: Confirms directory exists at bundles/[notebookID]/
  /// 2. Manifest Existence: Confirms manifest.json file exists in the bundle
  /// 3. Manifest Decoding: Confirms JSON can be parsed into Manifest struct
  /// 4. Version Check: Confirms manifest.version is in ManifestVersion.supported
  /// 5. Required Fields: Confirms notebookID and displayName are non-empty strings
  ///
  /// # lastAccessedAt Update
  /// Before returning the handle, this method updates lastAccessedAt to the current time.
  /// If this update fails (e.g., file write error), the method continues and opens the
  /// notebook anyway, using the original manifest. This prevents blocking access due to
  /// a non-critical timestamp update failure.
  ///
  /// # Throws
  /// - BundleError.bundleNotFound if directory doesn't exist or isn't a directory
  /// - BundleError.manifestNotFound if manifest.json doesn't exist
  /// - BundleError.manifestDecodingFailed if JSON parsing fails (includes underlying error)
  /// - BundleError.unsupportedManifestVersion if version is not in supported set
  /// - BundleError.invalidManifest if notebookID or displayName is empty
  /// - DocumentHandleError.engineUnavailable if MyScript engine is not initialized
  /// - DocumentHandleError.packageOpenFailed if .iink package cannot be opened
  ///
  /// # Thread Safety
  /// The DocumentHandle is returned as an isolated actor. The caller must use `await`
  /// to interact with it. Multiple opens of the same notebook may cause conflicts if
  /// both handles attempt to modify the package simultaneously.
  ///
  /// # Package Opening
  /// The DocumentHandle internally calls engine.openPackage() with openOption: .existing.
  /// This assumes the .iink file already exists (created by createBundle).
  /// The package remains open for the lifetime of the DocumentHandle.
  func openNotebook(id notebookID: String) async throws -> DocumentHandle

  /// Returns the file system path to the MyScript .iink package for a given notebook.
  ///
  /// This is a helper method for constructing the full path to a notebook's package file.
  /// The path is derived from:
  /// 1. The bundles directory (typically Documents/Notebooks/)
  /// 2. The notebook's unique ID as a subdirectory
  /// 3. The standard package filename "content.iink"
  ///
  /// # Parameters
  /// - forNotebookID: The unique identifier of the notebook.
  ///                  Does NOT validate that the notebook or package actually exists.
  ///
  /// # Return Value
  /// Returns a String path using decomposedStringWithCanonicalMapping.
  /// Example: "/Users/.../Documents/Notebooks/ABC-123-DEF/content.iink"
  ///
  /// The decomposedStringWithCanonicalMapping normalization ensures consistent
  /// Unicode representation, which is important for MyScript's file handling.
  ///
  /// # Behavior
  /// - Does NOT check if the directory or file exists
  /// - Does NOT validate the notebookID format
  /// - Simply constructs the path based on the storage conventions
  ///
  /// # Throws
  /// - Throws if the bundles directory cannot be accessed or determined
  ///
  /// # Use Cases
  /// This method is useful when you need the package path for:
  /// - Direct MyScript engine operations (without opening through BundleManager)
  /// - File system checks or operations
  /// - Diagnostic or debugging purposes
  func iinkPackagePath(forNotebookID notebookID: String) async throws -> String
}

/// Struct representing lightweight metadata for a notebook.
///
/// This is the data structure returned by listBundles() and createBundle().
/// It contains only the essential information needed to display a notebook in a list or grid.
///
/// # Thread Safety
/// Conforms to Sendable, allowing it to be safely passed across actor boundaries.
/// All fields are immutable (let) and contain Sendable types.
///
/// # Design Rationale
/// NotebookMetadata is separate from the full Manifest to:
/// - Minimize data copying when listing many notebooks
/// - Avoid exposing internal manifest details (version, etc.) to UI layer
/// - Provide a stable API even if Manifest structure changes
struct NotebookMetadataProtocol: Identifiable, Sendable {

  /// Unique identifier for this notebook.
  ///
  /// This is the same as the notebookID in the Manifest and the bundle directory name.
  /// Format: UUID string (e.g., "550E8400-E29B-41D4-A716-446655440000")
  ///
  /// Conforms to Identifiable, making this suitable for use in SwiftUI ForEach loops.
  let id: String

  /// Human-readable name for the notebook.
  ///
  /// This is shown to users in the dashboard and editor title bar.
  /// Examples: "Math Notes", "Meeting Notes 2024-01-15"
  ///
  /// Matches the displayName field in the Manifest.
  let displayName: String

  /// Cached PNG image data for the notebook preview/thumbnail.
  ///
  /// # Behavior
  /// - nil if no preview has been saved yet (e.g., newly created notebook)
  /// - nil if preview.png file doesn't exist or couldn't be read
  /// - Contains PNG-encoded Data if preview exists
  ///
  /// # Usage
  /// UI code can convert this to a UIImage or Image for display:
  /// ```
  /// if let data = metadata.previewImageData,
  ///    let uiImage = UIImage(data: data) {
  ///   // Display the preview
  /// }
  /// ```
  ///
  /// # Performance Note
  /// This data is loaded into memory for each notebook in listBundles().
  /// For large preview images or many notebooks, consider lazy loading strategies.
  let previewImageData: Data?

  /// Timestamp when the notebook was last opened by the user.
  ///
  /// # Behavior
  /// - Set when the notebook is created (same as createdAt initially)
  /// - Updated each time openNotebook() is called
  /// - nil if the manifest doesn't have lastAccessedAt (older manifest versions)
  ///
  /// # Fallback
  /// If lastAccessedAt is nil, listBundles() uses modifiedAt instead.
  /// This ensures every notebook has a timestamp for sorting/displaying.
  ///
  /// # Use Cases
  /// - Sorting notebooks by recency ("Recently Opened" section)
  /// - Displaying "Last opened 2 days ago" text
  /// - Cleaning up rarely-used notebooks
  let lastAccessedAt: Date?
}

/// Errors that can occur when performing bundle operations.
///
/// Each error case includes the notebookID to help identify which bundle had the problem.
/// Some errors include underlying errors from the file system or JSON decoder.
///
/// All errors conform to LocalizedError, providing user-facing error messages.
enum BundleErrorProtocol: LocalizedError {

  /// The bundle directory does not exist at the expected path.
  ///
  /// This can occur when:
  /// - The notebookID doesn't correspond to any directory in the bundles folder
  /// - The bundle was deleted externally while the app was running
  /// - The notebookID path exists but is a file, not a directory
  ///
  /// Typically indicates the notebook has been deleted or the ID is invalid.
  case bundleNotFound(notebookID: String)

  /// The bundle directory exists but contains no manifest.json file.
  ///
  /// This indicates a corrupted or incomplete bundle. Possible causes:
  /// - Bundle creation was interrupted mid-process
  /// - User or external process deleted manifest.json
  /// - File system corruption
  ///
  /// The bundle directory exists but cannot be opened without a manifest.
  case manifestNotFound(notebookID: String)

  /// The manifest.json file exists but cannot be parsed as valid JSON.
  ///
  /// This wraps the underlying JSON decoding error for diagnosis.
  /// Possible causes:
  /// - File is corrupted or truncated
  /// - File was manually edited with syntax errors
  /// - File uses an unexpected encoding
  /// - Disk read error resulted in partial data
  ///
  /// The underlyingError contains the specific JSONDecoder error.
  case manifestDecodingFailed(notebookID: String, underlyingError: Error)

  /// The manifest has a version number that this app doesn't support.
  ///
  /// This occurs when:
  /// - Opening a notebook created by a newer version of the app
  /// - The manifest format has changed and this version is too old
  ///
  /// The version field indicates what version was found.
  /// Check ManifestVersion.supported to see what versions are currently supported.
  ///
  /// Users should update the app to open this notebook.
  case unsupportedManifestVersion(notebookID: String, version: Int)

  /// The manifest decoded successfully but contains invalid data.
  ///
  /// This indicates the JSON structure is correct, but required fields are missing
  /// or have invalid values. Examples:
  /// - notebookID is an empty string
  /// - displayName is an empty string
  /// - A required field is malformed
  ///
  /// The reason string describes what validation failed.
  case invalidManifest(notebookID: String, reason: String)

  /// The MyScript .iink package could not be created.
  ///
  /// This occurs during createBundle() when:
  /// - MyScript engine is not initialized (nil)
  /// - engine.createPackage() throws an error
  /// - package.createPart() fails to create the initial Drawing part
  /// - package.save() fails to persist to disk
  ///
  /// Possible causes:
  /// - Invalid MyScript certificate
  /// - Disk space full
  /// - File permissions issues
  /// - MyScript engine configuration problems
  case packageCreationFailed(notebookID: String)

  /// User-facing error description for each case.
  ///
  /// These messages are shown to users in alerts or error UI.
  /// They should be clear, actionable, and avoid technical jargon where possible.
  var errorDescription: String? { get }
}
