import Foundation
import UIKit
import Combine

/// Protocol defining the contract for DisplayViewModel.
///
/// DisplayViewModel manages the rendering infrastructure for the MyScript editor.
/// It acts as a bridge between:
/// - MyScript's IINKRenderer (generates drawing commands)
/// - RenderView (UIView that displays the rendered content)
/// - OffscreenRenderSurfaces (manages cached rendering for off-screen content)
///
/// # Architecture Role
/// DisplayViewModel sits in the rendering pipeline:
/// ```
/// User draws → IINKEditor → IINKRenderer → DisplayViewModel → RenderView → Screen
/// ```
///
/// # Responsibilities
/// - Creating and configuring the RenderView
/// - Managing offscreen render surfaces
/// - Responding to MyScript invalidation callbacks
/// - Triggering view refreshes when content changes
///
/// # IINKIRenderTarget Conformance
/// DisplayViewModel conforms to IINKIRenderTarget, which means:
/// - MyScript calls methods on this object to request rendering
/// - The ViewModel translates those calls into UIKit view updates
///
/// # Thread Safety
/// Most methods run on MainActor because they interact with UIKit views.
/// MyScript rendering callbacks are dispatched to the main queue.
protocol DisplayViewModelProtocol: NSObjectProtocol, IINKIRenderTarget {

  // MARK: - Published Properties

  /// The RenderView that displays the rendered ink content.
  ///
  /// # Purpose
  /// This is the UIView that shows MyScript's rendered output to the user.
  /// It's published so SwiftUI or UIKit containers can embed it.
  ///
  /// # Creation
  /// Created during setupModel() with:
  /// - Frame: Initially CGRect.zero (sized by Auto Layout later)
  /// - offscreenRenderSurfaces: Shared surface manager
  /// - renderer: MyScript's IINKRenderer
  /// - imageLoader: Utility for loading images referenced in content
  ///
  /// # Lifecycle
  /// Lives as long as the DisplayViewModel.
  /// Deallocated when the editor is closed.
  var renderView: RenderView? { get set }

  // MARK: - Properties

  /// The MyScript renderer that generates drawing commands.
  ///
  /// # Purpose
  /// The renderer converts MyScript's internal model (strokes, text, math) into
  /// rendering operations (draw line, draw text, fill shape, etc.).
  ///
  /// # Lifecycle
  /// Created by InputViewModel during editor setup:
  /// ```swift
  /// let renderer = try engine.createRenderer(
  ///   dpiX: Helper.scaledDpi(),
  ///   dpiY: Helper.scaledDpi(),
  ///   target: displayViewModel
  /// )
  /// ```
  ///
  /// # Target
  /// The renderer's target is this DisplayViewModel.
  /// When content changes, the renderer calls invalidate() on this target.
  var renderer: IINKRenderer? { get set }

  /// Utility for loading images referenced in notebook content.
  ///
  /// # Purpose
  /// If the notebook contains images (e.g., inserted photos, pasted screenshots),
  /// the imageLoader fetches and caches them for rendering.
  ///
  /// # Caching
  /// The ImageLoader uses NSCache to avoid re-loading the same image multiple times.
  ///
  /// # Memory Management
  /// Cache has a 200 MB limit. Older images are evicted when limit is reached.
  var imageLoader: ImageLoader? { get set }

  /// Manager for offscreen render surfaces.
  ///
  /// # Purpose
  /// Offscreen surfaces cache rendered content that's not currently visible.
  /// This enables:
  /// - Smooth scrolling (pre-rendered content)
  /// - Efficient large documents (only visible area needs re-rendering)
  ///
  /// # Lifecycle
  /// Created during initialization and reused for all surfaces.
  var offscreenRenderSurfaces: OffscreenRenderSurfacesProtocol { get }

  // MARK: - Setup

  /// Sets up the model by creating and configuring the RenderView.
  ///
  /// # Behavior
  /// 1. Creates a new RenderView with frame CGRect.zero
  /// 2. Assigns the offscreenRenderSurfaces to the view
  /// 3. If renderer exists, assigns it to the view
  /// 4. If imageLoader exists, assigns it to the view
  /// 5. Stores the view in the renderView property
  ///
  /// # When to Call
  /// Called once during InputViewModel.setupModel(), before the editor is shown.
  ///
  /// # Auto Layout
  /// The view is created with zero frame but will be sized by Auto Layout.
  /// Constraints are set up in initModelViewConstraints().
  ///
  /// # Dependencies
  /// If renderer or imageLoader are nil when this is called, they can be set later.
  /// The view will pick them up when they're assigned to the ViewModel.
  func setupModel()

  /// Sets the scale for offscreen render surfaces.
  ///
  /// # Parameters
  /// - scale: The scale factor (typically UIScreen.main.scale)
  ///
  /// # Purpose
  /// Tells the surface manager what pixel density to use.
  /// - 1.0: Standard resolution
  /// - 2.0: Retina
  /// - 3.0: Super Retina
  ///
  /// # When to Call
  /// Should be called once during setup, before any surfaces are created.
  ///
  /// # Effect
  /// All subsequently created surfaces will use this scale.
  /// Surfaces created before this call are NOT affected.
  func setOffScreenRendererSurfacesScale(scale: CGFloat)

  /// Initializes Auto Layout constraints for the render view.
  ///
  /// # Parameters
  /// - view: The parent view to add constraints to
  ///
  /// # Constraints
  /// Sets up constraints so renderView fills the parent view:
  /// - H:|[renderView]| (leading and trailing edges)
  /// - V:|[renderView]| (top and bottom edges)
  ///
  /// # When to Call
  /// Called once during view controller setup, after the views are created.
  ///
  /// # Idempotency
  /// This method only sets constraints once (tracked by didSetConstraints).
  /// Subsequent calls are ignored.
  ///
  /// # Thread Safety
  /// Must be called on MainActor (modifies view hierarchy).
  func initModelViewConstraints(view: UIView)

  /// Triggers a display refresh of the render view.
  ///
  /// # Behavior
  /// Calls renderView.setNeedsDisplay(), which:
  /// - Marks the view as needing redraw
  /// - Triggers a call to renderView.draw(_:) on the next render cycle
  ///
  /// # When to Call
  /// - After content changes
  /// - After scrolling or zooming
  /// - After invalidate() callbacks from MyScript
  ///
  /// # Efficiency
  /// Multiple calls to setNeedsDisplay() in the same run loop are coalesced.
  /// The view only redraws once per frame (60 FPS).
  ///
  /// # Thread Safety
  /// Must be called on MainActor (UIKit requirement).
  func refreshDisplay()
}

/// Protocol defining MyScript's render target interface.
///
/// IINKIRenderTarget is called by MyScript's IINKRenderer to:
/// - Request view refreshes when content changes
/// - Create offscreen surfaces for caching
/// - Release offscreen surfaces when no longer needed
/// - Create Canvas objects for drawing into surfaces
///
/// DisplayViewModel implements this protocol to bridge MyScript and UIKit.
protocol IINKIRenderTarget: AnyObject {

  /// Called when content has changed and the view needs to be invalidated.
  ///
  /// # Parameters
  /// - renderer: The renderer requesting invalidation
  /// - layers: Which layers changed (model, temporary, capture)
  ///
  /// # Behavior
  /// This version invalidates the entire view:
  /// 1. Dispatches to main queue (MyScript may call from background)
  /// 2. Calls renderView.setNeedsDisplay()
  ///
  /// # Layers
  /// MyScript has multiple rendering layers:
  /// - Model: The finalized ink strokes
  /// - Temporary: Strokes being drawn (not yet committed)
  /// - Capture: Recognition visualization
  ///
  /// Different layers changing require different update strategies.
  /// Currently, the app always does a full redraw regardless of which layers changed.
  ///
  /// # Thread Safety
  /// MyScript may call this from any thread.
  /// The implementation must dispatch to MainActor for UIKit access.
  func invalidate(_ renderer: IINKRenderer, layers: IINKLayerType)

  /// Called when a specific area has changed and needs invalidation.
  ///
  /// # Parameters
  /// - renderer: The renderer requesting invalidation
  /// - area: The rectangular area that changed (in view coordinates)
  /// - layers: Which layers changed in that area
  ///
  /// # Behavior
  /// Despite receiving a specific area, the app does a full redraw:
  /// 1. Dispatches to main queue
  /// 2. Calls renderView.setNeedsDisplay() (full view, not just area)
  ///
  /// # Why Not Partial Invalidation?
  /// Partial invalidation (setNeedsDisplay(_:)) can cause artifacts:
  /// - Live capture creates striped rendering bugs
  /// - Stroke anti-aliasing needs surrounding context
  /// - MyScript's area calculations aren't always precise
  ///
  /// Full redraws are fast enough on modern devices.
  ///
  /// # Future Optimization
  /// For very large documents, partial invalidation could be reconsidered:
  /// - Only if live-capture issues are resolved
  /// - With testing on large, complex notebooks
  /// - With performance profiling to confirm benefit
  ///
  /// # Thread Safety
  /// MyScript may call this from any thread.
  /// The implementation must dispatch to MainActor.
  func invalidate(_ renderer: IINKRenderer, area: CGRect, layers: IINKLayerType)

  /// Creates an offscreen render surface for caching.
  ///
  /// # Parameters
  /// - width: Width in pixels (not points)
  /// - height: Height in pixels (not points)
  /// - alphaMask: Whether the surface should have an alpha channel
  ///
  /// # Return Value
  /// Returns a unique UInt32 ID for the created surface.
  /// Returns 0 if creation fails.
  ///
  /// # Creation Process
  /// 1. Calculate actual size accounting for scale:
  ///    ```
  ///    actualSize = CGSize(
  ///      width: scale * width,
  ///      height: scale * height
  ///    )
  ///    ```
  /// 2. Create a graphics context with that size
  /// 3. Create a CGLayer from the context
  /// 4. Add the layer to offscreenRenderSurfaces
  /// 5. Return the assigned ID
  ///
  /// # Graphics Context
  /// Created with UIGraphicsBeginImageContextWithOptions:
  /// - size: Scaled size
  /// - opaque: false (supports transparency)
  /// - scale: 1 (size already includes scale factor)
  ///
  /// # Why Scale is Applied
  /// MyScript requests sizes in pixels, but we need to account for device DPI.
  /// The scale factor ensures sharp rendering on Retina displays.
  ///
  /// # Failure Conditions
  /// Creation can fail if:
  /// - Memory allocation fails (size too large, low memory)
  /// - Graphics context creation fails
  ///
  /// # Thread Safety
  /// Called by MyScript, potentially from background.
  /// The implementation must be thread-safe (offscreenRenderSurfaces handles this).
  func createOffscreenRenderSurface(width: Int32, height: Int32, alphaMask: Bool) -> UInt32

  /// Releases an offscreen render surface.
  ///
  /// # Parameters
  /// - surfaceId: The ID returned by createOffscreenRenderSurface()
  ///
  /// # Behavior
  /// Calls offscreenRenderSurfaces.releaseSurface(forId: surfaceId)
  /// This removes the surface from cache and frees its memory.
  ///
  /// # When Called
  /// MyScript calls this when:
  /// - Content scrolls off screen
  /// - Memory pressure requires freeing caches
  /// - The part is being closed
  ///
  /// # Invalid IDs
  /// If surfaceId doesn't exist, this is a safe no-op.
  ///
  /// # Thread Safety
  /// Called by MyScript, potentially from background.
  /// offscreenRenderSurfaces handles synchronization.
  func releaseOffscreenRenderSurface(_ surfaceId: UInt32)

  /// Creates a Canvas for drawing into an offscreen surface.
  ///
  /// # Parameters
  /// - surfaceId: The ID of the surface to draw into
  ///
  /// # Return Value
  /// Returns an IINKICanvas configured for this surface.
  ///
  /// # Canvas Purpose
  /// A Canvas wraps a Core Graphics context and provides:
  /// - Drawing methods (draw line, fill rect, draw text)
  /// - Coordinate transformations
  /// - State management (save/restore graphics state)
  ///
  /// # Creation Process
  /// 1. Get the CGLayer for the surface ID
  /// 2. Create a Canvas object
  /// 3. Set canvas.context to the layer's context
  /// 4. Calculate the canvas size (pixel size / scale)
  /// 5. Assign offscreenRenderSurfaces and imageLoader
  /// 6. Save the graphics state (will be restored in releaseOffscreenRenderCanvas)
  /// 7. Return the canvas
  ///
  /// # Size Calculation
  /// ```
  /// pixelSize = layer.size (e.g., 800x600 pixels)
  /// scale = offscreenRenderSurfaces.scale (e.g., 2.0)
  /// canvasSize = CGSize(
  ///   width: pixelSize.width / scale,   // 800 / 2.0 = 400 points
  ///   height: pixelSize.height / scale  // 600 / 2.0 = 300 points
  /// )
  /// ```
  ///
  /// # Graphics State
  /// The graphics state is saved so MyScript can modify it (transforms, clipping, etc.)
  /// without affecting other drawing operations.
  ///
  /// # Thread Safety
  /// Called by MyScript during rendering.
  /// Core Graphics is thread-safe for different contexts.
  func createOffscreenRenderCanvas(_ surfaceId: UInt32) -> IINKICanvas

  /// Releases a Canvas after drawing is complete.
  ///
  /// # Parameters
  /// - canvas: The Canvas returned by createOffscreenRenderCanvas()
  ///
  /// # Behavior
  /// 1. Cast canvas to the concrete Canvas type
  /// 2. Restore the graphics state (saved in createOffscreenRenderCanvas)
  ///
  /// # Graphics State Restoration
  /// Restoring the state ensures:
  /// - Transforms are reset
  /// - Clipping is reset
  /// - Drawing attributes are reset
  ///
  /// This prevents state leakage between drawing operations.
  ///
  /// # When Called
  /// MyScript calls this after finishing drawing into a canvas.
  /// The canvas should not be used after release.
  ///
  /// # Thread Safety
  /// Called by MyScript during rendering.
  /// Operates on canvas-specific graphics context.
  func releaseOffscreenRenderCanvas(_ canvas: IINKICanvas)

  /// The pixel density of the target display.
  ///
  /// # Purpose
  /// MyScript uses this to:
  /// - Convert points to pixels
  /// - Determine rendering quality
  /// - Scale visual elements appropriately
  ///
  /// # Value
  /// Returns UIScreen.main.scale:
  /// - 1.0: Non-Retina displays
  /// - 2.0: Retina displays
  /// - 3.0: Super Retina displays
  ///
  /// # Type
  /// Returns Float (MyScript's numeric type).
  ///
  /// # Example
  /// If pixelDensity is 2.0:
  /// - A 10-point line renders as 20 pixels
  /// - A 100x100 point area is 200x200 pixels
  var pixelDensity: Float { get }
}

/// MyScript's layer types for rendering.
///
/// Different layers can be invalidated independently for efficiency.
enum IINKLayerTypeProtocol {
  /// The model layer contains finalized content (committed strokes).
  case model

  /// The temporary layer contains in-progress content (stroke being drawn).
  case temporary

  /// The capture layer contains recognition visualization (debugging).
  case capture

  /// All layers need invalidation.
  case all
}

/// Protocol for a Canvas that MyScript draws into.
///
/// A Canvas wraps a Core Graphics context and provides drawing methods.
protocol IINKICanvasProtocol: AnyObject {
  /// The Core Graphics context for drawing.
  var context: CGContext? { get set }

  /// The size of the canvas in points.
  var size: CGSize { get set }

  /// The offscreen render surfaces manager (for nested surfaces).
  var offscreenRenderSurfaces: OffscreenRenderSurfacesProtocol? { get set }

  /// The image loader for loading referenced images.
  var imageLoader: ImageLoader? { get set }
}

// MARK: - Rendering Flow

/// # Full Rendering Flow
///
/// When the user draws a stroke, the rendering flow is:
///
/// 1. User touches screen → InputView captures touch
/// 2. InputView passes touch to IINKEditor
/// 3. IINKEditor updates its model (adds stroke)
/// 4. IINKEditor calls IINKRenderer to render changes
/// 5. IINKRenderer determines what changed and calls invalidate() on DisplayViewModel
/// 6. DisplayViewModel dispatches to main queue and calls renderView.setNeedsDisplay()
/// 7. On next frame, UIKit calls renderView.draw(_:)
/// 8. RenderView creates a CGContext for the view
/// 9. RenderView creates a Canvas wrapping that context
/// 10. RenderView calls renderer.draw() with the canvas
/// 11. IINKRenderer issues drawing commands (draw stroke at X, fill rect, etc.)
/// 12. Canvas translates those commands into Core Graphics calls
/// 13. Core Graphics renders to the view's backing buffer
/// 14. UIKit composites the buffer to the screen
/// 15. User sees the stroke
///
/// # Offscreen Rendering Flow
///
/// For content not currently visible:
///
/// 1. IINKRenderer determines it needs to cache off-screen content
/// 2. Calls createOffscreenRenderSurface(width: 800, height: 600)
/// 3. DisplayViewModel creates a CGLayer and returns ID 42
/// 4. IINKRenderer calls createOffscreenRenderCanvas(42)
/// 5. DisplayViewModel creates a Canvas for surface 42
/// 6. IINKRenderer draws into the canvas
/// 7. DisplayViewModel calls releaseOffscreenRenderCanvas()
/// 8. Surface 42 now contains cached rendered content
/// 9. When user scrolls, IINKRenderer reuses surface 42 (no re-rendering)
/// 10. When content is far off screen, IINKRenderer calls releaseOffscreenRenderSurface(42)
/// 11. DisplayViewModel frees the memory

// MARK: - Performance Considerations

/// # Rendering Performance
///
/// Rendering is the most performance-critical part of the app.
/// Poor rendering performance causes:
/// - Laggy drawing (strokes appear behind finger)
/// - Choppy scrolling
/// - Unresponsive UI
///
/// # Optimization Strategies
///
/// ## 1. Offscreen Caching
/// Offscreen surfaces cache rendered content.
/// When scrolling, pre-rendered content is composited, not re-rendered.
///
/// ## 2. Full Redraw vs Partial
/// Currently, the app always does full redraws.
/// Partial invalidation (setNeedsDisplay(_:)) was tried but caused artifacts.
///
/// For small views (< 1000x1000 points), full redraw is fast enough.
/// For larger canvases, revisit partial invalidation.
///
/// ## 3. Scale Factor
/// Higher scale factors (3.0) require more pixels to be rendered.
/// On memory-constrained devices, could reduce scale to 2.0.
///
/// ## 4. Layer Granularity
/// MyScript invalidates layers separately (model, temporary, capture).
/// The app could optimize by only redrawing changed layers.
///
/// Currently, all layers are redrawn on any invalidation.
/// This is simpler and fast enough for typical use.
///
/// ## 5. Async Rendering
/// Core Graphics rendering is synchronous (blocks the main thread).
/// For very large documents, could explore async rendering:
/// - Render to offscreen context on background thread
/// - Composite to view on main thread
///
/// This requires careful synchronization with MyScript's state.
///
/// # Profiling
/// Use Instruments to measure rendering performance:
/// - Time Profiler: Which methods take time?
/// - Core Animation: Are frames being dropped?
/// - Allocations: Is memory growing unbounded?
///
/// Target: 60 FPS (16ms per frame) during drawing and scrolling.
