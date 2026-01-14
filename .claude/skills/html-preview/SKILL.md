---
name: html-preview
description: Preview and verify HTML design system files using headless browser capture. No screen access required. Use when checking design system components, verifying layouts, or testing visual styling.
---

# HTML Preview & Verification

Capture screenshots of HTML files using Playwright (headless browser). No screen access needed.

## CRITICAL: Visual Verification Protocol

**NEVER verify UI by only reading CSS code.** Always capture and view screenshots to verify visual output.

## Quick Reference

```bash
# Capture top of page
Scripts/html-preview capture file.html screenshot-name

# Capture specific section (scroll to element ID)
Scripts/html-preview capture file.html#section-id screenshot-name

# Capture full page (very tall image)
Scripts/html-preview fullcapture file.html full-page

# List screenshots
Scripts/html-preview list

# Clean up
Scripts/html-preview clean
```

Then use **Read tool** to view: `/tmp/html-preview-screenshots/<name>_<timestamp>.png`

## Setup (One-time)

For scroll-to-element support, run once:
```bash
cd /tmp && mkdir -p html-capture && cd html-capture && npm init -y && npm install playwright
```

## Workflow Example

### 1. Capture Section of Interest

```bash
Scripts/html-preview capture /Users/andrewallen/Desktop/swift_projects/alan-unified-design-system.html#progress-bar progress
```

### 2. View Screenshot

```
Read tool: /tmp/html-preview-screenshots/progress_20260111_203639.png
```

### 3. Analyze What You See

Describe actual observations:
- "Progress bars render as thin ~4px horizontal lines"
- "Fill color (#E8E4DF) is visible against dark background"
- "Background track is subtle (15% opacity)"

### 4. Compare to Specs

| Property | Expected | Observed |
|----------|----------|----------|
| height | 4px | ~4px (matches) |
| border-radius | 2px | Rounded ends visible |
| background | rgba(255,255,255,0.15) | Subtle track visible |
| fill-color | #E8E4DF | Warm off-white |

### 5. State Result

**PASS** or **FAIL** with reasoning.

## Available Section IDs

The unified design system has these IDs for targeted capture:

| Section | ID |
|---------|-----|
| Design Tokens | `#design-tokens` |
| Components | `#components` |
| Progress Bar | `#progress-bar` |
| Block Components | `#block-components` |
| Izuminka Effects | `#izuminka` |

## Commands

| Command | Description |
|---------|-------------|
| `capture <file>[#id] [name] [w] [h]` | Capture viewport, optionally scroll to #id |
| `fullcapture <file> [name] [w]` | Capture entire page height |
| `open <file>` | Open in Safari for manual inspection |
| `list` | List captured screenshots |
| `view <file>` | Open screenshot in Preview app |
| `clean` | Delete all screenshots |

## File Locations

| Item | Path |
|------|------|
| Unified Design System | `/Users/andrewallen/Desktop/swift_projects/alan-unified-design-system.html` |
| Screenshots | `/tmp/html-preview-screenshots/` |

## Technical Details

- Uses Playwright for headless Chromium capture
- No screen recording or system audio access
- Supports viewport sizing (default 1470x900)
- Full page capture creates tall images (can be thousands of pixels)
