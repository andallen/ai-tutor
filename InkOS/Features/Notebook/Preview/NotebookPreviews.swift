//
// NotebookPreviews.swift
// InkOS
//
// Preview data for development and testing.
// Realistic tutoring scenarios demonstrating kinetic typography in context.
// Uses design tokens for consistent typography hierarchy and spacing.
// User controls pacing by tapping to advance through blocks.
//

import Foundation

// MARK: - NotebookDocument Preview Extension

extension NotebookDocument {
  // Realistic tutoring session - Alan explains the Pythagorean theorem.
  // Demonstrates typography hierarchy: display → section → content.
  // User taps to advance through each block at their own pace.
  static var preview: NotebookDocument {
    NotebookDocument(
      title: "Understanding the Pythagorean Theorem",
      blocks: [
        // BIG TEXT BLOCK FOR TESTING BLOB POSITIONING
        Block.text(
          content: TextContent(
            segments: [
              .plain(
                text: "This is a really long block of text that should wrap to multiple lines so we can test whether the blob indicator properly follows the currently visible text as it streams in character by character. The blob should start at the top and gradually move downward as each new line appears. If this is working correctly, you'll see the orbiting circles stay positioned just below the last line of visible text throughout the entire animation. This paragraph has been deliberately made very long to ensure we get plenty of line wraps to thoroughly test the behavior. Let's add even more text to make absolutely sure we have enough content to see the effect clearly across many lines of streaming text.",
                style: TextStyle(size: .body)
              )
            ]
          )),

        // SECTION 1: The Hook
        // Title-level opener sets the stage. Left-aligned to start reading flow.
        Block.text(
          content: TextContent(
            segments: [
              .kinetic(
                text: "Let's talk about one of the most useful ideas in all of math.",
                animation: .typewriter,
                durationMs: 2500,
                delayMs: 0,
                style: TextStyle(size: .title, weight: .medium)
              )
            ]
          )),

        // The big reveal - display level, centered. This is the climax of the hook.
        Block.text(
          content: TextContent(
            segments: [
              .kinetic(
                text: "The Pythagorean Theorem",
                animation: .typewriter,
                durationMs: 800,
                delayMs: 0,
                style: TextStyle(size: .largeTitle, weight: .bold)
              )
            ],
            alignment: .center
          )),

        // Context - stays centered to maintain visual continuity with the reveal.
        // Headline size bridges between display and body.
        Block.text(
          content: TextContent(
            segments: [
              .kinetic(
                text: "This theorem connects the three sides of any right triangle.",
                animation: .typewriter,
                durationMs: 1800,
                delayMs: 0,
                style: TextStyle(size: .headline)
              )
            ],
            alignment: .center
          )),

        // SECTION 2: The Formula
        // Display-mode LaTeX is centered by default.
        Block.text(
          content: TextContent(
            segments: [
              .latex(latex: "a^2 + b^2 = c^2", displayMode: true)
            ],
            alignment: .center
          )),

        // Transition to explanation. Headline level signals new focus.
        Block.text(
          content: TextContent(
            segments: [
              .kinetic(
                text: "Here's what each letter means:",
                animation: .typewriter,
                durationMs: 1200,
                delayMs: 0,
                style: TextStyle(size: .headline, weight: .semibold)
              )
            ]
          )),

        // Explanation of terms. Body level for detailed reading.
        Block.text(
          content: TextContent(
            segments: [
              .plain(text: "a", style: TextStyle(weight: .bold)),
              .plain(text: " and "),
              .plain(text: "b", style: TextStyle(weight: .bold)),
              .plain(text: " are the two shorter sides (the legs)")
            ]
          )),

        Block.text(
          content: TextContent(
            segments: [
              .plain(text: "c", style: TextStyle(weight: .bold)),
              .plain(text: " is the longest side (the hypotenuse) — always opposite the right angle")
            ]
          )),

        // SECTION 3: The Insight
        // Title level for the question, centered for emphasis.
        Block.text(
          content: TextContent(
            segments: [
              .kinetic(
                text: "The magic?",
                animation: .typewriter,
                durationMs: 500,
                delayMs: 0,
                style: TextStyle(size: .title, weight: .bold)
              )
            ],
            alignment: .center
          )),

        // The answer - headline level, centered to pair with the question.
        Block.text(
          content: TextContent(
            segments: [
              .kinetic(
                text: "If you know any two sides, you can always find the third.",
                animation: .typewriter,
                durationMs: 2000,
                delayMs: 0,
                style: TextStyle(size: .headline)
              )
            ],
            alignment: .center
          )),

        // SECTION 4: Worked Example
        // Transition back to left-aligned content for the walkthrough.
        Block.text(
          content: TextContent(
            segments: [
              .kinetic(
                text: "A real-world problem:",
                animation: .typewriter,
                durationMs: 800,
                delayMs: 0,
                style: TextStyle(size: .headline, weight: .semibold)
              )
            ]
          )),

        // The problem statement. Body level, italic for distinction.
        Block.text(
          content: TextContent(
            segments: [
              .plain(
                text: "A ladder is leaning against a wall. The base is 3 meters from the wall, and the ladder reaches 4 meters up. How long is the ladder?",
                style: TextStyle(size: .body, italic: true)
              )
            ]
          )),

        // Setup.
        Block.text(
          content: TextContent(
            segments: [
              .plain(text: "We have: "),
              .plain(text: "a = 3", style: TextStyle(weight: .bold)),
              .plain(text: ", "),
              .plain(text: "b = 4", style: TextStyle(weight: .bold))
            ]
          )),

        // Math steps - centered LaTeX sequence.
        Block.text(
          content: TextContent(
            segments: [
              .latex(latex: "3^2 + 4^2 = c^2", displayMode: true)
            ],
            alignment: .center
          )),

        Block.text(
          content: TextContent(
            segments: [
              .latex(latex: "9 + 16 = c^2", displayMode: true)
            ],
            alignment: .center
          )),

        Block.text(
          content: TextContent(
            segments: [
              .latex(latex: "25 = c^2", displayMode: true)
            ],
            alignment: .center
          )),

        Block.text(
          content: TextContent(
            segments: [
              .latex(latex: "c = 5", displayMode: true)
            ],
            alignment: .center
          )),

        // The answer - title level slam, centered.
        Block.text(
          content: TextContent(
            segments: [
              .kinetic(
                text: "The ladder is 5 meters long.",
                animation: .typewriter,
                durationMs: 800,
                delayMs: 0,
                style: TextStyle(size: .title, weight: .bold)
              )
            ],
            alignment: .center
          )),

        // Closing thought - returns to body level for reflection.
        Block.text(
          content: TextContent(
            segments: [
              .kinetic(
                text: "This same idea works for any right triangle — architecture, navigation, games, physics. Once you see it, you'll find it everywhere.",
                animation: .typewriter,
                durationMs: 3000,
                delayMs: 0,
                style: TextStyle(size: .body)
              )
            ]
          ))
      ]
    )
  }

  // Minimal preview for quick testing.
  static var minimal: NotebookDocument {
    NotebookDocument(
      title: "Quick Test",
      blocks: [
        Block.text(
          content: TextContent(
            segments: [
              .kinetic(
                text: "Hello! I'm Alan.",
                animation: .typewriter,
                durationMs: 1500,
                delayMs: 0,
                style: TextStyle(size: .title, weight: .medium)
              )
            ]
          ))
      ]
    )
  }
}
