import Foundation

/// Protocol defining the contract for NotebookModel.
///
/// NotebookModel is the in-memory representation of a notebook's metadata.
/// It is constructed by reading the Manifest when a notebook is opened.
///
/// # Purpose
/// While Manifest is the on-disk format (Codable, JSON), NotebookModel is:
/// - The runtime representation used by business logic
/// - A clean abstraction over the Manifest structure
/// - Potentially extended with computed properties or methods
///
/// # What It Does NOT Contain
/// Like Manifest, NotebookModel does NOT contain:
/// - Ink strokes (stored in MyScript .iink package)
/// - Preview images (stored separately as preview.png)
/// - Viewport state (that's in the Manifest, used by the editor)
///
/// It only contains metadata needed to work with the notebook.
///
/// # Relationship to Manifest
/// ```
/// Disk: manifest.json (Manifest struct)
///   ↓ Read and decode
/// Memory: NotebookModel (constructed from Manifest)
///   ↓ Business logic uses NotebookModel
/// Disk: Changes written back to Manifest, then to manifest.json
/// ```
///
/// # Why Have Both?
/// - Manifest: Codable, matches JSON structure, handles versioning
/// - NotebookModel: Pure Swift, convenient for business logic, can differ from JSON
///
/// In practice, they currently have the same fields. But separating them allows:
/// - Adding computed properties to NotebookModel without affecting JSON
/// - Changing JSON structure without changing business logic
/// - Different validation or transformation logic
protocol NotebookModelProtocol {

  /// Unique identifier for this notebook.
  ///
  /// # Format
  /// UUID string, matching the notebookID in the Manifest.
  /// Example: "550E8400-E29B-41D4-A716-446655440000"
  ///
  /// # Immutability
  /// This value is set once when the model is created and never changes.
  /// It's the same as the bundle directory name and the Manifest's notebookID.
  ///
  /// # Uniqueness
  /// Guaranteed to be unique across all notebooks on all devices.
  let notebookID: String

  /// Human-readable name for the notebook.
  ///
  /// # Examples
  /// - "Math Homework"
  /// - "Meeting Notes - January 15"
  /// - "Sketches 🎨"
  ///
  /// # Mutability
  /// This is a var (mutable) because users can rename notebooks.
  /// When renamed:
  /// 1. Update NotebookModel.displayName
  /// 2. Update Manifest.displayName
  /// 3. Write Manifest back to disk
  ///
  /// # Validation
  /// Should not be empty. The app enforces this when creating/renaming.
  ///
  /// # Encoding
  /// May contain any Unicode characters including emoji and special symbols.
  var displayName: String { get set }

  /// Version number of the Manifest format this notebook uses.
  ///
  /// # Purpose
  /// Indicates which version of the Manifest structure this notebook was created with.
  /// Used for backward compatibility and migration logic.
  ///
  /// # Current Version
  /// Currently 1 for all notebooks.
  ///
  /// # Immutability
  /// The version is set when the notebook is created and never changes.
  /// Notebooks don't "upgrade" their version automatically.
  ///
  /// # Version Checks
  /// When opening a notebook, the app checks:
  /// ```swift
  /// guard ManifestVersion.supported.contains(model.version) else {
  ///   throw BundleError.unsupportedManifestVersion(...)
  /// }
  /// ```
  let version: Int

  /// Timestamp when the notebook was originally created.
  ///
  /// # Behavior
  /// - Set once when createBundle() is called
  /// - Never modified
  /// - Preserved when renaming or modifying content
  ///
  /// # Use Cases
  /// - Displaying "Created 3 days ago" in UI
  /// - Sorting notebooks by creation date
  /// - Analytics (how old is the average notebook?)
  ///
  /// # Precision
  /// Full Date precision (seconds level).
  /// Example: 2024-01-15 10:30:45 +0000
  let createdAt: Date

  /// Timestamp when the notebook metadata or content was last modified.
  ///
  /// # When Updated
  /// This should be updated whenever:
  /// - The notebook is renamed
  /// - Content is added or edited
  /// - Viewport state is saved
  ///
  /// # Behavior
  /// - Initially set to createdAt (same as creation time)
  /// - Updated each time the Manifest is written
  ///
  /// # Use Cases
  /// - Displaying "Modified 2 hours ago" in UI
  /// - Sorting notebooks by recent modifications
  /// - Conflict detection (if syncing across devices)
  ///
  /// # Mutability
  /// This is a var because it changes as the notebook is used.
  var modifiedAt: Date { get set }

  /// Creates a NotebookModel from a Manifest.
  ///
  /// This is the primary way to construct a NotebookModel.
  /// The editor loads the Manifest from disk and converts it to a model.
  ///
  /// # Parameters
  /// - manifest: The Manifest read from manifest.json
  ///
  /// # Field Mapping
  /// The initializer copies fields from Manifest to NotebookModel:
  /// - manifest.notebookID → model.notebookID
  /// - manifest.displayName → model.displayName
  /// - manifest.version → model.version
  /// - manifest.createdAt → model.createdAt
  /// - manifest.modifiedAt → model.modifiedAt
  ///
  /// # What's Excluded
  /// The following Manifest fields are NOT copied to NotebookModel:
  /// - lastAccessedAt (used by BundleManager, not by editor business logic)
  /// - viewportState (used by EditorViewModel, not by NotebookModel)
  ///
  /// Rationale: NotebookModel is a minimal representation.
  /// If the editor needs viewport state, it accesses the Manifest directly.
  ///
  /// # Example Usage
  /// ```swift
  /// let manifest = try await documentHandle.loadManifest()
  /// let model = NotebookModel(from: manifest)
  /// // Use model.displayName, model.createdAt, etc.
  /// ```
  ///
  /// # Validation
  /// The initializer does NOT validate that:
  /// - notebookID is non-empty
  /// - displayName is non-empty
  /// - version is supported
  ///
  /// These checks should have been done when opening the notebook (in openNotebook).
  /// By the time we're constructing NotebookModel, the Manifest is known to be valid.
  ///
  /// # Performance
  /// This is a simple copy operation. No I/O or expensive computation.
  init(from manifest: ManifestProtocol)
}
