// sessionModelIntegration.test.ts
// Integration tests for the end-to-end session model flow.
// Tests the complete lifecycle from request to response.

import {z} from "zod";
import {
  SessionModelSchema,
  AlanOutputSchema,
} from "../../alan/outputSchema";

// Simulated types that match the client-server contract.
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

type AlanRequest = z.infer<typeof AlanRequestSchema>;
type SessionModel = z.infer<typeof SessionModelSchema>;

describe("Session Model End-to-End Flow", () => {
  // Helper to create initial session model.
  function createInitialSessionModel(sessionId: string): SessionModel {
    return {
      session_id: sessionId,
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
  }

  // Helper to simulate Alan's response (updating the session model).
  function simulateAlanResponse(
    currentModel: SessionModel,
    updates: {
      goalDescription?: string;
      goalProgress?: number;
      goalStatus?: "active" | "completed" | "abandoned";
      newConcepts?: Record<string, { status: "introduced" | "practicing" | "mastered" | "struggling"; attempts: number }>;
      conceptUpdates?: Record<string, { status?: "introduced" | "practicing" | "mastered" | "struggling"; attempts?: number }>;
      signalUpdates?: Partial<SessionModel["signals"]>;
      newFacts?: string[];
    }
  ): SessionModel {
    const updatedModel = { ...currentModel };
    updatedModel.turn_count = currentModel.turn_count + 1;

    if (updates.goalDescription) {
      updatedModel.goal = {
        description: updates.goalDescription,
        status: updates.goalStatus || "active",
        progress: updates.goalProgress || 0,
      };
    } else if (currentModel.goal && updates.goalProgress !== undefined) {
      updatedModel.goal = {
        ...currentModel.goal,
        progress: updates.goalProgress,
        status: updates.goalStatus || currentModel.goal.status,
      };
    }

    if (updates.newConcepts) {
      updatedModel.concepts = {
        ...currentModel.concepts,
        ...updates.newConcepts,
      };
    }

    if (updates.conceptUpdates) {
      for (const [concept, update] of Object.entries(updates.conceptUpdates)) {
        if (currentModel.concepts[concept]) {
          updatedModel.concepts[concept] = {
            ...currentModel.concepts[concept],
            ...update,
          };
        }
      }
    }

    if (updates.signalUpdates) {
      updatedModel.signals = {
        ...currentModel.signals,
        ...updates.signalUpdates,
      };
    }

    if (updates.newFacts) {
      updatedModel.facts = [...currentModel.facts, ...updates.newFacts];
    }

    return updatedModel;
  }

  describe("Multi-Turn Conversation Simulation", () => {
    it("should track a complete tutoring session lifecycle", () => {
      const sessionId = "tutoring-session-001";

      // Turn 1: User starts without session model (first turn).
      const request1: AlanRequest = {
        messages: [
          { role: "user", content: "I want to learn about derivatives" },
        ],
        notebook_context: {
          document_id: sessionId,
        },
      };

      expect(AlanRequestSchema.safeParse(request1).success).toBe(true);

      // Alan initializes session model.
      const model1 = createInitialSessionModel(sessionId);
      const response1 = simulateAlanResponse(model1, {
        goalDescription: "Understand derivatives",
        goalProgress: 0,
        newFacts: ["Student wants to learn calculus"],
      });

      expect(response1.turn_count).toBe(2);
      expect(response1.goal?.description).toBe("Understand derivatives");

      // Turn 2: User asks a follow-up.
      const request2: AlanRequest = {
        messages: [
          { role: "user", content: "I want to learn about derivatives" },
          { role: "assistant", content: "Let me explain derivatives..." },
          { role: "user", content: "Can you show me an example?" },
        ],
        notebook_context: {
          document_id: sessionId,
        },
        session_model: response1,
      };

      expect(AlanRequestSchema.safeParse(request2).success).toBe(true);
      expect(request2.session_model?.goal?.description).toBe("Understand derivatives");

      // Alan introduces a concept and updates progress.
      const response2 = simulateAlanResponse(response1, {
        goalProgress: 25,
        newConcepts: {
          "derivatives": { status: "introduced", attempts: 0 },
        },
        signalUpdates: { engagement: "high" },
      });

      expect(response2.turn_count).toBe(3);
      expect(response2.goal?.progress).toBe(25);
      expect(response2.concepts["derivatives"]).toBeDefined();
      expect(response2.signals.engagement).toBe("high");

      // Turn 3: User attempts practice problem.
      const response3 = simulateAlanResponse(response2, {
        goalProgress: 40,
        conceptUpdates: {
          "derivatives": { status: "practicing", attempts: 1 },
        },
      });

      expect(response3.concepts["derivatives"].status).toBe("practicing");
      expect(response3.concepts["derivatives"].attempts).toBe(1);

      // Turn 4: User struggles.
      const response4 = simulateAlanResponse(response3, {
        goalProgress: 35,
        conceptUpdates: {
          "derivatives": { status: "struggling", attempts: 3 },
        },
        signalUpdates: { frustration: "mild", pace: "slow" },
        newFacts: ["Needs more examples with step-by-step solutions"],
      });

      expect(response4.concepts["derivatives"].status).toBe("struggling");
      expect(response4.signals.frustration).toBe("mild");
      expect(response4.facts).toContain("Needs more examples with step-by-step solutions");

      // Turn 5: User recovers and masters concept.
      const response5 = simulateAlanResponse(response4, {
        goalProgress: 100,
        goalStatus: "completed",
        conceptUpdates: {
          "derivatives": { status: "mastered", attempts: 5 },
        },
        signalUpdates: { frustration: "none", engagement: "high", pace: "normal" },
        newFacts: ["Successfully mastered basic derivatives"],
      });

      expect(response5.goal?.status).toBe("completed");
      expect(response5.goal?.progress).toBe(100);
      expect(response5.concepts["derivatives"].status).toBe("mastered");

      // Validate final model.
      const validated = SessionModelSchema.safeParse(response5);
      expect(validated.success).toBe(true);
    });

    it("should handle goal abandonment", () => {
      const sessionId = "abandoned-session";
      const model = createInitialSessionModel(sessionId);

      // User starts with a goal.
      const response1 = simulateAlanResponse(model, {
        goalDescription: "Learn advanced topology",
        goalProgress: 5,
      });

      // User struggles significantly.
      const response2 = simulateAlanResponse(response1, {
        goalProgress: 10,
        signalUpdates: { frustration: "high", engagement: "low", pace: "slow" },
        newConcepts: {
          "topology_basics": { status: "struggling", attempts: 5 },
        },
      });

      // User abandons goal.
      const response3: SessionModel = {
        ...response2,
        turn_count: response2.turn_count + 1,
        goal: {
          description: response2.goal!.description,
          status: "abandoned",
          progress: response2.goal!.progress,
        },
        facts: [...response2.facts, "Student decided to switch to simpler topic"],
      };

      expect(response3.goal?.status).toBe("abandoned");
      expect(SessionModelSchema.safeParse(response3).success).toBe(true);
    });

    it("should accumulate concepts across multiple topics", () => {
      const sessionId = "multi-topic-session";
      let model = createInitialSessionModel(sessionId);

      // Cover multiple concepts.
      model = simulateAlanResponse(model, {
        goalDescription: "Complete calculus review",
        newConcepts: { "limits": { status: "introduced", attempts: 0 } },
      });

      model = simulateAlanResponse(model, {
        goalProgress: 15,
        conceptUpdates: { "limits": { status: "mastered", attempts: 3 } },
        newConcepts: { "derivatives": { status: "introduced", attempts: 0 } },
      });

      model = simulateAlanResponse(model, {
        goalProgress: 30,
        conceptUpdates: { "derivatives": { status: "practicing", attempts: 2 } },
        newConcepts: { "chain_rule": { status: "introduced", attempts: 0 } },
      });

      model = simulateAlanResponse(model, {
        goalProgress: 45,
        conceptUpdates: {
          "derivatives": { status: "mastered", attempts: 4 },
          "chain_rule": { status: "practicing", attempts: 1 },
        },
        newConcepts: { "product_rule": { status: "introduced", attempts: 0 } },
      });

      expect(Object.keys(model.concepts).length).toBe(4);
      expect(model.concepts["limits"].status).toBe("mastered");
      expect(model.concepts["derivatives"].status).toBe("mastered");
      expect(model.concepts["chain_rule"].status).toBe("practicing");
      expect(model.concepts["product_rule"].status).toBe("introduced");
    });
  });

  describe("Request/Response Cycle Validation", () => {
    it("should validate request without session model", () => {
      const request: AlanRequest = {
        messages: [{ role: "user", content: "Hello" }],
        notebook_context: { document_id: "new-session" },
      };

      const result = AlanRequestSchema.safeParse(request);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.session_model).toBeUndefined();
      }
    });

    it("should validate request with session model", () => {
      const request: AlanRequest = {
        messages: [{ role: "user", content: "Continue" }],
        notebook_context: { document_id: "existing-session" },
        session_model: createInitialSessionModel("existing-session"),
      };

      const result = AlanRequestSchema.safeParse(request);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.session_model?.session_id).toBe("existing-session");
      }
    });

    it("should validate complete Alan output with updates and model", () => {
      const output = {
        notebook_updates: [
          {
            action: "append",
            content: {
              type: "text",
              segments: [
                { type: "plain", text: "Great question! Let me explain." },
              ],
            },
          },
          {
            action: "request",
            content: {
              type: "subagent_request",
              id: "req-visual-001",
              target_type: "visual",
              concept: "derivative graph",
              intent: "show_relationship",
              description: "Graph showing tangent line slope",
            },
          },
        ],
        session_model: {
          session_id: "output-test-session",
          turn_count: 3,
          goal: {
            description: "Understand derivatives",
            status: "active",
            progress: 30,
          },
          concepts: {
            "derivatives": { status: "practicing", attempts: 1 },
          },
          signals: {
            engagement: "high",
            frustration: "none",
            pace: "normal",
          },
          facts: ["Visual learner"],
        },
      };

      const result = AlanOutputSchema.safeParse(output);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.notebook_updates.length).toBe(2);
        expect(result.data.session_model.session_id).toBe("output-test-session");
      }
    });
  });

  describe("Signal Detection Scenarios", () => {
    it("should model high engagement signals", () => {
      let model = createInitialSessionModel("engagement-test");

      // User asks many questions.
      model = simulateAlanResponse(model, {
        signalUpdates: { engagement: "high" },
        newFacts: ["Asks follow-up questions", "Shows curiosity"],
      });

      expect(model.signals.engagement).toBe("high");
    });

    it("should model low engagement signals", () => {
      let model = createInitialSessionModel("disengaged-test");

      // User gives short responses.
      model = simulateAlanResponse(model, {
        signalUpdates: { engagement: "low" },
        newFacts: ["Short responses", "Not attempting problems"],
      });

      expect(model.signals.engagement).toBe("low");
    });

    it("should model frustration escalation", () => {
      let model = createInitialSessionModel("frustration-test");

      // Initial: no frustration.
      expect(model.signals.frustration).toBe("none");

      // User starts struggling.
      model = simulateAlanResponse(model, {
        signalUpdates: { frustration: "mild" },
      });
      expect(model.signals.frustration).toBe("mild");

      // User becomes very frustrated.
      model = simulateAlanResponse(model, {
        signalUpdates: { frustration: "high" },
        newFacts: ["Expressing confusion", "Asking to skip topic"],
      });
      expect(model.signals.frustration).toBe("high");
    });

    it("should model pace variations", () => {
      let model = createInitialSessionModel("pace-test");

      // Fast learner.
      model = simulateAlanResponse(model, {
        signalUpdates: { pace: "fast" },
        newFacts: ["Quick to solve problems", "Asks to move forward"],
      });
      expect(model.signals.pace).toBe("fast");

      // Reset to normal.
      model = simulateAlanResponse(model, {
        signalUpdates: { pace: "normal" },
      });
      expect(model.signals.pace).toBe("normal");

      // Slow learner.
      model = simulateAlanResponse(model, {
        signalUpdates: { pace: "slow" },
        newFacts: ["Needs extra time", "Asks for repetition"],
      });
      expect(model.signals.pace).toBe("slow");
    });
  });

  describe("Concept Status Transitions", () => {
    it("should model concept mastery progression", () => {
      let model = createInitialSessionModel("mastery-test");

      // Introduce concept.
      model = simulateAlanResponse(model, {
        newConcepts: { "algebra": { status: "introduced", attempts: 0 } },
      });
      expect(model.concepts["algebra"].status).toBe("introduced");

      // Start practicing.
      model = simulateAlanResponse(model, {
        conceptUpdates: { "algebra": { status: "practicing", attempts: 1 } },
      });
      expect(model.concepts["algebra"].status).toBe("practicing");

      // More practice.
      model = simulateAlanResponse(model, {
        conceptUpdates: { "algebra": { attempts: 3 } },
      });
      expect(model.concepts["algebra"].attempts).toBe(3);

      // Master concept.
      model = simulateAlanResponse(model, {
        conceptUpdates: { "algebra": { status: "mastered", attempts: 5 } },
      });
      expect(model.concepts["algebra"].status).toBe("mastered");
      expect(model.concepts["algebra"].attempts).toBe(5);
    });

    it("should model struggling and recovery", () => {
      let model = createInitialSessionModel("struggle-test");

      // Start practicing.
      model = simulateAlanResponse(model, {
        newConcepts: { "calculus": { status: "practicing", attempts: 1 } },
      });

      // Start struggling.
      model = simulateAlanResponse(model, {
        conceptUpdates: { "calculus": { status: "struggling", attempts: 4 } },
        signalUpdates: { frustration: "mild" },
      });
      expect(model.concepts["calculus"].status).toBe("struggling");

      // Recover with different approach.
      model = simulateAlanResponse(model, {
        conceptUpdates: { "calculus": { status: "practicing", attempts: 6 } },
        signalUpdates: { frustration: "none" },
        newFacts: ["Responded well to visual explanation"],
      });
      expect(model.concepts["calculus"].status).toBe("practicing");

      // Eventually master.
      model = simulateAlanResponse(model, {
        conceptUpdates: { "calculus": { status: "mastered", attempts: 8 } },
      });
      expect(model.concepts["calculus"].status).toBe("mastered");
    });
  });

  describe("Facts Accumulation", () => {
    it("should accumulate learning preferences", () => {
      let model = createInitialSessionModel("preferences-test");

      model = simulateAlanResponse(model, {
        newFacts: ["Visual learner"],
      });

      model = simulateAlanResponse(model, {
        newFacts: ["Prefers step-by-step examples"],
      });

      model = simulateAlanResponse(model, {
        newFacts: ["Works better with real-world applications"],
      });

      expect(model.facts).toHaveLength(3);
      expect(model.facts).toContain("Visual learner");
      expect(model.facts).toContain("Prefers step-by-step examples");
      expect(model.facts).toContain("Works better with real-world applications");
    });

    it("should track learning context", () => {
      let model = createInitialSessionModel("context-test");

      model = simulateAlanResponse(model, {
        newFacts: ["Studying for AP Calculus exam"],
      });

      model = simulateAlanResponse(model, {
        newFacts: ["Exam in 2 weeks"],
      });

      model = simulateAlanResponse(model, {
        newFacts: ["Strong in algebra, weak in integration"],
      });

      expect(model.facts).toContain("Studying for AP Calculus exam");
      expect(model.facts).toContain("Exam in 2 weeks");
      expect(model.facts).toContain("Strong in algebra, weak in integration");
    });
  });

  describe("Session Consistency", () => {
    it("should maintain session_id across all turns", () => {
      const sessionId = "consistent-session-id";
      let model = createInitialSessionModel(sessionId);

      for (let i = 0; i < 10; i++) {
        model = simulateAlanResponse(model, {
          goalProgress: i * 10,
        });
        expect(model.session_id).toBe(sessionId);
      }
    });

    it("should increment turn_count correctly", () => {
      let model = createInitialSessionModel("turn-count-test");
      expect(model.turn_count).toBe(1);

      for (let i = 0; i < 20; i++) {
        model = simulateAlanResponse(model, {});
        expect(model.turn_count).toBe(i + 2);
      }
    });
  });
});

describe("JSON Serialization Round-Trip", () => {
  it("should survive JSON round-trip with all fields", () => {
    const model: SessionModel = {
      session_id: "round-trip-test",
      turn_count: 15,
      goal: {
        description: "Master all calculus concepts",
        status: "active",
        progress: 75,
      },
      concepts: {
        "limits": { status: "mastered", attempts: 5 },
        "derivatives": { status: "mastered", attempts: 8 },
        "integration": { status: "practicing", attempts: 3 },
      },
      signals: {
        engagement: "high",
        frustration: "none",
        pace: "fast",
      },
      facts: [
        "Quick learner",
        "Prefers visual examples",
        "Studying for AP exam",
      ],
    };

    const json = JSON.stringify(model);
    const parsed = JSON.parse(json);
    const validated = SessionModelSchema.safeParse(parsed);

    expect(validated.success).toBe(true);
    if (validated.success) {
      expect(validated.data).toEqual(model);
    }
  });

  it("should handle null goal in round-trip", () => {
    const model: SessionModel = {
      session_id: "null-goal-test",
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

    const json = JSON.stringify(model);
    const parsed = JSON.parse(json);
    const validated = SessionModelSchema.safeParse(parsed);

    expect(validated.success).toBe(true);
    if (validated.success) {
      expect(validated.data.goal).toBeNull();
    }
  });
});
