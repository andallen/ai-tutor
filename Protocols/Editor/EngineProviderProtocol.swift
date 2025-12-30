import Foundation

/// Protocol defining the contract for EngineProvider.
///
/// EngineProvider is a singleton that manages the lifecycle of the MyScript IINKEngine.
/// The engine is the root object in the MyScript SDK and must be:
/// - Created once at app startup
/// - Reused throughout the app's lifetime
/// - Never deallocated until app termination
///
/// # Singleton Pattern
/// EngineProvider uses the singleton pattern because:
/// - MyScript license validation happens once during engine creation
/// - Multiple engines would waste memory and resources
/// - All editors and renderers must share the same engine instance
///
/// # MainActor Requirement
/// EngineProvider must be annotated with @MainActor because:
/// - The MyScript SDK is not thread-safe
/// - Engine configuration and editor creation must happen on the main thread
/// - UI components that use the engine already run on MainActor
///
/// # Lazy Initialization
/// The engine property is lazy-loaded:
/// - Not created until first access
/// - Creation happens once, result is cached
/// - If creation fails, returns nil every time
///
/// # Certificate Validation
/// The engine requires a valid MyScript certificate to function.
/// Without a certificate, the engine cannot be created.
@MainActor
protocol EngineProviderProtocol: AnyObject {

  /// The shared singleton instance of EngineProvider.
  ///
  /// # Usage
  /// ```swift
  /// let engine = await EngineProvider.sharedInstance.engine
  /// ```
  ///
  /// # Thread Safety
  /// Accessing sharedInstance is safe from any context.
  /// The instance itself is MainActor-isolated, so await is required from non-MainActor contexts.
  ///
  /// # Singleton Guarantee
  /// Always returns the same instance. Creating multiple EngineProviders is not supported.
  static var sharedInstance: Self { get }

  /// Error message describing why engine creation failed.
  ///
  /// # When Set
  /// Set when the engine lazy initialization fails.
  /// Possible messages:
  /// - "Please replace the content of MyCertificate.c with the certificate you received from the developer portal"
  /// - "Invalid certificate"
  ///
  /// # When Empty
  /// Empty string ("") if:
  /// - Engine hasn't been accessed yet
  /// - Engine was created successfully
  ///
  /// # Use Cases
  /// If engine is nil, check this property to determine why:
  /// ```swift
  /// guard let engine = provider.engine else {
  ///   print("Engine failed: \(provider.engineErrorMessage)")
  ///   return
  /// }
  /// ```
  var engineErrorMessage: String { get set }

  /// The MyScript IINKEngine instance, lazy-loaded on first access.
  ///
  /// # Return Value
  /// - Returns the engine instance if creation succeeded
  /// - Returns nil if creation failed (check engineErrorMessage for details)
  ///
  /// # Lazy Initialization
  /// On first access, this property:
  /// 1. Validates the MyScript certificate
  /// 2. Creates the engine with the certificate data
  /// 3. Configures the engine (search paths, temp folder)
  /// 4. Returns the engine or nil if any step failed
  ///
  /// Subsequent accesses return the cached result (engine or nil).
  ///
  /// # Certificate Validation
  /// The certificate is loaded from MyCertificate.c:
  /// ```c
  /// const unsigned char myCertificate[] = { ... };
  /// const unsigned int myCertificate_length = ...;
  /// ```
  ///
  /// Validation checks:
  /// - Length > 0 (not empty)
  /// - Engine creation succeeds (valid format and license)
  ///
  /// # Configuration Steps
  ///
  /// ## 1. Recognition Assets Search Path
  /// Sets the path where MyScript loads recognition models and resources:
  /// ```
  /// configuration-manager.search-path = [Bundle.main.bundlePath/recognition-assets/conf]
  /// ```
  ///
  /// This folder contains:
  /// - Language models for text recognition
  /// - Math symbol recognition data
  /// - Diagram recognition resources
  ///
  /// Without this configuration, recognition won't work.
  ///
  /// ## 2. Temporary Folder
  /// Sets where MyScript stores temporary files:
  /// ```
  /// content-package.temp-folder = NSTemporaryDirectory()
  /// ```
  ///
  /// MyScript uses this for:
  /// - savePackageToTemp() operations
  /// - Internal caching
  /// - Intermediate processing files
  ///
  /// # Error Conditions
  ///
  /// ## Empty Certificate
  /// If myCertificate.length == 0:
  /// - engineErrorMessage = "Please replace the content of MyCertificate.c..."
  /// - engine = nil
  ///
  /// This occurs when:
  /// - Developer hasn't added their certificate yet (default empty cert)
  /// - MyCertificate.c file is corrupted
  ///
  /// ## Invalid Certificate
  /// If IINKEngine(certificate:) returns nil:
  /// - engineErrorMessage = "Invalid certificate"
  /// - engine = nil
  ///
  /// This occurs when:
  /// - Certificate format is wrong
  /// - Certificate is expired
  /// - Certificate is for a different app bundle ID
  ///
  /// ## Configuration Failure
  /// If engine.configuration.set() throws:
  /// - engine = nil (configuration is critical)
  /// - engineErrorMessage is not updated (still shows "Invalid certificate")
  ///
  /// This occurs when:
  /// - Configuration key name is wrong
  /// - Configuration value type is wrong
  ///
  /// # Thread Safety
  /// The lazy property is accessed on MainActor.
  /// Lazy initialization is thread-safe (Swift guarantees single initialization).
  ///
  /// # Lifecycle
  /// The engine lives for the entire app lifetime:
  /// - Created on first access
  /// - Never explicitly released
  /// - Deallocated when app terminates
  ///
  /// # Use Cases
  ///
  /// ## Creating an Editor
  /// ```swift
  /// guard let engine = await EngineProvider.sharedInstance.engine else {
  ///   // Handle missing engine
  ///   return
  /// }
  /// let editor = engine.createEditor(renderer: renderer, toolController: toolController)
  /// ```
  ///
  /// ## Opening a Package
  /// ```swift
  /// guard let engine = await EngineProvider.sharedInstance.engine else {
  ///   throw DocumentHandleError.engineUnavailable
  /// }
  /// let package = try engine.openPackage(path, openOption: .existing)
  /// ```
  ///
  /// ## Creating a Package
  /// ```swift
  /// guard let engine = await EngineProvider.sharedInstance.engine else {
  ///   throw BundleError.packageCreationFailed(notebookID: id)
  /// }
  /// let package = try engine.createPackage(path)
  /// ```
  ///
  /// # Important Notes
  ///
  /// ## Certificate Location
  /// The certificate must be in MyCertificate.c, which is compiled into the app.
  /// It cannot be loaded from a resource file or downloaded at runtime.
  ///
  /// ## Certificate Security
  /// The certificate should not be committed to public repositories.
  /// It's unique to your MyScript license and app.
  ///
  /// ## Production vs Development
  /// MyScript certificates can be:
  /// - Development: Limited to debug builds, expires after some time
  /// - Production: For release builds, longer validity
  ///
  /// Ensure you're using the correct certificate for your build type.
  var engine: IINKEngine? { get }
}

/// The MyScript IINKEngine class (external dependency).
///
/// This is the root object in the MyScript SDK. It provides factory methods for:
/// - Creating editors (createEditor)
/// - Creating renderers (createRenderer)
/// - Creating tool controllers (createToolController)
/// - Creating/opening packages (createPackage, openPackage)
/// - Deleting packages (deletePackage)
///
/// # Thread Safety
/// IINKEngine is NOT thread-safe. All access must be on MainActor.
///
/// # Configuration
/// The engine has a configuration object (engine.configuration) for:
/// - Recognition settings
/// - Rendering settings
/// - Behavior tuning
/// - Resource paths
///
/// # Initialization
/// Created via IINKEngine(certificate:)
/// - Parameter: Data containing the MyScript certificate
/// - Returns: Engine instance or nil if certificate is invalid
///
/// # Lifecycle
/// The engine should be created once and live for the app's lifetime.
/// Creating multiple engines wastes resources and can cause license issues.
protocol IINKEngineProtocol {
  /// Creates a new IINKEngine instance with the provided certificate.
  ///
  /// # Parameters
  /// - certificate: Data containing the MyScript certificate bytes
  ///
  /// # Return Value
  /// - Returns an initialized engine if the certificate is valid
  /// - Returns nil if:
  ///   * Certificate is malformed
  ///   * Certificate is expired
  ///   * Certificate bundle ID doesn't match the app
  ///   * License has been revoked
  ///
  /// # Side Effects
  /// - Validates the license with MyScript's licensing system
  /// - Initializes internal MyScript subsystems
  /// - Allocates memory for recognition models
  ///
  /// # Error Handling
  /// Does not throw; returns nil on failure.
  /// Callers should check for nil and provide a helpful error message.
  init?(certificate: Data)

  /// The configuration object for this engine.
  ///
  /// Used to set:
  /// - configuration-manager.search-path (where to find recognition assets)
  /// - content-package.temp-folder (where to save temporary files)
  /// - Various recognition and rendering settings
  ///
  /// # Usage
  /// ```swift
  /// try engine.configuration.set(
  ///   stringArray: ["/path/to/resources"],
  ///   forKey: "configuration-manager.search-path"
  /// )
  /// ```
  var configuration: IINKConfiguration { get }

  /// Creates a new MyScript package at the specified path.
  ///
  /// # Parameters
  /// - path: File system path where the package should be created
  ///
  /// # Return Value
  /// Returns an IINKContentPackage representing the new package.
  ///
  /// # Throws
  /// Throws if:
  /// - File already exists at the path
  /// - Disk is full
  /// - Path is invalid or inaccessible
  /// - MyScript internal error
  ///
  /// # Package Structure
  /// A package is a compressed archive (.iink file) containing:
  /// - Content parts (pages)
  /// - Recognition metadata
  /// - Undo/redo history
  ///
  /// Initially empty (0 parts). Call package.createPart() to add content.
  func createPackage(_ path: String) throws -> IINKContentPackage

  /// Opens an existing MyScript package from the specified path.
  ///
  /// # Parameters
  /// - path: File system path to the .iink package file
  /// - openOption: How to open (.existing, .create, etc.)
  ///
  /// # Return Value
  /// Returns an IINKContentPackage for accessing the package content.
  ///
  /// # Throws
  /// Throws if:
  /// - File doesn't exist (when using .existing)
  /// - File is corrupted or invalid format
  /// - File is locked by another process
  /// - MyScript internal error
  ///
  /// # Package Locking
  /// Only one process can have a package open at a time.
  /// Opening the same package twice may fail or cause data corruption.
  func openPackage(_ path: String, openOption: IINKPackageOpenOption) throws -> IINKContentPackage

  /// Deletes a MyScript package from disk.
  ///
  /// # Parameters
  /// - path: File system path to the .iink package to delete
  ///
  /// # Throws
  /// Throws if:
  /// - File doesn't exist
  /// - File is locked (currently open)
  /// - Insufficient permissions
  ///
  /// # Side Effects
  /// Permanently removes the .iink file from disk.
  /// This is irreversible.
  func deletePackage(_ path: String) throws

  /// Creates a renderer for drawing ink on screen.
  ///
  /// # Parameters
  /// - dpiX: Horizontal DPI of the target display
  /// - dpiY: Vertical DPI of the target display
  /// - target: The render target (typically DisplayViewModel)
  ///
  /// # Return Value
  /// Returns an IINKRenderer for this display configuration.
  ///
  /// # DPI Importance
  /// The DPI tells MyScript how to convert millimeters (document space) to pixels (screen space).
  /// Incorrect DPI causes:
  /// - Strokes appearing wrong size
  /// - Recognition accuracy issues
  /// - Text rendering at wrong scale
  ///
  /// # Throws
  /// Throws if renderer creation fails (rare).
  func createRenderer(dpiX: Float, dpiY: Float, target: IINKIRenderTarget) throws -> IINKRenderer

  /// Creates a tool controller for managing active tools.
  ///
  /// # Return Value
  /// Returns an IINKToolController for setting pen/eraser/highlighter.
  ///
  /// # Usage
  /// ```swift
  /// let toolController = engine.createToolController()
  /// try toolController.set(tool: .toolPen, forType: .pen)
  /// ```
  ///
  /// # Thread Safety
  /// Tool controller must be used on MainActor.
  func createToolController() -> IINKToolController

  /// Creates an editor that combines a renderer and tool controller.
  ///
  /// # Parameters
  /// - renderer: The renderer to use for display
  /// - toolController: The tool controller for input
  ///
  /// # Return Value
  /// Returns an IINKEditor for user interaction.
  ///
  /// # Editor Lifecycle
  /// The editor should live as long as the notebook is open.
  /// Release via editor.set(part: nil) when done.
  ///
  /// # Thread Safety
  /// Editor must be used on MainActor.
  func createEditor(renderer: IINKRenderer, toolController: IINKToolController) -> IINKEditor
}

/// Configuration object for the MyScript engine.
///
/// Provides methods to set various configuration parameters.
protocol IINKConfigurationProtocol {
  /// Sets a configuration value of type string array.
  ///
  /// # Parameters
  /// - stringArray: Array of strings to set
  /// - forKey: Configuration key (e.g., "configuration-manager.search-path")
  ///
  /// # Throws
  /// Throws if the key is invalid or the value type is wrong.
  func set(stringArray: [String], forKey key: String) throws

  /// Sets a configuration value of type string.
  ///
  /// # Parameters
  /// - string: String value to set
  /// - forKey: Configuration key (e.g., "content-package.temp-folder")
  ///
  /// # Throws
  /// Throws if the key is invalid or the value type is wrong.
  func set(string: String, forKey key: String) throws
}

/// Options for opening a MyScript package.
enum IINKPackageOpenOptionProtocol {
  /// Open an existing package (fail if doesn't exist)
  case existing

  /// Create a new package (fail if already exists)
  case create

  /// Open if exists, create if doesn't exist
  case openOrCreate
}
