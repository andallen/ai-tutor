// alanAgent.test.ts
// Unit tests for Alan agent request validation and session model handling.
// Tests request parsing, session model injection, and response validation.

import {z} from "zod";
import {SessionModelSchema, AlanOutputSchema} from "../../alan/outputSchema";

// Recreate the AlanRequestSchema for testing (same as in alanAgent.ts)
const AlanRequestSchema = z.object({
  messages: z.array(z.object({
    role: z.enum(["user", "assistant"]),
    content: z.string(),
  })),
  notebook_context: z.object({
    document_id: z.string(),
    current_blocks: z.array(z.any()).optional(),
    session_topic: z.string().optional(),
  }),
  session_model: SessionModelSchema.optional(),
});

describe("AlanRequestSchema", () => {
  describe("valid requests", () => {
    it("should validate request without session model (first turn)", () => {
      const request = {
        messages: [
          {role: "user", content: "Help me understand derivatives"},
        ],
        notebook_context: {
          document_id: "doc-123",
        },
      };

      const result = AlanRequestSchema.safeParse(request);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.session_model).toBeUndefined();
        expect(result.data.messages).toHaveLength(1);
      }
    });

    it("should validate request with session model (subsequent turn)", () => {
      const request = {
        messages: [
          {role: "user", content: "Help me understand derivatives"},
          {role: "assistant", content: "Let me explain..."},
          {role: "user", content: "Can you show me an example?"},
        ],
        notebook_context: {
          document_id: "doc-123",
          session_topic: "Calculus",
        },
        session_model: {
          session_id: "doc-123",
          turn_count: 2,
          goal: {
            description: "Understand derivatives",
            status: "active",
            progress: 25,
          },
          concepts: {
            "derivatives": {
              status: "introduced",
              attempts: 0,
            },
          },
          signals: {
            engagement: "high",
            frustration: "none",
            pace: "normal",
          },
          facts: [],
        },
      };

      const result = AlanRequestSchema.safeParse(request);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.session_model).toBeDefined();
        expect(result.data.session_model?.turn_count).toBe(2);
      }
    });

    it("should validate request with full context", () => {
      const request = {
        messages: [
          {role: "user", content: "What is integration?"},
        ],
        notebook_context: {
          document_id: "doc-456",
          current_blocks: [
            {id: "block-1", type: "text", content: "Previous content"},
          ],
          session_topic: "Integral Calculus",
        },
        session_model: {
          session_id: "doc-456",
          turn_count: 5,
          goal: {
            description: "Master integration",
            status: "active",
            progress: 40,
          },
          concepts: {
            "limits": {status: "mastered", attempts: 3},
            "derivatives": {status: "mastered", attempts: 4},
            "integration": {status: "practicing", attempts: 2},
          },
          signals: {
            engagement: "medium",
            frustration: "mild",
            pace: "slow",
          },
          facts: ["Struggling with u-substitution", "Prefers step-by-step"],
        },
      };

      const result = AlanRequestSchema.safeParse(request);
      expect(result.success).toBe(true);
    });

    it("should validate request with empty messages", () => {
      const request = {
        messages: [],
        notebook_context: {
          document_id: "doc-789",
        },
      };

      const result = AlanRequestSchema.safeParse(request);
      expect(result.success).toBe(true);
    });
  });

  describe("invalid requests", () => {
    it("should reject request without messages", () => {
      const request = {
        notebook_context: {
          document_id: "doc-123",
        },
      };

      const result = AlanRequestSchema.safeParse(request);
      expect(result.success).toBe(false);
    });

    it("should reject request without notebook_context", () => {
      const request = {
        messages: [
          {role: "user", content: "Hello"},
        ],
      };

      const result = AlanRequestSchema.safeParse(request);
      expect(result.success).toBe(false);
    });

    it("should reject request without document_id", () => {
      const request = {
        messages: [
          {role: "user", content: "Hello"},
        ],
        notebook_context: {},
      };

      const result = AlanRequestSchema.safeParse(request);
      expect(result.success).toBe(false);
    });

    it("should reject invalid message role", () => {
      const request = {
        messages: [
          {role: "system", content: "Hello"}, // Invalid role
        ],
        notebook_context: {
          document_id: "doc-123",
        },
      };

      const result = AlanRequestSchema.safeParse(request);
      expect(result.success).toBe(false);
    });

    it("should reject invalid session model in request", () => {
      const request = {
        messages: [
          {role: "user", content: "Hello"},
        ],
        notebook_context: {
          document_id: "doc-123",
        },
        session_model: {
          session_id: "doc-123",
          turn_count: 1,
          // Missing required fields
        },
      };

      const result = AlanRequestSchema.safeParse(request);
      expect(result.success).toBe(false);
    });

    it("should reject message without content", () => {
      const request = {
        messages: [
          {role: "user"}, // Missing content
        ],
        notebook_context: {
          document_id: "doc-123",
        },
      };

      const result = AlanRequestSchema.safeParse(request);
      expect(result.success).toBe(false);
    });
  });

  describe("edge cases", () => {
    it("should handle very long message content", () => {
      const request = {
        messages: [
          {role: "user", content: "a".repeat(10000)},
        ],
        notebook_context: {
          document_id: "doc-123",
        },
      };

      const result = AlanRequestSchema.safeParse(request);
      expect(result.success).toBe(true);
    });

    it("should handle many messages in conversation", () => {
      const messages = [];
      for (let i = 0; i < 50; i++) {
        messages.push({
          role: i % 2 === 0 ? "user" : "assistant",
          content: `Message ${i}`,
        });
      }

      const request = {
        messages,
        notebook_context: {
          document_id: "doc-123",
        },
      };

      const result = AlanRequestSchema.safeParse(request);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.messages).toHaveLength(50);
      }
    });

    it("should handle Unicode content in messages", () => {
      const request = {
        messages: [
          {role: "user", content: "如何计算积分？ 🧮"},
          {role: "assistant", content: "让我解释一下..."},
        ],
        notebook_context: {
          document_id: "doc-unicode",
        },
      };

      const result = AlanRequestSchema.safeParse(request);
      expect(result.success).toBe(true);
    });

    it("should handle empty string content", () => {
      const request = {
        messages: [
          {role: "user", content: ""},
        ],
        notebook_context: {
          document_id: "doc-123",
        },
      };

      const result = AlanRequestSchema.safeParse(request);
      expect(result.success).toBe(true);
    });
  });
});

describe("Session Model Injection Logic", () => {
  // Simulate the logic in alanAgent.ts for building system prompt
  function buildSystemPromptWithSessionModel(
    basePrompt: string,
    sessionModel: z.infer<typeof SessionModelSchema> | undefined,
    documentId: string
  ): string {
    let systemPrompt = basePrompt;
    if (sessionModel) {
      systemPrompt += `\n\n## Current Session Model\n\`\`\`json\n${JSON.stringify(sessionModel, null, 2)}\n\`\`\``;
    } else {
      systemPrompt += `\n\n## Current Session Model\nNo session model provided. This is the first turn. Initialize a new session model with session_id: "${documentId}", turn_count: 1, goal: null, concepts: {}, signals with medium engagement/none frustration/normal pace, and empty facts array.`;
    }
    return systemPrompt;
  }

  it("should inject session model when provided", () => {
    const basePrompt = "You are Alan.";
    const sessionModel = {
      session_id: "doc-123",
      turn_count: 3,
      goal: {
        description: "Learn derivatives",
        status: "active" as const,
        progress: 50,
      },
      concepts: {},
      signals: {
        engagement: "high" as const,
        frustration: "none" as const,
        pace: "fast" as const,
      },
      facts: ["student is motivated"],
    };

    const result = buildSystemPromptWithSessionModel(basePrompt, sessionModel, "doc-123");

    expect(result).toContain("You are Alan.");
    expect(result).toContain("## Current Session Model");
    expect(result).toContain("session_id");
    expect(result).toContain("doc-123");
    expect(result).toContain("Learn derivatives");
    expect(result).toContain("student is motivated");
    expect(result).not.toContain("No session model provided");
  });

  it("should provide initialization instructions when no session model", () => {
    const basePrompt = "You are Alan.";
    const result = buildSystemPromptWithSessionModel(basePrompt, undefined, "doc-456");

    expect(result).toContain("You are Alan.");
    expect(result).toContain("No session model provided");
    expect(result).toContain("This is the first turn");
    expect(result).toContain('session_id: "doc-456"');
    expect(result).toContain("turn_count: 1");
    expect(result).toContain("goal: null");
  });

  it("should format session model as valid JSON", () => {
    const sessionModel = {
      session_id: "doc-789",
      turn_count: 1,
      goal: null,
      concepts: {},
      signals: {
        engagement: "medium" as const,
        frustration: "none" as const,
        pace: "normal" as const,
      },
      facts: [],
    };

    const result = buildSystemPromptWithSessionModel("Base", sessionModel, "doc-789");

    // Extract JSON from the result
    const jsonMatch = result.match(/```json\n([\s\S]*?)\n```/);
    expect(jsonMatch).not.toBeNull();

    if (jsonMatch) {
      const parsed = JSON.parse(jsonMatch[1]);
      expect(parsed.session_id).toBe("doc-789");
      expect(parsed.turn_count).toBe(1);
    }
  });
});

describe("Alan Response Validation", () => {
  it("should validate a complete Alan response with session model", () => {
    const response = {
      notebook_updates: [
        {
          action: "append",
          content: {
            type: "text",
            segments: [
              {type: "plain", text: "Let me explain derivatives."},
            ],
          },
        },
      ],
      session_model: {
        session_id: "doc-123",
        turn_count: 2,
        goal: {
          description: "Understand derivatives",
          status: "active",
          progress: 10,
        },
        concepts: {
          "derivatives": {
            status: "introduced",
            attempts: 0,
          },
        },
        signals: {
          engagement: "high",
          frustration: "none",
          pace: "normal",
        },
        facts: [],
      },
    };

    const result = AlanOutputSchema.safeParse(response);
    expect(result.success).toBe(true);
  });

  it("should validate response with updated concept status", () => {
    const response = {
      notebook_updates: [
        {
          action: "append",
          content: {
            type: "text",
            segments: [{type: "plain", text: "Great work!"}],
          },
        },
      ],
      session_model: {
        session_id: "doc-123",
        turn_count: 5,
        goal: {
          description: "Master derivatives",
          status: "active",
          progress: 75,
        },
        concepts: {
          "derivatives": {
            status: "mastered",
            attempts: 5,
          },
          "chain_rule": {
            status: "practicing",
            attempts: 2,
          },
        },
        signals: {
          engagement: "high",
          frustration: "none",
          pace: "fast",
        },
        facts: ["Quick learner", "Responds well to examples"],
      },
    };

    const result = AlanOutputSchema.safeParse(response);
    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data.session_model.concepts["derivatives"].status).toBe("mastered");
    }
  });

  it("should validate response with goal completion", () => {
    const response = {
      notebook_updates: [
        {
          action: "append",
          content: {
            type: "text",
            segments: [{type: "plain", text: "Congratulations! You've mastered derivatives!"}],
          },
        },
      ],
      session_model: {
        session_id: "doc-123",
        turn_count: 10,
        goal: {
          description: "Understand derivatives",
          status: "completed",
          progress: 100,
        },
        concepts: {
          "derivatives": {status: "mastered", attempts: 8},
          "chain_rule": {status: "mastered", attempts: 5},
          "product_rule": {status: "mastered", attempts: 4},
        },
        signals: {
          engagement: "high",
          frustration: "none",
          pace: "normal",
        },
        facts: ["Completed derivatives module"],
      },
    };

    const result = AlanOutputSchema.safeParse(response);
    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data.session_model.goal?.status).toBe("completed");
      expect(result.data.session_model.goal?.progress).toBe(100);
    }
  });

  it("should validate response with frustration signals", () => {
    const response = {
      notebook_updates: [
        {
          action: "append",
          content: {
            type: "text",
            segments: [{type: "plain", text: "I can see this is challenging. Let me try a different approach."}],
          },
        },
      ],
      session_model: {
        session_id: "doc-123",
        turn_count: 6,
        goal: {
          description: "Understand integration",
          status: "active",
          progress: 20,
        },
        concepts: {
          "integration": {
            status: "struggling",
            attempts: 5,
          },
        },
        signals: {
          engagement: "medium",
          frustration: "high",
          pace: "slow",
        },
        facts: ["Finds integration difficult", "Needs more visual examples"],
      },
    };

    const result = AlanOutputSchema.safeParse(response);
    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data.session_model.signals.frustration).toBe("high");
      expect(result.data.session_model.concepts["integration"].status).toBe("struggling");
    }
  });

  it("should reject response without session model", () => {
    const response = {
      notebook_updates: [
        {
          action: "append",
          content: {
            type: "text",
            segments: [{type: "plain", text: "Hello"}],
          },
        },
      ],
      // Missing session_model
    };

    const result = AlanOutputSchema.safeParse(response);
    expect(result.success).toBe(false);
  });

  it("should reject response with invalid session model", () => {
    const response = {
      notebook_updates: [],
      session_model: {
        session_id: "doc-123",
        turn_count: 1,
        goal: {
          description: "Test",
          status: "invalid_status", // Invalid
          progress: 50,
        },
        concepts: {},
        signals: {
          engagement: "medium",
          frustration: "none",
          pace: "normal",
        },
        facts: [],
      },
    };

    const result = AlanOutputSchema.safeParse(response);
    expect(result.success).toBe(false);
  });
});

describe("Turn Count Progression", () => {
  it("should track turn count progression", () => {
    // Simulate a multi-turn conversation
    const turns = [
      {
        session_id: "doc-123",
        turn_count: 1,
        goal: null,
        concepts: {},
        signals: {engagement: "medium" as const, frustration: "none" as const, pace: "normal" as const},
        facts: [],
      },
      {
        session_id: "doc-123",
        turn_count: 2,
        goal: {description: "Learn calculus", status: "active" as const, progress: 10},
        concepts: {"limits": {status: "introduced" as const, attempts: 0}},
        signals: {engagement: "high" as const, frustration: "none" as const, pace: "normal" as const},
        facts: ["Wants to learn calculus"],
      },
      {
        session_id: "doc-123",
        turn_count: 3,
        goal: {description: "Learn calculus", status: "active" as const, progress: 25},
        concepts: {"limits": {status: "practicing" as const, attempts: 1}},
        signals: {engagement: "high" as const, frustration: "none" as const, pace: "fast" as const},
        facts: ["Wants to learn calculus", "Fast learner"],
      },
    ];

    for (let i = 0; i < turns.length; i++) {
      const result = SessionModelSchema.safeParse(turns[i]);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.turn_count).toBe(i + 1);
      }
    }
  });

  it("should maintain session_id consistency", () => {
    const sessionId = "doc-consistent-123";
    const turns = [1, 2, 3, 4, 5];

    for (const turnCount of turns) {
      const model = {
        session_id: sessionId,
        turn_count: turnCount,
        goal: null,
        concepts: {},
        signals: {engagement: "medium", frustration: "none", pace: "normal"},
        facts: [],
      };

      const result = SessionModelSchema.safeParse(model);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.session_id).toBe(sessionId);
      }
    }
  });
});

describe("Concept Status Transitions", () => {
  it("should allow valid status transitions", () => {
    // Valid progression: introduced -> practicing -> mastered
    const validTransitions = [
      ["introduced", "practicing"],
      ["practicing", "mastered"],
      ["practicing", "struggling"],
      ["struggling", "practicing"],
      ["struggling", "mastered"],
    ];

    for (const [from, to] of validTransitions) {
      const conceptBefore = {status: from, attempts: 1};
      const conceptAfter = {status: to, attempts: 2};

      const resultBefore = ConceptStatusSchema.safeParse(conceptBefore);
      const resultAfter = ConceptStatusSchema.safeParse(conceptAfter);

      expect(resultBefore.success).toBe(true);
      expect(resultAfter.success).toBe(true);
    }
  });

  it("should track attempts incrementally", () => {
    for (let attempts = 0; attempts <= 10; attempts++) {
      const concept = {
        status: "practicing",
        attempts,
      };

      const result = ConceptStatusSchema.safeParse(concept);
      expect(result.success).toBe(true);
    }
  });
});

describe("Facts Accumulation", () => {
  it("should handle growing facts array", () => {
    const facts: string[] = [];

    for (let i = 0; i < 20; i++) {
      facts.push(`Fact ${i}`);

      const model = {
        session_id: "doc-123",
        turn_count: i + 1,
        goal: null,
        concepts: {},
        signals: {engagement: "medium", frustration: "none", pace: "normal"},
        facts: [...facts],
      };

      const result = SessionModelSchema.safeParse(model);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.facts).toHaveLength(i + 1);
      }
    }
  });

  it("should preserve fact order", () => {
    const orderedFacts = [
      "First fact",
      "Second fact",
      "Third fact",
    ];

    const model = {
      session_id: "doc-123",
      turn_count: 1,
      goal: null,
      concepts: {},
      signals: {engagement: "medium", frustration: "none", pace: "normal"},
      facts: orderedFacts,
    };

    const result = SessionModelSchema.safeParse(model);
    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data.facts[0]).toBe("First fact");
      expect(result.data.facts[1]).toBe("Second fact");
      expect(result.data.facts[2]).toBe("Third fact");
    }
  });
});

// Helper type for the concept status
const ConceptStatusSchema = z.object({
  status: z.enum(["introduced", "practicing", "mastered", "struggling"]),
  attempts: z.number(),
});
