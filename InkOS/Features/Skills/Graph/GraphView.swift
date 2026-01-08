// GraphView.swift
// SwiftUI view that renders an interactive mathematical graph.
// Composes grid, axes, equations, points, annotations, and gesture handling.

import SwiftUI

// MARK: - GraphView

// Main view for rendering a mathematical graph from a GraphSpecification.
// Supports pan, zoom, and trace gestures for interactivity.
struct GraphView: View {
  @ObservedObject var viewModel: GraphViewModel

  // Optional callbacks for interaction events.
  var onTraceStarted: ((String) -> Void)?
  var onTraceEnded: (() -> Void)?
  var onViewportChanged: ((GraphViewport) -> Void)?

  // Renderer for converting equations to paths.
  private let renderer = EquationRenderer()

  // Parser for expression evaluation.
  private let parser = MathExpressionParser()

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        // Layer 1: Background
        backgroundLayer

        // Layer 2: Grid
        gridLayer

        // Layer 3: Axes
        axesLayer

        // Layer 4: Equations
        equationsLayer

        // Layer 5: Points
        pointsLayer

        // Layer 6: Annotations
        annotationsLayer

        // Layer 7: Trace overlay
        if viewModel.isTracing {
          traceOverlay
        }
      }
      .contentShape(Rectangle())
      .gesture(combinedGesture)
      .onAppear {
        viewModel.viewSize = geometry.size
      }
      .onChange(of: geometry.size) { _, newSize in
        viewModel.viewSize = newSize
      }
    }
  }

  // MARK: - Background Layer

  private var backgroundLayer: some View {
    Rectangle()
      .fill(Color(UIColor.systemBackground))
  }

  // MARK: - Grid Layer

  private var gridLayer: some View {
    SwiftUI.Canvas { context, size in
      let (vertical, horizontal) = renderer.renderGrid(
        viewModel.specification.axes,
        viewport: viewModel.currentViewport,
        viewSize: size
      )

      let gridColor = Color.gray.opacity(0.3)

      // Draw vertical grid lines.
      for path in vertical {
        context.stroke(
          path,
          with: .color(gridColor),
          lineWidth: GraphViewConstants.gridLineWidth
        )
      }

      // Draw horizontal grid lines.
      for path in horizontal {
        context.stroke(
          path,
          with: .color(gridColor),
          lineWidth: GraphViewConstants.gridLineWidth
        )
      }
    }
  }

  // MARK: - Axes Layer

  private var axesLayer: some View {
    SwiftUI.Canvas { context, size in
      let (xAxis, yAxis) = renderer.renderAxes(
        viewModel.specification.axes,
        viewport: viewModel.currentViewport,
        viewSize: size
      )

      let axisColor = Color.primary

      // Draw X axis.
      if let xPath = xAxis {
        context.stroke(
          xPath,
          with: .color(axisColor),
          lineWidth: GraphViewConstants.axisLineWidth
        )
      }

      // Draw Y axis.
      if let yPath = yAxis {
        context.stroke(
          yPath,
          with: .color(axisColor),
          lineWidth: GraphViewConstants.axisLineWidth
        )
      }
    }
    .overlay(tickLabelsOverlay)
  }

  private var tickLabelsOverlay: some View {
    GeometryReader { geometry in
      let xTicks = renderer.calculateTicks(
        viewModel.specification.axes.x,
        viewport: viewModel.currentViewport,
        viewSize: geometry.size,
        isXAxis: true
      )
      let yTicks = renderer.calculateTicks(
        viewModel.specification.axes.y,
        viewport: viewModel.currentViewport,
        viewSize: geometry.size,
        isXAxis: false
      )

      ZStack {
        // X axis tick labels.
        ForEach(xTicks, id: \.value) { tick in
          Text(tick.label)
            .font(.caption2)
            .foregroundColor(.secondary)
            .position(
              x: tick.screenPosition,
              y: geometry.size.height - 10
            )
        }

        // Y axis tick labels.
        ForEach(yTicks, id: \.value) { tick in
          Text(tick.label)
            .font(.caption2)
            .foregroundColor(.secondary)
            .position(
              x: 20,
              y: tick.screenPosition
            )
        }
      }
    }
  }

  // MARK: - Equations Layer

  private var equationsLayer: some View {
    SwiftUI.Canvas { context, size in
      for equation in viewModel.specification.equations {
        let result = renderer.renderEquation(
          equation,
          viewport: viewModel.currentViewport,
          viewSize: size,
          parser: parser
        )

        guard result.isValid else { continue }

        let strokeColor = Color(hex: result.style.color) ?? .blue
        let lineWidth = CGFloat(result.style.lineWidth)
        let dashPattern = LineDashPattern.from(result.style.lineStyle)

        // Draw fill path first (behind stroke).
        if let fillPath = result.fillPath {
          let fillColor = Color(hex: result.style.fillColor ?? result.style.color)?
            .opacity(Double(result.style.fillOpacity ?? 0.3)) ?? Color.blue.opacity(0.3)
          context.fill(fillPath, with: .color(fillColor))
        }

        // Draw stroke paths.
        for path in result.strokePaths {
          if dashPattern.pattern.isEmpty {
            // Solid line.
            context.stroke(
              path,
              with: .color(strokeColor),
              lineWidth: lineWidth
            )
          } else {
            // Dashed or dotted line.
            context.stroke(
              path,
              with: .color(strokeColor),
              style: StrokeStyle(
                lineWidth: lineWidth,
                lineCap: .round,
                lineJoin: .round,
                dash: dashPattern.pattern.map { CGFloat($0) },
                dashPhase: CGFloat(dashPattern.phase)
              )
            )
          }
        }
      }
    }
  }

  // MARK: - Points Layer

  private var pointsLayer: some View {
    GeometryReader { geometry in
      let renderedPoints = (viewModel.specification.points ?? []).map { point in
        renderer.renderPoint(
          point,
          viewport: viewModel.currentViewport,
          viewSize: geometry.size
        )
      }

      ZStack {
        ForEach(renderedPoints, id: \.pointID) { point in
          pointView(for: point)
        }
      }
    }
  }

  @ViewBuilder
  private func pointView(for point: RenderedPoint) -> some View {
    let color = Color(hex: point.style.color) ?? .blue
    let size = CGFloat(point.style.size)

    ZStack {
      // Point shape.
      switch point.style.shape {
      case .circle:
        Circle()
          .fill(color)
          .frame(width: size, height: size)
      case .square:
        Rectangle()
          .fill(color)
          .frame(width: size, height: size)
      case .triangle:
        Triangle()
          .fill(color)
          .frame(width: size, height: size)
      case .cross:
        Image(systemName: "plus")
          .font(.system(size: size))
          .foregroundColor(color)
      }

      // Point label.
      if let label = point.label {
        Text(label)
          .font(.caption)
          .foregroundColor(.primary)
          .offset(y: -size - 8)
      }
    }
    .position(point.screenPosition)
  }

  // MARK: - Annotations Layer

  private var annotationsLayer: some View {
    GeometryReader { geometry in
      let renderedAnnotations = (viewModel.specification.annotations ?? []).map { annotation in
        renderer.renderAnnotation(
          annotation,
          viewport: viewModel.currentViewport,
          viewSize: geometry.size
        )
      }

      ZStack {
        ForEach(Array(renderedAnnotations.enumerated()), id: \.offset) { _, annotation in
          if let text = annotation.text {
            Text(text)
              .font(.caption)
              .foregroundColor(.primary)
              .position(annotation.screenPosition)
          }
        }
      }
    }
  }

  // MARK: - Trace Overlay

  private var traceOverlay: some View {
    GeometryReader { geometry in
      if let state = viewModel.traceState {
        let screenPoint = viewModel.graphToScreen(state.position)

        ZStack {
          // Trace indicator (crosshairs).
          Circle()
            .stroke(Color.accentColor, lineWidth: 2)
            .frame(width: 20, height: 20)
            .position(screenPoint)

          // Vertical line.
          SwiftUI.Path { path in
            path.move(to: CGPoint(x: screenPoint.x, y: 0))
            path.addLine(to: CGPoint(x: screenPoint.x, y: geometry.size.height))
          }
          .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)

          // Horizontal line.
          SwiftUI.Path { path in
            path.move(to: CGPoint(x: 0, y: screenPoint.y))
            path.addLine(to: CGPoint(x: geometry.size.width, y: screenPoint.y))
          }
          .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)

          // Coordinate tooltip.
          coordinateTooltip(for: state, screenPoint: screenPoint, viewSize: geometry.size)
        }
      }
    }
  }

  private func coordinateTooltip(for state: TraceState, screenPoint: CGPoint, viewSize: CGSize)
    -> some View
  {
    let xText = formatCoordinate(state.position.x)
    let yText: String
    if let y = state.yValue {
      yText = formatCoordinate(y)
    } else {
      yText = formatCoordinate(state.position.y)
    }

    // Position tooltip to avoid edges.
    let tooltipX =
      screenPoint.x < viewSize.width / 2
      ? screenPoint.x + GraphViewConstants.tooltipOffset + 40
      : screenPoint.x - GraphViewConstants.tooltipOffset - 40
    let tooltipY =
      screenPoint.y < viewSize.height / 2
      ? screenPoint.y + GraphViewConstants.tooltipOffset
      : screenPoint.y - GraphViewConstants.tooltipOffset

    return Text("(\(xText), \(yText))")
      .font(.caption)
      .padding(6)
      .background(Color(UIColor.secondarySystemBackground))
      .cornerRadius(4)
      .shadow(radius: 2)
      .position(x: tooltipX, y: tooltipY)
  }

  private func formatCoordinate(_ value: Double) -> String {
    if abs(value) < 0.0001 && value != 0 {
      return String(format: "%.2e", value)
    } else if abs(value) >= 10000 {
      return String(format: "%.2e", value)
    } else {
      return String(format: "%.4g", value)
    }
  }

  // MARK: - Gestures

  @GestureState private var magnifyBy: CGFloat = 1.0
  @GestureState private var dragOffset: CGSize = .zero
  @State private var isLongPressing = false

  private var combinedGesture: some Gesture {
    let drag = DragGesture()
      .onChanged { value in
        if isLongPressing {
          // Update trace.
          viewModel.updateTrace(to: value.location)
        } else {
          // Pan.
          viewModel.pan(by: value.translation)
        }
      }
      .onEnded { _ in
        if isLongPressing {
          viewModel.endTrace()
          isLongPressing = false
          onTraceEnded?()
        }
        notifyViewportChange()
      }

    let magnify = MagnifyGesture()
      .onChanged { value in
        let center = CGPoint(
          x: viewModel.viewSize.width / 2,
          y: viewModel.viewSize.height / 2
        )
        viewModel.zoom(scale: value.magnification, around: center)
      }
      .onEnded { _ in
        notifyViewportChange()
      }

    let longPress = LongPressGesture(minimumDuration: GraphViewConstants.traceActivationDuration)
      .onEnded { _ in
        isLongPressing = true
      }
      .sequenced(before: DragGesture())
      .onChanged { value in
        switch value {
        case .first:
          break
        case .second(_, let dragValue):
          if let drag = dragValue {
            if !isLongPressing {
              isLongPressing = true
              viewModel.startTrace(at: drag.startLocation)
              if let state = viewModel.traceState {
                onTraceStarted?(state.equationID)
              }
            }
            viewModel.updateTrace(to: drag.location)
          }
        }
      }
      .onEnded { _ in
        viewModel.endTrace()
        isLongPressing = false
        onTraceEnded?()
      }

    return SimultaneousGesture(
      SimultaneousGesture(drag, magnify),
      longPress
    )
  }

  private func notifyViewportChange() {
    onViewportChanged?(viewModel.currentViewport.toGraphViewport())
  }
}

// MARK: - Triangle Shape

// Custom shape for triangle point markers.
struct Triangle: Shape {
  func path(in rect: CGRect) -> SwiftUI.Path {
    var path = SwiftUI.Path()
    path.move(to: CGPoint(x: rect.midX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
    path.closeSubpath()
    return path
  }
}

// MARK: - Color Extension

extension Color {
  // Creates a Color from a hex string (e.g., "#FF0000" or "FF0000").
  init?(hex: String) {
    var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

    var rgb: UInt64 = 0
    guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    if hexSanitized.count == 6 {
      red = Double((rgb & 0xFF0000) >> 16) / 255.0
      green = Double((rgb & 0x00FF00) >> 8) / 255.0
      blue = Double(rgb & 0x0000FF) / 255.0
      alpha = 1.0
    } else if hexSanitized.count == 8 {
      red = Double((rgb & 0xFF00_0000) >> 24) / 255.0
      green = Double((rgb & 0x00FF_0000) >> 16) / 255.0
      blue = Double((rgb & 0x0000_FF00) >> 8) / 255.0
      alpha = Double(rgb & 0x0000_00FF) / 255.0
    } else {
      return nil
    }

    self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
  }
}

// MARK: - Preview

#Preview {
  let spec = GraphSpecification(
    version: "1.0",
    title: "Preview Graph",
    viewport: GraphViewport(xMin: -10, xMax: 10, yMin: -10, yMax: 10, aspectRatio: .auto),
    axes: GraphAxes(
      x: AxisConfiguration(label: "x", gridSpacing: nil, showGrid: true, showAxis: true, tickLabels: true),
      y: AxisConfiguration(label: "y", gridSpacing: nil, showGrid: true, showAxis: true, tickLabels: true)
    ),
    equations: [
      GraphEquation(
        id: "parabola",
        type: .explicit,
        expression: "x^2",
        xExpression: nil,
        yExpression: nil,
        rExpression: nil,
        variable: nil,
        parameter: nil,
        domain: nil,
        parameterRange: nil,
        thetaRange: nil,
        style: EquationStyle(
          color: "#FF0000",
          lineWidth: 2,
          lineStyle: .solid,
          fillBelow: nil,
          fillAbove: nil,
          fillColor: nil,
          fillOpacity: nil
        ),
        label: "x²",
        visible: true,
        fillRegion: nil,
        boundaryStyle: nil
      ),
      GraphEquation(
        id: "sine",
        type: .explicit,
        expression: "sin(x)",
        xExpression: nil,
        yExpression: nil,
        rExpression: nil,
        variable: nil,
        parameter: nil,
        domain: nil,
        parameterRange: nil,
        thetaRange: nil,
        style: EquationStyle(
          color: "#0000FF",
          lineWidth: 2,
          lineStyle: .solid,
          fillBelow: nil,
          fillAbove: nil,
          fillColor: nil,
          fillOpacity: nil
        ),
        label: "sin(x)",
        visible: true,
        fillRegion: nil,
        boundaryStyle: nil
      ),
    ],
    points: nil,
    annotations: nil,
    interactivity: GraphInteractivity(
      allowPan: true,
      allowZoom: true,
      allowTrace: true,
      showCoordinates: true,
      snapToGrid: false
    )
  )

  GraphView(viewModel: GraphViewModel(specification: spec))
    .frame(width: 400, height: 400)
}
