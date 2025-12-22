import UIKit

// Groups small platform helpers used by the editor setup.
enum Helper {
    static func scaledDpi() -> Float {
        // Returns a device DPI estimate for renderer creation.
        // Keeps the value stable across runs without device-specific tables.
        deviceDpi()
    }

    static func deviceDpi() -> Float {
        // Uses common DPI defaults for iPad and iPhone families.
        switch UIDevice.current.userInterfaceIdiom {
        case .pad:
            return 264
        default:
            return 326
        }
    }
}