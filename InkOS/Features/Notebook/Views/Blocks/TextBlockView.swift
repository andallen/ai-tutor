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

  var body: some View {
    VStack(alignment: swiftUIAlignment, spacing: verticalSpacing) {
      ForEach(Array(groupedSegments.enumerated()), id: \.offset) { index, group in
        SegmentGroupView(
          group: group,
          animationState: animationState,
          sequenceIndex: index
        )
      }
    }
    .frame(maxWidth: .infinity, alignment: frameAlignment)
    // Note: Vertical spacing between blocks is handled by BlockContainerView.
  }

  // Groups consecutive plain segments together for inline rendering.
  private var groupedSegments: [SegmentGroup] {
    var groups: [SegmentGroup] = []
    var currentInlineRun: [TextSegment] = []

    for segment in content.segments {
      switch segment {
      case .plain:
        // Plain text flows together inline.
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
struct SegmentGroupView: View {
  let group: SegmentGroup
  let animationState: BlockAnimationState
  let sequenceIndex: Int

  var body: some View {
    content
  }

  @ViewBuilder
  private var content: some View {
    switch group {
    case .inline(let segments):
      StreamingTextView(segments: segments, animationState: animationState)
    case .block(let segment):
      BlockSegmentView(
        segment: segment,
        animationState: animationState,
        sequenceIndex: sequenceIndex
      )
    }
  }
}

// MARK: - StreamingTextView

// Renders text with left-to-right streaming animation.
// Uses TimelineView to animate character-by-character reveal.
// Supports pause segments for human-like rhythm.
struct StreamingTextView: View {
  let segments: [TextSegment]
  let animationState: BlockAnimationState

  // Animation timing.
  private let charactersPerSecond: Double = 60

  // Animation start time, set when entering animating state.
  @State private var animationStartTime: Date?

  // Timing model: each character takes 1/cps seconds.
  // Add fade time at end so last character fully appears.
  private var totalDuration: Double {
    let fadeCharacters = 3
    let fadeDuration = Double(fadeCharacters) / charactersPerSecond
    var duration: Double = 0
    for segment in segments {
      if case .plain(let text, _) = segment {
        duration += Double(text.count) / charactersPerSecond
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
        // Hidden to preserve layout space before reveal.
        staticText.hidden()
      case .animating:
        TimelineView(.animation) { timeline in
          let elapsed = elapsedTime(at: timeline.date)
          streamingText(elapsed: elapsed)
        }
        .onAppear {
          if animationStartTime == nil {
            animationStartTime = Date()
          }
        }
      case .complete:
        staticText
      }
    }
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
    let fullText = allPlainText
    let totalCharacters = fullText.count

    // Calculate cursor position based on elapsed time.
    // Cursor represents the character currently being "typed".
    var timeOffset: Double = 0
    var charIndex = 0
    for segment in segments {
      if case .plain(let text, _) = segment {
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
      }
    }

    // After all characters are typed, the fade period continues.
    // Calculate how many additional characters should be fully visible during fade.
    let textDuration = Double(totalCharacters) / charactersPerSecond
    let fadeProgress: Int
    if elapsed > textDuration {
      // Extra time past text completion advances visibility through the fade region.
      let fadeElapsed = elapsed - textDuration
      fadeProgress = min(fadeCharacters, Int(fadeElapsed * charactersPerSecond))
    } else {
      fadeProgress = 0
    }

    // Visible region: characters fully faded in.
    // During typing: charIndex - fadeCharacters are fully visible.
    // During fade: progressively include remaining characters.
    let visibleEnd = max(0, charIndex - fadeCharacters + fadeProgress)
    // Fading region: characters currently transitioning.
    let fadingStart = visibleEnd
    let fadingEnd = min(charIndex, totalCharacters)

    // Build text in chunks: visible (full opacity) + fading (partial opacity).
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
    }
  }
}
