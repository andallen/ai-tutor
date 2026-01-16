//
// MetaballMetalView.swift
// InkOS
//
// UIViewRepresentable that wraps MTKView for Metal shader rendering.
// Renders the metaball animation with parameterized uniforms.
//

import MetalKit
import SwiftUI

// MARK: - MetaballMetalView

// SwiftUI view that renders the metaball shader using Metal.
struct MetaballMetalView: UIViewRepresentable {
  let time: Float
  let speedMultiplier: Float
  let movementRange: Float
  let breathAmplitude: Float
  let vertexCount: Float

  func makeUIView(context: Context) -> MTKView {
    let mtkView = MTKView()
    mtkView.device = MTLCreateSystemDefaultDevice()
    mtkView.delegate = context.coordinator
    mtkView.enableSetNeedsDisplay = false
    mtkView.isPaused = false
    mtkView.preferredFramesPerSecond = 60
    mtkView.isOpaque = false
    mtkView.backgroundColor = .clear
    mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
    return mtkView
  }

  func updateUIView(_ uiView: MTKView, context: Context) {
    context.coordinator.updateUniforms(
      time: time,
      speedMultiplier: speedMultiplier,
      movementRange: movementRange,
      breathAmplitude: breathAmplitude,
      vertexCount: vertexCount
    )
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  // MARK: - Coordinator

  class Coordinator: NSObject, MTKViewDelegate {
    private var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var pipelineState: MTLRenderPipelineState?
    private var vertexBuffer: MTLBuffer?
    private var uniformBuffer: MTLBuffer?

    // Current uniform values.
    private var currentTime: Float = 0
    private var currentSpeedMultiplier: Float = 0.6
    private var currentMovementRange: Float = 0.12
    private var currentBreathAmplitude: Float = 0.0
    private var currentVertexCount: Float = 10.0

    override init() {
      super.init()
      setupMetal()
    }

    func updateUniforms(time: Float, speedMultiplier: Float, movementRange: Float, breathAmplitude: Float, vertexCount: Float) {
      currentTime = time
      currentSpeedMultiplier = speedMultiplier
      currentMovementRange = movementRange
      currentBreathAmplitude = breathAmplitude
      currentVertexCount = vertexCount
    }

    private func setupMetal() {
      guard let device = MTLCreateSystemDefaultDevice() else {
        print("Metal is not supported on this device")
        return
      }
      self.device = device
      self.commandQueue = device.makeCommandQueue()

      // Create vertex buffer for a fullscreen quad.
      // Format: position (x, y), uv (u, v)
      let vertices: [Float] = [
        // Triangle 1
        -1.0, -1.0, -1.0, -1.0,
        1.0, -1.0, 1.0, -1.0,
        -1.0, 1.0, -1.0, 1.0,
        // Triangle 2
        1.0, -1.0, 1.0, -1.0,
        1.0, 1.0, 1.0, 1.0,
        -1.0, 1.0, -1.0, 1.0
      ]
      vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.size, options: [])

      // Create uniform buffer.
      uniformBuffer = device.makeBuffer(length: MemoryLayout<Float>.size * 5, options: [])

      // Load shaders and create pipeline.
      guard let library = device.makeDefaultLibrary() else {
        print("Could not load Metal library")
        return
      }

      let vertexFunction = library.makeFunction(name: "metaball_vertex")
      let fragmentFunction = library.makeFunction(name: "metaball_fragment")

      let pipelineDescriptor = MTLRenderPipelineDescriptor()
      pipelineDescriptor.vertexFunction = vertexFunction
      pipelineDescriptor.fragmentFunction = fragmentFunction
      pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

      // Enable alpha blending for transparency.
      pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
      pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
      pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
      pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
      pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

      // Set up vertex descriptor.
      let vertexDescriptor = MTLVertexDescriptor()
      vertexDescriptor.attributes[0].format = .float2
      vertexDescriptor.attributes[0].offset = 0
      vertexDescriptor.attributes[0].bufferIndex = 0
      vertexDescriptor.attributes[1].format = .float2
      vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.size * 2
      vertexDescriptor.attributes[1].bufferIndex = 0
      vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.size * 4
      pipelineDescriptor.vertexDescriptor = vertexDescriptor

      do {
        pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
      } catch {
        print("Could not create pipeline state: \(error)")
      }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
      guard let drawable = view.currentDrawable,
            let descriptor = view.currentRenderPassDescriptor,
            let pipelineState = pipelineState,
            let commandQueue = commandQueue,
            let vertexBuffer = vertexBuffer,
            let uniformBuffer = uniformBuffer else { return }

      // Update uniform buffer with current values.
      var uniforms: [Float] = [
        currentTime,
        currentSpeedMultiplier,
        currentMovementRange,
        currentBreathAmplitude,
        currentVertexCount
      ]
      memcpy(uniformBuffer.contents(), &uniforms, MemoryLayout<Float>.size * 5)

      // Create command buffer and encoder.
      guard let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }

      encoder.setRenderPipelineState(pipelineState)
      encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
      encoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
      encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
      encoder.endEncoding()

      commandBuffer.present(drawable)
      commandBuffer.commit()
    }
  }
}
