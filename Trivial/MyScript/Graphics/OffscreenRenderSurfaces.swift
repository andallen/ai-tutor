import UIKit
import CoreGraphics

// OffscreenRenderSurfaces stores CGLayer buffers used for renderer tiling and caching.
final class OffscreenRenderSurfaces {

    // Store the pixel scale used when translating between pixel and point space.
    // Set this from a concrete screen or trait collection in the view layer.
    var scale: CGFloat = 1.0

    private var surfaces: [UInt32: CGLayer] = [:]
    private var nextId: UInt32 = 1
    private let lock = NSLock()

    // Create a new surface and return its id.
    func createSurface(width: Int32, height: Int32, context: CGContext, alphaMask: Bool) -> UInt32 {
        lock.lock()
        defer { lock.unlock() }

        let id = nextId
        nextId += 1

        let size = CGSize(width: CGFloat(width), height: CGFloat(height))
        let layer = CGLayer(context, size: size, auxiliaryInfo: nil)
        surfaces[id] = layer

        return id
    }

    // Return the layer for a surface id.
    func getSurface(_ id: UInt32) -> CGLayer? {
        lock.lock()
        defer { lock.unlock() }
        return surfaces[id]
    }

    // Remove a surface id and release its layer.
    func releaseSurface(_ id: UInt32) {
        lock.lock()
        defer { lock.unlock() }
        surfaces.removeValue(forKey: id)
    }
}