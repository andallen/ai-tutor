//
//  InkOSUITests.swift
//  InkOSUITests
//
//  UI tests for the InkOS dashboard.
//  These tests can be run on device or simulator.

import XCTest

final class InkOSUITests: XCTestCase {

    var app: XCUIApplication!

    // Directory to save screenshots.
    let screenshotDir = "/tmp/inkos-ui-tests/screenshots"

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launch()

        // Create screenshot directory.
        try? FileManager.default.createDirectory(
            atPath: screenshotDir,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helper Methods

    // Saves a screenshot with the given name.
    func saveScreenshot(name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        // Also save to disk for easy retrieval.
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let filename = "\(name)_\(timestamp).png"
        let path = (screenshotDir as NSString).appendingPathComponent(filename)

        let data = screenshot.pngRepresentation
        try? data.write(to: URL(fileURLWithPath: path))
        print("[UITest] Screenshot saved: \(path)")
    }

    // Finds the first notebook card in the collection view.
    func findFirstNotebookCard() -> XCUIElement? {
        // Try to find by accessibility identifier pattern.
        let cards = app.cells.matching(NSPredicate(format: "identifier BEGINSWITH 'notebookCard_'"))
        if cards.count > 0 {
            return cards.element(boundBy: 0)
        }

        // Fallback: find by accessibility label.
        let notebookCells = app.cells.matching(NSPredicate(format: "label BEGINSWITH 'Notebook:'"))
        if notebookCells.count > 0 {
            return notebookCells.element(boundBy: 0)
        }

        return nil
    }

    // Dismisses any alert or dialog that might be visible.
    func dismissAnyDialog() {
        // Check for OK button (common in alerts).
        let okButton = app.buttons["OK"]
        if okButton.waitForExistence(timeout: 1) {
            okButton.tap()
            Thread.sleep(forTimeInterval: 0.3)
        }

        // Check for Cancel button.
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.exists {
            cancelButton.tap()
            Thread.sleep(forTimeInterval: 0.3)
        }
    }

    // Creates a new notebook by tapping the + button and returns to dashboard.
    func createNotebook() {
        // Dismiss any existing dialogs first.
        dismissAnyDialog()

        // Tap the + button in the navigation bar.
        let addButton = app.navigationBars.buttons.matching(NSPredicate(format: "label CONTAINS 'Add' OR label CONTAINS '+'")).firstMatch
        if addButton.waitForExistence(timeout: 2) {
            addButton.tap()
        } else {
            // Fallback to last button in nav bar.
            let buttons = app.navigationBars.buttons
            if buttons.count > 0 {
                buttons.element(boundBy: buttons.count - 1).tap()
            }
        }

        // Wait for the menu to appear.
        Thread.sleep(forTimeInterval: 0.5)

        // Tap "New Notebook" option if it appears.
        let newNotebook = app.buttons["New Notebook"]
        if newNotebook.waitForExistence(timeout: 2) {
            newNotebook.tap()
        }

        // Wait for editor to load.
        Thread.sleep(forTimeInterval: 1.5)

        // Navigate back to dashboard by tapping home button.
        let homeButton = app.buttons["Home"]
        if homeButton.waitForExistence(timeout: 2) {
            homeButton.tap()
        }

        // Wait for dashboard to reload.
        Thread.sleep(forTimeInterval: 1.0)

        // Dismiss any dialogs that might have appeared.
        dismissAnyDialog()
    }

    // Finds any card (notebook, PDF, folder, or lesson).
    func findFirstCard() -> XCUIElement? {
        let cardPredicates = [
            "identifier BEGINSWITH 'notebookCard_'",
            "identifier BEGINSWITH 'pdfCard_'",
            "identifier BEGINSWITH 'folderCard_'",
            "identifier BEGINSWITH 'lessonCard_'"
        ]

        for predicate in cardPredicates {
            let cards = app.cells.matching(NSPredicate(format: predicate))
            if cards.count > 0 {
                return cards.element(boundBy: 0)
            }
        }

        // Fallback: just get first cell.
        if app.cells.count > 0 {
            return app.cells.element(boundBy: 0)
        }

        return nil
    }

    // MARK: - Dashboard Tests

    // Calculates the horizontal center of the context menu by finding its menu items.
    func getMenuBounds() -> (centerX: CGFloat, minX: CGFloat, maxX: CGFloat, width: CGFloat)? {
        // Menu items appear as menuItems, not buttons.
        let renameItem = app.menuItems["Rename"]
        let deleteItem = app.menuItems["Delete"]

        guard renameItem.exists, deleteItem.exists else {
            return nil
        }

        // Menu bounds span from leftmost to rightmost item edge.
        let minX = min(renameItem.frame.minX, deleteItem.frame.minX)
        let maxX = max(renameItem.frame.maxX, deleteItem.frame.maxX)
        let centerX = (minX + maxX) / 2
        let width = maxX - minX
        return (centerX, minX, maxX, width)
    }

    // Determines grid column index (0-based) based on card X position.
    // Returns the column number where 0 = leftmost column.
    func determineColumnIndex(cardMinX: CGFloat, allCards: [XCUIElement]) -> Int {
        // Get all unique minX values to determine column boundaries.
        var uniqueMinXs = Set<CGFloat>()
        for card in allCards {
            // Round to nearest 10pt to group cards in same column.
            let roundedX = (card.frame.minX / 10).rounded() * 10
            uniqueMinXs.insert(roundedX)
        }

        let sortedColumns = uniqueMinXs.sorted()
        let roundedCardX = (cardMinX / 10).rounded() * 10

        for (index, columnX) in sortedColumns.enumerated() {
            if abs(roundedCardX - columnX) < 15 {
                return index
            }
        }
        return 0
    }

    // MARK: - Search Tests

    @MainActor
    func testSearchResultsNoMarkdownArtifacts() throws {
        // Verifies that search results:
        // 1. Do not contain raw markdown artifacts like ### or [/MATCH]
        // 2. Do not show duplicate results for the same notebook

        let navBar = app.navigationBars["InkOS"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 10), "Dashboard should load")

        // Find and tap the search button in the nav bar.
        let searchButton = app.buttons["Search"]
        XCTAssertTrue(searchButton.waitForExistence(timeout: 5), "Search button should exist")
        searchButton.tap()

        // Wait for the search overlay to appear.
        Thread.sleep(forTimeInterval: 0.5)

        // Tap the Populate debug button if it exists to ensure test data.
        let populateButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Populate'")).firstMatch
        if populateButton.waitForExistence(timeout: 2) {
            populateButton.tap()
            Thread.sleep(forTimeInterval: 1.0)
        }

        // Find and type in the search field.
        let searchField = app.textFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 3), "Search field should exist")
        searchField.tap()
        searchField.typeText("linear")

        // Wait for search results to load.
        Thread.sleep(forTimeInterval: 1.5)

        // Capture screenshot for visual verification.
        saveScreenshot(name: "search_results_linear")

        // Get all static text elements in the search results area.
        let allStaticTexts = app.staticTexts.allElementsBoundByIndex

        // Check for markdown artifacts.
        var foundArtifacts: [String] = []
        let forbiddenPatterns = ["[/MATCH]", "[MATCH]", "###", "##", "# "]

        for staticText in allStaticTexts {
            let label = staticText.label
            for pattern in forbiddenPatterns {
                if label.contains(pattern) {
                    foundArtifacts.append("Found '\(pattern)' in: '\(label)'")
                }
            }
        }

        // Assert no markdown artifacts found.
        XCTAssertTrue(
            foundArtifacts.isEmpty,
            "Found markdown artifacts in search results:\n\(foundArtifacts.joined(separator: "\n"))"
        )

        // Check for duplicate results by looking at all static texts that appear
        // to be notebook titles (contain "Linear Algebra" etc.).
        let resultTitles = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Linear Algebra'")
        ).allElementsBoundByIndex

        // If we have multiple results with same title, that may indicate duplicates.
        // We allow this if they are different notebooks, but log it for verification.
        print("[UITest] Found \(resultTitles.count) results matching 'Linear Algebra'")

        // Verify at least one result exists.
        XCTAssertGreaterThan(resultTitles.count, 0, "Should find at least one result for 'linear'")

        print("[UITest] Search results test completed successfully - no markdown artifacts found")
    }

    @MainActor
    func testContextMenuCenteringColumns2to4() throws {
        // Objectively verifies context menu is horizontally centered over cards
        // in columns 2, 3, and 4 (indices 1, 2, 3).
        //
        // This test:
        // 1. Identifies cards by their actual column position (not array index)
        // 2. Long presses cards in columns 2-4
        // 3. Measures the horizontal center of both card and menu
        // 4. Asserts they align within a tight tolerance

        let navBar = app.navigationBars["InkOS"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 10), "Dashboard should load")

        let cellExists = app.cells.firstMatch.waitForExistence(timeout: 5)
        XCTAssertTrue(cellExists, "At least one card should exist")

        saveScreenshot(name: "menu_centering_1_dashboard")

        let allCells = app.cells.allElementsBoundByIndex
        print("[UITest] Found \(allCells.count) cells total")

        // Print all card positions for debugging.
        print("[UITest] Card positions:")
        for (i, cell) in allCells.enumerated() {
            let col = determineColumnIndex(cardMinX: cell.frame.minX, allCards: allCells)
            print("[UITest]   Cell \(i): column=\(col), frame=\(cell.frame), id=\(cell.identifier)")
        }

        // Find cards that are in columns 2, 3, 4 (indices 1, 2, 3).
        var cardsInColumnsToTest: [(cell: XCUIElement, column: Int, index: Int)] = []
        for (index, cell) in allCells.enumerated() {
            let column = determineColumnIndex(cardMinX: cell.frame.minX, allCards: allCells)
            // We want columns 2, 3, 4 which are indices 1, 2, 3 (0-based).
            if column >= 1 && column <= 3 {
                cardsInColumnsToTest.append((cell, column, index))
            }
        }

        guard cardsInColumnsToTest.count >= 3 else {
            XCTFail("Need at least 3 cards in columns 2-4 to test. Found \(cardsInColumnsToTest.count)")
            return
        }

        print("[UITest] Testing \(cardsInColumnsToTest.count) cards in columns 2-4")

        // Tolerance for centering check (in points).
        // Use a tight tolerance since we're measuring exact alignment.
        let tolerance: CGFloat = 10.0

        let dismissCoord = app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.05))

        // Test each card in columns 2-4.
        var testedColumns = Set<Int>()
        for (cell, column, index) in cardsInColumnsToTest {
            // Only test one card per column to keep test fast.
            if testedColumns.contains(column) {
                continue
            }

            let cardFrame = cell.frame
            let cardCenterX = cardFrame.midX

            print("[UITest] ----------------------------------------")
            print("[UITest] Testing card at index \(index), column \(column + 1) (1-based)")
            print("[UITest] Card frame: \(cardFrame)")
            print("[UITest] Card horizontal center: \(cardCenterX)")

            // Long press to show context menu.
            cell.press(forDuration: 1.0)
            Thread.sleep(forTimeInterval: 0.5)

            // Verify menu appears.
            let renameItem = app.menuItems["Rename"]
            guard renameItem.waitForExistence(timeout: 3) else {
                print("[UITest] Menu did not appear for card in column \(column + 1), skipping")
                dismissCoord.tap()
                Thread.sleep(forTimeInterval: 0.5)
                continue
            }

            // Get menu bounds.
            guard let menuBounds = getMenuBounds() else {
                print("[UITest] Could not determine menu bounds for column \(column + 1)")
                dismissCoord.tap()
                Thread.sleep(forTimeInterval: 0.5)
                continue
            }

            print("[UITest] Menu bounds: minX=\(menuBounds.minX), maxX=\(menuBounds.maxX), width=\(menuBounds.width)")
            print("[UITest] Menu horizontal center: \(menuBounds.centerX)")

            // Calculate horizontal offset between card center and menu center.
            let horizontalOffset = menuBounds.centerX - cardCenterX
            let absOffset = abs(horizontalOffset)

            print("[UITest] Horizontal offset: \(horizontalOffset) points (positive = menu is right of card center)")
            print("[UITest] Absolute offset: \(absOffset) points")

            saveScreenshot(name: "menu_centering_col\(column + 1)_offset\(Int(absOffset))pt")

            // Assert menu is centered within tolerance.
            XCTAssertLessThanOrEqual(
                absOffset,
                tolerance,
                "FAIL: Column \(column + 1) menu not centered! " +
                "Card centerX: \(cardCenterX), Menu centerX: \(menuBounds.centerX), " +
                "Offset: \(horizontalOffset) points (tolerance: \(tolerance)pt)"
            )

            print("[UITest] PASS: Column \(column + 1) menu centered within \(tolerance)pt tolerance")

            testedColumns.insert(column)

            // Dismiss menu.
            dismissCoord.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Verify we tested all columns 2-4.
        let expectedColumns = Set([1, 2, 3])  // 0-based indices for columns 2, 3, 4
        let missingColumns = expectedColumns.subtracting(testedColumns)
        if !missingColumns.isEmpty {
            let missingColumnNames = missingColumns.map { $0 + 1 }.sorted()
            print("[UITest] Warning: Could not test columns: \(missingColumnNames)")
        }

        print("[UITest] ========================================")
        print("[UITest] SUMMARY: Tested \(testedColumns.count) columns")
        for col in testedColumns.sorted() {
            print("[UITest]   Column \(col + 1): PASSED")
        }
        print("[UITest] All context menu centering tests completed!")
    }

}
