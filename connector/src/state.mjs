import { randomUUID } from "node:crypto";

export const validStatuses = new Set(["idle", "thinking", "complete", "needs_input", "error"]);
export const validActions = new Set([
  "approve", "reject", "interrupt", "new_chat", "prompt",
  "set_mode", "set_effort", "set_speed", "create_branch", "workflow",
]);
const validProviders = new Set(["codex", "claude_code", "generic"]);
const validModes = new Set(["manual", "plan", "accept_edits", "auto"]);
const validEfforts = new Set(["low", "medium", "high", "xhigh", "max"]);
const validSpeeds = new Set(["standard", "fast"]);
const validWorkflows = new Set(["review_pr", "debug", "refactor", "tests"]);
const MAX_AGENTS = 64;

const defaultCapabilities = {
  codex: {
    modes: ["manual", "plan"],
    efforts: ["low", "medium", "high", "xhigh"],
    speeds: ["standard", "fast"],
    workflows: ["review_pr", "debug", "refactor", "tests"],
    supportsBranch: true,
  },
  claude_code: {
    modes: ["manual", "accept_edits", "plan", "auto"],
    efforts: ["low", "medium", "high", "xhigh", "max"],
    speeds: ["standard"],
    workflows: ["review_pr", "debug", "refactor", "tests"],
    supportsBranch: true,
  },
  generic: { modes: ["manual"], efforts: ["medium"], speeds: ["standard"], workflows: [], supportsBranch: false },
};

export class ConnectorState {
  #agents = new Map();
  #actions = new Map();
  #requestIDs = new Set();
  #requestIDOrder = [];
  #revision = 0;

  constructor({ demo = false } = {}) {
    if (demo) this.#seedDemo();
  }

  snapshot() {
    return { revision: this.#revision, agents: [...this.#agents.values()] };
  }

  upsertAgent(input) {
    if (!input || typeof input !== "object") throw new TypeError("agent must be an object");
    const id = assertUUID(input.id, "agent id");
    if (!validStatuses.has(input.status)) throw new TypeError("invalid agent status");
    const previous = this.#agents.get(id);
    if (!previous && this.#agents.size >= MAX_AGENTS) throw new RangeError("agent limit reached");
    const harness = boundedString(input.harness, "harness", 80);
    const provider = input.provider ?? inferProvider(harness);
    if (!validProviders.has(provider)) throw new TypeError("invalid agent provider");
    const capabilities = validateCapabilities(input.capabilities ?? defaultCapabilities[provider]);
    const mode = input.mode ?? "manual";
    const effort = input.effort ?? "medium";
    const speed = input.speed ?? "standard";
    if (!capabilities.modes.includes(mode)) throw new TypeError("mode is not supported by agent capabilities");
    if (!capabilities.efforts.includes(effort)) throw new TypeError("effort is not supported by agent capabilities");
    if (!capabilities.speeds.includes(speed)) throw new TypeError("speed is not supported by agent capabilities");
    const branch = input.branch == null ? null : validBranch(input.branch);
    if (branch && !capabilities.supportsBranch) throw new TypeError("branch is not supported by agent capabilities");
    const agent = {
      id,
      name: boundedString(input.name, "name", 80),
      harness,
      task: boundedString(input.task, "task", 500),
      status: input.status,
      provider,
      mode,
      effort,
      speed,
      branch,
      capabilities,
      updatedAt: new Date().toISOString(),
    };
    this.#agents.set(id, { ...previous, ...agent });
    this.#revision += 1;
    return agent;
  }

  enqueueAction(input) {
    if (!input || typeof input !== "object") throw new TypeError("action must be an object");
    const agentID = assertUUID(input.agentID, "agentID");
    const requestID = assertUUID(input.requestID, "requestID");
    if (!this.#agents.has(agentID)) throw new RangeError("unknown agent");
    if (!validActions.has(input.action)) throw new TypeError("invalid action");
    if (this.#requestIDs.has(requestID)) return { duplicate: true };
    const text = input.text == null ? null : boundedString(input.text, "text", 8_000);
    if (input.action === "prompt" && !text) throw new TypeError("prompt text is required");
    validateSemanticAction(this.#agents.get(agentID), input.action, text);

    this.#requestIDs.add(requestID);
    this.#requestIDOrder.push(requestID);
    if (this.#requestIDOrder.length > 10_000) {
      this.#requestIDs.delete(this.#requestIDOrder.shift());
    }
    const action = { agentID, requestID, action: input.action, text, createdAt: new Date().toISOString() };
    const queue = this.#actions.get(agentID) ?? [];
    queue.push(action);
    this.#actions.set(agentID, queue.slice(-100));
    return { duplicate: false, action };
  }

  drainActions(agentID) {
    const id = assertUUID(agentID, "agentID");
    const actions = this.#actions.get(id) ?? [];
    this.#actions.set(id, []);
    return actions;
  }

  #seedDemo() {
    const entries = [
      ["73659c11-43ed-4aac-8f18-771b977c6901", "Codex", "Codex CLI", "Implement connector protocol", "thinking", { effort: "high", speed: "fast", branch: "feat/control-deck" }],
      ["8fb44c64-d268-4728-bdc8-89c0ac9caad2", "Review", "Codex", "Review security boundary", "needs_input", { mode: "plan", effort: "xhigh", branch: "review/security" }],
      ["fc2e5070-041c-4ad2-a90e-959a34af3bbf", "Design", "Claude Code", "Polish tactile controls", "complete", { mode: "accept_edits", effort: "high", branch: "design/hardware-ui" }],
      ["c8c71a25-245b-4eab-92a3-a03c39a9fa08", "Docs", "Generic", "Waiting for work", "idle", {}],
      ["25d4ee53-91e4-4b40-91ee-b33fe5472a2a", "Tests", "Codex", "Simulator smoke test", "error", { branch: "test/smoke" }],
    ];
    for (const [id, name, harness, task, status, controls] of entries) {
      this.upsertAgent({ id, name, harness, task, status, ...controls });
    }
  }
}

export function newAgentID() {
  return randomUUID();
}

function assertUUID(value, field) {
  if (typeof value !== "string" || !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)) {
    throw new TypeError(`${field} must be a UUID`);
  }
  return value.toLowerCase();
}

function boundedString(value, field, maxLength) {
  if (typeof value !== "string") throw new TypeError(`${field} must be a string`);
  const text = value.trim();
  if (!text || text.length > maxLength) throw new TypeError(`${field} must be 1-${maxLength} characters`);
  return text;
}

function inferProvider(harness) {
  if (/codex/i.test(harness)) return "codex";
  if (/claude/i.test(harness)) return "claude_code";
  return "generic";
}

function validateCapabilities(input) {
  if (!input || typeof input !== "object" || Array.isArray(input)) throw new TypeError("capabilities must be an object");
  return {
    modes: enumArray(input.modes, "modes", validModes),
    efforts: enumArray(input.efforts, "efforts", validEfforts),
    speeds: enumArray(input.speeds, "speeds", validSpeeds),
    workflows: enumArray(input.workflows, "workflows", validWorkflows, true),
    supportsBranch: input.supportsBranch === true,
  };
}

function enumArray(value, field, allowed, allowEmpty = false) {
  if (!Array.isArray(value) || (!allowEmpty && value.length === 0) || value.length > allowed.size) {
    throw new TypeError(`invalid ${field}`);
  }
  if (new Set(value).size !== value.length || value.some((entry) => !allowed.has(entry))) {
    throw new TypeError(`invalid ${field}`);
  }
  return [...value];
}

function validateSemanticAction(agent, action, text) {
  if (action === "set_mode" && !agent.capabilities.modes.includes(text)) throw new TypeError("unsupported mode");
  if (action === "set_effort" && !agent.capabilities.efforts.includes(text)) throw new TypeError("unsupported effort");
  if (action === "set_speed" && !agent.capabilities.speeds.includes(text)) throw new TypeError("unsupported speed");
  if (action === "workflow" && !agent.capabilities.workflows.includes(text)) throw new TypeError("unsupported workflow");
  if (action === "create_branch") {
    if (!agent.capabilities.supportsBranch) throw new TypeError("branch is not supported");
    validBranch(text);
  }
}

function validBranch(value) {
  const branch = boundedString(value, "branch", 80);
  const components = branch.split("/");
  if (
    branch.startsWith("-") || branch.startsWith("/") || branch.endsWith("/") || branch.endsWith(".") ||
    branch.includes("..") || branch.includes("//") || !/^[A-Za-z0-9._/-]+$/.test(branch) ||
    components.some((component) => component.startsWith(".") || component.endsWith(".lock"))
  ) {
    throw new TypeError("invalid branch name");
  }
  return branch;
}
