// Copyright @ MyScript. All rights reserved.

import Foundation
import UIKit

struct OffscreenRenderSurface {
  var buffer: CGLayer
}

// Protocol defining the interface for offscreen render surface management.
// Used for dependency injection and testing.
protocol OffscreenRenderSurfacesProtocol: NSObjectProtocol {
  var scale: CGFloat { get set }
  func addSurface(with buffer: CGLayer) -> UInt32
  func getSurfaceBuffer(forId offscreenId: UInt32) -> CGLayer?
  func releaseSurface(forId offscreenId: UInt32)
}

/// The OffscreenRenderSurfaces role is to manage the content blocks not currently displayed on the screen.
/// It adds and releases surfaces on the need. It is important to understand that the
/// addSurface/getSurface/ReleaseSurface methods can be called very often, so we must always wait that a
/// call is finished before making another one, in order not to mix the ids.
/// Hence the use of the "synchronized" utility class.

class OffscreenRenderSurfaces: NSObject, OffscreenRenderSurfacesProtocol {

  // MARK: - Properties

  @objc var scale: CGFloat = 1
  private var buffers: [NSNumber: OffscreenRenderSurface] = [NSNumber: OffscreenRenderSurface]()
  private var nextId: UInt32 = 0

  // MARK: - Methods

  @objc func addSurface(with buffer: CGLayer) -> UInt32 {
    return synchronized(lock: self) {
      let surface: OffscreenRenderSurface = OffscreenRenderSurface(buffer: buffer)
      nextId += 1
      let offscreenId: UInt32 = self.nextId
      let key: NSNumber = NSNumber(value: offscreenId)
      self.buffers[key] = surface
      return nextId
    }
  }

  @objc func getSurfaceBuffer(forId offscreenId: UInt32) -> CGLayer? {
    let key: NSNumber = NSNumber(value: offscreenId)
    var surface: OffscreenRenderSurface?
    synchronized(self) {
      surface = buffers[key]
    }
    return surface?.buffer ?? nil
  }

  @objc func releaseSurface(forId offscreenId: UInt32) {
    let key: NSNumber = NSNumber(value: offscreenId)
    synchronized(self) {
      buffers.removeValue(forKey: key)
    }
  }
}
