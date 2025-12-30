import Foundation

/// Protocol defining constants for Manifest version management.
///
/// The Manifest version system allows the app to evolve the manifest format over time
/// while maintaining backward compatibility with older notebook files.
///
/// # Version Strategy
/// - current: The version used when creating new notebooks
/// - supported: The set of versions this app can open and read
///
/// # When to Increment Version
/// Increment the version number when making breaking changes to the manifest structure:
/// - Adding required fields
/// - Removing fields
/// - Changing field types
/// - Changing field semantics
///
/// Non-breaking changes (adding optional fields) may not require a version increment.
///
/// # Backward Compatibility
/// When incrementing current, consider whether to keep old versions in supported.
/// If you can read old formats, keep them in supported.
/// If migration is needed, implement migration code and still keep old versions supported.
protocol ManifestVersionProtocol {

  /// The current manifest version used when creating new notebooks.
  ///
  /// New notebooks created by createBundle() will have this version number.
  /// This should always be the highest version number the app supports.
  ///
  /// Current value: 1
  static var current: Int { get }

  /// The set of manifest versions that this app can successfully open and parse.
  ///
  /// When opening a notebook, openNotebook() checks that manifest.version
  /// is contained in this set. If not, it throws unsupportedManifestVersion.
  ///
  /// # Current Supported Versions
  /// - Version 1: The initial manifest format
  ///
  /// # Future Compatibility
  /// As the format evolves, this set should include all versions that can be read.
  /// Example: If version 2 is released, this might become [1, 2] if both are supported.
  static var supported: Set<Int> { get }
}

/// Represents the saved viewport configuration for a notebook.
///
/// The viewport state preserves the user's scroll position and zoom level when closing a notebook,
/// allowing restoration of the same view when reopening. This creates a seamless experience where
/// the user picks up exactly where they left off.
///
/// # Coordinate System
/// All measurements are in MyScript's document coordinate system (millimeters), not screen pixels.
/// - offsetX/offsetY: Position in millimeters from the document origin (top-left)
/// - scale: Zoom multiplier where 1.0 = 100% (no zoom)
///
/// # Document Space vs Screen Space
/// MyScript maintains a separation between document space (mm) and screen space (pixels):
/// - Document space is independent of device resolution and DPI
/// - Screen space is device-specific and depends on screen density
/// - The renderer converts between these spaces using the configured DPI
///
/// This protocol represents document space only. Screen coordinates are calculated by the renderer.
struct ViewportStateProtocol: Codable, Equatable, Sendable {

  /// Horizontal offset in millimeters from the document origin.
  ///
  /// # Meaning
  /// - 0.0: The left edge of the viewport is aligned with the left edge of the document
  /// - Positive values: The viewport is scrolled to the right
  /// - Negative values: Invalid (should not occur after clamping)
  ///
  /// # Valid Range
  /// - Minimum: 0.0 (cannot scroll left past document edge)
  /// - Maximum: Depends on document width and zoom level
  ///   * At scale 1.0 (no zoom): maxX is typically 0 (whole page visible)
  ///   * At scale > 1.0: maxX increases to allow viewing the zoomed content
  ///
  /// # Clamping
  /// The editor's clampViewOffset() method ensures offsetX stays within valid bounds.
  /// Invalid values may exist in corrupted manifests, which is why isValid() checks for finite numbers.
  let offsetX: Float

  /// Vertical offset in millimeters from the document origin.
  ///
  /// # Meaning
  /// - 0.0: The top edge of the viewport is aligned with the top edge of the document
  /// - Positive values: The viewport is scrolled downward
  /// - Negative values: Invalid (should not occur after clamping)
  ///
  /// # Valid Range
  /// - Minimum: 0.0 (cannot scroll above document top)
  /// - Maximum: Unlimited in theory (document grows downward as user adds content)
  ///   * In practice, clamped to the current document height
  ///
  /// # Document Growth
  /// Unlike offsetX (bounded by page width), offsetY can grow indefinitely as the user
  /// adds more content downward. The canvas is vertically infinite in MyScript's drawing mode.
  let offsetY: Float

  /// Zoom scale factor where 1.0 represents 100% zoom (no magnification).
  ///
  /// # Zoom Levels
  /// - 1.0: Default view, 100% size, no zoom
  /// - < 1.0: Zoomed out (not typically used in this app, minZoomScale is 1.0)
  /// - > 1.0: Zoomed in (magnified)
  /// - 2.0: 200% zoom (twice the size)
  /// - 4.0: 400% zoom (four times the size, typically the maximum)
  ///
  /// # Valid Range
  /// The app enforces zoom limits:
  /// - Minimum: 0.1 (checked by isValid(), but app typically uses 1.0 as practical min)
  /// - Maximum: 10.0 (checked by isValid(), but app typically uses 4.0 as practical max)
  ///
  /// # Relationship to Offset
  /// Zoom affects the valid range for offsets:
  /// - At scale 1.0, horizontal scrolling is usually disabled (entire page width visible)
  /// - At scale > 1.0, horizontal scrolling becomes necessary to view the full width
  /// - Higher zoom increases the maximum valid offsetX and offsetY
  let scale: Float

  /// Creates a default viewport state centered at the document origin with 100% zoom.
  ///
  /// # Default State
  /// - offsetX: 0.0 (left edge of document)
  /// - offsetY: 0.0 (top edge of document)
  /// - scale: 1.0 (100% zoom, no magnification)
  ///
  /// # Use Cases
  /// This default is used when:
  /// - Opening a newly created notebook that has never been saved
  /// - Opening a notebook whose manifest has viewportState = nil
  /// - Resetting to a known good state after detecting invalid viewport data
  static var `default`: ViewportStateProtocol { get }

  /// Validates that viewport values are within reasonable bounds.
  ///
  /// This method prevents crashes or undefined behavior from corrupted or invalid manifest data.
  /// It checks that all numeric values are mathematically valid and within acceptable ranges.
  ///
  /// # Validation Rules
  ///
  /// ## Scale Validation
  /// - Must be positive: scale > 0.1
  /// - Must not be extreme: scale < 10.0
  ///
  /// Rationale:
  /// - Scale values near zero or negative would cause division by zero or inverted rendering
  /// - Extremely high scale values (>10.0) could cause numeric overflow or performance issues
  /// - The range 0.1 to 10.0 provides a safety buffer around practical zoom limits (1.0 to 4.0)
  ///
  /// ## Offset Validation
  /// - offsetX must be a finite number (not NaN, not infinity)
  /// - offsetY must be a finite number (not NaN, not infinity)
  ///
  /// Rationale:
  /// - NaN (Not a Number) values arise from invalid math operations and cause comparisons to fail
  /// - Infinity values arise from overflow and cause rendering to break
  /// - Finite numbers can be safely used in arithmetic and comparison operations
  ///
  /// # Return Value
  /// - true: All values are valid and safe to use
  /// - false: One or more values are invalid; state should not be applied
  ///
  /// # Error Recovery
  /// If isValid() returns false, callers should:
  /// 1. Fall back to ViewportState.default
  /// 2. Log or report the corruption for diagnostics
  /// 3. Continue execution (don't crash)
  ///
  /// # Example Invalid States
  /// ```
  /// ViewportState(offsetX: .nan, offsetY: 0, scale: 1.0)      // false - NaN offset
  /// ViewportState(offsetX: 0, offsetY: .infinity, scale: 1.0) // false - infinite offset
  /// ViewportState(offsetX: 0, offsetY: 0, scale: 0.0)         // false - zero scale
  /// ViewportState(offsetX: 0, offsetY: 0, scale: -1.0)        // false - negative scale
  /// ViewportState(offsetX: 0, offsetY: 0, scale: 15.0)        // false - extreme scale
  /// ```
  ///
  /// # Example Valid States
  /// ```
  /// ViewportState(offsetX: 0, offsetY: 0, scale: 1.0)         // true - default state
  /// ViewportState(offsetX: 100, offsetY: 200, scale: 2.5)     // true - zoomed and scrolled
  /// ViewportState(offsetX: -5, offsetY: -10, scale: 1.0)      // true - finite (will be clamped by editor)
  /// ```
  func isValid() -> Bool
}

/// The Manifest is a JSON file stored inside each notebook bundle that describes the notebook's metadata.
///
/// # Purpose
/// The Manifest contains app-level metadata about the notebook:
/// - Identity (notebookID, displayName)
/// - Timestamps (createdAt, modifiedAt, lastAccessedAt)
/// - UI state (viewportState for scroll/zoom position)
/// - Format version (for backward compatibility)
///
/// # What It Does NOT Contain
/// The Manifest does NOT store the actual ink content. That is stored in the MyScript .iink package file.
/// The Manifest only tracks metadata needed by the app to manage and display the notebook.
///
/// # File Location
/// The Manifest is always stored at:
/// `Notebooks/[notebookID]/manifest.json`
///
/// Example:
/// `Notebooks/550E8400-E29B-41D4-A716-446655440000/manifest.json`
///
/// # JSON Format
/// The Manifest is encoded as JSON with:
/// - ISO 8601 date format for all Date fields
/// - Pretty-printed with sorted keys for human readability
/// - Atomic write (temp file + rename) to prevent corruption
///
/// # Thread Safety
/// Conforms to @unchecked Sendable. The Sendable requirement is bypassed because:
/// - All fields are either Sendable types or simple value types
/// - Mutability is controlled through actor isolation (BundleManager and DocumentHandle)
/// - Direct concurrent access is prevented by the actor system
struct ManifestProtocol: Codable, Sendable {

  /// Unique identifier for this notebook.
  ///
  /// # Format
  /// A UUID string, for example: "550E8400-E29B-41D4-A716-446655440000"
  ///
  /// # Behavior
  /// - Generated once when the notebook is created (by createBundle)
  /// - Never changes for the lifetime of the notebook
  /// - Used as the bundle directory name
  /// - Must not be empty (validated by openNotebook)
  ///
  /// # Uniqueness
  /// The UUID ensures global uniqueness even if multiple devices create notebooks.
  /// Collisions are statistically impossible.
  let notebookID: String

  /// Human-readable name for the notebook shown to the user.
  ///
  /// # Examples
  /// - "Math Notes"
  /// - "Meeting Notes 2024-01-15"
  /// - "Project Ideas 💡"
  ///
  /// # Behavior
  /// - Set when the notebook is created
  /// - Can be changed by the user via renameBundle()
  /// - Shown in the dashboard list and editor title bar
  /// - Must not be empty (validated by openNotebook)
  /// - No maximum length enforced
  /// - May contain any Unicode characters including emoji
  ///
  /// # Mutability
  /// This is a var (mutable) field. When renaming:
  /// 1. Load the manifest
  /// 2. Modify displayName
  /// 3. Update modifiedAt
  /// 4. Write back to disk
  var displayName: String

  /// Format version number for backward compatibility.
  ///
  /// # Purpose
  /// Allows the app to evolve the manifest structure while still opening old notebooks.
  /// When opening, the app checks: `ManifestVersion.supported.contains(manifest.version)`
  ///
  /// # Current Version
  /// All new notebooks are created with version = ManifestVersion.current (currently 1)
  ///
  /// # Behavior
  /// - Set once when the notebook is created
  /// - Never modified (version is immutable for the notebook's lifetime)
  /// - If the app can't read the version, throws unsupportedManifestVersion error
  ///
  /// # Future Compatibility
  /// If the manifest format changes (e.g., new required fields), increment the version.
  /// Older app versions will refuse to open newer manifests, preventing data loss.
  let version: Int

  /// Timestamp when the notebook was originally created.
  ///
  /// # Behavior
  /// - Set once when createBundle() is called
  /// - Never modified
  /// - Stored in ISO 8601 format in JSON: "2024-01-15T10:30:00Z"
  ///
  /// # Use Cases
  /// - Displaying "Created on January 15, 2024" in notebook info
  /// - Sorting notebooks by creation date
  /// - Calculating notebook age for analytics or cleanup
  let createdAt: Date

  /// Timestamp when the notebook metadata or content was last modified.
  ///
  /// # When Updated
  /// This timestamp should be updated whenever:
  /// - The notebook is renamed (via renameBundle)
  /// - The viewport state is saved (via updateViewportState)
  /// - Any other manifest field changes
  ///
  /// # When NOT Updated
  /// - When only lastAccessedAt changes (opening the notebook)
  /// - When the .iink package is modified without manifest changes
  ///
  /// # Behavior
  /// - Initially set to createdAt when the notebook is created
  /// - Updated each time the manifest is written
  /// - Stored in ISO 8601 format in JSON: "2024-01-15T14:20:00Z"
  ///
  /// # Mutability
  /// This is a var field, updated by:
  /// - renameBundle() when changing displayName
  /// - updateViewportState() when saving viewport
  var modifiedAt: Date

  /// Timestamp when the notebook was last opened by the user.
  ///
  /// # Purpose
  /// Tracks when the user last interacted with this notebook, enabling:
  /// - "Recently Opened" sorting in the dashboard
  /// - "Last opened 3 days ago" display text
  /// - Identifying abandoned notebooks for cleanup
  ///
  /// # When Updated
  /// - Set to createdAt when the notebook is created
  /// - Updated to current time when openNotebook() is called
  ///
  /// # Optional Nature
  /// This field is optional (nil) to maintain compatibility with older manifests that
  /// didn't have this field. When nil:
  /// - listBundles() falls back to using modifiedAt for sorting
  /// - UI can show modifiedAt instead, or omit the timestamp
  ///
  /// # Update Failure Handling
  /// When openNotebook() updates lastAccessedAt, the write may fail (disk full, permissions, etc.).
  /// If the update fails, openNotebook() continues and opens the notebook anyway.
  /// Rationale: lastAccessedAt is a convenience feature; failure shouldn't block access.
  ///
  /// # Mutability
  /// This is a var field, updated by:
  /// - init() when creating a new manifest
  /// - openNotebook() when opening an existing notebook
  var lastAccessedAt: Date?

  /// Optional viewport state preserving scroll position and zoom level.
  ///
  /// # Purpose
  /// When closing a notebook, the editor captures the current scroll offset and zoom scale.
  /// When reopening, the editor restores this state so the user sees the same view.
  ///
  /// # When Set
  /// - nil when the notebook is first created (no viewport history yet)
  /// - Set when the editor closes or saves the notebook
  /// - Updated periodically if the app implements auto-save of viewport state
  ///
  /// # When Nil
  /// If this field is nil, the editor should:
  /// 1. Initialize viewport to default (top-left corner, 100% zoom)
  /// 2. NOT throw an error (nil is a valid state)
  ///
  /// # Validation
  /// Before applying a non-nil viewport state, call isValid() to detect corruption:
  /// ```
  /// if let state = manifest.viewportState {
  ///   if state.isValid() {
  ///     restoreViewportState(state)
  ///   } else {
  ///     initializeDefaultViewport()
  ///   }
  /// } else {
  ///   initializeDefaultViewport()
  /// }
  /// ```
  ///
  /// # Mutability
  /// This is a var field, updated by:
  /// - DocumentHandle.updateViewportState() when saving scroll/zoom position
  var viewportState: ViewportStateProtocol?

  /// Creates a new Manifest with the given notebook ID and display name.
  ///
  /// This initializer is used by createBundle() when creating a new notebook.
  ///
  /// # Parameters
  /// - notebookID: The unique identifier (UUID string) for the notebook.
  ///               Should be generated with UUID().uuidString.
  /// - displayName: The human-readable name for the notebook.
  ///                Should not be empty.
  ///
  /// # Initial State
  /// The initializer sets up the manifest with:
  /// - version: ManifestVersion.current
  /// - createdAt: Current timestamp
  /// - modifiedAt: Same as createdAt (notebook just created)
  /// - lastAccessedAt: Same as createdAt (notebook just created)
  /// - viewportState: nil (no viewport history yet)
  ///
  /// # Example
  /// ```
  /// let id = UUID().uuidString
  /// let manifest = Manifest(notebookID: id, displayName: "My Notes")
  /// // manifest.createdAt == now
  /// // manifest.modifiedAt == now
  /// // manifest.lastAccessedAt == now
  /// // manifest.viewportState == nil
  /// ```
  init(notebookID: String, displayName: String)
}

/// Explicit Codable conformance extension for Manifest.
///
/// # Purpose
/// Although Manifest has Codable fields, the explicit conformance allows:
/// - Custom JSON key mapping (CodingKeys enum)
/// - Custom decoding logic (init(from:))
/// - Custom encoding logic (encode(to:))
/// - Handling of optional fields (decodeIfPresent)
///
/// # JSON Structure
/// The Manifest encodes to JSON with these keys:
/// ```json
/// {
///   "notebookID": "550E8400-...",
///   "displayName": "My Notes",
///   "version": 1,
///   "createdAt": "2024-01-15T10:30:00Z",
///   "modifiedAt": "2024-01-15T14:20:00Z",
///   "lastAccessedAt": "2024-01-16T09:15:00Z",
///   "viewportState": {
///     "offsetX": 0.0,
///     "offsetY": 150.5,
///     "scale": 2.0
///   }
/// }
/// ```
///
/// # Optional Field Handling
/// - lastAccessedAt: Uses decodeIfPresent/encodeIfPresent (may be nil)
/// - viewportState: Uses decodeIfPresent/encodeIfPresent (may be nil)
///
/// # Date Encoding
/// Uses ISO 8601 format via JSONEncoder/Decoder date strategy:
/// - Encoding: encoder.dateEncodingStrategy = .iso8601
/// - Decoding: decoder.dateDecodingStrategy = .iso8601
///
/// Example date: "2024-01-15T10:30:00Z"
///
/// # Error Handling
/// Decoding throws if:
/// - Any required field is missing
/// - Any field has the wrong type
/// - Dates cannot be parsed from ISO 8601 format
/// - JSON is malformed
extension ManifestProtocol {

  /// Defines the JSON keys for encoding/decoding.
  ///
  /// Each case name matches the property name in the Manifest struct.
  /// Each rawValue is the actual JSON key string.
  ///
  /// By default, Swift uses the case name as the JSON key, so this enum
  /// is mostly documentation. However, if you wanted to rename a JSON key
  /// without changing the property name, you would set the rawValue differently.
  enum CodingKeys: String, CodingKey {
    case notebookID
    case displayName
    case version
    case createdAt
    case modifiedAt
    case lastAccessedAt
    case viewportState
  }

  /// Decodes a Manifest from a JSON decoder.
  ///
  /// # Required Fields
  /// These must be present in the JSON or decoding throws:
  /// - notebookID (String)
  /// - displayName (String)
  /// - version (Int)
  /// - createdAt (Date in ISO 8601 format)
  /// - modifiedAt (Date in ISO 8601 format)
  ///
  /// # Optional Fields
  /// These may be absent from the JSON (decoded as nil):
  /// - lastAccessedAt (Date in ISO 8601 format)
  /// - viewportState (ViewportState object)
  ///
  /// # Date Format
  /// Dates are decoded from ISO 8601 strings: "2024-01-15T10:30:00Z"
  /// The decoder must have dateDecodingStrategy = .iso8601 set.
  ///
  /// # Throws
  /// - DecodingError.keyNotFound if a required field is missing
  /// - DecodingError.typeMismatch if a field has the wrong type
  /// - DecodingError.dataCorrupted if a date string is not valid ISO 8601
  init(from decoder: any Decoder) throws

  /// Encodes a Manifest to a JSON encoder.
  ///
  /// # Required Fields
  /// These are always encoded:
  /// - notebookID (String)
  /// - displayName (String)
  /// - version (Int)
  /// - createdAt (Date as ISO 8601 string)
  /// - modifiedAt (Date as ISO 8601 string)
  ///
  /// # Optional Fields
  /// These are only encoded if non-nil:
  /// - lastAccessedAt (Date as ISO 8601 string, if not nil)
  /// - viewportState (ViewportState object, if not nil)
  ///
  /// # Date Format
  /// Dates are encoded as ISO 8601 strings: "2024-01-15T10:30:00Z"
  /// The encoder must have dateEncodingStrategy = .iso8601 set.
  ///
  /// # Output Formatting
  /// The encoder should be configured with:
  /// - encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  ///
  /// This produces human-readable JSON with consistent key ordering.
  ///
  /// # Throws
  /// - EncodingError if any field cannot be encoded
  func encode(to encoder: any Encoder) throws
}
