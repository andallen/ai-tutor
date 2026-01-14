---
name: ui-testing
description: Run UI tests on the InkOS iPad app. Use when verifying UI behavior, testing animations, checking gestures, or capturing screenshots. Covers writing tests, running them on device, and viewing results. Use after making any UI update to ensure it works as you intended, if applicable.
---

# InkOS UI Testing

Run XCUITests to verify UI behavior, capture screenshots, and validate features.

## Important: Temporary Verification Tests

UI tests in this workflow are **temporary verification tests**, not permanent test suite additions:

- **Write only tests for the specific UI change** you are verifying
- **Delete previous test methods** before writing new ones - keep only the test(s) needed for the current verification
- Tests are meant to confirm a UI change works, then be removed
- Do not accumulate test methods over time

## Test Type Priority

**Prefer precise objective tests over visual screenshot tests when possible.**

| Use Objective Tests For | Use Visual Tests For |
|-------------------------|----------------------|
| Element existence/absence | Layout and spacing verification |
| Element counts | Animation behavior |
| Label/text content | Visual styling (colors, shadows) |
| Button enabled/disabled state | Complex visual states |
| Element position relationships | Before/after comparison of visual changes |

**Objective tests are faster, more reliable, and provide clearer pass/fail signals.** Only use screenshots when the verification genuinely requires visual inspection (e.g., checking that an animation looks correct, verifying spacing, or confirming visual styling).

Example - prefer this:
```swift
// Objective: verify context menu appears with correct options
contextMenu.tap()
XCTAssertTrue(app.buttons["deleteAction"].waitForExistence(timeout: 2))
XCTAssertTrue(app.buttons["renameAction"].exists)
XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'Action'")).count, 3)
```

Over this:
```swift
// Visual: screenshot-based verification
contextMenu.tap()
saveScreenshot(name: "context_menu_open")  // Requires manual inspection
```

## Test Runner

Use `Scripts/test-ui` to run tests on the connected iPad device:

```bash
# Run a specific test
Scripts/test-ui run <TestMethodName>

# Example
Scripts/test-ui run testMyFeature

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

    // 3. Perform interaction
    element.tap()
    // or: element.press(forDuration: 0.5)  // long press

    // 4. Assert expected state with OBJECTIVE tests (preferred)
    let result = app.buttons["ExpectedButton"]
    XCTAssertTrue(result.waitForExistence(timeout: 3), "Result should appear")
    XCTAssertTrue(result.isEnabled, "Button should be enabled")
    XCTAssertEqual(app.cells.count, 5, "Should show 5 items")

    // 5. OPTIONAL: Capture screenshot only if visual verification needed
    // saveScreenshot(name: "after_action")
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

Screenshots are attached to test results via `XCTAttachment` and stored in the xcresult bundle on the Mac (not on the device filesystem).

### Extracting Screenshots from xcresult

After running tests, extract screenshots from the xcresult bundle:

```bash
# Find the latest xcresult bundle
xcresult_path=$(ls -td ~/Library/Developer/Xcode/DerivedData/InkOS-*/Logs/Test/*.xcresult 2>/dev/null | head -1)
echo "xcresult: $xcresult_path"

# Create output directory
mkdir -p /tmp/inkos-screenshots-local

# Extract all PNG screenshots from the Data directory
for f in "$xcresult_path/Data/"*; do
    filetype=$(file "$f" 2>/dev/null)
    if echo "$filetype" | grep -q "PNG image"; then
        name=$(basename "$f")
        cp "$f" "/tmp/inkos-screenshots-local/${name}.png"
        echo "Extracted: ${name}.png"
    fi
done

# List extracted screenshots
ls -la /tmp/inkos-screenshots-local/*.png
```

### Viewing Extracted Screenshots

Use the Read tool on the extracted PNG files:

```
/tmp/inkos-screenshots-local/screenshot_1.png
```

### Why This Is Necessary

- Tests run on the physical iPad device
- `FileManager` operations in tests write to the device filesystem
- Screenshots attached via `XCTAttachment` are synced back to the Mac in the xcresult bundle
- The xcresult Data directory contains the raw PNG files (not compressed)

## Lock File Protection

A lock at `/tmp/inkos-ui-test.lock` prevents concurrent test runs:
- Auto-expires after 5 minutes
- Clear manually: `rm -f /tmp/inkos-ui-test.lock`

## Workflow

1. **Add accessibility identifiers** to the UI elements you want to test
2. **Determine test type**: Can this be verified with objective assertions (element exists, count, label, enabled state)? If yes, use objective tests. Only use screenshots for visual verification.
3. **Write test method** in `InkOSUITests.swift` following the pattern above
4. **Build the app**: `Scripts/buildapp`
5. **Run the test**: `Scripts/test-ui run testMethodName`
6. **Check results**: `Scripts/test-ui results`
7. **If using screenshots**: Extract and view them (see "Viewing Screenshots" section)

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

Run with: `Scripts/test-ui run testPrintHierarchy`

## Device Configuration

- **iPad UDID**: `00008120-001665CC21900032`

To find connected devices: `xcrun devicectl list devices`
