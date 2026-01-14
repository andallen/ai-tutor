---
name: ui-testing
description: Run UI tests on the InkOS iPad app. Use when verifying UI behavior, testing animations, checking gestures, or capturing screenshots. Covers writing tests, running them on device or simulator, and viewing results. Use after making any UI update to ensure it works as you intended, if applicable.
---

# InkOS UI Testing

Run XCUITests to verify UI behavior, capture screenshots, and validate features.

## Test Runner

Use `Scripts/test-ui` to run tests:

```bash
# Run a specific test
Scripts/test-ui run <TestMethodName> [sim|device]

# Run on iPad device
Scripts/test-ui run testMyFeature device

# Run on simulator
Scripts/test-ui run testMyFeature sim

# View results
Scripts/test-ui results

# List screenshots
Scripts/test-ui screenshots

# Clean artifacts
Scripts/test-ui clean
```

## Writing Tests

Tests live in `InkOSUITests/InkOSUITests.swift`. Follow this pattern:

```swift
@MainActor
func testFeatureName() throws {
    // 1. Wait for app to load
    let navBar = app.navigationBars["InkOS"]
    XCTAssertTrue(navBar.waitForExistence(timeout: 10), "Dashboard should load")

    // 2. Find elements using accessibility identifiers
    let element = app.cells["myElement_id"]
    XCTAssertTrue(element.waitForExistence(timeout: 5), "Element should exist")

    // 3. Capture screenshot before action
    saveScreenshot(name: "before_action")

    // 4. Perform interaction
    element.tap()
    // or: element.press(forDuration: 0.5)  // long press

    // 5. Capture screenshot after action
    saveScreenshot(name: "after_action")

    // 6. Assert expected state
    let result = app.buttons["ExpectedButton"]
    XCTAssertTrue(result.waitForExistence(timeout: 3), "Result should appear")
}
```

## Making UI Testable

Add accessibility identifiers to UIKit views for reliable element finding:

```swift
// In cell configure method
accessibilityIdentifier = "cardType_\(item.id)"
isAccessibilityElement = true
accessibilityLabel = "CardType: \(item.displayName)"
```

## Finding Elements

```swift
// By accessibility identifier
app.cells["notebookCard_abc123"]
app.buttons["deleteButton"]

// By identifier pattern
app.cells.matching(NSPredicate(format: "identifier BEGINSWITH 'notebookCard_'"))

// By label
app.cells.matching(NSPredicate(format: "label BEGINSWITH 'Notebook:'"))

// First match
app.cells.firstMatch
```

## Capturing Screenshots

The test file includes a `saveScreenshot(name:)` helper that:
- Attaches screenshot to test results
- Saves PNG to `/tmp/inkos-ui-tests/screenshots/`

```swift
saveScreenshot(name: "descriptive_name")
```

Screenshots are saved as: `descriptive_name_<timestamp>.png`

## Viewing Screenshots

After running tests, view captured screenshots:

```bash
# List all screenshots
ls -la /tmp/inkos-ui-tests/screenshots/

# View a specific screenshot (use Read tool on the PNG file)
```

## Lock File Protection

A lock at `/tmp/inkos-ui-test.lock` prevents concurrent test runs:
- Auto-expires after 5 minutes
- Clear manually: `rm -f /tmp/inkos-ui-test.lock`

## Workflow

1. **Add accessibility identifiers** to the UI elements you want to test
2. **Write test method** in `InkOSUITests.swift` following the pattern above
3. **Build the app**: `Scripts/buildapp`
4. **Run the test**: `Scripts/test-ui run testMethodName device`
5. **Check results**: `Scripts/test-ui results`
6. **View screenshots**: Read PNG files from `/tmp/inkos-ui-tests/screenshots/`

## Common Interactions

```swift
// Tap
element.tap()

// Long press
element.press(forDuration: 0.5)

// Wait for element
element.waitForExistence(timeout: 5)

// Wait for element to disappear
element.waitForNonExistence(timeout: 2)

// Check if exists
element.exists

// Get element count
app.cells.count

// Swipe
element.swipeUp()
element.swipeDown()
```

## Debugging

Print accessibility hierarchy to find element identifiers:

```swift
@MainActor
func testPrintHierarchy() throws {
    let navBar = app.navigationBars["InkOS"]
    XCTAssertTrue(navBar.waitForExistence(timeout: 10))

    print("Cells count: \(app.cells.count)")
    for i in 0..<min(app.cells.count, 10) {
        let cell = app.cells.element(boundBy: i)
        print("Cell \(i): id='\(cell.identifier)' label='\(cell.label)'")
    }
}
```

Run with: `Scripts/test-ui run testPrintHierarchy sim`

## Device Configuration

- **iPad UDID**: `00008120-001665CC21900032`
- **Simulator**: iPad Pro 13-inch (M5)

To find connected devices: `xcrun devicectl list devices`
