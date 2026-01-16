// outputSchema.ts
// Zod schemas for validating Alan's structured output.
// These schemas match the Swift types in AlanContract.swift.

import {z} from "zod";

// Request constraints for subagent requests.
export const RequestConstraintsSchema = z.object({
  max_rows: z.number().optional(),
  preferred_engine: z.string().optional(),
  preferred_provider: z.string().optional(),
  allow_ai_generation: z.boolean().optional(),
  max_wait_time_ms: z.number().optional(),
});

// Subagent request schema.
export const SubagentRequestSchema = z.object({
  id: z.string(),
  target_type: z.enum(["table", "visual"]),
  concept: z.string(),
  intent: z.string(),
  description: z.string(),
  constraints: RequestConstraintsSchema.optional(),
});

// Text segment types for rich text content.
export const TextSegmentSchema = z.discriminatedUnion("type", [
  z.object({
    type: z.literal("plain"),
    text: z.string(),
    style: z.object({
      size: z.enum(["caption", "body", "headline", "title", "largeTitle"]).optional(),
      weight: z.enum(["regular", "medium", "semibold", "bold", "heavy"]).optional(),
      color: z.string().optional(),
      italic: z.boolean().optional(),
      underline: z.boolean().optional(),
      strikethrough: z.boolean().optional(),
    }).optional(),
  }),
  z.object({
    type: z.literal("latex"),
    latex: z.string(),
    display_mode: z.boolean().optional(),
    color: z.string().optional(),
  }),
  z.object({
    type: z.literal("code"),
    code: z.string(),
    language: z.string().optional(),
    show_line_numbers: z.boolean().optional(),
    highlight_lines: z.array(z.number()).optional(),
  }),
  z.object({
    type: z.literal("kinetic"),
    text: z.string(),
    animation: z.enum([
      "typewriter", "word_cascade", "letter_bounce", "slam", "shake", "pulse", "rainbow",
    ]).optional(),
    duration_ms: z.number().optional(),
    delay_ms: z.number().optional(),
    style: z.object({
      size: z.enum(["caption", "body", "headline", "title", "largeTitle"]).optional(),
      weight: z.enum(["regular", "medium", "semibold", "bold", "heavy"]).optional(),
      color: z.string().optional(),
      italic: z.boolean().optional(),
    }).optional(),
  }),
]);

// Text content schema.
export const TextContentSchema = z.object({
  segments: z.array(TextSegmentSchema),
  alignment: z.enum(["leading", "center", "trailing"]).optional(),
  spacing: z.enum(["compact", "normal", "relaxed"]).optional(),
});

// Choice option for multiple choice inputs.
export const ChoiceOptionSchema = z.object({
  id: z.string(),
  text: z.string(),
  correct: z.boolean().optional(),
});

// Input content schema (simplified for Alan's direct output).
export const InputContentSchema = z.object({
  input_type: z.enum([
    "text", "handwriting", "multiple_choice", "multi_select", "button", "slider", "numeric",
  ]),
  prompt: z.string(),
  placeholder: z.string().optional(),
  choice_config: z.object({
    options: z.array(ChoiceOptionSchema),
    allow_multiple: z.boolean().optional(),
  }).optional(),
  slider_config: z.object({
    min: z.number(),
    max: z.number(),
    step: z.number().optional(),
    default_value: z.number().optional(),
  }).optional(),
  numeric_config: z.object({
    min: z.number().optional(),
    max: z.number().optional(),
    precision: z.number().optional(),
  }).optional(),
  feedback: z.object({
    correct_message: z.string().optional(),
    incorrect_message: z.string().optional(),
    hint: z.string().optional(),
  }).optional(),
});

// Notebook update content (either direct block or subagent request).
export const UpdateContentSchema = z.discriminatedUnion("type", [
  z.object({
    type: z.literal("text"),
    ...TextContentSchema.shape,
  }),
  z.object({
    type: z.literal("input"),
    ...InputContentSchema.shape,
  }),
  z.object({
    type: z.literal("subagent_request"),
    ...SubagentRequestSchema.shape,
  }),
]);

// Notebook update schema.
export const NotebookUpdateSchema = z.object({
  action: z.enum(["append", "request"]),
  content: UpdateContentSchema,
});

// Session model goal schema.
export const SessionGoalSchema = z.object({
  description: z.string(),
  status: z.enum(["active", "completed", "abandoned"]),
  progress: z.number().min(0).max(100),
});

// Session model concept status schema.
export const ConceptStatusSchema = z.object({
  status: z.enum(["introduced", "practicing", "mastered", "struggling"]),
  attempts: z.number(),
});

// Session model signals schema.
export const SessionSignalsSchema = z.object({
  engagement: z.enum(["high", "medium", "low"]),
  frustration: z.enum(["none", "mild", "high"]),
  pace: z.enum(["fast", "normal", "slow"]),
});

// Per-session user model schema.
// Tracks student state throughout a tutoring session.
export const SessionModelSchema = z.object({
  session_id: z.string(),
  turn_count: z.number(),
  goal: SessionGoalSchema.nullable(),
  concepts: z.record(z.string(), ConceptStatusSchema),
  signals: SessionSignalsSchema,
  facts: z.array(z.string()),
});

// Alan's complete output schema.
export const AlanOutputSchema = z.object({
  notebook_updates: z.array(NotebookUpdateSchema),
  session_model: SessionModelSchema,
});

// Type exports.
export type RequestConstraints = z.infer<typeof RequestConstraintsSchema>;
export type SubagentRequest = z.infer<typeof SubagentRequestSchema>;
export type TextSegment = z.infer<typeof TextSegmentSchema>;
export type TextContent = z.infer<typeof TextContentSchema>;
export type InputContent = z.infer<typeof InputContentSchema>;
export type NotebookUpdate = z.infer<typeof NotebookUpdateSchema>;
export type SessionGoal = z.infer<typeof SessionGoalSchema>;
export type ConceptStatus = z.infer<typeof ConceptStatusSchema>;
export type SessionSignals = z.infer<typeof SessionSignalsSchema>;
export type SessionModel = z.infer<typeof SessionModelSchema>;
export type AlanOutput = z.infer<typeof AlanOutputSchema>;

// JSON Schema for Gemini structured output.
// This is a simplified schema that Gemini can use for structured generation.
export const GEMINI_RESPONSE_SCHEMA = {
  type: "object",
  properties: {
    notebook_updates: {
      type: "array",
      items: {
        type: "object",
        properties: {
          action: {
            type: "string",
            enum: ["append", "request"],
          },
          content: {
            type: "object",
            properties: {
              type: {
                type: "string",
                enum: ["text", "input", "subagent_request"],
              },
            },
            required: ["type"],
          },
        },
        required: ["action", "content"],
      },
    },
    session_model: {
      type: "object",
      properties: {
        session_id: {type: "string"},
        turn_count: {type: "number"},
        goal: {
          type: "object",
          nullable: true,
          properties: {
            description: {type: "string"},
            status: {type: "string", enum: ["active", "completed", "abandoned"]},
            progress: {type: "number"},
          },
          required: ["description", "status", "progress"],
        },
        concepts: {
          type: "object",
          additionalProperties: {
            type: "object",
            properties: {
              status: {type: "string", enum: ["introduced", "practicing", "mastered", "struggling"]},
              attempts: {type: "number"},
            },
            required: ["status", "attempts"],
          },
        },
        signals: {
          type: "object",
          properties: {
            engagement: {type: "string", enum: ["high", "medium", "low"]},
            frustration: {type: "string", enum: ["none", "mild", "high"]},
            pace: {type: "string", enum: ["fast", "normal", "slow"]},
          },
          required: ["engagement", "frustration", "pace"],
        },
        facts: {
          type: "array",
          items: {type: "string"},
        },
      },
      required: ["session_id", "turn_count", "goal", "concepts", "signals", "facts"],
    },
  },
  required: ["notebook_updates", "session_model"],
};
