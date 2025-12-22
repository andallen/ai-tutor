import UIKit

// Bundles the views used to render model and capture layers.
final class DisplayModel {
    // Draws the persistent content layer.
    let modelRenderView = RenderView(frame: .zero, layer: .model)

    // Draws the transient capture strokes layer.
    let captureRenderView = RenderView(frame: .zero, layer: .capture)
}