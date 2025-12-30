import Foundation

/// Protocol defining the contract for the DocumentHandle actor.
///
/// A DocumentHandle represents one opened notebook and provides safe, isolated access to:
/// - The notebook's manifest metadata
/// - The MyScript .iink package containing ink content
/// - Operations for loading, saving, and managing the package
///
/// # Actor Isolation
/// DocumentHandle is an actor to ensure that:
/// - Package operations are serialized (no concurrent modifications)
/// - Manifest updates are atomic
/// - File system access is safe
///
/// All methods are async and must be called with `await`.
///
/// # Lifecycle
/// 1. Created by BundleManager.openNotebook()
/// 2. Used to access parts, save changes, update viewport
/// 3. Closed via close() when the user exits the notebook
///
/// # Thread Safety
/// The MyScript package (IINKContentPackage) is NOT thread-safe.
/// DocumentHandle ensures all package access happens on the MainActor via:
/// ```swift
/// await MainActor.run {
///   // Package operations here
/// }
/// ```
///
/// # Package Lifecycle
/// The handle opens the package on initialization and keeps it open for its lifetime.
/// The package is saved and released when close() is called.
protocol DocumentHandleProtocol: Actor {

  /// The unique identifier for the notebook this handle represents.
  ///
  /// This matches the notebookID in the manifest and the bundle directory name.
  /// Immutable for the lifetime of the handle.
  var notebookID: String { get }

  /// The manifest loaded when the handle was opened.
  ///
  /// This is a snapshot of the manifest at open time.
  /// It does NOT reflect changes made by updateViewportState() or other operations.
  /// Use the `manifest` computed property to get the current manifest state.
  ///
  /// # Use Cases
  /// - Comparing current state to initial state
  /// - Detecting if anything changed during the session
  var initialManifest: ManifestProtocol { get }

  /// The file system path to the MyScript .iink package.
  ///
  /// This path uses decomposedStringWithCanonicalMapping normalization.
  /// Example: "/Users/.../Documents/Notebooks/ABC-123-DEF/content.iink"
  ///
  /// # Immutability
  /// This path is set once when the handle is created and never changes.
  var packagePath: String { get }

  /// The current state of the manifest, including any updates.
  ///
  /// This property reflects the most recent manifest state, including:
  /// - Viewport state updates from updateViewportState()
  /// - Any other modifications made through the handle
  ///
  /// # Difference from initialManifest
  /// - initialManifest: Snapshot at open time (immutable)
  /// - manifest: Current state (may have been updated)
  ///
  /// # Use Cases
  /// - Getting the current viewport state
  /// - Checking the current displayName
  /// - Accessing up-to-date timestamps
  var manifest: ManifestProtocol { get }

  /// Creates a DocumentHandle and opens the MyScript package.
  ///
  /// This initializer is called by BundleManager.openNotebook() after validating the bundle.
  ///
  /// # Parameters
  /// - notebookID: The unique identifier for this notebook
  /// - bundleURL: The URL to the bundle directory
  /// - manifest: The manifest loaded from manifest.json
  /// - packagePath: The file system path to the .iink package
  /// - openOption: How to open the package (.existing for normal open)
  ///
  /// # Package Opening
  /// The initializer opens the package on the MainActor:
  /// 1. Gets the engine from EngineProvider.sharedInstance
  /// 2. Calls engine.openPackage(packagePath, openOption: openOption)
  /// 3. Stores the opened package for the lifetime of the handle
  ///
  /// # Throws
  /// - DocumentHandleError.engineUnavailable if MyScript engine is nil
  /// - DocumentHandleError.packageOpenFailed if engine.openPackage() throws
  ///
  /// # Thread Safety
  /// Package opening happens on MainActor because MyScript APIs require it.
  /// The opened package reference is stored in the actor and accessed via MainActor.run.
  ///
  /// # Important Note
  /// Once created, the DocumentHandle takes ownership of the package.
  /// The package remains open until close() is called.
  /// Do not attempt to open the same package again while a handle exists.
  init(
    notebookID: String,
    bundleURL: URL,
    manifest: ManifestProtocol,
    packagePath: String,
    openOption: IINKPackageOpenOption
  ) async throws

  /// Loads the current manifest from disk.
  ///
  /// This method reads and decodes manifest.json from the bundle directory.
  /// It does NOT update the handle's internal manifest state - it simply returns
  /// what is currently on disk.
  ///
  /// # Use Cases
  /// - Checking if another process modified the manifest
  /// - Reloading after external changes
  /// - Validating that disk state matches memory state
  ///
  /// # Return Value
  /// Returns a freshly decoded Manifest struct from the manifest.json file.
  ///
  /// # Throws
  /// - File system errors if manifest.json cannot be read
  /// - DecodingError if the JSON cannot be parsed
  ///
  /// # Note
  /// This is a synchronous method (not async) because it only does file I/O,
  /// not MyScript operations. However, it still runs in the actor's isolation context.
  func loadManifest() throws -> ManifestProtocol

  /// Returns the opened MyScript package.
  ///
  /// # Return Value
  /// - Returns the IINKContentPackage if the package was opened successfully
  /// - Returns nil if package opening failed during init or if close() was called
  ///
  /// # Thread Safety
  /// The package is accessed on MainActor because MyScript APIs require it.
  /// Even though this method returns the package, the caller must still use
  /// MainActor.run or @MainActor contexts when calling package methods.
  ///
  /// # Important Warning
  /// The returned package is owned by the DocumentHandle.
  /// Do not call package.save() directly - use savePackage() instead.
  /// Do not store the package reference beyond the immediate scope.
  func getPackage() async -> IINKContentPackage?

  /// Returns the number of parts in the MyScript package.
  ///
  /// A "part" in MyScript is a logical page or section.
  /// Most notebooks have one part, but the package can contain multiple parts.
  ///
  /// # Return Value
  /// - Returns the count of parts if the package is available
  /// - Returns 0 if the package is nil (failed to open or already closed)
  ///
  /// # Thread Safety
  /// Accesses the package on MainActor via MainActor.run.
  ///
  /// # Use Cases
  /// - Checking if the notebook has any content
  /// - Iterating over all parts
  /// - Validating package structure
  func getPartCount() async -> Int

  /// Returns a specific part from the package by index.
  ///
  /// Parts are zero-indexed: the first part is at index 0.
  ///
  /// # Parameters
  /// - index: The zero-based index of the part to retrieve.
  ///          Must be >= 0 and < getPartCount().
  ///
  /// # Return Value
  /// - Returns the IINKContentPart if the index is valid
  /// - Returns nil if:
  ///   * The package is nil (failed to open or closed)
  ///   * The index is negative
  ///   * The index is >= part count
  ///   * package.part(at:) throws an error
  ///
  /// # Thread Safety
  /// Accesses the package on MainActor via MainActor.run.
  ///
  /// # Error Handling
  /// This method returns nil instead of throwing to simplify caller code.
  /// If you need to distinguish between "index out of range" and "package error",
  /// use getPackage() directly.
  func getPart(at index: Int) async -> IINKContentPart?

  /// Ensures there is at least one part in the package and returns it.
  ///
  /// This method guarantees that the package has a part to work with:
  /// - If the package already has parts, returns the first one (index 0)
  /// - If the package is empty, creates a new part of the specified type
  ///
  /// # Parameters
  /// - type: The type of part to create if needed.
  ///         Common types: "Drawing", "Text Document", "Math", "Diagram"
  ///
  /// # Return Value
  /// Returns the IINKContentPart at index 0, either existing or newly created.
  ///
  /// # Behavior
  /// 1. Checks if package has parts (partCount > 0)
  /// 2. If yes: Returns part at index 0
  /// 3. If no: Creates a new part with package.createPart(with: type)
  /// 4. Returns the newly created part
  ///
  /// # Throws
  /// - DocumentHandleError.packageNotAvailable if package is nil
  /// - DocumentHandleError.partCreationFailed if package.createPart() throws
  /// - DocumentHandleError.partLoadFailed if package.part(at: 0) throws
  ///
  /// # Thread Safety
  /// All package operations happen on MainActor via MainActor.run.
  ///
  /// # Use Cases
  /// This is the primary method used by the editor to get the working part:
  /// ```swift
  /// let part = try await handle.ensureInitialPart(type: "Drawing")
  /// try editor.set(part: part)
  /// ```
  func ensureInitialPart(type: String) async throws -> IINKContentPart

  /// Saves the MyScript package to its compressed archive file.
  ///
  /// This method calls package.save(), which:
  /// - Writes all in-memory changes to the .iink file
  /// - Compresses the content
  /// - Makes the changes persistent
  ///
  /// # When to Call
  /// Call savePackage() when:
  /// - The user explicitly saves (Save button)
  /// - Auto-save timer triggers (full save, not temp)
  /// - The notebook is being closed
  /// - The app is backgrounding
  ///
  /// # Difference from savePackageToTemp()
  /// - savePackage(): Full save to .iink file (slower, persistent)
  /// - savePackageToTemp(): Quick save to temp folder (faster, for auto-save)
  ///
  /// # Throws
  /// - DocumentHandleError.packageNotAvailable if package is nil
  /// - MyScript errors if package.save() fails (disk full, I/O error, etc.)
  ///
  /// # Thread Safety
  /// Package save happens on MainActor via MainActor.run.
  ///
  /// # Performance
  /// Full package save can take 100-500ms for large notebooks.
  /// For frequent auto-save, prefer savePackageToTemp() and do full saves periodically.
  func savePackage() async throws

  /// Saves current in-memory changes to the temporary folder.
  ///
  /// This method calls package.saveToTemp(), which:
  /// - Writes changes to a temporary location
  /// - Is faster than full save (no compression)
  /// - Provides crash protection without full I/O overhead
  ///
  /// # Purpose
  /// Temporary saves allow rapid auto-save without blocking the UI:
  /// - User is drawing → Auto-save triggers every 2 seconds → savePackageToTemp()
  /// - Changes are safe from crashes but not yet in the final .iink file
  /// - Periodically (every 20 seconds), do a full savePackage()
  ///
  /// # Throws
  /// - DocumentHandleError.packageNotAvailable if package is nil
  /// - MyScript errors if package.saveToTemp() fails
  ///
  /// # Thread Safety
  /// Package save happens on MainActor via MainActor.run.
  ///
  /// # Performance
  /// Temp saves are typically 10x faster than full saves.
  /// Suitable for high-frequency auto-save without UI lag.
  func savePackageToTemp() async throws

  /// Saves and releases the package reference, closing the handle.
  ///
  /// This method is called when the user exits the notebook.
  /// It performs cleanup and ensures changes are persisted.
  ///
  /// # Parameters
  /// - saveBeforeClose: If true, calls savePackage() before releasing.
  ///                    Defaults to true.
  ///
  /// # Behavior
  /// 1. If saveBeforeClose is true:
  ///    - Attempts to save the package
  ///    - Ignores save errors (logs but doesn't throw)
  /// 2. Sets the package reference to nil, releasing it
  ///
  /// # Why Ignore Save Errors?
  /// If save fails, we still want to release the package and close the handle.
  /// Otherwise, the package stays locked and the notebook can't be reopened.
  /// Save errors should have been caught and presented to the user earlier.
  ///
  /// # After close()
  /// Once close() is called:
  /// - getPackage() returns nil
  /// - getPartCount() returns 0
  /// - getPart() returns nil
  /// - Save methods throw packageNotAvailable
  ///
  /// The DocumentHandle is effectively dead and should be discarded.
  ///
  /// # saveBeforeClose = false
  /// Only use false if you've already saved manually or if you're discarding changes.
  /// Example: User explicitly chose "Don't Save" when closing.
  func close(saveBeforeClose: Bool) async

  /// Saves a preview image for the notebook.
  ///
  /// The preview image is shown in the dashboard as a thumbnail.
  /// It's typically a PNG snapshot of the notebook's first page or current view.
  ///
  /// # Parameters
  /// - data: PNG-encoded image data.
  ///         Should be a reasonably-sized thumbnail (e.g., 300x400 pixels).
  ///
  /// # Behavior
  /// Writes the data to preview.png in the bundle directory using atomic write.
  /// If preview.png already exists, it is replaced.
  ///
  /// # Throws
  /// - DocumentHandleError.previewSaveFailed if the file cannot be written
  ///
  /// # Thread Safety
  /// This is a synchronous method (not async) but runs in the actor's isolation.
  ///
  /// # When to Call
  /// - When closing the notebook (capture the current view)
  /// - After significant changes (update the preview periodically)
  /// - On explicit "Update Preview" action
  ///
  /// # PNG Format
  /// The data must be PNG-encoded. Use UIImage.pngData() or similar:
  /// ```swift
  /// if let pngData = image.pngData() {
  ///   try await handle.savePreviewImageData(pngData)
  /// }
  /// ```
  func savePreviewImageData(_ data: Data) throws

  /// Updates the viewport state in the manifest and persists it to disk.
  ///
  /// This method allows incremental manifest updates without a full package save.
  /// It's used to preserve scroll position and zoom level as the user navigates.
  ///
  /// # Parameters
  /// - state: The new viewport state to save.
  ///          Should contain the current offsetX, offsetY, and scale.
  ///
  /// # Behavior
  /// 1. Updates the in-memory manifest:
  ///    - Sets manifest.viewportState = state
  ///    - Sets manifest.modifiedAt = Date()
  /// 2. Encodes the updated manifest to JSON
  /// 3. Writes the JSON to manifest.json atomically
  ///
  /// # Error Handling
  /// If the write fails, the error is silently ignored (no throw).
  /// Rationale: Viewport state is a convenience feature. If it fails, the document
  /// content is still safe, and the user can still work. The next open will just
  /// use default viewport or the last successfully saved state.
  ///
  /// # When to Call
  /// - When the user scrolls or zooms (debounced to avoid excessive writes)
  /// - When closing the notebook (save final position)
  /// - Periodically during editing (e.g., every 5 seconds)
  ///
  /// # Thread Safety
  /// Runs in the actor's isolation. File I/O is synchronous but safe.
  ///
  /// # No Package Save Required
  /// This method only modifies manifest.json, not the .iink package.
  /// You can update viewport state without triggering a package save.
  func updateViewportState(_ state: ViewportStateProtocol) async
}

/// Errors that can occur when using a DocumentHandle.
///
/// These errors represent failures in package management and access.
/// All errors conform to LocalizedError for user-facing messages.
enum DocumentHandleErrorProtocol: LocalizedError {

  /// The MyScript engine is not available or not initialized.
  ///
  /// This occurs when:
  /// - EngineProvider.sharedInstance.engine is nil
  /// - The MyScript certificate is missing or invalid
  /// - Engine initialization failed
  ///
  /// # Recovery
  /// This is typically a fatal error. The app cannot function without the engine.
  /// User should see an error message explaining the certificate is missing.
  case engineUnavailable

  /// Failed to open the MyScript package.
  ///
  /// This wraps the underlying error from engine.openPackage().
  /// Possible causes:
  /// - .iink file is corrupted
  /// - File has wrong format or version
  /// - Disk read error
  /// - File permissions issue
  ///
  /// # Recovery
  /// The notebook cannot be opened. User should be notified that the file is damaged.
  /// The underlyingError contains details for diagnosis.
  case packageOpenFailed(underlyingError: Error)

  /// The package is not available for the requested operation.
  ///
  /// This occurs when:
  /// - Trying to use the package after close() was called
  /// - The package failed to open during init (should have thrown packageOpenFailed)
  /// - Internal state corruption
  ///
  /// # Recovery
  /// The DocumentHandle is unusable. Create a new handle by calling openNotebook() again.
  case packageNotAvailable

  /// Failed to create a new part in the package.
  ///
  /// This wraps the underlying error from package.createPart().
  /// Possible causes:
  /// - Invalid part type specified
  /// - Package is read-only
  /// - Disk space full
  /// - MyScript internal error
  ///
  /// # Context
  /// Occurs in ensureInitialPart() when the package is empty and a new part is needed.
  case partCreationFailed(underlyingError: Error)

  /// Failed to load an existing part from the package.
  ///
  /// This wraps the underlying error from package.part(at:).
  /// Possible causes:
  /// - Package is corrupted
  /// - Part index is invalid (shouldn't happen if logic is correct)
  /// - MyScript internal error
  ///
  /// # Context
  /// Occurs in ensureInitialPart() when trying to get part 0 from a non-empty package.
  case partLoadFailed(underlyingError: Error)

  /// Failed to save the notebook preview image.
  ///
  /// This wraps the underlying file system error.
  /// Possible causes:
  /// - Disk space full
  /// - Disk write error
  /// - File permissions issue
  /// - Bundle directory deleted externally
  ///
  /// # Recovery
  /// The preview save is non-critical. The notebook content is unaffected.
  /// User can be notified, but the session can continue.
  case previewSaveFailed(underlyingError: Error)

  /// User-facing error description for each case.
  ///
  /// These messages are shown in alerts or error UI.
  /// They should be clear and helpful without exposing internal details.
  var errorDescription: String? { get }
}
