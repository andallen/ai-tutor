import Foundation
import UIKit
import Combine
import QuartzCore

/// Protocol defining the contract for InputViewModel.
///
/// InputViewModel manages the low-level editor infrastructure:
/// - MyScript editor creation and configuration
/// - Touch and gesture input handling (pan, pinch)
/// - Scroll physics and viewport bounds
/// - Zoom behavior and limits
/// - Inertial scrolling (momentum after finger lift)
/// - Tool switching at the MyScript SDK level
///
/// # Architecture
/// InputViewModel sits between:
/// - InputViewController (captures gesture events from UIKit)
/// - MyScript SDK (IINKEditor, IINKRenderer, IINKEngine)
/// - DisplayViewModel (manages rendering surfaces)
/// - EditorViewModel (high-level business logic)
///
/// # Complexity Rationale
/// This class is large because it manages tightly coupled concerns:
/// - Gesture state (began, changed, ended)
/// - Inertial scroll state (velocity, deceleration)
/// - Viewport bounds enforcement (zoom-dependent calculations)
/// - Editor lifecycle (creation, configuration)
///
/// Splitting these would break cohesion and require complex state sharing.
protocol InputViewModelProtocol: AnyObject {

  // MARK: - Published Properties

  /// The current input mode controlling how touch is interpreted.
  ///
  /// # Input Modes
  /// - .forcePen: Touch and pencil both draw
  /// - .auto: Touch pans, pencil draws
  ///
  /// # When Changed
  /// Updated by updateInputMode() when the user toggles the setting.
  var inputMode: InputMode { get set }

  /// The display view controller that manages rendering.
  ///
  /// Created during setupModel().
  /// Published so SwiftUI can embed the display view.
  var displayViewController: DisplayViewController? { get set }

  /// The smart guide view controller for text conversion UI.
  ///
  /// Created during setupModel() unless smart guide is disabled.
  /// Shows text suggestions when handwriting is recognized.
  var smartGuideViewController: SmartGuideViewController? { get set }

  /// The input view that captures touch and pencil events.
  ///
  /// Created during setupModel().
  /// Gesture recognizers are attached to this view.
  var neboInputView: InputView? { get set }

  // MARK: - Properties

  /// The MyScript editor instance.
  ///
  /// Created by initEditor() during setupModel().
  /// Used for all ink operations (drawing, erasing, recognition).
  var editor: IINKEditor? { get set }

  /// The original view offset when a pan gesture began.
  ///
  /// Stored in handlePanGestureRecognizerAction() when state is .began.
  /// Used to calculate the new offset during the gesture:
  /// ```
  /// newOffset = originalViewOffset - adjustedTranslation
  /// ```
  var originalViewOffset: CGPoint { get }

  // MARK: - Initialization

  /// Creates an InputViewModel with the specified configuration.
  ///
  /// # Parameters
  /// - engine: The MyScript engine instance (from EngineProvider)
  /// - inputMode: Initial input mode (.forcePen or .auto)
  /// - editorDelegate: Delegate to receive editor lifecycle events
  /// - smartGuideDelegate: Delegate to receive smart guide events (or nil)
  /// - smartGuideDisabled: If true, don't create the smart guide UI
  ///
  /// # Smart Guide
  /// The smart guide shows text suggestions when handwriting is recognized.
  /// Disable it for pure drawing notebooks where text recognition isn't needed.
  ///
  /// # Editor Delegate
  /// The delegate receives callbacks when:
  /// - Editor is created (didCreateEditor)
  /// - Content changes (contentChanged)
  /// - Errors occur (onError)
  ///
  /// Typically, EditorViewModel is the delegate.
  init(
    engine: IINKEngine?,
    inputMode: InputMode,
    editorDelegate: EditorDelegate?,
    smartGuideDelegate: SmartGuideViewControllerDelegate?,
    smartGuideDisabled: Bool
  )

  // MARK: - Setup

  /// Sets up the model with gesture recognizers.
  ///
  /// This method:
  /// 1. Creates a DisplayViewModel for rendering
  /// 2. Initializes the MyScript editor with initEditor()
  /// 3. Creates the DisplayViewController
  /// 4. Creates the SmartGuideViewController (unless disabled)
  /// 5. Creates the InputView and attaches gesture recognizers
  ///
  /// # Parameters
  /// - panGesture: UIPanGestureRecognizer for scrolling
  /// - pinchGesture: UIPinchGestureRecognizer for zooming
  ///
  /// # Gesture Handling
  /// The gesture recognizers are attached to neboInputView.
  /// Their action methods should call:
  /// - handlePanGestureRecognizerAction() for pan
  /// - handlePinchGestureRecognizerAction() for pinch
  ///
  /// # When to Call
  /// Call this once during InputViewController initialization.
  func setupModel(
    panGesture: UIPanGestureRecognizer?,
    pinchGesture: UIPinchGestureRecognizer?
  )

  /// Updates the input mode and refreshes the input view.
  ///
  /// # Parameters
  /// - newInputMode: The input mode to apply
  ///
  /// # Behavior
  /// 1. Stores the new input mode
  /// 2. Updates neboInputView.inputMode (affects touch interpretation)
  ///
  /// # Input Mode Effects
  /// In .forcePen mode:
  /// - Touch events are treated as pen input
  /// - Gestures are disabled during drawing
  ///
  /// In .auto mode:
  /// - Touch events are treated as touch (panning)
  /// - Pencil events are treated as pen input
  ///
  /// # When to Call
  /// - User toggles input mode in settings
  /// - EditorViewModel calls updateInputMode()
  func updateInputMode(newInputMode: InputMode)

  /// Configures the editor's view size and margins.
  ///
  /// # Parameters
  /// - viewSize: The size of the editor canvas in points
  ///
  /// # Behavior
  /// 1. Sets editor.viewSize to the provided size
  /// 2. Configures MyScript margins in millimeters:
  ///    - Horizontal margins: 5mm
  ///    - Vertical margins: 15mm
  ///
  /// These margins apply to:
  /// - Text content (text.margin.top/left/right)
  /// - Math content (math.margin.top/bottom/left/right)
  ///
  /// # Margins Purpose
  /// Margins prevent content from appearing right at the edge of the canvas.
  /// They provide visual breathing room and avoid clipping.
  ///
  /// # When to Call
  /// - When the editor is first created
  /// - When the view size changes (rotation, window resize)
  func configureEditorUI(with viewSize: CGSize)

  /// Initializes view constraints for the editor components.
  ///
  /// # Parameters
  /// - view: The parent view to add constraints to
  /// - containerView: The container for the editor components
  ///
  /// # Constraints
  /// Sets up Auto Layout constraints:
  /// - containerView fills the parent view
  /// - displayViewControllerView fills containerView
  /// - inputView fills containerView (layered on top of display view)
  ///
  /// # Layering
  /// The views are layered as:
  /// 1. displayViewControllerView (bottom, renders ink)
  /// 2. inputView (top, captures touch)
  ///
  /// # When to Call
  /// Call this once during view controller setup, after creating the views.
  ///
  /// # Idempotency
  /// This method only sets constraints once (tracked by didSetConstraints flag).
  /// Subsequent calls are ignored.
  func initModelViewConstraints(view: UIView, containerView: UIView)

  // MARK: - Gesture Handling

  /// Handles pan gesture for scrolling the canvas.
  ///
  /// # Parameters
  /// - translation: The cumulative translation since gesture began
  /// - velocity: The current velocity in points/second
  /// - state: The gesture state (.began, .changed, .ended, etc.)
  ///
  /// # Scrolling Behavior
  /// The canvas scrolls in response to pan gestures with custom physics:
  ///
  /// ## Drag Resistance
  /// Translation is multiplied by 0.88 to create a dragging feel:
  /// ```
  /// adjustedTranslation = translation * 0.88
  /// ```
  /// This prevents 1:1 tracking and feels more like iOS native scrolling.
  ///
  /// ## Directional Scrolling
  /// - Vertical: Always enabled
  /// - Horizontal: Only enabled when zoomed in (scale > 1.0)
  ///
  /// Rationale: At 100% zoom, the entire page width fits on screen.
  /// Horizontal scrolling only makes sense when zoomed in.
  ///
  /// ## Viewport Bounds
  /// Offsets are clamped to valid ranges:
  /// - offsetY: [0, infinity) (can scroll down as document grows)
  /// - offsetX: [0, maxXOffset] where maxXOffset depends on zoom
  ///
  /// ## Inertial Scrolling
  /// When the gesture ends (.ended state):
  /// - If velocity exceeds threshold (60 points/sec), starts deceleration
  /// - The canvas continues scrolling and gradually slows down
  /// - Velocity decays using UIScrollView.DecelerationRate.normal
  ///
  /// # State Handling
  /// - .began: Stores originalViewOffset, stops any ongoing deceleration
  /// - .changed: Calculates new offset based on translation, clamps bounds
  /// - .ended: Checks velocity, starts deceleration if above threshold
  ///
  /// # Scroll Blocking
  /// If editor.isScrollAllowed is false, the method does nothing.
  /// MyScript may disable scrolling during certain operations.
  ///
  /// # Display Refresh
  /// Posts DisplayViewController.refreshNotification to trigger redraw.
  func handlePanGestureRecognizerAction(
    with translation: CGPoint,
    velocity: CGPoint,
    state: UIGestureRecognizer.State
  )

  /// Handles pinch gesture for zooming the canvas.
  ///
  /// # Parameters
  /// - scale: The cumulative scale factor since gesture began
  /// - center: The center point of the pinch in view coordinates
  /// - state: The gesture state (.began, .changed, .ended, .cancelled)
  ///
  /// # Zoom Behavior
  ///
  /// ## Zoom Limits
  /// The zoom scale is clamped to [1.0, 4.0]:
  /// - Minimum 1.0: Default view, entire page width visible
  /// - Maximum 4.0: 400% zoom, significant magnification
  ///
  /// Values outside this range are rejected (zoom doesn't change).
  ///
  /// ## Zoom Application
  /// Zoom is applied via renderer.zoom(at:factor:):
  /// 1. Calculates the scale factor: newScale / currentScale
  /// 2. Applies the zoom centered at the pinch point
  /// 3. MyScript adjusts viewOffset to keep the center point fixed
  ///
  /// ## Viewport Bounds After Zoom
  /// After zooming, the viewport offset may be outside valid bounds.
  /// The method enforces bounds:
  /// - Calls editor.clampViewOffset() for vertical clamping
  /// - Manually clamps horizontal to [0, maxXOffset]
  /// - Clamps top edge to 0 (can't scroll above document top)
  ///
  /// ## No Momentum
  /// Unlike panning, zooming does NOT have momentum.
  /// Zoom stops immediately when fingers lift (.ended or .cancelled).
  ///
  /// Rationale: Momentum zoom would be disorienting and hard to control.
  ///
  /// # State Handling
  /// - .began: Begin tracking zoom changes
  /// - .changed: Apply zoom incrementally, enforce bounds
  /// - .ended/.cancelled: Stop zooming, no further action
  ///
  /// # Display Refresh
  /// Posts DisplayViewController.refreshNotification to trigger redraw.
  ///
  /// # Error Handling
  /// If renderer.zoom() throws, the error is silently ignored.
  /// The zoom change is skipped and the scale remains unchanged.
  func handlePinchGestureRecognizerAction(
    scale: CGFloat,
    center: CGPoint,
    state: UIGestureRecognizer.State
  )

  /// Stops any ongoing inertial scrolling.
  ///
  /// # When to Call
  /// - When the user touches down (new gesture is starting)
  /// - When switching notebooks
  /// - When programmatically scrolling to a position
  ///
  /// # Behavior
  /// If deceleration is active:
  /// - Invalidates the CADisplayLink
  /// - Clears velocity
  /// - Stops the scroll animation immediately
  ///
  /// If no deceleration is active, this is a no-op.
  ///
  /// # Thread Safety
  /// Must be called on MainActor (accesses CADisplayLink).
  func stopInertialScroll()

  // MARK: - View Size

  /// Updates the editor's view size.
  ///
  /// # Parameters
  /// - size: The new size in points
  ///
  /// # When to Call
  /// - View controller's viewDidLayoutSubviews()
  /// - Device rotation
  /// - Window resize (split screen, iPad multitasking)
  ///
  /// # Behavior
  /// Calls editor.set(viewSize:), which tells MyScript:
  /// - The canvas dimensions in points
  /// - How to scale document space to screen space
  ///
  /// # Error Handling
  /// If set(viewSize:) throws, the error is silently ignored.
  func setEditorViewSize(size: CGSize)

  // MARK: - Tool Selection

  /// Selects the pen tool for drawing.
  ///
  /// # Behavior
  /// Sets the pen pointer type to IINKPointerTool.toolPen.
  /// The pen draws with the currently configured color and width.
  ///
  /// # Error Handling
  /// If tool setting fails, the error is silently ignored.
  /// The tool selection may not change, but the app remains stable.
  func selectPenTool()

  /// Selects the eraser tool for removing ink.
  ///
  /// # Behavior
  /// Sets the pen pointer type to IINKPointerTool.eraser.
  /// The eraser uses the currently configured radius.
  ///
  /// # Error Handling
  /// If tool setting fails, the error is silently ignored.
  func selectEraserTool()

  /// Selects the highlighter tool for highlighting text.
  ///
  /// # Behavior
  /// Sets the pen pointer type to IINKPointerTool.toolHighlighter.
  /// The highlighter uses the currently configured color and width.
  ///
  /// # Rendering
  /// Highlighter strokes appear semi-transparent and behind other content.
  ///
  /// # Error Handling
  /// If tool setting fails, the error is silently ignored.
  func selectHighlighterTool()
}

/// Protocol defining the delegate for SmartGuide events.
///
/// The SmartGuide is a UI component that appears when handwriting is recognized as text.
/// It shows:
/// - Recognized text
/// - Alternative interpretations
/// - Word completion suggestions
protocol SmartGuideViewControllerDelegateProtocol: AnyObject {
  // Delegate methods would be defined here, but are not critical for testing the ViewModel
  // The actual implementation would handle:
  // - Text selection from the smart guide
  // - Word completion acceptance
  // - Smart guide dismissal
}

/// Enum representing input modes for touch and pencil.
///
/// # Input Mode Behavior
///
/// ## .forcePen
/// Both touch and Apple Pencil are treated as pen input.
/// - Good for devices without Apple Pencil support
/// - Good when users want to draw with their finger
/// - Gestures (pan, pinch) may conflict with drawing
///
/// ## .auto
/// Touch and Apple Pencil are distinguished:
/// - Touch: Hand tool (panning and scrolling)
/// - Apple Pencil: Active tool (pen, eraser, highlighter)
///
/// Good for devices with Apple Pencil where users want:
/// - Touch for navigation
/// - Pencil for precise drawing
enum InputModeProtocol {
  /// Touch and pencil both use the active tool
  case forcePen

  /// Touch uses hand tool, pencil uses active tool
  case auto
}

// MARK: - Gesture Physics Constants

/// Drag resistance factor applied to pan translation.
///
/// # Purpose
/// Creates a non-1:1 scrolling feel similar to iOS native scrolling.
///
/// # Value
/// 0.88 means the canvas moves 88% as far as the finger.
/// This prevents the content from feeling "glued" to the finger.
///
/// # Tuning
/// - Lower values (0.7-0.8): More resistance, slower scrolling
/// - Higher values (0.9-1.0): Less resistance, faster scrolling
/// - 1.0: Direct 1:1 tracking (feels unnatural)
///
/// # Historical Note
/// This value was tuned to match the feel of native iOS scroll views.
let dragResistanceProtocol: CGFloat = 0.88

/// Velocity threshold for starting inertial scrolling.
///
/// # Purpose
/// Filters out small finger movements when lifting.
/// Only meaningful velocity triggers momentum.
///
/// # Value
/// 60 points/second. If velocity is below this in both X and Y, no momentum.
///
/// # Rationale
/// Small velocities when lifting would cause brief, jarring mini-scrolls.
/// The threshold ensures momentum only kicks in for intentional flicks.
///
/// # Units
/// Points per second in UIKit coordinate space.
let velocityThresholdProtocol: CGFloat = 60

/// Minimum zoom scale factor.
///
/// # Value
/// 1.0 = 100% zoom (default view, no zoom out)
///
/// # Rationale
/// At 100% zoom, the page width fits the screen.
/// Zooming out below 100% would show empty space around the page.
///
/// # Future Enhancement
/// Could allow zoom out (<1.0) to show multiple pages side-by-side.
let minZoomScaleProtocol: Float = 1.0

/// Maximum zoom scale factor.
///
/// # Value
/// 4.0 = 400% zoom
///
/// # Rationale
/// 400% provides significant magnification for detail work without:
/// - Performance issues from rendering very large areas
/// - Extreme offsets that cause numeric precision problems
/// - Disorienting zoom levels where the user loses context
///
/// # Historical Note
/// Values above 4.0 were tested but caused:
/// - Slow rendering on older devices
/// - Confusing navigation (user gets lost)
/// - Stroke precision issues in MyScript
let maxZoomScaleProtocol: Float = 4.0

// MARK: - Inertial Scrolling

/// The inertial scrolling system uses CADisplayLink to animate momentum.
///
/// # How It Works
/// 1. User pans and lifts finger with velocity V
/// 2. If |V| > velocityThreshold, startDeceleration(V) is called
/// 3. CADisplayLink fires on every frame (60 FPS)
/// 4. applyDeceleration() is called each frame:
///    a. Calculate time delta since last frame
///    b. Decay velocity: V *= pow(decayRate, deltaTime * 1000)
///    c. Update offset: offset += V * deltaTime
///    d. If V drops below 8 points/sec, stop
/// 5. When stopped, invalidate CADisplayLink
///
/// # Decay Rate
/// Uses UIScrollView.DecelerationRate.normal.rawValue (0.998)
/// This matches iOS native scroll deceleration.
///
/// # Momentum Calculation
/// ```
/// velocity(t) = velocity(0) * pow(0.998, t_milliseconds)
/// offset(t) = offset(0) + integral(velocity(t) dt)
/// ```
///
/// # Stopping Conditions
/// Deceleration stops when:
/// - Velocity in both X and Y drops below 8 points/sec
/// - User touches down (new gesture starts)
/// - Offset hits a boundary (edge of document)
///
/// # Boundary Behavior
/// When scrolling hits a boundary:
/// - Offset is clamped to the boundary
/// - Velocity in that direction is set to 0
/// - Deceleration continues in the other direction (if any)
///
/// # Thread Safety
/// CADisplayLink fires on the main run loop (MainActor).
/// All deceleration logic runs on MainActor.

// MARK: - Maximum Horizontal Offset Calculation

/// Calculates the maximum horizontal offset based on current zoom level.
///
/// # Formula
/// ```
/// maxXOffset = pageWidth * (scale - 1)
/// ```
///
/// # Examples
/// If pageWidth = 800 points:
///
/// At scale 1.0 (100% zoom):
/// maxXOffset = 800 * (1.0 - 1.0) = 0
/// - Entire page width fits on screen
/// - No horizontal scrolling needed
///
/// At scale 2.0 (200% zoom):
/// maxXOffset = 800 * (2.0 - 1.0) = 800
/// - Page is 1600 points wide (2x)
/// - Screen shows 800 points
/// - Can scroll 800 points to the right
///
/// At scale 4.0 (400% zoom):
/// maxXOffset = 800 * (4.0 - 1.0) = 2400
/// - Page is 3200 points wide (4x)
/// - Screen shows 800 points
/// - Can scroll 2400 points to the right
///
/// # Coordinate System
/// viewOffset is in scaled view coordinates, not document coordinates.
/// The formula accounts for this by using (scale - 1) instead of just scale.
///
/// # Why Not Use Document Width?
/// MyScript's viewOffset is in view space, not document space.
/// The view space expands as zoom increases, so the offset range grows proportionally.
