import Foundation
import UIKit
import Combine

/// Protocol defining the contract for EditorViewModel.
///
/// EditorViewModel is the business logic layer for the editor screen. It manages:
/// - Notebook loading and initialization
/// - Tool selection (pen, eraser, highlighter)
/// - Ink color and thickness configuration
/// - Edit operations (undo, redo, clear)
/// - Auto-save and manual save coordination
/// - Viewport restoration when opening notebooks
/// - Preview image capture when closing
///
/// # MainActor Requirement
/// EditorViewModel must be annotated with @MainActor because:
/// - It interacts with MyScript IINKEditor and IINKRenderer (not thread-safe)
/// - It publishes UI state via @Published properties
/// - It manages UIKit view controllers (InputViewController)
///
/// All methods run on the main thread and can safely access UI and MyScript objects.
///
/// # Architecture
/// EditorViewModel sits between:
/// - UI Layer (EditorViewController, SwiftUI views)
/// - Storage Layer (DocumentHandle actor)
/// - MyScript Layer (IINKEditor, EngineProvider)
///
/// It translates user actions into MyScript operations and storage updates.
@MainActor
protocol EditorViewModelProtocol: AnyObject {

  // MARK: - Published Properties

  /// The input view controller that manages touch input and rendering.
  ///
  /// This is created during setupModel() and published so SwiftUI can embed it.
  /// Changes trigger UI updates via Combine.
  var editorViewController: InputViewController? { get set }

  /// The title shown in the editor navigation bar.
  ///
  /// Set to the notebook's displayName when loading.
  /// Updates if the notebook is renamed externally.
  var title: String? { get set }

  /// Alert controller to present to the user.
  ///
  /// When non-nil, the UI layer should present this alert.
  /// After presenting, the UI should set this back to nil.
  ///
  /// Used for:
  /// - Error messages (save failures, part loading errors)
  /// - Warnings (unsupported operations)
  var alert: UIAlertController? { get set }

  // MARK: - Properties

  /// The MyScript editor instance that manages ink rendering and recognition.
  ///
  /// Set by the EditorDelegate callback when the editor is created.
  /// Used to:
  /// - Load notebook parts
  /// - Apply tool selections
  /// - Perform edit operations (undo, redo, clear)
  /// - Capture viewport state
  var editor: IINKEditor? { get set }

  // MARK: - Setup

  /// Sets up the view model with an engine provider and document handle.
  ///
  /// This method initializes the editor components:
  /// 1. Creates an InputViewModel with the engine and input mode
  /// 2. Creates an InputViewController wrapping the InputViewModel
  /// 3. Sets the title from the manifest displayName
  /// 4. Stores the document handle reference
  /// 5. Begins loading the notebook part
  ///
  /// # Parameters
  /// - engineProvider: Provides access to the MyScript engine singleton
  /// - documentHandle: The opened notebook to display
  ///
  /// # Input Mode
  /// Currently configured as .forcePen, which treats touch as pen input.
  /// For Apple Pencil devices, consider .auto to distinguish touch from pencil.
  ///
  /// # Asynchronous Loading
  /// Part loading begins asynchronously but is not awaited.
  /// The editor will become available when loading completes.
  ///
  /// # When to Call
  /// Call this once when presenting the editor screen, before showing the UI.
  func setupModel(engineProvider: EngineProvider, documentHandle: DocumentHandle)

  /// Sets the editor view's frame bounds.
  ///
  /// # Parameters
  /// - bounds: The CGRect defining the editor's position and size
  ///
  /// # Purpose
  /// Updates the InputViewController's view frame to match the container.
  /// Call this when:
  /// - The editor is first laid out
  /// - The view size changes (rotation, split screen, etc.)
  ///
  /// # Thread Safety
  /// Must be called on MainActor since it modifies UIView properties.
  func setEditorViewSize(bounds: CGRect)

  // MARK: - Tool Selection

  /// Applies the requested tool selection to the editor.
  ///
  /// # Parameters
  /// - selection: The tool the user wants to use
  ///
  /// # Behavior
  /// Dispatches to the appropriate tool method:
  /// - .pen → selectPenTool()
  /// - .eraser → selectEraserTool()
  /// - .highlighter → selectHighlighterTool()
  ///
  /// # Use Cases
  /// Called when the user taps a tool button in the ToolPaletteView.
  func selectTool(_ selection: ToolPaletteView.ToolSelection)

  /// Switches the editor to pen mode.
  ///
  /// # Behavior
  /// Calls editorViewController?.selectPenTool(), which:
  /// - Sets the active tool to IINKPointerTool.toolPen
  /// - Applies the currently selected pen color and width
  /// - Updates touch input handling (if in forcePen mode, touch draws with pen)
  ///
  /// # State Preservation
  /// The pen's color and width are preserved when switching away and back.
  /// Example: User draws in black → Switches to eraser → Switches back to pen → Still black
  func selectPenTool()

  /// Switches the editor to eraser mode.
  ///
  /// # Behavior
  /// Calls editorViewController?.selectEraserTool(), which:
  /// - Sets the active tool to IINKPointerTool.eraser
  /// - Applies the currently configured eraser radius
  /// - Updates touch input handling (if in forcePen mode, touch erases)
  ///
  /// # Eraser Configuration
  /// The eraser radius is configured in the MyScript configuration for each part type:
  /// - raw-content.eraser.radius
  /// - text.eraser.radius
  /// - math.eraser.radius
  /// - diagram.eraser.radius
  /// - text-document.eraser.radius
  func selectEraserTool()

  /// Switches the editor to highlighter mode.
  ///
  /// # Behavior
  /// Calls editorViewController?.selectHighlighterTool(), which:
  /// - Sets the active tool to IINKPointerTool.toolHighlighter
  /// - Applies the currently selected highlighter color and width
  /// - Updates touch input handling (if in forcePen mode, touch highlights)
  ///
  /// # Highlighter Appearance
  /// Highlighters render as semi-transparent colored strokes that appear behind text.
  /// The transparency is controlled by the color's alpha channel or MyScript's rendering.
  func selectHighlighterTool()

  /// Updates the input mode for touch handling.
  ///
  /// # Parameters
  /// - newInputMode: The input mode to apply
  ///
  /// # Input Modes
  /// - .forcePen: Touch and pencil both draw (good for devices without Apple Pencil)
  /// - .auto: Touch pans, pencil draws (good for devices with Apple Pencil)
  ///
  /// # Behavior
  /// 1. Stores the new input mode
  /// 2. Updates the InputViewController's input mode
  /// 3. Reapplies the current tool selection to update touch behavior
  ///
  /// # Tool Behavior by Mode
  /// In .forcePen:
  /// - Touch uses the active tool (pen, eraser, highlighter)
  /// - Pencil uses the active tool
  ///
  /// In .auto:
  /// - Touch uses hand tool (pan/scroll)
  /// - Pencil uses the active tool
  func updateInputMode(newInputMode: InputMode)

  /// Updates the active tool to match the palette selection.
  ///
  /// # Parameters
  /// - selection: The tool to activate
  ///
  /// # Behavior
  /// 1. Stores the selection for later (if editor not ready yet)
  /// 2. If editor exists, immediately applies the tool
  /// 3. Updates both pen and touch pointer types (depending on input mode)
  ///
  /// # Deferred Application
  /// If called before the editor is created, the tool selection is stored and
  /// applied later when the editor becomes available (in didCreateEditor callback).
  func updateTool(selection: ToolPaletteView.ToolSelection)

  /// Updates the color for the specified tool.
  ///
  /// # Parameters
  /// - hex: The color in hexadecimal format (e.g., "#FF5733")
  /// - tool: Which tool's color to update (.pen or .highlighter)
  ///
  /// # Behavior
  /// For .pen:
  /// - Stores the color as selectedPenColorHex
  /// - Applies the color to the pen tool's style
  ///
  /// For .highlighter:
  /// - Stores the color as selectedHighlighterColorHex
  /// - Applies the color to the highlighter tool's style
  ///
  /// For .eraser:
  /// - No-op (erasers don't have a color)
  ///
  /// # Style Application
  /// The color is applied via MyScript's tool style string:
  /// ```
  /// "color:#FF5733;-myscript-pen-width:0.65"
  /// ```
  ///
  /// # Color Persistence
  /// The color is stored and reapplied when switching back to the tool.
  /// Example: User sets pen to red → Switches to eraser → Switches back → Pen is still red
  func updateInkColor(hex: String, for tool: ToolPaletteView.ToolSelection)

  /// Updates the stroke width for the specified tool.
  ///
  /// # Parameters
  /// - width: The width in millimeters
  /// - tool: Which tool's width to update (.pen or .highlighter)
  ///
  /// # Width Units
  /// Width is in millimeters in document space (not pixels).
  /// Typical ranges:
  /// - Pen: 0.3 mm (thin) to 2.0 mm (thick)
  /// - Highlighter: 3.0 mm to 10.0 mm
  ///
  /// # Behavior
  /// For .pen:
  /// - Stores the width as selectedPenWidth
  /// - Applies the width to the pen tool's style
  ///
  /// For .highlighter:
  /// - Stores the width as selectedHighlighterWidth
  /// - Applies the width to the highlighter tool's style
  ///
  /// For .eraser:
  /// - No-op (eraser width is controlled separately via configuration)
  ///
  /// # Style Application
  /// The width is applied via MyScript's tool style string:
  /// ```
  /// "color:#000000;-myscript-pen-width:0.65"
  /// ```
  ///
  /// # Width Persistence
  /// The width is stored and reapplied when switching back to the tool.
  func updateInkWidth(width: CGFloat, for tool: ToolPaletteView.ToolSelection)

  // MARK: - Edit Operations

  /// Clears all content from the current part.
  ///
  /// # Behavior
  /// Calls editor.clear(), which:
  /// - Removes all strokes and content blocks from the current part
  /// - Clears the undo stack
  /// - Triggers a content changed event (which schedules auto-save)
  ///
  /// # Error Handling
  /// If clear() throws, presents an alert with the error message.
  /// The editor should remain in a usable state even if clear fails.
  ///
  /// # Confirmation
  /// This is a destructive operation. Callers should confirm user intent before calling.
  ///
  /// # Undo
  /// Clear is NOT undoable (it clears the undo stack).
  /// This is a MyScript SDK limitation.
  func clear()

  /// Undoes the last edit operation.
  ///
  /// # Behavior
  /// Calls editor.undo(), which:
  /// - Reverts the most recent content change
  /// - Updates the redo stack (redo becomes available)
  /// - Triggers a content changed event
  ///
  /// # Availability
  /// Undo is only available if there are operations in the undo stack.
  /// The UI should disable the undo button when editor.canUndo() is false.
  ///
  /// # Examples of Undoable Operations
  /// - Adding a stroke
  /// - Erasing content
  /// - Converting handwriting to text
  /// - Moving or resizing content
  func undo()

  /// Redoes the last undone operation.
  ///
  /// # Behavior
  /// Calls editor.redo(), which:
  /// - Re-applies the most recently undone change
  /// - Updates the undo stack (undo becomes available again)
  /// - Triggers a content changed event
  ///
  /// # Availability
  /// Redo is only available after calling undo().
  /// The UI should disable the redo button when editor.canRedo() is false.
  ///
  /// # Redo Stack Clearing
  /// The redo stack is cleared when the user makes a new edit after undo.
  /// Example: Draw → Undo → Draw → Redo is no longer available
  func redo()

  // MARK: - Lifecycle

  /// Releases the editor binding and saves the notebook.
  ///
  /// This method is called when the user exits the notebook.
  /// It performs cleanup, saves changes, and releases resources.
  ///
  /// # Parameters
  /// - previewImage: Optional snapshot of the notebook for the dashboard preview
  ///
  /// # Behavior
  /// 1. Captures the current viewport state (scroll position and zoom)
  /// 2. Cancels any pending auto-save or full-save tasks
  /// 3. Releases the editor's part binding
  /// 4. Asynchronously:
  ///    a. Saves the viewport state to the manifest
  ///    b. Saves the preview image (if provided)
  ///    c. Performs a full package save
  ///    d. Closes the DocumentHandle
  ///
  /// # Viewport State
  /// The viewport is captured before releasing the editor to preserve:
  /// - Current scroll offset (offsetX, offsetY)
  /// - Current zoom scale
  ///
  /// When the notebook is reopened, this state is restored.
  ///
  /// # Preview Image
  /// If previewImage is provided:
  /// - Converts to PNG data
  /// - Saves to preview.png in the bundle
  /// - Posts a notification so the dashboard can reload the preview
  ///
  /// # Save Errors
  /// If package save fails, presents an error alert to the user.
  /// The handle is still closed to prevent leaving the package locked.
  ///
  /// # When to Call
  /// - User taps the back button to exit the editor
  /// - App is about to terminate
  /// - User switches to a different notebook
  func releaseEditor(previewImage: UIImage?)

  /// Handles the app entering background state.
  ///
  /// # Behavior
  /// Immediately performs a full package save to ensure:
  /// - User's work is persisted to disk
  /// - If the app is terminated by the OS, no data is lost
  ///
  /// # Background Execution
  /// iOS gives apps a few seconds of background time.
  /// The save should complete quickly to avoid being suspended mid-save.
  ///
  /// # When Called
  /// This should be called from:
  /// - UIApplication.didEnterBackgroundNotification
  /// - SceneDelegate sceneDidEnterBackground()
  func handleAppBackground()

  /// Presents an error alert indicating the notebook details are missing.
  ///
  /// # Use Cases
  /// Called when:
  /// - setupModel() wasn't called before trying to use the editor
  /// - The DocumentHandle was unexpectedly nil
  /// - Internal state corruption
  ///
  /// # Alert Content
  /// Title: "Error"
  /// Message: "Notebook details are missing."
  ///
  /// This is a fatal error for the editor session.
  /// The user should exit and try reopening the notebook.
  func presentMissingNotebookError()
}

/// Delegate protocol for editor lifecycle events.
///
/// The EditorViewModel conforms to this protocol to receive callbacks from InputViewModel
/// when the editor is created or content changes occur.
protocol EditorDelegateProtocol: AnyObject {

  /// Called when the MyScript editor has been created and is ready to use.
  ///
  /// # Parameters
  /// - editor: The newly created IINKEditor instance
  ///
  /// # When Called
  /// This is called by InputViewModel after:
  /// 1. Creating the renderer
  /// 2. Creating the tool controller
  /// 3. Creating the editor with engine.createEditor()
  /// 4. Setting up font metrics and theme
  ///
  /// # EditorViewModel Behavior
  /// When EditorViewModel receives this callback, it:
  /// 1. Stores the editor reference
  /// 2. Applies the selected tool (pen, eraser, or highlighter)
  /// 3. Applies the pen color and width
  /// 4. Applies the highlighter color and width
  /// 5. Begins loading the notebook part
  ///
  /// # Thread Safety
  /// Called on MainActor (editor creation happens on main thread).
  func didCreateEditor(editor: IINKEditor)

  /// Called when the editor's active part has changed.
  ///
  /// # Parameters
  /// - editor: The IINKEditor instance
  ///
  /// # When Called
  /// This is called when editor.set(part:) is called with a different part.
  ///
  /// # EditorViewModel Behavior
  /// Currently, EditorViewModel doesn't implement any behavior for this event.
  /// In a multi-part notebook, this could be used to:
  /// - Update the UI to show the current part number
  /// - Load part-specific settings
  /// - Update the navigation
  func partChanged(editor: IINKEditor)

  /// Called when content in the editor has changed.
  ///
  /// # Parameters
  /// - editor: The IINKEditor instance
  /// - blockIds: Array of block IDs that changed
  ///
  /// # When Called
  /// This is called after any user action that modifies content:
  /// - Drawing a stroke
  /// - Erasing content
  /// - Converting handwriting to text
  /// - Undo/redo operations
  ///
  /// # EditorViewModel Behavior
  /// When content changes, EditorViewModel:
  /// 1. Sets hasPendingFullSave = true (indicates unsaved changes)
  /// 2. Schedules an auto-save (temp save in 2 seconds)
  /// 3. Schedules a full save (package save in 20 seconds)
  ///
  /// # Block IDs
  /// The blockIds parameter contains the MyScript block identifiers that changed.
  /// This can be used to:
  /// - Determine what type of content changed
  /// - Invalidate specific cache entries
  /// - Update recognition results
  ///
  /// Currently, EditorViewModel doesn't use the block IDs.
  ///
  /// # Thread Safety
  /// Called on MainActor.
  func contentChanged(editor: IINKEditor, blockIds: [String])

  /// Called when an error occurs in the editor.
  ///
  /// # Parameters
  /// - editor: The IINKEditor instance
  /// - blockId: The block ID where the error occurred (may be empty)
  /// - message: The error message from MyScript
  ///
  /// # When Called
  /// This is called when MyScript encounters an error:
  /// - Recognition failure
  /// - Invalid operation
  /// - Resource loading failure
  /// - Internal SDK error
  ///
  /// # EditorViewModel Behavior
  /// When an error occurs, EditorViewModel:
  /// - Creates an alert with title "Error" and the error message
  /// - Sets the alert property so the UI can present it
  ///
  /// # Error Recovery
  /// Most errors are non-fatal. The editor should remain usable.
  /// The user can dismiss the alert and continue working.
  ///
  /// # Thread Safety
  /// Called on MainActor.
  func onError(editor: IINKEditor, blockId: String, message: String)
}
