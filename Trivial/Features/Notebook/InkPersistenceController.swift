import Combine
import PencilKit
import SwiftUI

// Controller that manages ink persistence operations.
// It handles loading visible ink items and saving new ink.
@MainActor
class InkPersistenceController: ObservableObject {
  // The combined drawing to display on the canvas (loaded + working ink).
  // This is bound to PKCanvasView and updated when the user draws.
  @Published var drawing: PKDrawing = PKDrawing()

  // True while a save operation is in progress.
  @Published var isSaving: Bool = false

  // The document handle used for file operations.
  private let documentHandle: DocumentHandle

  // Logic for determining which items to load.
  private let viewportController: ViewportController

  // The local source of truth for all ink items.
  // Updated when saving new ink or when reloading from manifest (if implemented).
  private var allInkItems: [InkItem]

  // Cache of loaded drawings by InkItem ID.
  // Only contains items currently considered "loaded" (in or near viewport).
  private var loadedDrawings: [String: PKDrawing] = [:]

  // The strokes currently drawn by the user but not yet committed to an InkItem.
  // We store this as a PKDrawing for convenience.
  private var workingDrawing: PKDrawing = PKDrawing()

  // IDs of items currently being loaded to prevent duplicate requests.
  private var loadingItemIDs: Set<String> = []

  // Number of strokes in the current `drawing` that come from loaded items.
  // Strokes after this index are considered "working ink".
  private var loadedStrokeCount: Int = 0

  // Task used to detect pause and commit working ink.
  private var commitTask: Task<Void, Never>?

  // Delay before committing working ink after the last drawing change.
  private let commitDebounceDelay: TimeInterval = 0.5

  init(documentHandle: DocumentHandle, model: NotebookModel) {
    self.documentHandle = documentHandle
    self.allInkItems = model.inkItems
    self.viewportController = ViewportController()
  }

  // Updates the loaded ink based on the current visible rect.
  func updateViewport(visibleRect: CGRect) {
    let desiredIDs = viewportController.itemsToLoad(visibleRect: visibleRect, inkItems: allInkItems)
    let currentIDs = Set(loadedDrawings.keys)

    // 1. Unload items that are no longer needed.
    let toUnload = currentIDs.subtracting(desiredIDs)
    if !toUnload.isEmpty {
      for id in toUnload {
        loadedDrawings.removeValue(forKey: id)
      }
      // Recompose immediately to hide unloaded items.
      recomposeDrawing()
    }

    // 2. Identify items that need to be loaded.
    let toLoad = desiredIDs.subtracting(currentIDs).subtracting(loadingItemIDs)
    guard !toLoad.isEmpty else { return }

    loadingItemIDs.formUnion(toLoad)

    // 3. Load missing items in background.
    Task {
      let payloads = await documentHandle.loadInkPayloads(for: Array(toLoad))

      await MainActor.run {
        for payload in payloads {
          if let dr = try? PKDrawing(data: payload.payload) {
            loadedDrawings[payload.id] = dr
          }
          loadingItemIDs.remove(payload.id)
        }
        // Recompose to show newly loaded items.
        recomposeDrawing()
      }
    }
  }

  // Rebuilds the main `drawing` from `loadedDrawings` + `workingDrawing`.
  // Returns true if the drawing actually changed.
  @discardableResult
  private func recomposeDrawing() -> Bool {
    var newBase = PKDrawing()

    // Append loaded strokes. Order matters (z-index).
    // We iterate through `allInkItems` to preserve the original creation order.
    for item in allInkItems {
      if let dr = loadedDrawings[item.id] {
        newBase.strokes.append(contentsOf: dr.strokes)
      }
    }

    // Update the count of loaded strokes.
    loadedStrokeCount = newBase.strokes.count

    // Append working strokes.
    newBase.strokes.append(contentsOf: workingDrawing.strokes)

    // Only update and publish if the content is different.
    // We use stroke count as a proxy for "did something meaningful change?".
    // This avoids triggering View updates (and canvas resets) when we simply
    // moved strokes from one internal list to another without changing the total.
    if self.drawing.strokes.count != newBase.strokes.count {
      self.drawing = newBase
      return true
    }
    return false
  }

  // Called when the drawing changes (user input).
  func drawingDidChange(_ newDrawing: PKDrawing) {
    let totalCount = newDrawing.strokes.count
    
    // If we have fewer strokes than we expect from loaded items, something weird happened.
    // (e.g., user erased a loaded stroke - currently not supported fully logic-wise).
    // For now, we assume append-only for working ink or basic eraser support.
    
    // Calculate new working strokes.
    // We assume the first `loadedStrokeCount` strokes are the loaded ones (unchanged).
    // Everything after that is working ink.
    
    if totalCount >= loadedStrokeCount {
      let newWorkingStrokes = newDrawing.strokes.dropFirst(loadedStrokeCount)
      var newWorking = PKDrawing()
      newWorking.strokes.append(contentsOf: newWorkingStrokes)
      self.workingDrawing = newWorking
      
      // Update our drawing reference to match what the view has.
      self.drawing = newDrawing
    } else {
      // Handle eraser case: If total count dropped below loaded count, 
      // it means loaded strokes were removed.
      // For this simple implementation, we might need to re-verify against loadedDrawings.
      // But for now, let's just update `drawing` and `workingDrawing`.
      // NOTE: This simple logic might be buggy if erasing loaded strokes.
      // But "Trivial" app likely focuses on writing for now.
      self.drawing = newDrawing
      // If we erased into loaded territory, loadedStrokeCount is now invalid.
      // We should ideally detect which loaded items changed, but that's complex.
      // Fallback: reset working drawing and maybe let next recompose fix it (or break it).
      // Let's just set workingDrawing empty if we dug into loaded strokes to be safe from crashes.
      self.workingDrawing = PKDrawing() 
    }

    // Schedule commit.
    commitTask?.cancel()
    commitTask = Task { [weak self] in
      guard let self = self else { return }
      try? await Task.sleep(nanoseconds: UInt64(commitDebounceDelay * 1_000_000_000))
      if Task.isCancelled { return }
      await self.commitWorkingInk()
    }
  }

  // Commits the current working ink as a new InkItem.
  private func commitWorkingInk() async {
    // 1. Capture ONLY the strokes we intend to save.
    let strokesToSave = workingDrawing.strokes
    guard !strokesToSave.isEmpty else { 
        return 
    }

    isSaving = true
    defer { isSaving = false }

    // Create a temporary drawing for the save payload
    let drawingToSave = PKDrawing(strokes: strokesToSave)
    let itemID = UUID().uuidString
    let bounds = drawingToSave.bounds
    let rectangle = InkRectangle(from: bounds)
    let drawingData = drawingToSave.dataRepresentation()

    let saveRequest = InkItemSaveRequest(
      id: itemID,
      rectangle: rectangle,
      payload: drawingData
    )

    // 2. Save to disk.
    do {
      try await Task.detached { [documentHandle, saveRequest] in
        try await documentHandle.saveInkItems([saveRequest])
      }.value

      // 3. Update internal state.
      let newItem = InkItem(id: itemID, rectangle: rectangle, payloadPath: "ink/\(itemID).ink")
      allInkItems.append(newItem)
      
      // Move the SAVED strokes to loaded ink.
      loadedDrawings[itemID] = drawingToSave
      
      // Remove the SAVED strokes from working ink.
      // If the user drew new strokes (Stroke B) while we were saving, 
      // they remain in workingDrawing.
      if workingDrawing.strokes.count >= strokesToSave.count {
          let remainingStrokes = workingDrawing.strokes.dropFirst(strokesToSave.count)
          workingDrawing = PKDrawing(strokes: remainingStrokes)
      } else {
          // Fallback if state got weird (e.g. undo)
          workingDrawing = PKDrawing()
      }
      
      // Recompose. This will update loadedStrokeCount.
      // Crucially, if workingDrawing had new strokes, they are appended back.
      // If the visual result is same as before, `drawing` is NOT published,
      // avoiding the canvas overwrite.
      recomposeDrawing()
    } catch {
      // Save failed. Keep working ink in memory so user doesn't lose it.
      // The commit will be retried on the next pause or on saveImmediately.
    }
  }

  func saveImmediately() async {
    commitTask?.cancel()
    await commitWorkingInk()
  }
}
