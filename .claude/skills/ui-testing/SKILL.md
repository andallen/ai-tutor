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

## CRITICAL: Every Test MUST Have Assertions

**MANDATORY RULE**: Every test MUST contain at least one `XCTAssert*` statement that would FAIL if the feature being tested is broken.

### ❌ INVALID Test (No Assertions)
```swift
func testGhostNotation() throws {
    saveScreenshot(name: "ghost_notation")
    print("Verify manually that ghost notation appears")  // ← INVALID
}
```
**Problem**: This test will ALWAYS PASS even if ghost notation is completely broken.

### ✅ VALID Test (Has Assertions)
```swift
func testGhostNotation() throws {
    // Find an element that proves ghost notation initialized
    let ghostIndicator = app.otherElements["ghost_notation_view"]
    XCTAssertTrue(ghostIndicator.exists, "Ghost notation view should exist")

    // OPTIONAL: Screenshot for visual verification
    saveScreenshot(name: "ghost_notation")
}
```

**Before writing any test, answer this question**: *"What assertion would FAIL if this feature stopped working?"*

If you cannot answer this question with a specific XCTAssert statement, you must either:
1. Add testability hooks to the code (accessibility identifiers, debug views)
2. Find a proxy indicator that proves the feature is working
3. Document why objective testing is impossible and provide a detailed visual verification protocol

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

## Visual Verification Protocol

When objective assertions are impossible and screenshots are required, follow this protocol:

### 1. Pre-Screenshot Checklist
Before capturing a screenshot, verify:
- [ ] I've exhausted all objective testing options (element existence, counts, labels)
- [ ] I've documented WHY objective testing is impossible
- [ ] I know EXACTLY what visual element I'm looking for in the screenshot

### 2. Screenshot Capture
```swift
// Document what you expect to see
print("[Test] Expecting to see: X equations distributed across screen, avoiding center content area")
saveScreenshot(name: "descriptive_name")
```

### 3. Screenshot Analysis (MANDATORY)
After extracting screenshots, you MUST:

1. **Read the screenshot file using the Read tool**
2. **Explicitly describe what you observe**:
   - "I see 5 equations: 'E=mc2' (top-left), 'F=ma' (middle-right)..."
   - "The center content area from Y=200 to Y=800 is clear"
3. **Compare against expectations**:
   - ✅ "Expected: equations avoiding center. Observed: all equations are in margins. PASS"
   - ❌ "Expected: ghost notation visible. Observed: NO equations visible anywhere. FAIL"
4. **State pass/fail explicitly**:
   - DO NOT say "looks good" without describing what you see
   - DO NOT assume test passed just because screenshot was captured

### 4. Negative Testing
For visual features, always test that they DON'T appear when they shouldn't:
```swift
// Navigate away from the screen where feature should appear
navigateToOtherScreen()
saveScreenshot(name: "feature_should_not_appear")
// Then verify in screenshot that feature is absent
```

### ❌ INVALID Visual Test
```swift
saveScreenshot(name: "ghost_notation")
print("Verify manually...")  // ← Who will verify? When? INVALID
```

### ✅ VALID Visual Test
```swift
print("[Test] Expecting: 8-10 equations scattered across screen, none in center Y=300-700")
saveScreenshot(name: "ghost_notation_present")

// Then in analysis:
// "Screenshot shows: 9 equations visible. 'E=mc2' at (100,150), 'F=ma' at (600,200)...
//  All equations are outside center zone. PASS ✅"
```

## Viewing Screenshots

Screenshots are attached to test results via `XCTAttachment` and stored in the xcresult bundle on the Mac (not on the device filesystem).

### Extracting Screenshots from xcresult

After running tests, extract screenshots from the xcresult bundle using the official `xcresulttool` command:

```bash
# Find the latest xcresult bundle
xcresult_path=$(ls -td ~/Library/Developer/Xcode/DerivedData/InkOS-*/Logs/Test/*.xcresult 2>/dev/null | head -1)
echo "Extracting from: $xcresult_path"

# Create output directory
output_dir="/tmp/inkos-ui-screenshots"
rm -rf "$output_dir"
mkdir -p "$output_dir"

# Export all attachments using xcresulttool
xcrun xcresulttool export attachments --path "$xcresult_path" --output-path "$output_dir"

# List extracted screenshots
find "$output_dir" -name "*.png"
```

**Important**: Use `xcresulttool export attachments` instead of manually copying files from the Data directory. The Data directory no longer contains raw PNG files in modern Xcode versions - attachments are stored in a compressed format.

### Optional: Export Only Specific Tests or Failures

```bash
# Export attachments for a specific test
xcrun xcresulttool export attachments --path "$xcresult_path" --output-path "$output_dir" --test-id "InkOSUITests/testMethodName()"

# Export only attachments from failed tests
xcrun xcresulttool export attachments --path "$xcresult_path" --output-path "$output_dir" --only-failures
```

### Viewing Extracted Screenshots

Use the Read tool on the extracted PNG files:

```
/tmp/inkos-ui-screenshots/F8C0E679-F5BE-4010-A6E6-BFEAA6DBB457.png
```

The export command also creates a `manifest.json` file with metadata about each attachment (test name, suggested filename, timestamp, etc.).

### Why xcresulttool Is Required

- Tests run on the physical iPad device
- Screenshots attached via `XCTAttachment` are synced to the Mac in the xcresult bundle
- Modern Xcode stores attachments in a compressed/optimized format, not as raw PNGs
- The official `xcresulttool export attachments` command properly extracts and decompresses them

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
8. **MANDATORY: Validate test quality** (see below)

## Test Quality Validation

Before declaring a test complete, validate it using this checklist:

### ✅ Pre-Completion Checklist

Run through this checklist BEFORE reporting test success:

1. **Assertion Check**
   - [ ] Test contains at least one `XCTAssert*` statement
   - [ ] OR has documented visual verification with explicit pass/fail criteria

2. **Failure Validation**
   - [ ] Answer: "If I broke this feature right now, would this test FAIL?"
   - [ ] If unsure, mentally walk through what would happen if feature was disabled

3. **Screenshot Validation** (if screenshots used)
   - [ ] I have EXTRACTED and READ the screenshot files
   - [ ] I have DESCRIBED what I observe in the screenshots
   - [ ] I have COMPARED observations against expectations
   - [ ] I have EXPLICITLY stated PASS or FAIL with reasoning

4. **Negative Testing**
   - [ ] Test verifies feature appears when it should
   - [ ] Test verifies feature doesn't appear when it shouldn't (or documented why this is N/A)

### Red Flags That Indicate Invalid Test

- ❌ Print statement says "Verify manually..."
- ❌ No XCTAssert statements in entire test
- ❌ Test passed but you didn't look at screenshots
- ❌ Test passed but you can't explain what it verified
- ❌ You said "looks good" without describing what you saw

### Example: Proper Test Completion

```swift
// Test written and run ✅
func testGhostNotation() throws {
    let questionText = app.staticTexts["onboarding_question"]
    XCTAssertTrue(questionText.exists)
    Thread.sleep(forTimeInterval: 2)
    saveScreenshot(name: "ghost_notation")
}
```

**Validation:**
1. ✅ Has assertion (questionText.exists)
2. ❓ Would test fail if ghost notation broke? NO - it only checks question text
3. ❌ INVALID TEST - needs better assertion or visual verification

**Fix:**
Add accessibility element for ghost notation OR document detailed visual verification protocol.

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
