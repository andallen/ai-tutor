// Copyright @ MyScript. All rights reserved.

import Foundation

// Manages the creation and lifecycle of the MyScript iink Engine.
// Uses singleton pattern to ensure the same engine instance is used throughout the app.
@MainActor
class EngineProvider {
    static var sharedInstance = EngineProvider()
    var engineErrorMessage: String = ""

    // IINK Engine, lazy loaded.
    // Returns the iink engine instance or nil if initialization fails.
    lazy var engine: IINKEngine? = {
        // Check that the MyScript certificate is present
        if myCertificate.length == 0 {
            self.engineErrorMessage =
                "Please replace the content of MyCertificate.c with the certificate you received from the developer portal"
            return nil
        }

        // Create the iink runtime environment
        let data = Data(bytes: myCertificate.bytes, count: myCertificate.length)
        guard let engine = IINKEngine(certificate: data) else {
            self.engineErrorMessage = "Invalid certificate"
            return nil
        }

        // Configure the iink runtime environment
        let configurationPath = Bundle.main.bundlePath.appending("/recognition-assets/conf")
        do {
            try engine.configuration.set(
                stringArray: [configurationPath],
                forKey: "configuration-manager.search-path")
        } catch {
            return nil
        }

        // Set the temporary directory
        do {
            try engine.configuration.set(
                string: NSTemporaryDirectory(),
                forKey: "content-package.temp-folder")
        } catch {
            return nil
        }

        return engine
    }()
}
