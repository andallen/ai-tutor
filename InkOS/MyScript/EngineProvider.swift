import Foundation

// Errors used during engine creation and configuration.
enum EngineProviderError: Error {
  case alreadyInitialized
  case emptyCertificate
  case engineCreationFailed
  case invalidAssetsPath
  case configurationFailed(Error)
}

// EngineProvider creates and configures a single MyScript engine instance.
@MainActor
final class EngineProvider {

  static let shared = EngineProvider()

  // Store the created engine for reuse across the app.
  private(set) var engine: IINKEngine?

  // Store the last error message for UI display.
  private(set) var engineErrorMessage: String?

  // Prevent multiple concurrent initialization attempts.
  private var isInitializing: Bool = false

  private init() {}

  // Create and configure the engine once.
  func initializeEngine() async throws {
    if engine != nil {
      throw EngineProviderError.alreadyInitialized
    }
    if isInitializing {
      throw EngineProviderError.alreadyInitialized
    }

    isInitializing = true
    defer { isInitializing = false }

    // Read certificate bytes from the bundled header symbol.
    if myCertificate.length == 0 {
      engineErrorMessage = "Certificate data is empty."
      throw EngineProviderError.emptyCertificate
    }

    // Convert C string pointer to Data.
    // myCertificate.bytes is const char*, which is UnsafePointer<Int8>
    // We need to convert it to UnsafePointer<UInt8> for Data initialization.
    let bytes = UnsafeRawPointer(myCertificate.bytes).bindMemory(
      to: UInt8.self, capacity: myCertificate.length)
    let certificateData = Data(bytes: bytes, count: myCertificate.length)

    // Create the engine off the main thread.
    let created: IINKEngine? = await Task.detached(priority: .userInitiated) {
      IINKEngine(certificate: certificateData)
    }.value

    guard let created else {
      engineErrorMessage = "Engine creation failed."
      throw EngineProviderError.engineCreationFailed
    }

    do {
      try configureEngine(created)
    } catch {
      engineErrorMessage = "Engine configuration failed: \(error)"
      throw EngineProviderError.configurationFailed(error)
    }

    engine = created
    engineErrorMessage = nil
  }

  // Configure recognition assets and temp folders required by the SDK.
  private func configureEngine(_ engine: IINKEngine) throws {
    let config = engine.configuration

    // Point the engine at recognition assets.
    let confPath = Bundle.main.bundlePath + "/recognition-assets/conf"
    if !FileManager.default.fileExists(atPath: confPath) {
      throw EngineProviderError.invalidAssetsPath
    }
    try config.set(stringArray: [confPath], forKey: "configuration-manager.search-path")

    // Create a temp folder used by the content package system.
    let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    let tempDir = tempRoot.appendingPathComponent("myscript-iink", isDirectory: true)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

    try config.set(string: tempDir.path, forKey: "content-package.temp-folder")

    // Set conservative defaults for drop shadow.
    // All values are set to 0 to disable drop shadow rendering.
    try config.set(number: 0.0, forKey: "renderer.drop-shadow.x-offset")
    try config.set(number: 0.0, forKey: "renderer.drop-shadow.y-offset")
    try config.set(number: 0.0, forKey: "renderer.drop-shadow.radius")
    // Color is set as a number (ARGB format), not a string. 0x00000000 = transparent black.
    try config.set(number: 0x0000_0000, forKey: "renderer.drop-shadow.color")
  }
}
