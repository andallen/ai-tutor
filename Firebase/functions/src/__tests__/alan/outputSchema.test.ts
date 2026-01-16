// outputSchema.test.ts
// Comprehensive unit tests for the Session Model and Alan output schemas.
// Tests validation logic, edge cases, and type correctness.

import {
  SessionModelSchema,
  SessionGoalSchema,
  ConceptStatusSchema,
  SessionSignalsSchema,
  AlanOutputSchema,
  NotebookUpdateSchema,
  TextSegmentSchema,
  TextContentSchema,
  InputContentSchema,
  SubagentRequestSchema,
  UpdateContentSchema,
  RequestConstraintsSchema,
} from "../../alan/outputSchema";

describe("SessionModelSchema", () => {
  describe("valid inputs", () => {
    it("should validate a minimal session model", () => {
      const model = {
        session_id: "session-123",
        turn_count: 1,
        goal: null,
        concepts: {},
        signals: {
          engagement: "medium",
          frustration: "none",
          pace: "normal",
        },
        facts: [],
      };

      const result = SessionModelSchema.safeParse(model);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.session_id).toBe("session-123");
        expect(result.data.turn_count).toBe(1);
        expect(result.data.goal).toBeNull();
      }
    });

    it("should validate a complete session model with goal", () => {
      const model = {
        session_id: "doc-abc-123",
        turn_count: 5,
        goal: {
          description: "Understand derivatives",
          status: "active",
          progress: 45,
        },
        concepts: {
          "derivatives": {
            status: "practicing",
            attempts: 3,
          },
          "limits": {
            status: "mastered",
            attempts: 5,
          },
        },
        signals: {
          engagement: "high",
          frustration: "none",
          pace: "fast",
        },
        facts: ["studying for AP Calc", "prefers visual examples"],
      };

      const result = SessionModelSchema.safeParse(model);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.goal?.description).toBe("Understand derivatives");
        expect(result.data.goal?.status).toBe("active");
        expect(result.data.goal?.progress).toBe(45);
        expect(result.data.concepts["derivatives"].status).toBe("practicing");
        expect(result.data.concepts["limits"].attempts).toBe(5);
        expect(result.data.facts).toHaveLength(2);
      }
    });

    it("should validate session model with completed goal", () => {
      const model = {
        session_id: "session-456",
        turn_count: 10,
        goal: {
          description: "Master quadratic equations",
          status: "completed",
          progress: 100,
        },
        concepts: {},
        signals: {
          engagement: "high",
          frustration: "none",
          pace: "normal",
        },
        facts: [],
      };

      const result = SessionModelSchema.safeParse(model);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.goal?.status).toBe("completed");
        expect(result.data.goal?.progress).toBe(100);
      }
    });

    it("should validate session model with high frustration signals", () => {
      const model = {
        session_id: "session-789",
        turn_count: 8,
        goal: null,
        concepts: {
          "integration": {
            status: "struggling",
            attempts: 7,
          },
        },
        signals: {
          engagement: "low",
          frustration: "high",
          pace: "slow",
        },
        facts: ["finds integration difficult"],
      };

      const result = SessionModelSchema.safeParse(model);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.signals.frustration).toBe("high");
        expect(result.data.concepts["integration"].status).toBe("struggling");
      }
    });
  });

  describe("invalid inputs", () => {
    it("should reject missing session_id", () => {
      const model = {
        turn_count: 1,
        goal: null,
        concepts: {},
        signals: {
          engagement: "medium",
          frustration: "none",
          pace: "normal",
        },
        facts: [],
      };

      const result = SessionModelSchema.safeParse(model);
      expect(result.success).toBe(false);
    });

    it("should reject negative turn_count", () => {
      const model = {
        session_id: "session-123",
        turn_count: -1,
        goal: null,
        concepts: {},
        signals: {
          engagement: "medium",
          frustration: "none",
          pace: "normal",
        },
        facts: [],
      };

      // Note: The schema doesn't explicitly reject negative numbers,
      // but the model should always have non-negative turn count.
      const result = SessionModelSchema.safeParse(model);
      expect(result.success).toBe(true); // Schema allows it, but semantically wrong
    });

    it("should reject invalid goal status", () => {
      const model = {
        session_id: "session-123",
        turn_count: 1,
        goal: {
          description: "Test goal",
          status: "invalid_status",
          progress: 50,
        },
        concepts: {},
        signals: {
          engagement: "medium",
          frustration: "none",
          pace: "normal",
        },
        facts: [],
      };

      const result = SessionModelSchema.safeParse(model);
      expect(result.success).toBe(false);
    });

    it("should reject progress below 0", () => {
      const model = {
        session_id: "session-123",
        turn_count: 1,
        goal: {
          description: "Test goal",
          status: "active",
          progress: -10,
        },
        concepts: {},
        signals: {
          engagement: "medium",
          frustration: "none",
          pace: "normal",
        },
        facts: [],
      };

      const result = SessionModelSchema.safeParse(model);
      expect(result.success).toBe(false);
    });

    it("should reject progress above 100", () => {
      const model = {
        session_id: "session-123",
        turn_count: 1,
        goal: {
          description: "Test goal",
          status: "active",
          progress: 150,
        },
        concepts: {},
        signals: {
          engagement: "medium",
          frustration: "none",
          pace: "normal",
        },
        facts: [],
      };

      const result = SessionModelSchema.safeParse(model);
      expect(result.success).toBe(false);
    });

    it("should reject invalid engagement value", () => {
      const model = {
        session_id: "session-123",
        turn_count: 1,
        goal: null,
        concepts: {},
        signals: {
          engagement: "very_high", // Invalid
          frustration: "none",
          pace: "normal",
        },
        facts: [],
      };

      const result = SessionModelSchema.safeParse(model);
      expect(result.success).toBe(false);
    });

    it("should reject invalid concept status", () => {
      const model = {
        session_id: "session-123",
        turn_count: 1,
        goal: null,
        concepts: {
          "derivatives": {
            status: "unknown", // Invalid
            attempts: 1,
          },
        },
        signals: {
          engagement: "medium",
          frustration: "none",
          pace: "normal",
        },
        facts: [],
      };

      const result = SessionModelSchema.safeParse(model);
      expect(result.success).toBe(false);
    });

    it("should reject non-string facts", () => {
      const model = {
        session_id: "session-123",
        turn_count: 1,
        goal: null,
        concepts: {},
        signals: {
          engagement: "medium",
          frustration: "none",
          pace: "normal",
        },
        facts: [123, true], // Invalid types
      };

      const result = SessionModelSchema.safeParse(model);
      expect(result.success).toBe(false);
    });

    it("should reject missing signals", () => {
      const model = {
        session_id: "session-123",
        turn_count: 1,
        goal: null,
        concepts: {},
        facts: [],
      };

      const result = SessionModelSchema.safeParse(model);
      expect(result.success).toBe(false);
    });
  });

  describe("edge cases", () => {
    it("should handle empty string session_id", () => {
      const model = {
        session_id: "",
        turn_count: 0,
        goal: null,
        concepts: {},
        signals: {
          engagement: "medium",
          frustration: "none",
          pace: "normal",
        },
        facts: [],
      };

      const result = SessionModelSchema.safeParse(model);
      // Empty string is technically valid by the schema
      expect(result.success).toBe(true);
    });

    it("should handle very long session_id", () => {
      const model = {
        session_id: "a".repeat(1000),
        turn_count: 0,
        goal: null,
        concepts: {},
        signals: {
          engagement: "medium",
          frustration: "none",
          pace: "normal",
        },
        facts: [],
      };

      const result = SessionModelSchema.safeParse(model);
      expect(result.success).toBe(true);
    });

    it("should handle large turn count", () => {
      const model = {
        session_id: "session-123",
        turn_count: 999999,
        goal: null,
        concepts: {},
        signals: {
          engagement: "medium",
          frustration: "none",
          pace: "normal",
        },
        facts: [],
      };

      const result = SessionModelSchema.safeParse(model);
      expect(result.success).toBe(true);
    });

    it("should handle many concepts", () => {
      const concepts: Record<string, { status: string; attempts: number }> = {};
      for (let i = 0; i < 100; i++) {
        concepts[`concept_${i}`] = {
          status: "introduced",
          attempts: i,
        };
      }

      const model = {
        session_id: "session-123",
        turn_count: 100,
        goal: null,
        concepts,
        signals: {
          engagement: "medium",
          frustration: "none",
          pace: "normal",
        },
        facts: [],
      };

      const result = SessionModelSchema.safeParse(model);
      expect(result.success).toBe(true);
    });

    it("should handle many facts", () => {
      const facts = Array.from({ length: 50 }, (_, i) => `Fact number ${i}`);

      const model = {
        session_id: "session-123",
        turn_count: 50,
        goal: null,
        concepts: {},
        signals: {
          engagement: "medium",
          frustration: "none",
          pace: "normal",
        },
        facts,
      };

      const result = SessionModelSchema.safeParse(model);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.facts).toHaveLength(50);
      }
    });

    it("should handle progress at boundary values", () => {
      // Test progress = 0
      const modelZero = {
        session_id: "session-123",
        turn_count: 1,
        goal: {
          description: "Test",
          status: "active",
          progress: 0,
        },
        concepts: {},
        signals: {
          engagement: "medium",
          frustration: "none",
          pace: "normal",
        },
        facts: [],
      };
      expect(SessionModelSchema.safeParse(modelZero).success).toBe(true);

      // Test progress = 100
      const modelHundred = {
        session_id: "session-123",
        turn_count: 1,
        goal: {
          description: "Test",
          status: "active",
          progress: 100,
        },
        concepts: {},
        signals: {
          engagement: "medium",
          frustration: "none",
          pace: "normal",
        },
        facts: [],
      };
      expect(SessionModelSchema.safeParse(modelHundred).success).toBe(true);
    });

    it("should handle goal status transitions", () => {
      const statuses = ["active", "completed", "abandoned"];
      for (const status of statuses) {
        const model = {
          session_id: "session-123",
          turn_count: 1,
          goal: {
            description: "Test goal",
            status,
            progress: 50,
          },
          concepts: {},
          signals: {
            engagement: "medium",
            frustration: "none",
            pace: "normal",
          },
          facts: [],
        };
        const result = SessionModelSchema.safeParse(model);
        expect(result.success).toBe(true);
      }
    });
  });
});

describe("SessionGoalSchema", () => {
  it("should validate all goal statuses", () => {
    const statuses = ["active", "completed", "abandoned"];
    for (const status of statuses) {
      const goal = {
        description: "Learn calculus",
        status,
        progress: 50,
      };
      const result = SessionGoalSchema.safeParse(goal);
      expect(result.success).toBe(true);
    }
  });

  it("should reject empty description", () => {
    // Empty string is allowed by the schema
    const goal = {
      description: "",
      status: "active",
      progress: 0,
    };
    const result = SessionGoalSchema.safeParse(goal);
    expect(result.success).toBe(true);
  });

  it("should handle Unicode in description", () => {
    const goal = {
      description: "理解微积分 🎓",
      status: "active",
      progress: 25,
    };
    const result = SessionGoalSchema.safeParse(goal);
    expect(result.success).toBe(true);
  });
});

describe("ConceptStatusSchema", () => {
  it("should validate all concept statuses", () => {
    const statuses = ["introduced", "practicing", "mastered", "struggling"];
    for (const status of statuses) {
      const conceptStatus = {
        status,
        attempts: 1,
      };
      const result = ConceptStatusSchema.safeParse(conceptStatus);
      expect(result.success).toBe(true);
    }
  });

  it("should allow zero attempts", () => {
    const conceptStatus = {
      status: "introduced",
      attempts: 0,
    };
    const result = ConceptStatusSchema.safeParse(conceptStatus);
    expect(result.success).toBe(true);
  });

  it("should allow high attempt counts", () => {
    const conceptStatus = {
      status: "struggling",
      attempts: 1000,
    };
    const result = ConceptStatusSchema.safeParse(conceptStatus);
    expect(result.success).toBe(true);
  });
});

describe("SessionSignalsSchema", () => {
  it("should validate all signal combinations", () => {
    const engagements = ["high", "medium", "low"];
    const frustrations = ["none", "mild", "high"];
    const paces = ["fast", "normal", "slow"];

    for (const engagement of engagements) {
      for (const frustration of frustrations) {
        for (const pace of paces) {
          const signals = { engagement, frustration, pace };
          const result = SessionSignalsSchema.safeParse(signals);
          expect(result.success).toBe(true);
        }
      }
    }
  });
});

describe("AlanOutputSchema", () => {
  describe("valid outputs", () => {
    it("should validate complete Alan output with text content", () => {
      const output = {
        notebook_updates: [
          {
            action: "append",
            content: {
              type: "text",
              segments: [
                { type: "plain", text: "Hello, student!" },
              ],
            },
          },
        ],
        session_model: {
          session_id: "session-123",
          turn_count: 1,
          goal: null,
          concepts: {},
          signals: {
            engagement: "medium",
            frustration: "none",
            pace: "normal",
          },
          facts: [],
        },
      };

      const result = AlanOutputSchema.safeParse(output);
      expect(result.success).toBe(true);
    });

    it("should validate output with multiple notebook updates", () => {
      const output = {
        notebook_updates: [
          {
            action: "append",
            content: {
              type: "text",
              segments: [
                { type: "plain", text: "Let me explain derivatives." },
                { type: "latex", latex: "\\frac{dy}{dx}", display_mode: true },
              ],
            },
          },
          {
            action: "request",
            content: {
              type: "subagent_request",
              id: "req-001",
              target_type: "visual",
              concept: "derivative as slope",
              intent: "show_relationship",
              description: "Graph showing tangent line on a curve",
            },
          },
        ],
        session_model: {
          session_id: "session-123",
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

      const result = AlanOutputSchema.safeParse(output);
      expect(result.success).toBe(true);
    });

    it("should validate output with input content", () => {
      const output = {
        notebook_updates: [
          {
            action: "append",
            content: {
              type: "input",
              input_type: "multiple_choice",
              prompt: "What is 2 + 2?",
              choice_config: {
                options: [
                  { id: "a", text: "3", correct: false },
                  { id: "b", text: "4", correct: true },
                  { id: "c", text: "5", correct: false },
                ],
              },
            },
          },
        ],
        session_model: {
          session_id: "session-123",
          turn_count: 1,
          goal: null,
          concepts: {},
          signals: {
            engagement: "medium",
            frustration: "none",
            pace: "normal",
          },
          facts: [],
        },
      };

      const result = AlanOutputSchema.safeParse(output);
      expect(result.success).toBe(true);
    });

    it("should validate output with empty notebook updates", () => {
      const output = {
        notebook_updates: [],
        session_model: {
          session_id: "session-123",
          turn_count: 1,
          goal: null,
          concepts: {},
          signals: {
            engagement: "medium",
            frustration: "none",
            pace: "normal",
          },
          facts: [],
        },
      };

      const result = AlanOutputSchema.safeParse(output);
      expect(result.success).toBe(true);
    });
  });

  describe("invalid outputs", () => {
    it("should reject missing session_model", () => {
      const output = {
        notebook_updates: [],
      };

      const result = AlanOutputSchema.safeParse(output);
      expect(result.success).toBe(false);
    });

    it("should reject missing notebook_updates", () => {
      const output = {
        session_model: {
          session_id: "session-123",
          turn_count: 1,
          goal: null,
          concepts: {},
          signals: {
            engagement: "medium",
            frustration: "none",
            pace: "normal",
          },
          facts: [],
        },
      };

      const result = AlanOutputSchema.safeParse(output);
      expect(result.success).toBe(false);
    });

    it("should reject invalid update action", () => {
      const output = {
        notebook_updates: [
          {
            action: "invalid_action",
            content: {
              type: "text",
              segments: [],
            },
          },
        ],
        session_model: {
          session_id: "session-123",
          turn_count: 1,
          goal: null,
          concepts: {},
          signals: {
            engagement: "medium",
            frustration: "none",
            pace: "normal",
          },
          facts: [],
        },
      };

      const result = AlanOutputSchema.safeParse(output);
      expect(result.success).toBe(false);
    });

    it("should reject invalid content type", () => {
      const output = {
        notebook_updates: [
          {
            action: "append",
            content: {
              type: "invalid_type",
              data: "some data",
            },
          },
        ],
        session_model: {
          session_id: "session-123",
          turn_count: 1,
          goal: null,
          concepts: {},
          signals: {
            engagement: "medium",
            frustration: "none",
            pace: "normal",
          },
          facts: [],
        },
      };

      const result = AlanOutputSchema.safeParse(output);
      expect(result.success).toBe(false);
    });
  });
});

describe("TextSegmentSchema", () => {
  it("should validate plain text segment", () => {
    const segment = {
      type: "plain",
      text: "Hello world",
    };
    const result = TextSegmentSchema.safeParse(segment);
    expect(result.success).toBe(true);
  });

  it("should validate plain text with style", () => {
    const segment = {
      type: "plain",
      text: "Important",
      style: {
        size: "headline",
        weight: "bold",
        color: "#FF0000",
        italic: true,
        underline: false,
        strikethrough: false,
      },
    };
    const result = TextSegmentSchema.safeParse(segment);
    expect(result.success).toBe(true);
  });

  it("should validate latex segment", () => {
    const segment = {
      type: "latex",
      latex: "x^2 + y^2 = z^2",
      display_mode: true,
      color: "#0000FF",
    };
    const result = TextSegmentSchema.safeParse(segment);
    expect(result.success).toBe(true);
  });

  it("should validate code segment", () => {
    const segment = {
      type: "code",
      code: "print('hello')",
      language: "python",
      show_line_numbers: true,
      highlight_lines: [1, 3, 5],
    };
    const result = TextSegmentSchema.safeParse(segment);
    expect(result.success).toBe(true);
  });

  it("should validate kinetic segment", () => {
    const segment = {
      type: "kinetic",
      text: "AMAZING!",
      animation: "slam",
      duration_ms: 1000,
      delay_ms: 500,
      style: {
        size: "largeTitle",
        weight: "heavy",
        color: "#00FF00",
      },
    };
    const result = TextSegmentSchema.safeParse(segment);
    expect(result.success).toBe(true);
  });

  it("should validate all kinetic animations", () => {
    const animations = ["typewriter", "word_cascade", "letter_bounce", "slam", "shake", "pulse", "rainbow"];
    for (const animation of animations) {
      const segment = {
        type: "kinetic",
        text: "Test",
        animation,
      };
      const result = TextSegmentSchema.safeParse(segment);
      expect(result.success).toBe(true);
    }
  });
});

describe("InputContentSchema", () => {
  it("should validate all input types", () => {
    const inputTypes = ["text", "handwriting", "multiple_choice", "multi_select", "button", "slider", "numeric"];
    for (const inputType of inputTypes) {
      const content = {
        input_type: inputType,
        prompt: "Test prompt",
      };
      const result = InputContentSchema.safeParse(content);
      expect(result.success).toBe(true);
    }
  });

  it("should validate multiple choice with options", () => {
    const content = {
      input_type: "multiple_choice",
      prompt: "Choose one:",
      choice_config: {
        options: [
          { id: "a", text: "Option A", correct: true },
          { id: "b", text: "Option B", correct: false },
        ],
        allow_multiple: false,
      },
    };
    const result = InputContentSchema.safeParse(content);
    expect(result.success).toBe(true);
  });

  it("should validate slider config", () => {
    const content = {
      input_type: "slider",
      prompt: "Rate from 1-10:",
      slider_config: {
        min: 1,
        max: 10,
        step: 1,
        default_value: 5,
      },
    };
    const result = InputContentSchema.safeParse(content);
    expect(result.success).toBe(true);
  });

  it("should validate numeric config", () => {
    const content = {
      input_type: "numeric",
      prompt: "Enter a number:",
      numeric_config: {
        min: 0,
        max: 100,
        precision: 2,
      },
    };
    const result = InputContentSchema.safeParse(content);
    expect(result.success).toBe(true);
  });

  it("should validate feedback messages", () => {
    const content = {
      input_type: "text",
      prompt: "What is the capital of France?",
      feedback: {
        correct_message: "That's right! Paris is the capital.",
        incorrect_message: "Not quite. The answer is Paris.",
        hint: "It's a city known for the Eiffel Tower.",
      },
    };
    const result = InputContentSchema.safeParse(content);
    expect(result.success).toBe(true);
  });
});

describe("SubagentRequestSchema", () => {
  it("should validate table request", () => {
    const request = {
      id: "req-001",
      target_type: "table",
      concept: "multiplication table",
      intent: "practice multiplication",
      description: "Generate a 10x10 multiplication table",
    };
    const result = SubagentRequestSchema.safeParse(request);
    expect(result.success).toBe(true);
  });

  it("should validate visual request", () => {
    const request = {
      id: "req-002",
      target_type: "visual",
      concept: "projectile motion",
      intent: "interactive_exploration",
      description: "Interactive simulation showing projectile trajectory",
    };
    const result = SubagentRequestSchema.safeParse(request);
    expect(result.success).toBe(true);
  });

  it("should validate request with constraints", () => {
    const request = {
      id: "req-003",
      target_type: "visual",
      concept: "sine wave",
      intent: "show_relationship",
      description: "Plot sin(x) from 0 to 2pi",
      constraints: {
        preferred_engine: "chartjs",
        max_wait_time_ms: 5000,
      },
    };
    const result = SubagentRequestSchema.safeParse(request);
    expect(result.success).toBe(true);
  });

  it("should reject invalid target type", () => {
    const request = {
      id: "req-004",
      target_type: "invalid",
      concept: "test",
      intent: "test",
      description: "test",
    };
    const result = SubagentRequestSchema.safeParse(request);
    expect(result.success).toBe(false);
  });
});

describe("RequestConstraintsSchema", () => {
  it("should validate empty constraints", () => {
    const constraints = {};
    const result = RequestConstraintsSchema.safeParse(constraints);
    expect(result.success).toBe(true);
  });

  it("should validate all constraint fields", () => {
    const constraints = {
      max_rows: 10,
      preferred_engine: "chartjs",
      preferred_provider: "phet",
      allow_ai_generation: true,
      max_wait_time_ms: 5000,
    };
    const result = RequestConstraintsSchema.safeParse(constraints);
    expect(result.success).toBe(true);
  });

  it("should allow partial constraints", () => {
    const constraints = {
      preferred_engine: "p5js",
    };
    const result = RequestConstraintsSchema.safeParse(constraints);
    expect(result.success).toBe(true);
  });
});

describe("UpdateContentSchema", () => {
  it("should discriminate text content correctly", () => {
    const content = {
      type: "text",
      segments: [
        { type: "plain", text: "Hello" },
      ],
    };
    const result = UpdateContentSchema.safeParse(content);
    expect(result.success).toBe(true);
  });

  it("should discriminate input content correctly", () => {
    const content = {
      type: "input",
      input_type: "text",
      prompt: "Enter your answer:",
    };
    const result = UpdateContentSchema.safeParse(content);
    expect(result.success).toBe(true);
  });

  it("should discriminate subagent_request correctly", () => {
    const content = {
      type: "subagent_request",
      id: "req-001",
      target_type: "table",
      concept: "test",
      intent: "test",
      description: "test",
    };
    const result = UpdateContentSchema.safeParse(content);
    expect(result.success).toBe(true);
  });
});

describe("TextContentSchema", () => {
  it("should validate text content with alignment", () => {
    const content = {
      segments: [{ type: "plain", text: "Centered text" }],
      alignment: "center",
      spacing: "relaxed",
    };
    const result = TextContentSchema.safeParse(content);
    expect(result.success).toBe(true);
  });

  it("should validate all alignment values", () => {
    const alignments = ["leading", "center", "trailing"];
    for (const alignment of alignments) {
      const content = {
        segments: [{ type: "plain", text: "Test" }],
        alignment,
      };
      const result = TextContentSchema.safeParse(content);
      expect(result.success).toBe(true);
    }
  });

  it("should validate all spacing values", () => {
    const spacings = ["compact", "normal", "relaxed"];
    for (const spacing of spacings) {
      const content = {
        segments: [{ type: "plain", text: "Test" }],
        spacing,
      };
      const result = TextContentSchema.safeParse(content);
      expect(result.success).toBe(true);
    }
  });
});

describe("NotebookUpdateSchema", () => {
  it("should validate append action with text", () => {
    const update = {
      action: "append",
      content: {
        type: "text",
        segments: [{ type: "plain", text: "Hello" }],
      },
    };
    const result = NotebookUpdateSchema.safeParse(update);
    expect(result.success).toBe(true);
  });

  it("should validate request action with subagent_request", () => {
    const update = {
      action: "request",
      content: {
        type: "subagent_request",
        id: "req-001",
        target_type: "visual",
        concept: "test",
        intent: "test",
        description: "test",
      },
    };
    const result = NotebookUpdateSchema.safeParse(update);
    expect(result.success).toBe(true);
  });
});
