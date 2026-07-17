import { randomUUID } from "node:crypto";

export const validStatuses = new Set(["idle", "thinking", "complete", "needs_input", "error"]);
export const validActions = new Set(["approve", "reject", "interrupt", "new_chat", "prompt"]);
const MAX_AGENTS = 64;

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
    const agent = {
      id,
      name: boundedString(input.name, "name", 80),
      harness: boundedString(input.harness, "harness", 80),
      task: boundedString(input.task, "task", 500),
      status: input.status,
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
      ["73659c11-43ed-4aac-8f18-771b977c6901", "Codex", "Codex CLI", "Implement connector protocol", "thinking"],
      ["8fb44c64-d268-4728-bdc8-89c0ac9caad2", "Review", "Codex", "Review security boundary", "needs_input"],
      ["fc2e5070-041c-4ad2-a90e-959a34af3bbf", "Design", "Claude Code", "Polish tactile controls", "complete"],
      ["c8c71a25-245b-4eab-92a3-a03c39a9fa08", "Docs", "Generic", "Waiting for work", "idle"],
      ["25d4ee53-91e4-4b40-91ee-b33fe5472a2a", "Tests", "Codex", "Simulator smoke test", "error"],
    ];
    for (const [id, name, harness, task, status] of entries) {
      this.upsertAgent({ id, name, harness, task, status });
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
