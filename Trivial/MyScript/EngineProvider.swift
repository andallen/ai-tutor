import Foundation

// Errors that can occur during engine initialization.
enum EngineProviderError: LocalizedError {
  case missingCertificate
  case invalidCertificate
  case configurationFailed(String)

  var errorDescription: String? {
    switch self {
    case .missingCertificate:
      return
        "Missing MyScript certificate. Replace the certificate file with one from the MyScript Developer Portal."
    case .invalidCertificate:
      return
        "Invalid certificate or application identifier mismatch. Ensure your bundle ID matches the one registered in the MyScript Developer Portal."
    case let .configurationFailed(details):
      return "Engine configuration failed: \(details)"
    }
  }
}

// Singleton class that manages the MyScript IINKEngine lifecycle.
// Annotated with @MainActor because the IINKEngine and IINKEditor are not thread-safe
// and must be accessed from the main thread to sync with the UI.
@MainActor
final class EngineProvider {
  // Shared singleton instance.
  static let shared = EngineProvider()

  // Stores any error message that occurred during engine initialization.
  // Can be used by the UI to display an error to the user.
  private(set) var engineErrorMessage: String = ""

  // The IINKEngine instance. Lazily initialized with the MyScript certificate.
  // Returns nil if the certificate is missing or invalid.
  private(set) lazy var engine: IINKEngine? = {
    // Check if certificate data is present.
    // The myCertificate constant is defined in the bridged MyCertificate.h file.
    guard myCertificate.length > 0 else {
      self.engineErrorMessage = EngineProviderError.missingCertificate.localizedDescription
      return nil
    }

    // Convert the certificate bytes into a Data object.
    // The bytes pointer is cast to UInt8 since Swift Data expects unsigned bytes.
    let certificateData = Data(
      bytes: myCertificate.bytes,
      count: myCertificate.length
    )

    // Attempt to instantiate the engine with the certificate.
    guard let engine = IINKEngine(certificate: certificateData) else {
      self.engineErrorMessage = EngineProviderError.invalidCertificate.localizedDescription
      return nil
    }

    // Configure the engine with asset paths and temporary directory.
    do {
      try configure(engine: engine)
    } catch {
      self.engineErrorMessage = error.localizedDescription
      return nil
    }

    return engine
  }()

  // Private initializer to enforce singleton pattern.
  private init() {}

  // Configures the engine with the required paths for recognition assets
  // and a temporary directory for intermediate data.
  private func configure(engine: IINKEngine) throws {
    let configuration = engine.configuration

    // Build the path to the recognition assets configuration folder.
    // The conf folder contains .conf files that tell the engine where to find .res files.
    let configurationPath = Bundle.main.bundlePath.appending("/recognition-assets/conf")

    // Set the search path for recognition asset configuration files.
    // The engine will look for .conf files in this directory.
    do {
      try configuration.set(
        stringArray: [configurationPath],
        forKey: "configuration-manager.search-path"
      )
    } catch {
      throw EngineProviderError.configurationFailed(
        "Failed to set recognition assets search path: \(error.localizedDescription)"
      )
    }

    // Set the temporary directory for the engine.
    // The engine requires read/write access to store intermediate work data.
    // This is mandatory for handling large packages and images efficiently.
    do {
      try configuration.set(
        string: NSTemporaryDirectory(),
        forKey: "content-package.temp-folder"
      )
    } catch {
      throw EngineProviderError.configurationFailed(
        "Failed to set temporary folder: \(error.localizedDescription)"
      )
    }
  }

  // Checks whether the engine is available and ready to use.
  var isEngineAvailable: Bool {
    return engine != nil
  }
}

