//
// GraphicsBlockView.swift
// InkOS
//
// SwiftUI view for rendering GraphicsContent blocks via WKWebView.
// Supports Chart.js, p5.js, Three.js, JSXGraph, Plotly with KaTeX overlays.
//

import SwiftUI
import WebKit

// MARK: - GraphicsBlockView

// SwiftUI wrapper for graphics rendering via WebView.
struct GraphicsBlockView: View {
  let content: GraphicsContent

  // Callback for interactive parameter changes from the WebView.
  var onParameterChange: ((String, Double) -> Void)?

  @State private var webViewHeight: CGFloat = 300

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      GraphicsWebView(
        content: content,
        height: $webViewHeight,
        onParameterChange: onParameterChange
      )
      .frame(height: calculatedHeight)
      .clipShape(RoundedRectangle(cornerRadius: 8))

      if let caption = content.caption {
        Text(caption)
          .font(.caption)
          .foregroundColor(.secondary)
          .padding(.horizontal, 8)
      }
    }
  }

  private var calculatedHeight: CGFloat {
    if let sizing = content.sizing {
      if let height = sizing.height {
        return height
      }
      if let aspectRatio = sizing.aspectRatio {
        // Use screen width minus some padding.
        let width = UIScreen.main.bounds.width - 32
        return width / aspectRatio
      }
    }
    return webViewHeight
  }
}

// MARK: - GraphicsWebView

// UIViewRepresentable wrapper for WKWebView.
struct GraphicsWebView: UIViewRepresentable {
  let content: GraphicsContent
  @Binding var height: CGFloat
  let onParameterChange: ((String, Double) -> Void)?

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  func makeUIView(context: Context) -> WKWebView {
    let config = WKWebViewConfiguration()

    // Allow inline media playback.
    config.allowsInlineMediaPlayback = true
    config.mediaTypesRequiringUserActionForPlayback = []

    // Add message handler for callbacks from JavaScript.
    config.userContentController.add(context.coordinator, name: "graphicsCallback")

    let webView = WKWebView(frame: .zero, configuration: config)
    webView.navigationDelegate = context.coordinator
    webView.scrollView.isScrollEnabled = false
    webView.scrollView.bounces = false
    webView.isOpaque = false
    webView.backgroundColor = .clear
    webView.scrollView.backgroundColor = .clear

    // Disable zoom gestures.
    webView.scrollView.minimumZoomScale = 1.0
    webView.scrollView.maximumZoomScale = 1.0

    return webView
  }

  func updateUIView(_ webView: WKWebView, context: Context) {
    let html = HTMLRenderer.render(content)
    webView.loadHTMLString(html, baseURL: nil)
  }

  // MARK: - Coordinator

  class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    var parent: GraphicsWebView

    init(_ parent: GraphicsWebView) {
      self.parent = parent
    }

    // Handle messages from JavaScript.
    func userContentController(
      _ userContentController: WKUserContentController,
      didReceive message: WKScriptMessage
    ) {
      guard let body = message.body as? [String: Any] else { return }

      if let type = body["type"] as? String {
        switch type {
        case "parameterChange":
          // Handle interactive parameter updates.
          if let name = body["name"] as? String,
             let value = body["value"] as? Double {
            DispatchQueue.main.async {
              self.parent.onParameterChange?(name, value)
            }
          }

        case "heightUpdate":
          // Handle dynamic height changes from content.
          if let height = body["height"] as? Double {
            DispatchQueue.main.async {
              self.parent.height = height
            }
          }

        case "error":
          // Log errors from JavaScript.
          if let errorMessage = body["message"] as? String {
            print("[GraphicsWebView] JS Error: \(errorMessage)")
          }

        default:
          break
        }
      }
    }

    // Navigation delegate methods.
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      // Optionally measure content height after load.
      webView.evaluateJavaScript("document.body.scrollHeight") { [weak self] result, _ in
        if let height = result as? CGFloat, height > 0 {
          DispatchQueue.main.async {
            self?.parent.height = min(height, 600) // Cap at reasonable max.
          }
        }
      }
    }

    func webView(
      _ webView: WKWebView,
      didFail navigation: WKNavigation!,
      withError error: Error
    ) {
      print("[GraphicsWebView] Navigation failed: \(error.localizedDescription)")
    }
  }
}

// MARK: - Preview

#if DEBUG
struct GraphicsBlockView_Previews: PreviewProvider {
  static var previews: some View {
    // Sample Chart.js content for preview.
    let chartContent = GraphicsContent(
      engine: .chartjs,
      spec: .chartjs(ChartJSSpec(
        chartType: .line,
        data: ChartJSData(
          labels: ["A", "B", "C", "D"],
          datasets: [
            ChartJSDataset(
              label: "Sample Data",
              data: [10, 20, 15, 30],
              backgroundColor: AnyCodable("rgba(33, 150, 243, 0.2)"),
              borderColor: AnyCodable("#2196F3"),
              borderWidth: 2
            ),
          ]
        )
      )),
      sizing: GraphicsSizing(width: "100%", height: 250),
      caption: "Sample Chart"
    )

    GraphicsBlockView(content: chartContent)
      .padding()
      .previewLayout(.sizeThatFits)
  }
}
#endif
