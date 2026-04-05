//
// NoteViewModel.swift
// PaperClip
//
// State management for a single note canvas.
// Handles drawing state, auto-save, and clipboard send.
//

import PencilKit
import SwiftUI

// MARK: - NoteViewModel

// Observable state for the note canvas.
@MainActor @Observable
final class NoteViewModel {
  // Current PencilKit drawing.
  var drawing = PKDrawing()

  // Current note data (nil if no note loaded).
  var noteData: NoteData?

  // Whether a send operation just succeeded (drives toast visibility).
  var showSentToast = false

  // Message displayed in the send toast (nil falls back to "Sent").
  var sentToastMessage: String?

  // Error message for display.
  var errorMessage: String?

  // Reference to persistence service.
  private var noteService: NoteService?

  // Auto-save debounce task.
  private var saveTask: Task<Void, Never>?

  init() {}

  // MARK: - Note Lifecycle

  // Loads a note from saved data.
  func loadNote(_ data: NoteData, service: NoteService) {
    noteService = service
    noteData = data

    // Deserialize drawing from saved data.
    if !data.drawingData.isEmpty,
       let restored = try? PKDrawing(data: data.drawingData) {
      drawing = restored
    } else {
      drawing = PKDrawing()
    }
  }

  // Creates a fresh empty note.
  func loadEmpty(service: NoteService) {
    noteService = service
    noteData = nil
    drawing = PKDrawing()
  }

  // Called when the drawing changes (from the canvas delegate).
  func drawingDidChange() {
    scheduleSave()
  }

  // Clears the canvas.
  func clearCanvas() {
    drawing = PKDrawing()
    scheduleSave()
  }

  // MARK: - Auto-save

  // Debounced save: waits 2 seconds after last change.
  private func scheduleSave() {
    saveTask?.cancel()
    saveTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(2))
      guard !Task.isCancelled else { return }
      self?.saveNow()
    }
  }

  // Saves the current drawing to disk immediately.
  func saveNow() {
    guard var note = noteData, let service = noteService else { return }

    // Sync title from service in case the note was renamed since it was loaded.
    // Without this, auto-save would overwrite a rename with the stale title.
    if let current = service.notes.first(where: { $0.id == note.metadata.id }) {
      note.metadata.title = current.title
    }

    // Serialize drawing.
    note.drawingData = drawing.dataRepresentation()
    note.metadata.updatedAt = Date()

    // Generate thumbnail with white background so it renders correctly
    // regardless of the host app's compositing surface.
    if !drawing.strokes.isEmpty {
      let bounds = drawing.bounds
      let rawImage = drawing.image(from: bounds, scale: 1.0)
      let size = CGSize(width: bounds.width, height: bounds.height)
      let renderer = UIGraphicsImageRenderer(size: size)
      let thumbnail = renderer.image { context in
        UIColor.white.setFill()
        context.fill(CGRect(origin: .zero, size: size))
        rawImage.draw(in: CGRect(origin: .zero, size: size))
      }
      note.thumbnailData = thumbnail.pngData()
    } else {
      note.thumbnailData = nil
    }

    noteData = note
    service.saveNote(note)
  }
}
