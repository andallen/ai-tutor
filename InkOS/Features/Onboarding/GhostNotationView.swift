import SwiftUI

// Background effect showing faint equations and symbols drifting through the void.
// Uses typewriter-style reveal animation where text appears character-by-character.
struct GhostNotationView: View {
    // Adjustable parameters
    var speed: Double = 1.0  // 0-10 animation speed multiplier
    var opacity: Double = 0.12  // 0-1 base opacity
    var density: Int = 10  // 1-15 number of equations on screen

    // Exclusion zones to avoid (e.g., progress bar, question content)
    var exclusionZones: [CGRect] = []

    // Trigger to force re-initialization with new random positions
    var refreshTrigger: UUID = UUID()

    // Respect reduce motion accessibility setting
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            if reduceMotion {
                // Static version for reduced motion
                StaticNotationView(
                    density: density,
                    opacity: opacity,
                    bounds: geometry.size,
                    exclusionZones: exclusionZones,
                    refreshTrigger: refreshTrigger
                )
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("ghost_notation_view")
                .accessibilityLabel("Ghost notation background")
            } else {
                // Animated version
                AnimatedNotationView(
                    speed: speed,
                    opacity: opacity,
                    density: density,
                    bounds: geometry.size,
                    exclusionZones: exclusionZones,
                    refreshTrigger: refreshTrigger
                )
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("ghost_notation_view")
                .accessibilityLabel("Ghost notation background")
            }
        }
        .allowsHitTesting(false)
    }
}

// Animated version using TimelineView for smooth 60fps animation.
private struct AnimatedNotationView: View {
    let speed: Double
    let opacity: Double
    let density: Int
    let bounds: CGSize
    let exclusionZones: [CGRect]
    let refreshTrigger: UUID

    @State private var particles: [EquationParticle] = []
    @State private var hasInitialized = false

    var body: some View {
        ZStack {
            TimelineView(.animation) { timeline in
                SwiftUI.Canvas { context, size in
                    let time = timeline.date.timeIntervalSinceReferenceDate * speed

                    for index in particles.indices {
                        let particle = particles[index]
                        let cycleTime = (time / particle.cycleDuration) + particle.cycleOffset
                        let progress = cycleTime.truncatingRemainder(dividingBy: 1.0)

                        // Detect cycle wrap-around: was in hidden phase, now starting new cycle
                        if particle.lastProgress > 0.85 && progress < 0.15 {
                            repositionParticle(at: index)
                        }
                        particles[index].lastProgress = progress

                        drawEquation(particles[index], progress: progress, in: &context, size: size)
                    }
                }
            }
        }
        .onAppear {
            // Initialize particles when view first appears
            if !hasInitialized && bounds.width > 100 && bounds.height > 100 {
                initializeParticles()
            }
        }
        .onChange(of: bounds) { _, newBounds in
            // Reinitialize if bounds change significantly
            if !hasInitialized && newBounds.width > 100 && newBounds.height > 100 {
                initializeParticles()
            }
        }
        .onChange(of: density) { _, _ in
            hasInitialized = false
            initializeParticles()
        }
        .onChange(of: exclusionZones) { _, newZones in
            // Reinitialize when exclusion zones change
            if !newZones.isEmpty {
                hasInitialized = false  // Force re-initialization
                initializeParticles()
            }
        }
        .onChange(of: refreshTrigger) { _, _ in
            // Reinitialize with new random positions when refresh is triggered
            hasInitialized = false
            initializeParticles()
        }
    }

    // Reposition a particle to a new location with new equation text.
    private func repositionParticle(at index: Int) {
        guard index < particles.count else { return }

        let newEquation = GhostEquations.random()
        let newDepth = DepthLayer.random()
        let fontSize = newDepth.fontSize

        // Estimate text size (Chalkduster is wider than typical fonts)
        let estimatedWidth = CGFloat(newEquation.count) * fontSize * 0.75
        let estimatedHeight = fontSize * 1.6
        let size = CGSize(width: estimatedWidth, height: estimatedHeight)

        // Build list of other particle boxes to avoid
        var otherBoxes: [CGRect] = []
        for (i, p) in particles.enumerated() where i != index {
            let pWidth = CGFloat(p.equation.count) * p.depthLayer.fontSize * 0.6
            let pHeight = p.depthLayer.fontSize * 1.5
            otherBoxes.append(CGRect(origin: p.position, size: CGSize(width: pWidth, height: pHeight)))
        }

        // Find new position
        guard let newPosition = findNonOverlappingPosition(
            for: size,
            avoiding: otherBoxes,
            excluding: exclusionZones,
            in: CGRect(origin: .zero, size: bounds)
        ) else {
            // Can't find valid position - move particle offscreen to hide it
            particles[index].position = CGPoint(x: -1000, y: -1000)
            return
        }

        particles[index].equation = newEquation
        particles[index].position = newPosition
        particles[index].depthLayer = newDepth
    }

    // Initialize equation particles with random positions and timings.
    private func initializeParticles() {
        // Don't initialize if bounds aren't ready
        guard bounds.width > 100, bounds.height > 100 else { return }
        hasInitialized = true

        var newParticles: [EquationParticle] = []
        var occupiedRects: [CGRect] = []

        for index in 0..<density {
            let equation = GhostEquations.random()
            let depthLayer = DepthLayer.random()
            let fontSize = depthLayer.fontSize

            // Estimate text size for handwritten font
            let estimatedWidth = CGFloat(equation.count) * fontSize * 0.6
            let estimatedHeight = fontSize * 1.5
            let size = CGSize(width: estimatedWidth, height: estimatedHeight)

            // Find non-overlapping position
            guard let position = findNonOverlappingPosition(
                for: size,
                avoiding: occupiedRects,
                excluding: exclusionZones,
                in: CGRect(origin: .zero, size: bounds)
            ) else {
                // Skip this particle if we can't find a valid position
                continue
            }

            let rect = CGRect(origin: position, size: size)
            occupiedRects.append(rect)

            // Stagger cycle offsets so equations don't all appear/disappear together
            let staggeredOffset = Double(index) / Double(density)

            let particle = EquationParticle(
                id: index,
                equation: equation,
                position: position,
                depthLayer: depthLayer,
                cycleOffset: staggeredOffset,
                cycleDuration: Double.random(in: 8...14)
            )
            newParticles.append(particle)
        }

        particles = newParticles
    }

    // Draw a single equation with typewriter reveal effect using clipping.
    private func drawEquation(_ particle: EquationParticle, progress: Double, in context: inout GraphicsContext, size: CGSize) {
        // Calculate clip percentages for typewriter effect
        var clipStart: CGFloat = 0  // Left edge of visible area (0 = start of text)
        var clipEnd: CGFloat = 1    // Right edge of visible area (1 = end of text)
        var fadeOpacity: CGFloat = 1.0

        if progress < 0.30 {
            // Type on: reveal left to right
            let revealProgress = progress / 0.30
            clipEnd = revealProgress
            fadeOpacity = min(1.0, revealProgress * 2.5)
        } else if progress < 0.50 {
            // Hold: fully visible
            clipStart = 0
            clipEnd = 1
            fadeOpacity = 1.0
        } else if progress < 0.80 {
            // Type off: erase left to right
            let eraseProgress = (progress - 0.50) / 0.30
            clipStart = eraseProgress
            fadeOpacity = 1.0 - (eraseProgress * 0.3)
        } else {
            // Hidden phase before repositioning
            fadeOpacity = 0
        }

        // Skip if nothing to draw
        if clipStart >= clipEnd || fadeOpacity <= 0 {
            return
        }

        let baseOpacity = opacity * particle.depthLayer.opacityMultiplier * fadeOpacity
        let fontSize = particle.depthLayer.fontSize

        // Use pen-style handwritten font
        let font: UIFont = UIFont(name: "Bradley Hand", size: fontSize)
            ?? UIFont(name: "Noteworthy-Light", size: fontSize)
            ?? UIFont.italicSystemFont(ofSize: fontSize)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor(AlanColors.textPrimary).withAlphaComponent(baseOpacity)
        ]

        let attributedString = NSAttributedString(string: particle.equation, attributes: attributes)
        let textSize = attributedString.size()

        // Calculate the clipping rectangle in absolute coordinates
        let clipX = particle.position.x + (textSize.width * clipStart)
        let clipWidth = textSize.width * (clipEnd - clipStart)
        let clipRect = CGRect(
            x: clipX,
            y: particle.position.y - 4,
            width: clipWidth,
            height: textSize.height + 8
        )

        // Draw in isolated layer so clip doesn't affect other particles
        context.drawLayer { layerContext in
            layerContext.clip(to: SwiftUI.Path(clipRect))
            layerContext.draw(
                Text(AttributedString(attributedString)),
                at: particle.position,
                anchor: .topLeading
            )
        }
    }

    // Find a position that doesn't overlap with existing rects or the exclusion zone.
    private func findNonOverlappingPosition(
        for size: CGSize,
        avoiding existingBoxes: [CGRect],
        excluding exclusionZones: [CGRect],
        in bounds: CGRect
    ) -> CGPoint? {
        let padding: CGFloat = 20

        for _ in 0..<500 {
            let x = CGFloat.random(in: padding...(bounds.width - size.width - padding))
            let y = CGFloat.random(in: padding...(bounds.height - size.height - padding))
            let candidateRect = CGRect(origin: CGPoint(x: x, y: y), size: size)
                .insetBy(dx: -padding, dy: -padding)

            // Check all exclusion zones
            var intersectsExclusionZone = false
            for zone in exclusionZones where !zone.isEmpty {
                if candidateRect.intersects(zone) {
                    intersectsExclusionZone = true
                    break
                }
            }
            if intersectsExclusionZone {
                continue
            }

            // Check existing equations
            let hasOverlap = existingBoxes.contains { $0.intersects(candidateRect) }
            if !hasOverlap {
                return CGPoint(x: x, y: y)
            }
        }

        return nil
    }
}

// Static version for reduced motion preference.
private struct StaticNotationView: View {
    let density: Int
    let opacity: Double
    let bounds: CGSize
    let exclusionZones: [CGRect]
    let refreshTrigger: UUID

    var body: some View {
        ForEach(0..<density, id: \.self) { index in
            let equation = GhostEquations.equations[index % GhostEquations.equations.count]
            let depthLayer = DepthLayer.allCases[index % 3]

            Text(equation)
                .font(.custom("Bradley Hand", size: depthLayer.fontSize))
                .foregroundColor(AlanColors.textPrimary)
                .opacity(opacity * depthLayer.opacityMultiplier)
                .position(
                    x: CGFloat(index * 180).truncatingRemainder(dividingBy: max(1, bounds.width - 180)) + 90,
                    y: CGFloat(index * 120).truncatingRemainder(dividingBy: max(1, bounds.height - 80)) + 40
                )
        }
        .id(refreshTrigger)  // Force view recreation with new positions when trigger changes
    }
}

// Represents a single floating equation.
private struct EquationParticle: Identifiable {
    let id: Int
    var equation: String
    var position: CGPoint
    var depthLayer: DepthLayer
    let cycleOffset: Double
    let cycleDuration: Double
    var lastProgress: Double = 0
}

// Depth layers affect size and opacity of equations.
private enum DepthLayer: CaseIterable {
    case far
    case mid
    case near

    var fontSize: CGFloat {
        switch self {
        case .far: return 26
        case .mid: return 32
        case .near: return 38
        }
    }

    var opacityMultiplier: Double {
        switch self {
        case .far: return 0.6
        case .mid: return 0.8
        case .near: return 1.0
        }
    }

    static func random() -> DepthLayer {
        allCases.randomElement() ?? .mid
    }
}

// Collection of equations and symbols from various disciplines.
// Uses Unicode math symbols with font fallback (Bradley Hand for text, system fonts for math glyphs).
private enum GhostEquations {
    static let equations: [String] = [
        // Mathematics - Iconic
        "e^(iπ) + 1 = 0",           // Euler's identity
        "a² + b² = c²",              // Pythagorean theorem
        "∫₀^∞ e^(-x²) dx = √π/2",
        "lim(x→∞) = L",
        "∂u/∂t = c²∇²u",            // Wave equation
        "∑ᵢ₌₁^∞ 1/n²",
        "dy/dx = f(x,y)",
        "f'(x) = df/dx",
        "∇ × E = -∂B/∂t",           // Maxwell
        "∇ · B = 0",
        "Δx · Δp ≥ ℏ/2",            // Heisenberg uncertainty

        // Physics - Core Laws
        "E = mc²",
        "F = ma",
        "F = GMm/r²",                // Universal gravitation
        "PV = nRT",
        "W = ∫ F · ds",
        "F = -kx",                   // Hooke's law
        "ΔS ≥ 0",                    // Entropy
        "λ = h/p",                   // de Broglie
        "v = λf",
        "τ = r × F",
        "L = Iω",

        // Computer Science - Theory
        "P = NP ?",
        "O(n log n)",
        "O(2ⁿ)",
        "Θ(n²)",
        "P ⊆ NP ⊆ PSPACE",
        "halting problem",
        "Turing completeness",
        "λx.x",                      // Lambda calculus
        "∀x ∈ S: P(x)",
        "Church-Turing thesis",
        "Gödel incompleteness",

        // Statistics & Data Science
        "p < 0.05",
        "r = 0.95",
        "N = 1,247",
        "χ² test",
        "CI: [μ ± 1.96σ]",
        "β₁ ≠ 0",
        "H₀: μ₁ = μ₂",
        "P(A|B) = P(B|A)P(A)/P(B)",  // Bayes' theorem
        "σ² = E[(X-μ)²]",

        // Philosophy - Major Concepts
        "cogito ergo sum",
        "esse est percipi",          // Berkeley: to be is to be perceived
        "memento mori",
        "amor fati",
        "the examined life",
        "being-in-itself",
        "Dasein (Heidegger)",
        "the absurd (Camus)",
        "categorical imperative",
        "Übermensch",
        "tabula rasa",
        "a priori",

        // Economics - Theory
        "Nash equilibrium",
        "Pareto efficiency",
        "∂U/∂x = 0",                 // Utility maximization
        "MR = MC",
        "supply = demand",
        "tragedy of commons",
        "moral hazard",
        "efficient markets",
        "ROI = 12.5%",
        "NPV > 0",
        "P/E = 18.2",

        // Legal - Landmark Cases & Doctrine
        "Marbury v. Madison",
        "Brown v. Board",
        "Miranda v. Arizona",
        "Roe v. Wade",
        "res ipsa loquitur",
        "habeas corpus",
        "stare decisis",
        "strict scrutiny",
        "rational basis review",
        "substantive due process",
        "pro bono",

        // Medicine & Biology
        "Rx: 20mg BID",
        "BP: 120/80 mmHg",
        "BMI = 22.4",
        "pH = 7.4 ± 0.05",
        "O₂ + 2H₂ → 2H₂O",
        "ATP → ADP + Pᵢ",
        "Hardy-Weinberg: p² + 2pq + q²",
        "double-blind RCT",
        "HR = 0.67, p<0.001",

        // Chemistry
        "ΔG = ΔH - TΔS",
        "pH = -log[H⁺]",
        "Kₐ = [H⁺][A⁻]/[HA]",
        "2H₂ + O₂ → 2H₂O",
        "C₆H₁₂O₆ + 6O₂",

        // Academic Citations
        "Smith, Wealth (1776)",
        "Darwin, Origin (1859)",
        "Marx, Kapital (1867)",
        "Keynes, General Theory",
        "Kuhn, Structure (1962)",
        "Rawls, Theory (1971)",
        "et al., 2024",
        "MLA 9th ed.",

        // Music Theory
        "120 BPM",
        "I-IV-V-I",
        "4/4 time",
        "A440 Hz",
        "allegro con brio",
        "sforzando"
    ]

    static func random() -> String {
        equations.randomElement() ?? "E = mc²"
    }
}

#if DEBUG
struct GhostNotationView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            AlanColors.void.ignoresSafeArea()
            GhostNotationView(
                speed: 1.0,
                opacity: 0.12,
                density: 10
            )
        }
        .previewDevice("iPad Pro (12.9-inch) (6th generation)")
    }
}
#endif
