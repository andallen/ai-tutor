//
// MetaballShader.metal
// InkOS
//
// Metal shader for the metaball presence indicator.
// A single parameterized shader that supports seamless transitions
// between idle, thinking, and outputting states by interpolating parameters.
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Uniforms

// Parameters passed from Swift to control animation behavior.
struct Uniforms {
  float time;
  float speedMultiplier;
  float movementRange;
  float breathAmplitude;
  float vertexCount;
};

// MARK: - Vertex Shader Types

struct VertexIn {
  float2 position [[attribute(0)]];
  float2 uv [[attribute(1)]];
};

struct VertexOut {
  float4 position [[position]];
  float2 uv;
};

// MARK: - Vertex Shader

vertex VertexOut metaball_vertex(VertexIn in [[stage_in]]) {
  VertexOut out;
  out.position = float4(in.position, 0.0, 1.0);
  out.uv = in.uv;
  return out;
}

// MARK: - Metaball Field Function

// Computes the metaball field value at a given UV coordinate.
// Blobs merge at center when idle, expand and orbit counterclockwise when active.
float metaball_field(float2 uv, float time, float speedMult, float moveRange, float breathAmp, float verts) {
  float size = 0.0;
  float TWO_PI = 6.28318530718;
  float radSegment = TWO_PI / verts;

  // Spread factor: controls how far blobs are from center.
  // At moveRange = 0, blobs are at center (merged into one circle).
  // At moveRange >= 0.3, blobs are at full orbit radius.
  float spread = smoothstep(0.0, 0.3, moveRange);

  // Orbit radius when fully expanded - larger than idle circle.
  float orbitRadius = 0.55;

  // Counterclockwise orbit at constant speed.
  // Speed is independent of state transitions to avoid backwards rotation.
  float orbitAngle = time * 3.0;

  // Blob contributions - they merge at center when idle, separate when active.
  for (float i = 0.0; i < 10.0; i += 1.0) {
    // Skip vertices beyond the current vertex count.
    if (i >= verts) break;

    // Each blob's base angle, evenly distributed.
    float baseAngle = i * radSegment;

    // Add orbit rotation. Rotation continues regardless of spread.
    // Only the radius changes during transitions, not the rotation.
    float angle = baseAngle + orbitAngle;

    // Distance from center: 0 when idle (all at center), orbitRadius when active.
    float radius = spread * orbitRadius;

    // Blob position.
    float2 blobPos = float2(cos(angle), sin(angle)) * radius;

    // Add blob contribution to field.
    // Multiplier controls blob tightness - lower = more merged, higher = more distinct.
    // High tightness (20.0) when spread keeps blobs completely separate.
    float tightness = mix(4.0, 20.0, spread);
    float contribution = 1.0 / pow(2.0, distance(uv, blobPos) * tightness);

    // Scale down when merged so combined blobs equal one normal-sized circle.
    // When spread = 0, divide by verts. When spread = 1, full contribution.
    float scale = mix(1.0 / verts, 1.0, spread);
    size += contribution * scale;
  }
  return size;
}

// MARK: - Fragment Shader

fragment float4 metaball_fragment(VertexOut in [[stage_in]],
                                   constant Uniforms& uniforms [[buffer(0)]]) {
  // Scale UV to metaball space.
  float2 uv = in.uv * 2.8;

  // Compute metaball field.
  float field = metaball_field(uv, uniforms.time,
                                uniforms.speedMultiplier,
                                uniforms.movementRange,
                                uniforms.breathAmplitude,
                                uniforms.vertexCount);

  // Circular boundary mask to contain the metaball.
  float container = length(in.uv);
  float boundaryMask = 1.0 - smoothstep(0.88, 0.9, container);

  // Threshold the field to create solid shapes.
  float inkMask = smoothstep(0.2, 0.22, field);
  float finalMask = inkMask * boundaryMask;

  // Output black ink on transparent background.
  // finalMask is 1 where ink is, 0 where background is.
  return float4(0.0, 0.0, 0.0, finalMask);
}
