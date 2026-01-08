// graphingCalculator.ts
// Gemini-powered interpretation of JIIX content and natural language prompts
// to generate GraphSpecification JSON for the Graphing Calculator skill.

import * as logger from "firebase-functions/logger";

// GraphSpecification type definitions matching Swift implementation.
interface GraphViewport {
  xMin: number;
  xMax: number;
  yMin: number;
  yMax: number;
  aspectRatio: "auto" | "equal" | "free";
}

interface AxisConfiguration {
  label: string;
  gridSpacing: number;
  showGrid: boolean;
  showAxis: boolean;
  tickLabels: boolean;
}

interface GraphAxes {
  x: AxisConfiguration;
  y: AxisConfiguration;
}

interface ParameterRange {
  min: number;
  max: number;
  step?: number;
}

interface EquationStyle {
  color: string;
  lineWidth: number;
  lineStyle: "solid" | "dashed" | "dotted";
  fillBelow?: boolean;
  fillAbove?: boolean;
  fillColor?: string;
  fillOpacity?: number;
}

interface GraphEquation {
  id: string;
  type: "explicit" | "parametric" | "polar" | "implicit" | "inequality";
  expression?: string;
  xExpression?: string;
  yExpression?: string;
  rExpression?: string;
  variable?: string;
  parameter?: string;
  domain?: ParameterRange;
  parameterRange?: ParameterRange;
  thetaRange?: ParameterRange;
  style: EquationStyle;
  label?: string;
  visible: boolean;
  fillRegion?: boolean;
  boundaryStyle?: string;
}

interface PointStyle {
  color: string;
  size: number;
  shape: "circle" | "square" | "triangle" | "diamond" | "cross";
  filled: boolean;
}

interface GraphPoint {
  id: string;
  x: number;
  y: number;
  label?: string;
  style: PointStyle;
  draggable: boolean;
  visible: boolean;
}

interface GraphAnnotation {
  id: string;
  type: "label" | "arrow" | "line" | "rectangle" | "circle";
  position: { x: number; y: number };
  text?: string;
  style: Record<string, unknown>;
}

interface GraphInteractivity {
  allowPan: boolean;
  allowZoom: boolean;
  allowTrace: boolean;
  showCoordinates: boolean;
  snapToGrid: boolean;
}

/**
 * Full GraphSpecification structure matching Swift implementation.
 */
export interface GraphSpecification {
  version: string;
  title?: string;
  viewport: GraphViewport;
  axes: GraphAxes;
  equations: GraphEquation[];
  points?: GraphPoint[];
  annotations?: GraphAnnotation[];
  interactivity: GraphInteractivity;
}

// Default configuration values.
const DEFAULTS = {
  version: "1.0",
  xMin: -10,
  xMax: 10,
  yMin: -10,
  yMax: 10,
  lineColor: "#2196F3",
  lineWidth: 2.0,
  gridSpacing: 1.0,
};

// Color palette for multiple equations.
const EQUATION_COLORS = [
  "#2196F3", // Blue
  "#F44336", // Red
  "#4CAF50", // Green
  "#9C27B0", // Purple
  "#FF9800", // Orange
  "#00BCD4", // Cyan
  "#E91E63", // Pink
  "#3F51B5", // Indigo
];

// System prompt for Gemini to interpret mathematical content.
const GRAPH_INTERPRETATION_PROMPT = `You are a mathematical graph \
specification generator. Your task is to analyze mathematical content \
(either JIIX handwriting data or natural language descriptions) and \
generate a GraphSpecification JSON object.

OUTPUT FORMAT:
You must respond with ONLY valid JSON matching this schema:

{
  "version": "1.0",
  "title": "optional title",
  "viewport": {
    "xMin": number, "xMax": number,
    "yMin": number, "yMax": number,
    "aspectRatio": "auto" | "equal" | "free"
  },
  "axes": {
    "x": { "label": "x", "gridSpacing": 1, "showGrid": true,
           "showAxis": true, "tickLabels": true },
    "y": { "label": "y", "gridSpacing": 1, "showGrid": true,
           "showAxis": true, "tickLabels": true }
  },
  "equations": [
    {
      "id": "eq-1",
      "type": "explicit" | "parametric" | "polar" | "implicit" | "inequality",
      "expression": "for explicit: f(x) like 'x^2', 'sin(x)', etc.",
      "xExpression": "for parametric: x(t)",
      "yExpression": "for parametric: y(t)",
      "rExpression": "for polar: r(theta)",
      "variable": "x" | "t" | "theta",
      "parameter": "t for parametric",
      "domain": { "min": number, "max": number },
      "parameterRange": { "min": number, "max": number },
      "thetaRange": { "min": number, "max": number },
      "style": {
        "color": "#hex", "lineWidth": 2,
        "lineStyle": "solid" | "dashed" | "dotted",
        "fillBelow": boolean, "fillAbove": boolean,
        "fillColor": "#hex", "fillOpacity": 0-1
      },
      "label": "display label",
      "visible": true,
      "fillRegion": boolean,
      "boundaryStyle": "solid" | "dashed"
    }
  ],
  "points": [
    {
      "id": "pt-1", "x": number, "y": number, "label": "optional",
      "style": { "color": "#hex", "size": 8, "shape": "circle",
                 "filled": true },
      "draggable": false, "visible": true
    }
  ],
  "annotations": [],
  "interactivity": {
    "allowPan": true, "allowZoom": true, "allowTrace": true,
    "showCoordinates": true, "snapToGrid": false
  }
}

EQUATION TYPE RULES:
- explicit: y = f(x). Use "expression" and "variable": "x".
- parametric: x(t), y(t). Use "xExpression", "yExpression", "parameter": "t".
- polar: r = f(theta). Use "rExpression", "variable": "theta", "thetaRange".
- implicit: F(x,y) = 0. Use "expression" with x and y.
- inequality: y < f(x). Use "expression", set "fillRegion": true.

EXPRESSION SYNTAX:
- Use standard math: x^2 (power), sqrt(x), sin(x), cos(x), tan(x), etc.
- Multiplication must be explicit: "2*x" not "2x"
- Pi is "pi" or "PI", e is "e" or "E"

VIEWPORT GUIDELINES:
- For polynomials: typically -10 to 10
- For trig functions: consider period (e.g., -2*pi to 2*pi)
- Use "equal" aspectRatio for circles/geometric shapes

COLOR ASSIGNMENT:
- First equation: #2196F3 (blue)
- Second: #F44336 (red)
- Third: #4CAF50 (green)
- Continue cycling through palette

RESPOND WITH ONLY THE JSON OBJECT.`;

/**
 * Interprets JIIX handwriting data and generates a GraphSpecification.
 * @param {string} jiixContent - The JIIX JSON content to interpret.
 * @param {string} apiKey - The Gemini API key.
 * @return {Promise<GraphSpecification>} The generated graph specification.
 */
export async function interpretJIIXForGraph(
  jiixContent: string,
  apiKey: string
): Promise<GraphSpecification> {
  logger.info("Interpreting JIIX for graph", {
    contentLength: jiixContent.length,
  });

  // Parse JIIX to extract mathematical expressions.
  let mathContent = "";
  try {
    const jiix = JSON.parse(jiixContent);
    mathContent = extractMathFromJIIX(jiix);
    logger.info("Extracted math content from JIIX", {mathContent});
  } catch (error) {
    logger.warn("Failed to parse JIIX, using raw content", {error});
    mathContent = jiixContent;
  }

  if (!mathContent.trim()) {
    logger.warn("No mathematical content found in JIIX");
    return createDefaultGraphSpec();
  }

  // Call Gemini to interpret the math content.
  const userPrompt = `Analyze this handwritten mathematical content \
and generate a GraphSpecification:

${mathContent}

Generate appropriate equations, viewport, and styling based on what you see.`;

  return await callGeminiForGraph(userPrompt, apiKey);
}

/**
 * Generates a GraphSpecification from a natural language prompt.
 * @param {string} prompt - The natural language description.
 * @param {string} apiKey - The Gemini API key.
 * @return {Promise<GraphSpecification>} The generated graph specification.
 */
export async function generateGraphFromPrompt(
  prompt: string,
  apiKey: string
): Promise<GraphSpecification> {
  logger.info("Generating graph from prompt", {prompt});

  const userPrompt = `Generate a GraphSpecification for the following request:

${prompt}

Include all necessary equations, points, and appropriate viewport settings.`;

  return await callGeminiForGraph(userPrompt, apiKey);
}

/**
 * Extracts mathematical expressions from JIIX data structure.
 * @param {Record<string, unknown>} jiix - The parsed JIIX object.
 * @return {string} Extracted mathematical expressions.
 */
function extractMathFromJIIX(jiix: Record<string, unknown>): string {
  const expressions: string[] = [];

  /**
   * Helper to recursively find math content.
   * @param {unknown} obj - Object to search.
   */
  function findMath(obj: unknown): void {
    if (!obj || typeof obj !== "object") return;

    const record = obj as Record<string, unknown>;

    // Look for label (recognized text).
    if (typeof record.label === "string") {
      expressions.push(record.label);
    }

    // Look for export property (LaTeX or text export).
    if (record.export && typeof record.export === "object") {
      const exportObj = record.export as Record<string, string>;
      if (exportObj["text/plain"]) {
        expressions.push(exportObj["text/plain"]);
      }
      if (exportObj["application/x-latex"]) {
        expressions.push(`LaTeX: ${exportObj["application/x-latex"]}`);
      }
    }

    // Look for words/chars in text content.
    if (Array.isArray(record.words)) {
      for (const word of record.words) {
        if (typeof word === "object" && word !== null) {
          const wordObj = word as Record<string, unknown>;
          if (typeof wordObj.label === "string") {
            expressions.push(wordObj.label);
          }
        }
      }
    }

    // Recurse into children.
    if (Array.isArray(record.children)) {
      for (const child of record.children) {
        findMath(child);
      }
    }
    if (Array.isArray(record.elements)) {
      for (const element of record.elements) {
        findMath(element);
      }
    }
    if (Array.isArray(record.items)) {
      for (const item of record.items) {
        findMath(item);
      }
    }
  }

  findMath(jiix);
  return expressions.join("\n");
}

/**
 * Calls Gemini API to generate a GraphSpecification.
 * @param {string} userPrompt - The prompt to send to Gemini.
 * @param {string} apiKey - The Gemini API key.
 * @return {Promise<GraphSpecification>} The generated graph specification.
 */
async function callGeminiForGraph(
  userPrompt: string,
  apiKey: string
): Promise<GraphSpecification> {
  try {
    const apiUrl = "https://generativelanguage.googleapis.com/v1beta" +
      `/models/gemini-2.0-flash-lite:generateContent?key=${apiKey}`;

    const response = await fetch(apiUrl, {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({
        systemInstruction: {
          parts: [{text: GRAPH_INTERPRETATION_PROMPT}],
        },
        contents: [
          {
            role: "user",
            parts: [{text: userPrompt}],
          },
        ],
        generationConfig: {
          responseMimeType: "application/json",
          temperature: 0.2,
        },
      }),
    });

    const data = await response.json();

    if (!response.ok) {
      logger.error("Gemini API error for graph generation", {
        status: response.status,
        data,
      });
      throw new Error(`Gemini API error: ${JSON.stringify(data)}`);
    }

    // Extract JSON from response.
    const text = data.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!text) {
      logger.error("Empty response from Gemini for graph");
      return createDefaultGraphSpec();
    }

    // Parse and validate the GraphSpecification.
    const spec = JSON.parse(text) as GraphSpecification;
    return validateAndNormalizeSpec(spec);
  } catch (error) {
    logger.error("Failed to generate graph with Gemini", {error});
    return createDefaultGraphSpec();
  }
}

/**
 * Validates and normalizes a GraphSpecification, filling in defaults.
 * @param {GraphSpecification} spec - The specification to validate.
 * @return {GraphSpecification} The normalized specification.
 */
function validateAndNormalizeSpec(
  spec: GraphSpecification
): GraphSpecification {
  // Ensure version.
  spec.version = spec.version || DEFAULTS.version;

  // Validate viewport.
  if (!spec.viewport) {
    spec.viewport = {
      xMin: DEFAULTS.xMin,
      xMax: DEFAULTS.xMax,
      yMin: DEFAULTS.yMin,
      yMax: DEFAULTS.yMax,
      aspectRatio: "auto",
    };
  } else {
    if (spec.viewport.xMin >= spec.viewport.xMax) {
      spec.viewport.xMin = DEFAULTS.xMin;
      spec.viewport.xMax = DEFAULTS.xMax;
    }
    if (spec.viewport.yMin >= spec.viewport.yMax) {
      spec.viewport.yMin = DEFAULTS.yMin;
      spec.viewport.yMax = DEFAULTS.yMax;
    }
    spec.viewport.aspectRatio = spec.viewport.aspectRatio || "auto";
  }

  // Validate axes.
  if (!spec.axes) {
    spec.axes = createDefaultAxes();
  } else {
    spec.axes.x = normalizeAxisConfig(spec.axes.x, "x");
    spec.axes.y = normalizeAxisConfig(spec.axes.y, "y");
  }

  // Validate equations.
  if (!spec.equations || !Array.isArray(spec.equations)) {
    spec.equations = [];
  } else {
    spec.equations = spec.equations.map((eq, index) =>
      normalizeEquation(eq, index)
    );
  }

  // Validate interactivity.
  if (!spec.interactivity) {
    spec.interactivity = {
      allowPan: true,
      allowZoom: true,
      allowTrace: true,
      showCoordinates: true,
      snapToGrid: false,
    };
  }

  return spec;
}

/**
 * Normalizes axis configuration with defaults.
 * @param {AxisConfiguration | undefined} config - The axis config.
 * @param {string} label - The default label.
 * @return {AxisConfiguration} The normalized axis configuration.
 */
function normalizeAxisConfig(
  config: AxisConfiguration | undefined,
  label: string
): AxisConfiguration {
  if (!config) {
    return {
      label,
      gridSpacing: DEFAULTS.gridSpacing,
      showGrid: true,
      showAxis: true,
      tickLabels: true,
    };
  }
  return {
    label: config.label || label,
    gridSpacing: config.gridSpacing || DEFAULTS.gridSpacing,
    showGrid: config.showGrid !== false,
    showAxis: config.showAxis !== false,
    tickLabels: config.tickLabels !== false,
  };
}

/**
 * Normalizes equation with defaults and assigned color.
 * @param {GraphEquation} eq - The equation to normalize.
 * @param {number} index - The equation index for color assignment.
 * @return {GraphEquation} The normalized equation.
 */
function normalizeEquation(
  eq: GraphEquation,
  index: number
): GraphEquation {
  const colorIndex = index % EQUATION_COLORS.length;

  return {
    id: eq.id || `eq-${index + 1}`,
    type: eq.type || "explicit",
    expression: eq.expression,
    xExpression: eq.xExpression,
    yExpression: eq.yExpression,
    rExpression: eq.rExpression,
    variable: eq.variable || "x",
    parameter: eq.parameter,
    domain: eq.domain,
    parameterRange: eq.parameterRange,
    thetaRange: eq.thetaRange,
    style: {
      color: eq.style?.color || EQUATION_COLORS[colorIndex],
      lineWidth: eq.style?.lineWidth || DEFAULTS.lineWidth,
      lineStyle: eq.style?.lineStyle || "solid",
      fillBelow: eq.style?.fillBelow,
      fillAbove: eq.style?.fillAbove,
      fillColor: eq.style?.fillColor,
      fillOpacity: eq.style?.fillOpacity,
    },
    label: eq.label,
    visible: eq.visible !== false,
    fillRegion: eq.fillRegion,
    boundaryStyle: eq.boundaryStyle,
  };
}

/**
 * Creates default axes configuration.
 * @return {GraphAxes} The default axes.
 */
function createDefaultAxes(): GraphAxes {
  return {
    x: {
      label: "x",
      gridSpacing: DEFAULTS.gridSpacing,
      showGrid: true,
      showAxis: true,
      tickLabels: true,
    },
    y: {
      label: "y",
      gridSpacing: DEFAULTS.gridSpacing,
      showGrid: true,
      showAxis: true,
      tickLabels: true,
    },
  };
}

/**
 * Creates a default empty GraphSpecification.
 * @return {GraphSpecification} The default specification.
 */
function createDefaultGraphSpec(): GraphSpecification {
  return {
    version: DEFAULTS.version,
    title: undefined,
    viewport: {
      xMin: DEFAULTS.xMin,
      xMax: DEFAULTS.xMax,
      yMin: DEFAULTS.yMin,
      yMax: DEFAULTS.yMax,
      aspectRatio: "auto",
    },
    axes: createDefaultAxes(),
    equations: [],
    points: undefined,
    annotations: undefined,
    interactivity: {
      allowPan: true,
      allowZoom: true,
      allowTrace: true,
      showCoordinates: true,
      snapToGrid: false,
    },
  };
}
