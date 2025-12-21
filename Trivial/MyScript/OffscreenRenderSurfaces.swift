import UIKit
import CoreGraphics

// Manages CGLayer buffers for offscreen rendering.
// The MyScript renderer creates offscreen surfaces for tiling and caching.
class OffscreenRenderSurfaces {
    private var surfaces: [UInt32: CGLayer] = [:]
    private var nextId: UInt32 = 1
    private let lock = NSLock()
    
    // Create a new offscreen surface and return its ID.
    func createSurface(width: Int32, height: Int32, context: CGContext, alphaMask: Bool) -> UInt32 {
        lock.lock()
        defer { lock.unlock() }
        
        let id = nextId
        nextId += 1
        
        // Create a CGLayer for offscreen rendering.
        let size = CGSize(width: CGFloat(width), height: CGFloat(height))
        let layer = CGLayer(context, size: size, auxiliaryInfo: nil)
        
        surfaces[id] = layer
        return id
    }
    
    // Retrieve a surface by ID.
    func getSurface(_ id: UInt32) -> CGLayer? {
        lock.lock()
        defer { lock.unlock() }
        return surfaces[id]
    }
    
    // Release a surface by ID.
    func releaseSurface(_ id: UInt32) {
        lock.lock()
        defer { lock.unlock() }
        surfaces.removeValue(forKey: id)
    }
    
    // Get the context for a surface.
    func getContext(_ id: UInt32) -> CGContext? {
        return getSurface(id)?.context
    }
}

