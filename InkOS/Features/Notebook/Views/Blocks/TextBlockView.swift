//
// TextBlockView.swift
// InkOS
//
// Renders text content with multiple segment types.
// Supports plain text, LaTeX, code, and kinetic typography.
// Plain segments flow inline; other types stack vertically.
//

import SwiftUI

// MARK: - TextBlockView

// Renders text content with segments.
// Groups consecutive plain segments into inline text runs.
struct TextBlockView: View {
  let content: TextContent
  let animationState: BlockAnimationState
  let isMetaballTarget: Bool

  var body: some View {
    VStack(alignment: swiftUIAlignment, spacing: verticalSpacing) {
      ForEach(Array(groupedSegments.enumerated()), id: \.offset) { index, group in
        SegmentGroupView(
          group: group,
          animationState: animationState,
          sequenceIndex: index,
          reportAnchor: isMetaballTarget && index == 0
        )
      }
    }
    .frame(maxWidth: .infinity, alignment: frameAlignment)
    // Note: Vertical spacing between blocks is handled by BlockContainerView.
  }

  // Groups consecutive plain and pause segments together for inline rendering.
  // Pauses stay inline so StreamingTextView can handle timing delays.
  private var groupedSegments: [SegmentGroup] {
    var groups: [SegmentGroup] = []
    var currentInlineRun: [TextSegment] = []

    for segment in content.segments {
      switch segment {
      case .plain, .pause:
        // Plain text and pauses flow together inline.
        currentInlineRun.append(segment)
      default:
        // Flush any accumulated inline segments.
        if !currentInlineRun.isEmpty {
          groups.append(.inline(currentInlineRun))
          currentInlineRun = []
        }
        // Add the non-inline segment as its own block.
        groups.append(.block(segment))
      }
    }

    // Flush remaining inline segments.
    if !currentInlineRun.isEmpty {
      groups.append(.inline(currentInlineRun))
    }

    return groups
  }

  // Maps TextAlignment to SwiftUI HorizontalAlignment.
  private var swiftUIAlignment: HorizontalAlignment {
    switch content.alignment {
    case .leading: return .leading
    case .center: return .center
    case .trailing: return .trailing
    }
  }

  // Maps TextAlignment to SwiftUI Alignment.
  private var frameAlignment: Alignment {
    switch content.alignment {
    case .leading: return .leading
    case .center: return .center
    case .trailing: return .trailing
    }
  }

  // Maps TextSpacing to CGFloat.
  private var verticalSpacing: CGFloat {
    switch content.spacing {
    case .compact: return 4
    case .normal: return 8
    case .relaxed: return 16
    }
  }
}

// MARK: - SegmentGroup

// Represents either inline plain text or a block-level segment.
enum SegmentGroup {
  // Multiple plain segments that flow inline as one paragraph.
  case inline([TextSegment])
  // A single segment that needs its own block (kinetic, latex, code).
  case block(TextSegment)
}

// MARK: - SegmentGroupView

// Renders a segment group - either inline text or a block segment.
// Reports anchor preference for current visible text when metaball targeting is active.
struct SegmentGroupView: View {
  let group: SegmentGroup
  let animationState: BlockAnimationState
  let sequenceIndex: Int
  let reportAnchor: Bool

  var body: some View {
    content
  }

  @ViewBuilder
  private var content: some View {
    switch group {
    case .inline(let segments):
      // StreamingTextView handles its own anchor reporting for visible text.
      StreamingTextView(segments: segments, animationState: animationState, reportAnchor: reportAnchor)
    case .block(let segment):
      BlockSegmentView(
        segment: segment,
        animationState: animationState,
        sequenceIndex: sequenceIndex
      )
      .anchorPreference(key: FirstLineAnchor.self, value: .bounds) { anchor in
        reportAnchor ? anchor : nil
      }
    }
  }
}

// MARK: - FirstLineMeasurementView

// Invisible view that measures the height of a single line of text.
// Used to report the anchor for the first line only.
struct FirstLineMeasurementView: View {
  let font: Font

  var body: some View {
    // Single character to get exact line height for this font.
    Text("X")
      .font(font)
      .opacity(0)
      .accessibilityHidden(true)
  }
}

// MARK: - StreamingTextView

// Renders text with left-to-right streaming animation.
// Uses TimelineView to animate character-by-character reveal.
// Supports pause segments for human-like rhythm.
struct StreamingTextView: View {
  let segments: [TextSegment]
  let animationState: BlockAnimationState
  let reportAnchor: Bool

  // Animation timing.
  private let charactersPerSecond: Double = 60

  // Animation start time, set when entering animating state.
  @State private var animationStartTime: Date?

  // Timing model: each character takes 1/cps seconds, pauses add their duration.
  // Add fade time at end so last character fully appears.
  private var totalDuration: Double {
    let fadeCharacters = 3
    let fadeDuration = Double(fadeCharacters) / charactersPerSecond
    var duration: Double = 0
    for segment in segments {
      switch segment {
      case .plain(let text, _):
        duration += Double(text.count) / charactersPerSecond
      case .pause(let durationMs):
        duration += Double(durationMs) / 1000.0
      default:
        break
      }
    }
    return duration + fadeDuration
  }

  // All plain text concatenated for efficient prefix slicing.
  private var allPlainText: String {
    segments.compactMap { segment in
      if case .plain(let text, _) = segment { return text }
      return nil
    }.joined()
  }

  // Style for the text (from first segment).
  private var textStyle: TextStyle? {
    for segment in segments {
      if case .plain(_, let style) = segment { return style }
    }
    return nil
  }

  var body: some View {
    Group {
      switch animationState {
      case .waiting:
        // Hidden but still reports anchor for smooth blob positioning during transitions.
        staticText.hidden()
          .anchorPreference(key: FirstLineAnchor.self, value: .bounds) { anchor in
            reportAnchor ? anchor : nil
          }
      case .animating:
        TimelineView(.animation) { timeline in
          let elapsed = elapsedTime(at: timeline.date)
          let visibleCount = visibleCharacterCount(at: elapsed)
          // Anchor leads visible text so blob moves before new line appears.
          let anchorLeadCharacters = 8
          let anchorCount = min(visibleCount + anchorLeadCharacters, allPlainText.count)

          ZStack(alignment: .topLeading) {
            // The streaming text with per-character opacity.
            streamingText(elapsed: elapsed)

            // Invisible measurement text leads visible text slightly.
            // Blob moves to new line position just before text wraps there.
            if reportAnchor {
              styledText(String(allPlainText.prefix(anchorCount)), style: textStyle)
                .opacity(0)
                .anchorPreference(key: FirstLineAnchor.self, value: .bounds) { $0 }
            }
          }
        }
        .onAppear {
          if animationStartTime == nil {
            animationStartTime = Date()
          }
        }
      case .complete:
        staticText
          .anchorPreference(key: FirstLineAnchor.self, value: .bounds) { anchor in
            reportAnchor ? anchor : nil
          }
      }
    }
  }

  // Calculates visible character count efficiently using math.
  // O(1) for plain text without pauses.
  private func visibleCharacterCount(at elapsed: Double) -> Int {
    let fadeDuration = 3.0 / charactersPerSecond
    let effectiveElapsed = max(0, elapsed - fadeDuration)
    let count = Int(effectiveElapsed * charactersPerSecond)
    return min(count, allPlainText.count)
  }

  private func elapsedTime(at date: Date) -> Double {
    guard let startTime = animationStartTime else { return 0 }
    return min(totalDuration, date.timeIntervalSince(startTime))
  }

  // Builds text with chunk-based streaming animation.
  // Splits text into visible, fading, and hidden regions for efficiency.
  // Avoids per-character iteration which caused stack overflow.
  private func streamingText(elapsed: Double) -> Text {
    let fadeCharacters = 3

    // Calculate cursor position based on elapsed time.
    var timeOffset: Double = 0
    var charIndex = 0
    // Account for pauses by adjusting character position.
    for segment in segments {
      switch segment {
      case .plain(let text, _):
        let segmentDuration = Double(text.count) / charactersPerSecond
        if timeOffset + segmentDuration <= elapsed {
          timeOffset += segmentDuration
          charIndex += text.count
        } else {
          // Cursor is within this segment.
          let segmentElapsed = elapsed - timeOffset
          let charsInSegment = Int(segmentElapsed * charactersPerSecond)
          charIndex += charsInSegment
          break
        }
      case .pause(let durationMs):
        let pauseDuration = Double(durationMs) / 1000.0
        if timeOffset + pauseDuration <= elapsed {
          timeOffset += pauseDuration
        } else {
          break
        }
      default:
        break
      }
    }

    // Visible region: characters fully faded in.
    let visibleEnd = max(0, charIndex - fadeCharacters)
    // Fading region: characters currently transitioning.
    let fadingStart = visibleEnd
    let fadingEnd = charIndex

    // Build text in chunks: visible (full opacity) + fading (partial opacity).
    let fullText = allPlainText
    var result = Text("")

    // Add fully visible text.
    if visibleEnd > 0 {
      let visibleText = String(fullText.prefix(visibleEnd))
      result = result + styledText(visibleText, style: textStyle)
    }

    // Add fading text with partial opacity for the chunk.
    if fadingEnd > fadingStart && fadingStart < fullText.count {
      let startIdx = fullText.index(fullText.startIndex, offsetBy: min(fadingStart, fullText.count))
      let endIdx = fullText.index(fullText.startIndex, offsetBy: min(fadingEnd, fullText.count))
      let fadingText = String(fullText[startIdx..<endIdx])
      result = result + styledTextWithOpacity(fadingText, style: textStyle, opacity: 0.5)
    }

    return result
  }

  // Static fully-visible text for waiting/complete states.
  private var staticText: some View {
    segments.reduce(Text("")) { result, segment in
      if case .plain(let text, let style) = segment {
        return result + styledText(text, style: style)
      }
      return result
    }
  }

  // Creates styled Text with opacity applied via foregroundColor.
  private func styledTextWithOpacity(_ text: String, style: TextStyle?, opacity: Double) -> Text {
    var result = Text(text)

    if let size = style?.size {
      switch size {
      case .caption: result = result.font(NotebookTypography.caption)
      case .body: result = result.font(NotebookTypography.body)
      case .headline: result = result.font(NotebookTypography.headline)
      case .title: result = result.font(NotebookTypography.title)
      case .largeTitle: result = result.font(NotebookTypography.display)
      }
    } else {
      result = result.font(NotebookTypography.body)
    }

    let baseColor: Color
    if let hexColor = style?.color, let color = Color(hex: hexColor) {
      baseColor = color
    } else {
      baseColor = NotebookPalette.ink
    }
    result = result.foregroundColor(baseColor.opacity(opacity))

    if style?.italic == true {
      result = result.italic()
    }

    if style?.underline == true {
      result = result.underline()
    }

    if style?.strikethrough == true {
      result = result.strikethrough()
    }

    return result
  }

  // Creates styled Text for a full string.
  private func styledText(_ text: String, style: TextStyle?) -> Text {
    var result = Text(text)

    // Map size to font from the typography scale.
    if let size = style?.size {
      switch size {
      case .caption: result = result.font(NotebookTypography.caption)
      case .body: result = result.font(NotebookTypography.body)
      case .headline: result = result.font(NotebookTypography.headline)
      case .title: result = result.font(NotebookTypography.title)
      case .largeTitle: result = result.font(NotebookTypography.display)
      }
    } else {
      result = result.font(NotebookTypography.body)
    }

    if let hexColor = style?.color, let color = Color(hex: hexColor) {
      result = result.foregroundColor(color)
    } else {
      result = result.foregroundColor(NotebookPalette.ink)
    }

    if style?.italic == true {
      result = result.italic()
    }

    if style?.underline == true {
      result = result.underline()
    }

    if style?.strikethrough == true {
      result = result.strikethrough()
    }

    return result
  }
}

// MARK: - BlockSegmentView

// Renders a single block-level segment (kinetic, latex, code).
// Handles waiting state by hiding content while preserving layout.
struct BlockSegmentView: View {
  let segment: TextSegment
  let animationState: BlockAnimationState
  let sequenceIndex: Int

  var body: some View {
    segmentContent
      .opacity(animationState == .waiting ? 0 : 1)
  }

  @ViewBuilder
  private var segmentContent: some View {
    switch segment {
    case .plain(let text, let style):
      // Plain segments should be handled by InlineTextView, but handle gracefully.
      PlainTextView(text: text, style: style)

    case .latex(let latex, let displayMode, let color):
      LaTeXView(latex: latex, displayMode: displayMode, color: color)

    case .code(let code, let language, let showLineNumbers, let highlightLines):
      CodeBlockView(
        code: code,
        language: language,
        showLineNumbers: showLineNumbers,
        highlightLines: highlightLines
      )

    case .kinetic(let text, let animation, let durationMs, let delayMs, let style):
      KineticTextView(
        text: text,
        animation: animation,
        durationMs: durationMs,
        delayMs: delayMs,
        style: style,
        shouldAnimate: animationState == .animating,
        sequenceIndex: sequenceIndex
      )

    case .pause:
      // Pauses are timing-only, no visual representation.
      EmptyView()
    }
  }
}
