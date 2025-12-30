import Foundation
import UIKit

/// Represents a single offscreen render surface.
///
/// An offscreen surface is a CGLayer used by MyScript for rendering content that's not
/// currently visible on screen. This allows:
/// - Rendering large documents incrementally
/// - Caching rendered content
/// - Smooth scrolling (pre-rendered content is ready to display)
///
/// # Structure
/// Each surface contains:
/// - buffer: The CGLayer holding the rendered pixels
///
/// # Lifecycle
/// 1. MyScript requests a surface via createOffscreenRenderSurface()
/// 2. App creates a CGLayer and wraps it in OffscreenRenderSurface
/// 3. MyScript draws into the surface
/// 4. Surface is cached until MyScript no longer needs it
/// 5. MyScript calls releaseOffscreenRenderSurface()
/// 6. App removes the surface from cache
struct OffscreenRenderSurfaceProtocol {
  /// The CGLayer buffer holding the rendered content.
  ///
  /// # CGLayer
  /// A CGLayer is a Core Graphics object optimized for:
  /// - Repeated drawing
  /// - Off-screen rendering
  /// - Caching rendered content
  ///
  /// # Buffer Ownership
  /// The buffer is owned by this surface struct.
  /// When the surface is deallocated, the buffer is released.
  ///
  /// # Access
  /// MyScript accesses the buffer via getSurfaceBuffer(forId:)
  var buffer: CGLayer { get }
}

/// Protocol defining the contract for OffscreenRenderSurfaces.
///
/// OffscreenRenderSurfaces manages a collection of offscreen render surfaces.
/// MyScript calls methods on this class to:
/// - Create new surfaces when needed
/// - Retrieve surfaces for drawing
/// - Release surfaces when no longer needed
///
/// # Thread Safety
/// MyScript may call these methods very frequently and from different contexts.
/// To prevent race conditions, all methods use synchronized blocks:
/// - addSurface: Synchronized to prevent ID collisions
/// - getSurfaceBuffer: Synchronized to prevent concurrent access
/// - releaseSurface: Synchronized to prevent concurrent modification
///
/// The synchronized utility ensures only one thread accesses the buffers dictionary at a time.
///
/// # Surface Identification
/// Each surface is assigned a unique UInt32 ID:
/// - IDs start at 1 (nextId is incremented before assigning)
/// - IDs are never reused (nextId only increases)
/// - ID 0 is invalid (creation failure)
///
/// # Memory Management
/// Surfaces consume significant memory (pixels in the CGLayer).
/// The app must:
/// - Release surfaces when MyScript requests it
/// - Not leak surfaces (memory will grow unbounded)
/// - Not release surfaces prematurely (MyScript will crash accessing invalid ID)
protocol OffscreenRenderSurfacesProtocol: AnyObject {

  /// The scale factor for rendering surfaces.
  ///
  /// # Purpose
  /// Determines the pixel density of created surfaces.
  /// - 1.0: Standard resolution (1 point = 1 pixel)
  /// - 2.0: Retina resolution (1 point = 2 pixels)
  /// - 3.0: Super Retina resolution (1 point = 3 pixels)
  ///
  /// # Setting
  /// Set by DisplayViewModel based on screen characteristics:
  /// ```swift
  /// offscreenRenderSurfaces.scale = UIScreen.main.scale
  /// ```
  ///
  /// # Effect on Surfaces
  /// When creating a surface with dimensions (width, height):
  /// - Actual pixel size = (width * scale, height * scale)
  ///
  /// Example with scale = 2.0:
  /// - Requested: 400x300 points
  /// - Created: 800x600 pixels (high resolution)
  ///
  /// # Why Needed
  /// Retina displays need more pixels per point for sharp rendering.
  /// Without scaling, surfaces would appear blurry on high-DPI screens.
  ///
  /// # Mutability
  /// This is a var because it's set during initialization.
  /// It should NOT change after surfaces start being created.
  var scale: CGFloat { get set }

  /// Adds a new surface to the cache and returns its unique ID.
  ///
  /// # Parameters
  /// - buffer: The CGLayer to add as a surface
  ///
  /// # Return Value
  /// Returns a unique UInt32 identifier for this surface.
  /// This ID is used to retrieve or release the surface later.
  ///
  /// # ID Generation
  /// IDs are generated sequentially:
  /// 1. Increment nextId (e.g., 1 → 2)
  /// 2. Assign current nextId as the ID
  /// 3. Store surface in buffers[ID]
  /// 4. Return ID
  ///
  /// # Thread Safety
  /// Wrapped in synchronized(self) to ensure:
  /// - nextId is incremented atomically
  /// - Dictionary insertion is thread-safe
  /// - No two surfaces get the same ID
  ///
  /// # Example
  /// ```swift
  /// let surfaceId = offscreenSurfaces.addSurface(with: cgLayer)
  /// // Later, MyScript can request this surface by surfaceId
  /// ```
  ///
  /// # Memory
  /// The surface is retained in the buffers dictionary until released.
  @objc func addSurface(with buffer: CGLayer) -> UInt32

  /// Retrieves the CGLayer buffer for a given surface ID.
  ///
  /// # Parameters
  /// - offscreenId: The unique identifier returned by addSurface()
  ///
  /// # Return Value
  /// - Returns the CGLayer if the ID exists in the cache
  /// - Returns nil if the ID is invalid or the surface was released
  ///
  /// # Thread Safety
  /// Wrapped in synchronized(self) to ensure:
  /// - Dictionary access is thread-safe
  /// - No race with addSurface or releaseSurface
  ///
  /// # Use Cases
  /// MyScript calls this when it needs to draw into a surface:
  /// ```swift
  /// if let buffer = surfaces.getSurfaceBuffer(forId: surfaceId) {
  ///   let context = buffer.context
  ///   // Draw into context
  /// }
  /// ```
  ///
  /// # Invalid IDs
  /// If you pass an invalid ID (never existed or already released):
  /// - Returns nil
  /// - Does NOT crash or throw
  /// - Caller should handle nil gracefully
  ///
  /// # Example
  /// ```swift
  /// // Create surface
  /// let id = surfaces.addSurface(with: layer)
  ///
  /// // Later, retrieve it
  /// if let buffer = surfaces.getSurfaceBuffer(forId: id) {
  ///   print("Found buffer with size: \(buffer.size)")
  /// }
  /// ```
  @objc func getSurfaceBuffer(forId offscreenId: UInt32) -> CGLayer?

  /// Releases a surface from the cache, freeing its memory.
  ///
  /// # Parameters
  /// - offscreenId: The unique identifier of the surface to release
  ///
  /// # Behavior
  /// 1. Removes the surface from the buffers dictionary
  /// 2. The CGLayer is deallocated (if no other references exist)
  /// 3. Memory is freed
  ///
  /// # When Called
  /// MyScript calls this when:
  /// - Content is scrolled off screen and no longer needed
  /// - Memory pressure requires freeing caches
  /// - The part is being closed
  ///
  /// # Thread Safety
  /// Wrapped in synchronized(self) to ensure:
  /// - Dictionary removal is thread-safe
  /// - No race with getSurfaceBuffer
  ///
  /// # Invalid IDs
  /// If you pass an invalid ID:
  /// - The method does nothing (safe no-op)
  /// - Does NOT crash or throw
  ///
  /// # Double Release
  /// Calling releaseSurface twice with the same ID:
  /// - First call: Removes the surface
  /// - Second call: Does nothing (ID no longer exists)
  /// - Safe, no error
  ///
  /// # Memory Management
  /// After release, the surface ID is invalid and should not be used.
  /// Calling getSurfaceBuffer with a released ID returns nil.
  ///
  /// # Example
  /// ```swift
  /// // Create and use surface
  /// let id = surfaces.addSurface(with: layer)
  /// let buffer = surfaces.getSurfaceBuffer(forId: id)
  ///
  /// // When done, release it
  /// surfaces.releaseSurface(forId: id)
  ///
  /// // Now buffer is deallocated and ID is invalid
  /// let nilBuffer = surfaces.getSurfaceBuffer(forId: id) // Returns nil
  /// ```
  @objc func releaseSurface(forId offscreenId: UInt32)
}

// MARK: - Implementation Details

/// Thread Synchronization
///
/// The OffscreenRenderSurfaces class uses a synchronized utility for thread safety.
///
/// # Why Synchronization?
/// MyScript's rendering system may call these methods:
/// - Very frequently (hundreds of times per second)
/// - From different contexts (though typically on MainActor)
/// - During complex rendering operations
///
/// Without synchronization, concurrent calls could cause:
/// - Two surfaces getting the same ID (nextId race condition)
/// - Dictionary corruption (concurrent modification)
/// - Reading while another thread is writing
///
/// # synchronized() Utility
/// The synchronized function provides Objective-C style @synchronized:
/// ```swift
/// synchronized(lock: self) {
///   // Only one thread executes this block at a time
/// }
/// ```
///
/// # Performance Impact
/// Synchronization adds minimal overhead:
/// - Lock acquisition is fast (microseconds)
/// - Critical sections are very short (simple dictionary operations)
/// - Contention is rare (MyScript typically renders on one thread)
///
/// # Alternative Approaches
/// Other thread-safety options considered:
/// - Actor: Overkill for simple dictionary access, would require await
/// - DispatchQueue: Similar to synchronized but more verbose
/// - Lock: Lower-level, easier to misuse
///
/// synchronized is chosen for:
/// - Simplicity
/// - Objective-C interop (MyScript is Obj-C based)
/// - Familiar to iOS developers

/// Surface ID Management
///
/// # ID Range
/// Surface IDs are UInt32, providing 4 billion unique IDs.
/// At 1000 surfaces per second, this would last:
/// - 4,294,967,295 / 1000 / 60 / 60 / 24 = ~50 days
///
/// In practice:
/// - Apps create far fewer surfaces (tens, not thousands per second)
/// - App lifetime is much shorter than 50 days
/// - ID overflow is not a concern
///
/// # ID 0
/// ID 0 is used to indicate creation failure:
/// ```swift
/// let id = createOffscreenRenderSurface(...)
/// if id == 0 {
///   // Creation failed
/// }
/// ```
///
/// Because nextId starts at 0 and is incremented before use,
/// the first valid ID is 1.

/// Memory Consumption
///
/// # Surface Size
/// Each surface consumes memory proportional to:
/// - width * height * bytesPerPixel * scale^2
///
/// Example:
/// - Size: 800x600 points
/// - Scale: 2.0 (Retina)
/// - Pixels: 1600x1200
/// - Memory: 1600 * 1200 * 4 bytes = ~7.7 MB
///
/// With 10 surfaces: ~77 MB
/// With 50 surfaces: ~385 MB
///
/// # Memory Pressure
/// On devices with limited memory (older iPhones):
/// - MyScript may create fewer surfaces
/// - Surfaces may be smaller
/// - Release may happen more frequently
///
/// The app should monitor memory warnings and assist MyScript if needed:
/// ```swift
/// NotificationCenter.default.addObserver(
///   forName: UIApplication.didReceiveMemoryWarningNotification
/// ) { _ in
///   // Could flush caches, reduce quality, etc.
/// }
/// ```

/// Scale Factor Details
///
/// # Device Scale Factors
/// - iPhone 1-3GS: 1.0
/// - iPhone 4-XS: 2.0
/// - iPhone XS Max and newer: 3.0
/// - iPad Mini/Air: 2.0
/// - iPad Pro: 2.0
///
/// # Setting Scale
/// ```swift
/// let scale = UIScreen.main.scale
/// offscreenRenderSurfaces.scale = scale
/// ```
///
/// # Impact on Quality
/// Higher scale = sharper rendering but more memory.
/// The app currently uses screen scale unconditionally.
///
/// # Alternative Strategies
/// For memory-constrained devices, could use:
/// - Fixed scale (e.g., always 2.0)
/// - Dynamic scale (reduce quality under memory pressure)
/// - Adaptive scale (scale based on zoom level)
