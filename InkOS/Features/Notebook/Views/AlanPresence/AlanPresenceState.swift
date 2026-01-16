//
// AlanPresenceState.swift
// InkOS
//
// Defines Alan's presence states with animation parameters.
// Each state has specific values that control the metaball shader behavior.
// Seamless transitions are achieved by animating between these parameter values.
//

import Foundation

// MARK: - AlanPresenceState

// Alan's current activity state, reflected in the metaball animation.
enum AlanPresenceState: Equatable {
  // Calm, attentive presence. Gentle breathing animation.
  case idle
  // Processing user input. Active swirling figure-8s.
  case thinking
  // Generating output. Unified breathing pulse.
  case outputting

  // Speed of the orbit. Higher = faster rotation.
  // Idle is zero for completely still state.
  var speedMultiplier: Float {
    switch self {
    case .idle: return 0.0
    case .thinking: return 1.0
    case .outputting: return 1.0
    }
  }

  // Controls expansion from center. 0 = merged at center, higher = expanded orbit.
  // Thinking and outputting both show expanded orbiting blobs.
  var movementRange: Float {
    switch self {
    case .idle: return 0.0
    case .thinking: return 0.5
    case .outputting: return 0.5
    }
  }

  // Unused in current shader but kept for potential future use.
  var breathAmplitude: Float {
    switch self {
    case .idle: return 0.0
    case .thinking: return 0.0
    case .outputting: return 0.0
    }
  }

  // Number of orbiting blobs.
  var vertexCount: Float {
    switch self {
    case .idle: return 6.0
    case .thinking: return 6.0
    case .outputting: return 6.0
    }
  }
}
