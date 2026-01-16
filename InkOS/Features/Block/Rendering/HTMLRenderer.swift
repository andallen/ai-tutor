//
// HTMLRenderer.swift
// InkOS
//
// Generates HTML documents from GraphicsContent specs.
// Handles CDN script injection and engine-specific rendering.
//

import Foundation

// MARK: - HTMLRenderer

// Generates HTML from GraphicsContent for WebView rendering.
enum HTMLRenderer {

  // CDN URLs for visualization libraries.
  private static let cdnURLs: [String: String] = [
    "chartjs": "https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js",
    "p5": "https://cdn.jsdelivr.net/npm/p5@1.9.0/lib/p5.min.js",
    "three": "https://cdn.jsdelivr.net/npm/three@0.160.0/build/three.min.js",
    "jsxgraph_css": "https://cdn.jsdelivr.net/npm/jsxgraph@1.8.0/distrib/jsxgraph.css",
    "jsxgraph": "https://cdn.jsdelivr.net/npm/jsxgraph@1.8.0/distrib/jsxgraphcore.js",
    "plotly": "https://cdn.jsdelivr.net/npm/plotly.js-dist@2.29.1/plotly.min.js",
    "katex_css": "https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css",
    "katex_js": "https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js",
  ]

  // MARK: - Public API

  // Renders GraphicsContent to complete HTML document.
  static func render(_ content: GraphicsContent) -> String {
    switch content.engine {
    case .chartjs:
      return renderChartJS(content)
    case .p5:
      return renderP5(content)
    case .three:
      return renderThreeJS(content)
    case .jsxgraph:
      return renderJSXGraph(content)
    case .plotly:
      return renderPlotly(content)
    case .custom:
      return renderCustom(content)
    }
  }

  // MARK: - Base HTML Template

  private static func baseHTML(
    title: String,
    scripts: [String],
    styles: [String],
    bodyContent: String
  ) -> String {
    let scriptTags = scripts.map { "<script src=\"\($0)\"></script>" }.joined(separator: "\n    ")
    let styleTags = styles.map { "<link rel=\"stylesheet\" href=\"\($0)\">" }.joined(separator: "\n    ")

    return """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
      <title>\(title)</title>
      \(styleTags)
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        html, body { width: 100%; height: 100%; overflow: hidden; }
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
          background: #FAFAFA;
        }
        #container { position: relative; width: 100%; height: 100%; }
        #sketch-container { width: 100%; height: 100%; }
        .katex-overlay {
          position: absolute;
          pointer-events: none;
          font-size: 14px;
          background: rgba(255, 255, 255, 0.85);
          padding: 4px 8px;
          border-radius: 4px;
        }
        canvas { display: block; max-width: 100%; }
      </style>
      \(scriptTags)
    </head>
    <body>
      \(bodyContent)
    </body>
    </html>
    """
  }

  // MARK: - KaTeX Overlay Generation

  private static func katexOverlays(_ annotations: [KaTeXAnnotation]?) -> String {
    guard let annotations = annotations, !annotations.isEmpty else {
      return ""
    }

    var overlays = ""
    for (index, annotation) in annotations.enumerated() {
      let textAlign: String
      switch annotation.anchor {
      case .left: textAlign = "left"
      case .center: textAlign = "center"
      case .right: textAlign = "right"
      }

      // Calculate transform based on anchor.
      let transform: String
      switch annotation.anchor {
      case .left: transform = "translateY(-50%)"
      case .center: transform = "translate(-50%, -50%)"
      case .right: transform = "translate(-100%, -50%)"
      }

      overlays += """
        <div id="katex-\(index)" class="katex-overlay" style="
          left: \(annotation.x * 100)%;
          top: \(annotation.y * 100)%;
          text-align: \(textAlign);
          transform: \(transform);
        "></div>

      """
    }

    // Script to render KaTeX.
    var renderScript = "<script>\n"
    for (index, annotation) in annotations.enumerated() {
      let escapedLatex = annotation.latex
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "'", with: "\\'")
      renderScript += """
          katex.render('\(escapedLatex)', document.getElementById('katex-\(index)'), { throwOnError: false });

      """
    }
    renderScript += "</script>"

    return overlays + renderScript
  }

  // MARK: - Chart.js Renderer

  private static func renderChartJS(_ content: GraphicsContent) -> String {
    guard case .chartjs(let spec) = content.spec else {
      return errorHTML("Invalid ChartJS spec")
    }

    let chartConfig = encodeToJSON(spec)

    let bodyContent = """
      <div id="container">
        <canvas id="chart"></canvas>
      </div>
      <script>
        const ctx = document.getElementById('chart').getContext('2d');
        const config = \(chartConfig);
        // Map chart_type to type for Chart.js
        if (config.chart_type) {
          config.type = config.chart_type;
          delete config.chart_type;
        }
        new Chart(ctx, config);
      </script>
    """

    return baseHTML(
      title: content.caption ?? "Chart",
      scripts: [cdnURLs["chartjs"]!],
      styles: [],
      bodyContent: bodyContent
    )
  }

  // MARK: - p5.js Renderer

  private static func renderP5(_ content: GraphicsContent) -> String {
    guard case .p5(let spec) = content.spec else {
      return errorHTML("Invalid P5 spec")
    }

    let sketchCode = spec.customCode ?? defaultP5Sketch(spec.sketchType)
    let katexOverlayHTML = katexOverlays(spec.katexAnnotations)

    let bodyContent = """
      <div id="container">
        <div id="sketch-container"></div>
        \(katexOverlayHTML)
      </div>
      <script>
        \(sketchCode)
      </script>
    """

    var scripts = [cdnURLs["p5"]!]
    var styles: [String] = []

    // Include KaTeX if we have annotations.
    if let annotations = spec.katexAnnotations, !annotations.isEmpty {
      scripts.append(cdnURLs["katex_js"]!)
      styles.append(cdnURLs["katex_css"]!)
    }

    return baseHTML(
      title: content.caption ?? "Animation",
      scripts: scripts,
      styles: styles,
      bodyContent: bodyContent
    )
  }

  private static func defaultP5Sketch(_ sketchType: P5SketchType) -> String {
    // Default placeholder sketch.
    return """
    function setup() {
      let canvas = createCanvas(400, 300);
      canvas.parent('sketch-container');
    }

    function draw() {
      background(240);
      fill(33, 150, 243);
      ellipse(width/2, height/2, 50, 50);
    }
    """
  }

  // MARK: - Three.js Renderer

  private static func renderThreeJS(_ content: GraphicsContent) -> String {
    guard case .three(let spec) = content.spec else {
      return errorHTML("Invalid Three.js spec")
    }

    let sceneCode = spec.customCode ?? defaultThreeJSScene(spec)

    let bodyContent = """
      <div id="container"></div>
      <script>
        \(sceneCode)
      </script>
    """

    return baseHTML(
      title: content.caption ?? "3D Visualization",
      scripts: [cdnURLs["three"]!],
      styles: [],
      bodyContent: bodyContent
    )
  }

  private static func defaultThreeJSScene(_ spec: ThreeJSSpec) -> String {
    let autoRotate = spec.camera?.autoRotate ?? false

    return """
    const scene = new THREE.Scene();
    scene.background = new THREE.Color(0xfafafa);

    const camera = new THREE.PerspectiveCamera(75, window.innerWidth / window.innerHeight, 0.1, 1000);
    camera.position.z = 5;

    const renderer = new THREE.WebGLRenderer({ antialias: true });
    renderer.setSize(window.innerWidth, window.innerHeight);
    document.getElementById('container').appendChild(renderer.domElement);

    const geometry = new THREE.BoxGeometry(2, 2, 2);
    const material = new THREE.MeshStandardMaterial({ color: 0x2196F3 });
    const cube = new THREE.Mesh(geometry, material);
    scene.add(cube);

    const light = new THREE.DirectionalLight(0xffffff, 1);
    light.position.set(5, 5, 5);
    scene.add(light);
    scene.add(new THREE.AmbientLight(0x404040));

    function animate() {
      requestAnimationFrame(animate);
      \(autoRotate ? "cube.rotation.x += 0.01; cube.rotation.y += 0.01;" : "")
      renderer.render(scene, camera);
    }
    animate();

    window.addEventListener('resize', () => {
      camera.aspect = window.innerWidth / window.innerHeight;
      camera.updateProjectionMatrix();
      renderer.setSize(window.innerWidth, window.innerHeight);
    });
    """
  }

  // MARK: - JSXGraph Renderer

  private static func renderJSXGraph(_ content: GraphicsContent) -> String {
    guard case .jsxgraph(let spec) = content.spec else {
      return errorHTML("Invalid JSXGraph spec")
    }

    let boundingBox = spec.boundingBox ?? [-10, 10, 10, -10]
    let boundingBoxStr = "[\(boundingBox.map { String($0) }.joined(separator: ", "))]"

    // Build element creation code.
    var elementsCode = ""
    for element in spec.elements {
      let paramsStr = element.params.map { encodeToJSON($0) } ?? "[]"
      let attrsStr = element.attributes.map { encodeToJSON($0) } ?? "{}"
      elementsCode += """
        board.create('\(element.elementType.rawValue)', \(paramsStr), \(attrsStr));

      """
    }

    let bodyContent = """
      <div id="container">
        <div id="jxgbox" style="width: 100%; height: 100%;"></div>
      </div>
      <script>
        const board = JXG.JSXGraph.initBoard('jxgbox', {
          boundingbox: \(boundingBoxStr),
          axis: \(spec.axis),
          grid: \(spec.grid),
          showNavigation: false,
          showCopyright: false
        });
        \(elementsCode)
      </script>
    """

    return baseHTML(
      title: content.caption ?? "Geometry",
      scripts: [cdnURLs["jsxgraph"]!],
      styles: [cdnURLs["jsxgraph_css"]!],
      bodyContent: bodyContent
    )
  }

  // MARK: - Plotly Renderer

  private static func renderPlotly(_ content: GraphicsContent) -> String {
    guard case .plotly(let spec) = content.spec else {
      return errorHTML("Invalid Plotly spec")
    }

    let dataStr = encodeToJSON(spec.data)
    let layoutStr = spec.layout.map { encodeToJSON($0) } ?? "{}"
    let configStr = spec.config.map { encodeToJSON($0) } ?? "{ responsive: true }"

    let bodyContent = """
      <div id="container">
        <div id="plotly-chart" style="width: 100%; height: 100%;"></div>
      </div>
      <script>
        Plotly.newPlot('plotly-chart', \(dataStr), \(layoutStr), \(configStr));
      </script>
    """

    return baseHTML(
      title: content.caption ?? "Chart",
      scripts: [cdnURLs["plotly"]!],
      styles: [],
      bodyContent: bodyContent
    )
  }

  // MARK: - Custom HTML Renderer

  private static func renderCustom(_ content: GraphicsContent) -> String {
    guard case .custom(let spec) = content.spec else {
      return errorHTML("Invalid custom spec")
    }

    var scriptTags = ""
    if let scripts = spec.scripts {
      scriptTags = scripts.map { "<script src=\"\($0)\"></script>" }.joined(separator: "\n")
    }

    var styleTags = ""
    if let styles = spec.styles {
      styleTags = styles.map { "<link rel=\"stylesheet\" href=\"\($0)\">" }.joined(separator: "\n")
    }

    return """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
      \(styleTags)
    </head>
    <body>
      \(spec.html)
      \(scriptTags)
    </body>
    </html>
    """
  }

  // MARK: - Error HTML

  private static func errorHTML(_ message: String) -> String {
    return """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <style>
        body {
          display: flex;
          justify-content: center;
          align-items: center;
          height: 100vh;
          margin: 0;
          font-family: -apple-system, sans-serif;
          background: #FFF3E0;
          color: #E65100;
        }
      </style>
    </head>
    <body>
      <div>Error: \(message)</div>
    </body>
    </html>
    """
  }

  // MARK: - JSON Encoding

  private static func encodeToJSON<T: Encodable>(_ value: T) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    guard let data = try? encoder.encode(value),
          let jsonString = String(data: data, encoding: .utf8) else {
      return "{}"
    }
    return jsonString
  }

  private static func encodeToJSON(_ value: [AnyCodable]) -> String {
    let encoder = JSONEncoder()
    guard let data = try? encoder.encode(value),
          let jsonString = String(data: data, encoding: .utf8) else {
      return "[]"
    }
    return jsonString
  }

  private static func encodeToJSON(_ value: [String: AnyCodable]) -> String {
    let encoder = JSONEncoder()
    guard let data = try? encoder.encode(value),
          let jsonString = String(data: data, encoding: .utf8) else {
      return "{}"
    }
    return jsonString
  }
}
