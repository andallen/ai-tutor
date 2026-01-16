# Notebook Design System

Design tokens and principles for the notebook renderer. This document explains the *why* behind the values in `NotebookDesignTokens.swift`.

## Core Principle

**Breathing room scales with visual weight.**

A big dramatic reveal needs more space after it than a line of body text. The eye needs time to process important moments before moving on.

---

## Typography Scale

Single scale, five levels. Walk down the scale. Font switches at Level 4.

| Level | Token | Font | Size | Weight | When to Use |
|-------|-------|------|------|--------|-------------|
| 1 | `display` | SF Pro Rounded | 42pt | Bold | Big dramatic reveals. Use sparingly. |
| 2 | `title` | SF Pro Rounded | 30pt | Bold | Section openers. |
| 3 | `headline` | SF Pro Rounded | 24pt | Semibold | Subsection markers. |
| 4 | `body` | Nunito | 20pt | Medium | Reading text. The bulk of content. |
| 5 | `caption` | Nunito | 16pt | Medium | Secondary information. |

### The Rule

**Headings announce (SF Pro Rounded). Body explains (Nunito).**

The font switch at Level 4 signals the shift from announcing to explaining. Nunito body text uses -0.3pt tracking for tighter letterspacing.

### Typography Principles

1. **Walk down the scale.** Display → Title → Headline → Body → Caption.
2. **One display per section maximum.** It's the climax, not the norm.
3. **Don't skip levels.** Going from display → body is jarring. Use headline as a bridge.
4. **Body carries the story.** Most content is body text. That's fine.

---

## Spacing Scale

Based on an 8pt grid with purposeful jumps:

| Token | Value | Feeling |
|-------|-------|---------|
| `xs` | 8pt | Tight. Related elements, inline. |
| `sm` | 16pt | Compact. Lines within a thought. |
| `md` | 24pt | Standard. Between body blocks. |
| `lg` | 40pt | Generous. After headlines, before new ideas. |
| `xl` | 56pt | Dramatic. After display text. Let it land. |
| `xxl` | 80pt | Pause. Checkpoints, major section breaks. |

### Why These Numbers?

- **8pt base** aligns with iOS conventions
- **Jumps are noticeable** — 16 → 24 → 40 feels like stepping up, not sliding
- **xl and xxl create moments** — the pause is the point

---

## Block Roles and Spacing

Every block has a *role* that determines how much space follows it:

| Role | Trailing Space | Examples |
|------|---------------|----------|
| `display` | 56pt (xl) | largeTitle centered text, big reveals |
| `section` | 40pt (lg) | title, headline text |
| `content` | 24pt (md) | body text, math, code |
| `interactive` | 24pt (md) | checkpoints, inputs (they have internal padding too) |

### How It Works

```
[Display: "The Pythagorean Theorem"]
         ↓ 56pt (xl) — let the reveal breathe
[Content: "This connects the three sides..."]
         ↓ 24pt (md) — standard rhythm
[Content: "a and b are the legs..."]
         ↓ 24pt (md)
[Checkpoint: "Ready for the insight?"]
```

The spacing *after* a block is determined by that block's role, not what comes next. Display text always gets xl space after, regardless of what follows.

---

## Alignment Rules

- **Display text**: Centered. It's a reveal, a moment.
- **Section openers (title)**: Left-aligned. Starts the reading flow.
- **Body text**: Left-aligned. Standard reading.
- **Math (display mode)**: Centered. Equations are focal points.
- **Checkpoints**: Centered. They're interactive pauses.

### The Alignment Shift

When going from centered (display) to left-aligned (body), the generous spacing (xl) gives the eye time to relocate. Without that space, the alignment change feels abrupt.

---

## Layout Constants

| Token | Value | Purpose |
|-------|-------|---------|
| `horizontalPaddingRegular` | 80pt | Margins on iPad. Creates focus. |
| `horizontalPaddingCompact` | 40pt | Margins on narrow screens. |
| `topPadding` | 100pt | Space before first block. Room to breathe. |
| `bottomPadding` | 80pt | Space after last block. Clean ending. |
| `maxContentWidth` | 680pt | Keeps lines readable (~65-70 chars). |

---

## Inline vs Block Segments

Text content can contain multiple segments. How they render depends on type:

**Inline segments** (flow together as a paragraph):
- `.plain` - Styled text spans

**Block segments** (each gets its own line):
- `.kinetic` - Animated text
- `.latex` - Math equations
- `.code` - Code blocks

### Example

```swift
// These plain segments flow inline as one paragraph:
TextContent(segments: [
  .plain(text: "The variable ", style: nil),
  .plain(text: "x", style: TextStyle(weight: .bold)),
  .plain(text: " represents the unknown.")
])
// Renders as: "The variable **x** represents the unknown."

// Mixed segments stack vertically:
TextContent(segments: [
  .kinetic(text: "Watch this:", animation: .typewriter, ...),
  .latex(latex: "E = mc^2", displayMode: true)
])
// Renders as two separate lines.
```

This allows styled runs within a sentence while keeping animated/special content on its own line.

---

## Checkpoints

Checkpoints are pacing mechanisms. They:
- Have `xxl` (80pt) internal vertical padding
- Center their content
- Use a simple prompt + Continue button

Place checkpoints at **cognitive boundaries**:
- Before introducing a new concept
- Before showing a worked example
- Before asking the user to try something

**Don't** place checkpoints after every block. The animation timing already creates rhythm. Checkpoints are for major section breaks.

---

## Animation Timing

Not strictly design tokens, but related:

- **Pause between blocks**: 2000ms. Time to read before next block appears.
- **Kinetic animation duration**: Varies by effect (slam: 800ms, typewriter: varies by length).

The pause is generous intentionally. This isn't a race. The user should absorb each piece before the next arrives.

---

## Iteration Workflow

1. Change a value in `NotebookDesignTokens.swift`
2. Build and run the preview
3. Evaluate the *feel* of the session
4. If it works, update this doc to reflect the intent
5. If not, try another value

The preview (`NotebookDocument.preview`) is designed to showcase the full range of typography and spacing. Use it to evaluate cohesion.

---

## Current Token Values (Quick Reference)

```swift
// Typography Scale (font switches at Level 4)
// Level 1-3: SF Pro Rounded (headings)
display:   42pt bold
title:     30pt bold
headline:  24pt semibold
// Level 4-5: Nunito (body, tracking: -0.3)
body:      20pt medium
caption:   16pt medium

// Spacing
xs:  12pt
sm:  20pt
md:  32pt
lg:  48pt
xl:  72pt
xxl: 96pt

// Block trailing space
display:     72pt (xl)
section:     48pt (lg)
content:     32pt (md)
interactive: 32pt (md)
```

## Font Files

The typography system requires the following font files:

| File | Font Family | Purpose |
|------|-------------|---------|
| `Nunito-Variable.ttf` | Nunito | Body text (variable weight 200-900) |

SF Pro Rounded is a system font on iOS and requires no additional files.
