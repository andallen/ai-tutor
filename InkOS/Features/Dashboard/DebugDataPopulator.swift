import Foundation

// Prefix used to identify debug-created items.
// Items with this prefix in their display name can be selectively deleted.
private let debugPrefix = "[DEBUG] "

// Service for populating the dashboard with test data for debugging.
// Creates notebooks with JIIX content and folders to test search functionality.
// All debug items are prefixed with "[DEBUG]" for easy identification and cleanup.
actor DebugDataPopulator {

  // BundleManager for creating notebooks and folders.
  private let bundleManager: BundleManager

  // Initializes the populator with a BundleManager instance.
  init(bundleManager: BundleManager = .shared) {
    self.bundleManager = bundleManager
  }

  // Creates a full set of test data including notebooks and folders.
  // Returns the count of items created.
  @discardableResult
  func populateTestData() async throws -> Int {
    var itemCount = 0

    // Create standalone notebooks with JIIX content.
    let standaloneNotebooks = try await createStandaloneNotebooks()
    itemCount += standaloneNotebooks.count

    // Create folders with notebooks inside.
    let folderItemCounts = try await createFoldersWithNotebooks()
    itemCount += folderItemCounts

    print("[DebugDataPopulator] Created \(itemCount) debug items")
    return itemCount
  }

  // Clears all debug-created items from the dashboard.
  // Only removes items whose displayName starts with "[DEBUG]".
  // Returns the count of items deleted.
  @discardableResult
  func clearDebugData() async throws -> Int {
    var deletedCount = 0

    // List all notebooks and delete debug ones.
    let notebooks = try await bundleManager.listBundles()
    for notebook in notebooks where notebook.displayName.hasPrefix(debugPrefix) {
      try await bundleManager.deleteBundle(notebookID: notebook.id)
      deletedCount += 1
      print("[DebugDataPopulator] Deleted debug notebook: \(notebook.displayName)")
    }

    // List all folders and delete debug ones.
    // Deleting a folder also deletes all notebooks inside it.
    let folders = try await bundleManager.listFolders()
    for folder in folders where folder.displayName.hasPrefix(debugPrefix) {
      // Count notebooks inside before deleting.
      let notebooksInFolder = try await bundleManager.listBundlesInFolder(folderID: folder.id)
      deletedCount += notebooksInFolder.count
      try await bundleManager.deleteFolder(folderID: folder.id)
      deletedCount += 1
      print("[DebugDataPopulator] Deleted debug folder: \(folder.displayName) with \(notebooksInFolder.count) notebooks")
    }

    print("[DebugDataPopulator] Cleared \(deletedCount) debug items")
    return deletedCount
  }

  // MARK: - Private Helpers

  // Creates standalone notebooks with various JIIX content for testing.
  private func createStandaloneNotebooks() async throws -> [NotebookMetadata] {
    var created: [NotebookMetadata] = []

    // Notebook 1: Meeting notes with handwritten text.
    let meetingNotes = try await createNotebookWithJIIX(
      displayName: "\(debugPrefix)Meeting Notes - Q4 Budget",
      jiixContent: createMeetingNotesJIIX()
    )
    created.append(meetingNotes)

    // Notebook 2: Math equations.
    let mathNotes = try await createNotebookWithJIIX(
      displayName: "\(debugPrefix)Calculus Practice",
      jiixContent: createMathNotesJIIX()
    )
    created.append(mathNotes)

    // Notebook 3: Recipe notes.
    let recipeNotes = try await createNotebookWithJIIX(
      displayName: "\(debugPrefix)Grandma's Recipes",
      jiixContent: createRecipeNotesJIIX()
    )
    created.append(recipeNotes)

    // Notebook 4: Shopping list.
    let shoppingList = try await createNotebookWithJIIX(
      displayName: "\(debugPrefix)Weekly Shopping List",
      jiixContent: createShoppingListJIIX()
    )
    created.append(shoppingList)

    // Notebook 5: Empty notebook (no JIIX).
    let emptyNotebook = try await bundleManager.createBundle(
      displayName: "\(debugPrefix)Empty Notebook"
    )
    created.append(emptyNotebook)

    return created
  }

  // Creates folders with notebooks inside for testing folder search.
  private func createFoldersWithNotebooks() async throws -> Int {
    var itemCount = 0

    // Folder 1: Work folder with project notes.
    let workFolder = try await bundleManager.createFolder(
      displayName: "\(debugPrefix)Work Projects"
    )
    itemCount += 1

    let projectAlpha = try await createNotebookWithJIIX(
      displayName: "\(debugPrefix)Project Alpha Notes",
      jiixContent: createProjectNotesJIIX(projectName: "Alpha")
    )
    try await bundleManager.moveNotebookToFolder(notebookID: projectAlpha.id, folderID: workFolder.id)
    itemCount += 1

    let projectBeta = try await createNotebookWithJIIX(
      displayName: "\(debugPrefix)Project Beta Planning",
      jiixContent: createProjectNotesJIIX(projectName: "Beta")
    )
    try await bundleManager.moveNotebookToFolder(notebookID: projectBeta.id, folderID: workFolder.id)
    itemCount += 1

    // Folder 2: Study folder with course notes.
    let studyFolder = try await bundleManager.createFolder(
      displayName: "\(debugPrefix)Study Materials"
    )
    itemCount += 1

    let physicsNotes = try await createNotebookWithJIIX(
      displayName: "\(debugPrefix)Physics 101",
      jiixContent: createPhysicsNotesJIIX()
    )
    try await bundleManager.moveNotebookToFolder(notebookID: physicsNotes.id, folderID: studyFolder.id)
    itemCount += 1

    let historyNotes = try await createNotebookWithJIIX(
      displayName: "\(debugPrefix)World History Notes",
      jiixContent: createHistoryNotesJIIX()
    )
    try await bundleManager.moveNotebookToFolder(notebookID: historyNotes.id, folderID: studyFolder.id)
    itemCount += 1

    // Folder 3: Personal folder.
    let personalFolder = try await bundleManager.createFolder(
      displayName: "\(debugPrefix)Personal"
    )
    itemCount += 1

    let journalEntry = try await createNotebookWithJIIX(
      displayName: "\(debugPrefix)Journal Entry",
      jiixContent: createJournalJIIX()
    )
    try await bundleManager.moveNotebookToFolder(notebookID: journalEntry.id, folderID: personalFolder.id)
    itemCount += 1

    return itemCount
  }

  // Creates a notebook and writes JIIX content to it.
  private func createNotebookWithJIIX(
    displayName: String,
    jiixContent: String
  ) async throws -> NotebookMetadata {
    // Create the notebook.
    let metadata = try await bundleManager.createBundle(displayName: displayName)

    // Write JIIX content to the notebook bundle.
    let bundlesDirectory = try await BundleStorage.bundlesDirectory()
    let jiixURL = bundlesDirectory
      .appendingPathComponent(metadata.id, isDirectory: true)
      .appendingPathComponent("content.jiix")

    guard let jiixData = jiixContent.data(using: .utf8) else {
      throw DebugDataError.jiixEncodingFailed
    }

    try jiixData.write(to: jiixURL, options: [.atomic])
    print("[DebugDataPopulator] Created notebook with JIIX: \(displayName)")

    return metadata
  }

  // MARK: - JIIX Content Generators

  // Creates JIIX for meeting notes with multiple text blocks.
  private func createMeetingNotesJIIX() -> String {
    return """
    {
      "type": "Raw Content",
      "version": "3",
      "id": "MainBlock",
      "bounding-box": {"x": 0, "y": 0, "width": 1000, "height": 800},
      "elements": [
        {
          "type": "Text",
          "id": "text-1",
          "label": "Q4 Budget Meeting - October 15th",
          "bounding-box": {"x": 50, "y": 50, "width": 400, "height": 30}
        },
        {
          "type": "Text",
          "id": "text-2",
          "label": "Attendees: Sarah, Mike, Jennifer, Tom",
          "bounding-box": {"x": 50, "y": 100, "width": 350, "height": 25}
        },
        {
          "type": "Text",
          "id": "text-3",
          "label": "Marketing budget increased by 15%",
          "bounding-box": {"x": 50, "y": 150, "width": 300, "height": 25}
        },
        {
          "type": "Text",
          "id": "text-4",
          "label": "Engineering headcount: 5 new hires approved",
          "bounding-box": {"x": 50, "y": 200, "width": 350, "height": 25}
        },
        {
          "type": "Text",
          "id": "text-5",
          "label": "Action items: Review vendor contracts by Friday",
          "bounding-box": {"x": 50, "y": 250, "width": 400, "height": 25}
        }
      ]
    }
    """
  }

  // Creates JIIX for math notes with equations.
  private func createMathNotesJIIX() -> String {
    return """
    {
      "type": "Raw Content",
      "version": "3",
      "id": "MainBlock",
      "bounding-box": {"x": 0, "y": 0, "width": 1000, "height": 800},
      "elements": [
        {
          "type": "Text",
          "id": "text-1",
          "label": "Calculus Chapter 5: Integration",
          "bounding-box": {"x": 50, "y": 50, "width": 300, "height": 30}
        },
        {
          "type": "Math",
          "id": "math-1",
          "label": "\\\\int x^2 dx = \\\\frac{x^3}{3} + C",
          "bounding-box": {"x": 50, "y": 100, "width": 250, "height": 50}
        },
        {
          "type": "Text",
          "id": "text-2",
          "label": "Remember: power rule for integration",
          "bounding-box": {"x": 50, "y": 170, "width": 300, "height": 25}
        },
        {
          "type": "Math",
          "id": "math-2",
          "label": "\\\\int e^x dx = e^x + C",
          "bounding-box": {"x": 50, "y": 220, "width": 200, "height": 50}
        },
        {
          "type": "Text",
          "id": "text-3",
          "label": "Practice problems: pages 142-145",
          "bounding-box": {"x": 50, "y": 290, "width": 280, "height": 25}
        }
      ]
    }
    """
  }

  // Creates JIIX for recipe notes.
  private func createRecipeNotesJIIX() -> String {
    return """
    {
      "type": "Raw Content",
      "version": "3",
      "id": "MainBlock",
      "bounding-box": {"x": 0, "y": 0, "width": 1000, "height": 800},
      "elements": [
        {
          "type": "Text",
          "id": "text-1",
          "label": "Chocolate Chip Cookies",
          "bounding-box": {"x": 50, "y": 50, "width": 250, "height": 30}
        },
        {
          "type": "Text",
          "id": "text-2",
          "label": "Ingredients: 2 cups flour, 1 cup sugar, butter",
          "bounding-box": {"x": 50, "y": 100, "width": 400, "height": 25}
        },
        {
          "type": "Text",
          "id": "text-3",
          "label": "1 tsp vanilla extract, chocolate chips",
          "bounding-box": {"x": 50, "y": 140, "width": 350, "height": 25}
        },
        {
          "type": "Text",
          "id": "text-4",
          "label": "Bake at 375 degrees for 12 minutes",
          "bounding-box": {"x": 50, "y": 200, "width": 300, "height": 25}
        },
        {
          "type": "Text",
          "id": "text-5",
          "label": "Secret ingredient: pinch of sea salt",
          "bounding-box": {"x": 50, "y": 250, "width": 320, "height": 25}
        }
      ]
    }
    """
  }

  // Creates JIIX for shopping list.
  private func createShoppingListJIIX() -> String {
    return """
    {
      "type": "Raw Content",
      "version": "3",
      "id": "MainBlock",
      "bounding-box": {"x": 0, "y": 0, "width": 1000, "height": 800},
      "elements": [
        {
          "type": "Text",
          "id": "text-1",
          "label": "Grocery Shopping - Sunday",
          "bounding-box": {"x": 50, "y": 50, "width": 250, "height": 30}
        },
        {
          "type": "Text",
          "id": "text-2",
          "label": "Milk, eggs, bread, cheese",
          "bounding-box": {"x": 50, "y": 100, "width": 250, "height": 25}
        },
        {
          "type": "Text",
          "id": "text-3",
          "label": "Apples, bananas, oranges",
          "bounding-box": {"x": 50, "y": 140, "width": 220, "height": 25}
        },
        {
          "type": "Text",
          "id": "text-4",
          "label": "Chicken breast, ground beef",
          "bounding-box": {"x": 50, "y": 180, "width": 250, "height": 25}
        },
        {
          "type": "Text",
          "id": "text-5",
          "label": "Olive oil, pasta, tomato sauce",
          "bounding-box": {"x": 50, "y": 220, "width": 280, "height": 25}
        }
      ]
    }
    """
  }

  // Creates JIIX for project notes.
  private func createProjectNotesJIIX(projectName: String) -> String {
    return """
    {
      "type": "Raw Content",
      "version": "3",
      "id": "MainBlock",
      "bounding-box": {"x": 0, "y": 0, "width": 1000, "height": 800},
      "elements": [
        {
          "type": "Text",
          "id": "text-1",
          "label": "Project \(projectName) - Sprint Planning",
          "bounding-box": {"x": 50, "y": 50, "width": 300, "height": 30}
        },
        {
          "type": "Text",
          "id": "text-2",
          "label": "Sprint Goal: Complete user authentication module",
          "bounding-box": {"x": 50, "y": 100, "width": 400, "height": 25}
        },
        {
          "type": "Text",
          "id": "text-3",
          "label": "Tasks: Login page, registration flow, password reset",
          "bounding-box": {"x": 50, "y": 150, "width": 450, "height": 25}
        },
        {
          "type": "Text",
          "id": "text-4",
          "label": "Dependencies: Backend API must be ready by Wednesday",
          "bounding-box": {"x": 50, "y": 200, "width": 450, "height": 25}
        },
        {
          "type": "Text",
          "id": "text-5",
          "label": "Risk: Third-party OAuth integration may delay timeline",
          "bounding-box": {"x": 50, "y": 250, "width": 450, "height": 25}
        }
      ]
    }
    """
  }

  // Creates JIIX for physics notes.
  private func createPhysicsNotesJIIX() -> String {
    return """
    {
      "type": "Raw Content",
      "version": "3",
      "id": "MainBlock",
      "bounding-box": {"x": 0, "y": 0, "width": 1000, "height": 800},
      "elements": [
        {
          "type": "Text",
          "id": "text-1",
          "label": "Newton's Laws of Motion",
          "bounding-box": {"x": 50, "y": 50, "width": 280, "height": 30}
        },
        {
          "type": "Text",
          "id": "text-2",
          "label": "First Law: An object at rest stays at rest",
          "bounding-box": {"x": 50, "y": 100, "width": 350, "height": 25}
        },
        {
          "type": "Math",
          "id": "math-1",
          "label": "F = ma",
          "bounding-box": {"x": 50, "y": 150, "width": 100, "height": 40}
        },
        {
          "type": "Text",
          "id": "text-3",
          "label": "Second Law: Force equals mass times acceleration",
          "bounding-box": {"x": 50, "y": 210, "width": 400, "height": 25}
        },
        {
          "type": "Text",
          "id": "text-4",
          "label": "Third Law: Every action has an equal and opposite reaction",
          "bounding-box": {"x": 50, "y": 260, "width": 480, "height": 25}
        }
      ]
    }
    """
  }

  // Creates JIIX for history notes.
  private func createHistoryNotesJIIX() -> String {
    return """
    {
      "type": "Raw Content",
      "version": "3",
      "id": "MainBlock",
      "bounding-box": {"x": 0, "y": 0, "width": 1000, "height": 800},
      "elements": [
        {
          "type": "Text",
          "id": "text-1",
          "label": "World War II Timeline",
          "bounding-box": {"x": 50, "y": 50, "width": 250, "height": 30}
        },
        {
          "type": "Text",
          "id": "text-2",
          "label": "1939: Germany invades Poland",
          "bounding-box": {"x": 50, "y": 100, "width": 280, "height": 25}
        },
        {
          "type": "Text",
          "id": "text-3",
          "label": "1941: Pearl Harbor attack, US enters war",
          "bounding-box": {"x": 50, "y": 140, "width": 350, "height": 25}
        },
        {
          "type": "Text",
          "id": "text-4",
          "label": "1944: D-Day invasion of Normandy",
          "bounding-box": {"x": 50, "y": 180, "width": 300, "height": 25}
        },
        {
          "type": "Text",
          "id": "text-5",
          "label": "1945: War ends with surrender of Japan",
          "bounding-box": {"x": 50, "y": 220, "width": 350, "height": 25}
        }
      ]
    }
    """
  }

  // Creates JIIX for journal entry.
  private func createJournalJIIX() -> String {
    return """
    {
      "type": "Raw Content",
      "version": "3",
      "id": "MainBlock",
      "bounding-box": {"x": 0, "y": 0, "width": 1000, "height": 800},
      "elements": [
        {
          "type": "Text",
          "id": "text-1",
          "label": "January 8, 2026 - Today's Thoughts",
          "bounding-box": {"x": 50, "y": 50, "width": 320, "height": 30}
        },
        {
          "type": "Text",
          "id": "text-2",
          "label": "Feeling grateful for the sunny weather today",
          "bounding-box": {"x": 50, "y": 100, "width": 380, "height": 25}
        },
        {
          "type": "Text",
          "id": "text-3",
          "label": "Had a productive meeting with the team",
          "bounding-box": {"x": 50, "y": 140, "width": 340, "height": 25}
        },
        {
          "type": "Text",
          "id": "text-4",
          "label": "Goals for tomorrow: finish the report, exercise",
          "bounding-box": {"x": 50, "y": 200, "width": 400, "height": 25}
        },
        {
          "type": "Text",
          "id": "text-5",
          "label": "Remember to call Mom for her birthday",
          "bounding-box": {"x": 50, "y": 250, "width": 350, "height": 25}
        }
      ]
    }
    """
  }
}

// Errors for debug data population.
enum DebugDataError: LocalizedError {
  case jiixEncodingFailed

  var errorDescription: String? {
    switch self {
    case .jiixEncodingFailed:
      return "Failed to encode JIIX content to UTF-8"
    }
  }
}
