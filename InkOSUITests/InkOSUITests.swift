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

    @MainActor
    func testCardScalesDownImmediatelyOnMenuDismiss() throws {
        // Verifies that cards scale down immediately when the context menu is dismissed,
        // not after a delay. This is a VISUAL test using screenshots.
        //
        // XCUITest's frame property doesn't reflect CGAffineTransform, so we use
        // screenshots to visually verify animation timing:
        // 1. Screenshot at rest (normal scale)
        // 2. Screenshot with menu open (card lifted/scaled up)
        // 3. Screenshot IMMEDIATELY after dismiss tap (should show card animating down)
        // 4. Screenshot after animation completes
        //
        // Visual inspection: Compare screenshot 3 to screenshots 2 and 4.
        // - If fix works: Screenshot 3 should show card visually smaller than screenshot 2
        // - If delay exists: Screenshot 3 would look identical to screenshot 2

        let navBar = app.navigationBars["InkOS"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 10), "Dashboard should load")

        // Find a card to test.
        guard let card = findFirstCard() else {
            XCTFail("No cards found on dashboard")
            return
        }

        XCTAssertTrue(card.waitForExistence(timeout: 5), "Card should exist")

        // 1. Screenshot at rest (normal scale).
        print("[UITest] Step 1: Capturing card at rest")
        saveScreenshot(name: "1_card_at_rest")

        // 2. Long press to show context menu (card lifts/scales up).
        print("[UITest] Step 2: Long pressing to show context menu")
        card.press(forDuration: 0.5)

        // Wait for menu to appear.
        let renameItem = app.menuItems["Rename"]
        guard renameItem.waitForExistence(timeout: 3) else {
            XCTFail("Context menu did not appear")
            return
        }

        // Give the lift animation time to complete.
        Thread.sleep(forTimeInterval: 0.3)

        print("[UITest] Step 2: Capturing card with menu open (lifted)")
        saveScreenshot(name: "2_card_lifted_with_menu")

        // 3. Dismiss the menu and IMMEDIATELY capture screenshot.
        print("[UITest] Step 3: Dismissing menu and capturing IMMEDIATELY")
        let dismissCoord = app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.05))
        dismissCoord.tap()

        // Capture IMMEDIATELY - this is the critical screenshot.
        // With the fix, the card should already be visibly animating down.
        saveScreenshot(name: "3_immediately_after_dismiss")

        // 4. Wait for animation to complete and capture final state.
        Thread.sleep(forTimeInterval: 0.5)
        print("[UITest] Step 4: Capturing card after animation completes")
        saveScreenshot(name: "4_after_animation_complete")

        // Verify the menu is dismissed.
        XCTAssertFalse(renameItem.exists, "Menu should be dismissed")

        print("[UITest] ========================================")
        print("[UITest] VISUAL VERIFICATION REQUIRED:")
        print("[UITest]   Compare screenshot 3 (immediately_after_dismiss) to:")
        print("[UITest]   - Screenshot 2 (lifted_with_menu): Card should be visibly SMALLER in 3")
        print("[UITest]   - Screenshot 4 (after_animation): Card should look similar in 3 and 4")
        print("[UITest]")
        print("[UITest]   If fix works: Screenshot 3 shows card already animating/shrinking")
        print("[UITest]   If delay exists: Screenshot 3 looks same as screenshot 2 (still lifted)")
        print("[UITest] ========================================")
    }

}
