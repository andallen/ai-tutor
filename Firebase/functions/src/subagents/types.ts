// types.ts
// Shared TypeScript types for subagent system.
// These types match the Swift types in AlanContract.swift.

import {z} from "zod";

// Visual intent enum - specific values for routing decisions.
export const VisualIntentSchema = z.enum([
  "show_structure", // Display anatomy, composition, parts
  "show_process", // Illustrate sequence, cycle, transformation
  "show_relationship", // Display how variables relate
  "show_example", // Concrete instance of abstract concept
  "interactive_exploration", // Manipulate variables, see results
  "worked_example", // Step through specific problem
  "comparison", // Show differences or similarities
  "analogy", // Visual metaphor
  "real_world", // Concept in authentic context
  "historical", // Primary source, historical photo
]);
export type VisualIntent = z.infer<typeof VisualIntentSchema>;

// Request constraints schema.
export const RequestConstraintsSchema = z.object({
  max_rows: z.number().optional(),
  preferred_engine: z.string().optional(),
  preferred_provider: z.string().optional(),
  allow_ai_generation: z.boolean().optional(),
  max_wait_time_ms: z.number().optional(),
  preferred_format: z.enum(["static", "animated", "interactive"]).optional(),
});

// Subagent request schema.
export const SubagentRequestSchema = z.object({
  id: z.string(),
  target_type: z.enum(["table", "visual"]),
  concept: z.string(),
  intent: z.string(), // VisualIntent for visual, free string for table
  description: z.string(),
  parameters: z.record(z.string(), z.unknown()).optional(), // Structured data (chart data, forces, etc.)
  constraints: RequestConstraintsSchema.optional(),
});

// Type exports.
export type RequestConstraints = z.infer<typeof RequestConstraintsSchema>;
export type SubagentRequest = z.infer<typeof SubagentRequestSchema>;

// Response status - replaces success boolean.
export type ResponseStatus = "ready" | "pending" | "failed";

// KaTeX annotation for math overlays on visualizations.
export interface KaTeXAnnotation {
  latex: string;
  x: number; // 0-1 relative position
  y: number;
  anchor?: "left" | "center" | "right";
}

// Response metadata for observability.
export interface ResponseMetadata {
  fulfillment_method:
    | "library_search"
    | "api_search"
    | "ai_generation"
    | "render"
    | "embed_match"
    | "placeholder";
  latency_ms: number;
  engine_selected?: string; // For graphics
  provider?: string; // For embed
  sources_searched?: string[]; // For image
  simulation_matched?: string; // For embed
  estimated_wait_ms?: number; // For pending status
  fallback_reason?: string; // When using fallback
}

// Subagent response interface.
export interface SubagentResponse {
  request_id: string;
  status: ResponseStatus;
  block?: Block;
  block_update?: Partial<Block>; // For updating pending blocks
  error?: SubagentError;
  metadata?: ResponseMetadata;
}

// Subagent error interface.
export interface SubagentError {
  code: string;
  message: string;
  details?: Record<string, unknown>;
}

// Block interface (matches Swift Block).
export interface Block {
  id: string;
  type: "text" | "image" | "graphics" | "table" | "embed" | "input";
  created_at: string;
  status: "pending" | "ready" | "rendered" | "hidden";
  content: unknown;
}

// Visual router decision.
export interface VisualRouterDecision {
  selected_type: "image" | "graphics" | "embed";
  reasoning: string;
  specific_recommendation?: string;
}

// Helper to generate block IDs.
export function generateBlockId(): string {
  return `block-${Date.now()}-${Math.random().toString(36).substring(2, 9)}`;
}

// Helper to create current ISO timestamp.
export function currentTimestamp(): string {
  return new Date().toISOString();
}

// Helper to create ready response.
export function readyResponse(
  requestId: string,
  block: Block,
  metadata: ResponseMetadata
): SubagentResponse {
  return {
    request_id: requestId,
    status: "ready",
    block,
    metadata,
  };
}

// Helper to create pending response.
export function pendingResponse(
  requestId: string,
  block: Block,
  metadata: ResponseMetadata
): SubagentResponse {
  return {
    request_id: requestId,
    status: "pending",
    block,
    metadata,
  };
}

// Helper to create failure response.
export function failedResponse(
  requestId: string,
  code: string,
  message: string,
  details?: Record<string, unknown>
): SubagentResponse {
  return {
    request_id: requestId,
    status: "failed",
    error: {code, message, details},
  };
}

// Legacy helpers for backward compatibility during migration.
export function successResponse(
  requestId: string,
  block: Block,
  metadata?: ResponseMetadata
): SubagentResponse {
  return {
    request_id: requestId,
    status: "ready",
    block,
    metadata,
  };
}

export function failureResponse(
  requestId: string,
  code: string,
  message: string
): SubagentResponse {
  return {
    request_id: requestId,
    status: "failed",
    error: {code, message},
  };
}
