// Extends IINKEditor to conform to EditorExportProtocol for JIIX persistence.
// This allows the JIIX persistence service to export content without directly
// coupling to the MyScript SDK types.

import Foundation

// MARK: - IINKEditor EditorExportProtocol Conformance

extension IINKEditor: EditorExportProtocol {

  // Exports the entire active part as a JIIX string.
  // Returns the JIIX JSON string representing the current editor content.
  // Throws if no part is loaded or export fails.
  func exportJIIX() throws -> String {
    guard self.part != nil else {
      throw JIIXPersistenceError.noPartLoaded
    }

    // Export the entire part by passing nil as the selection parameter.
    // This exports all content in the active part as JIIX format.
    let jiix = try self.export(selection: nil, mimeType: .JIIX)
    return jiix
  }
}
