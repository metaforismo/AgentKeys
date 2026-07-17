import test from "node:test";
import assert from "node:assert/strict";
import { ClaudeAdapter } from "../src/adapters/claude-agent-sdk.mjs";

const AGENT_ID = "90f9c233-70fc-43fb-a1ac-71b966c6eb35";
const SESSION_ID = "6e85b18d-cb94-4c2a-824d-77be23c1732d";

test("Claude adapter publishes model-specific controls without bypass permission mode", async (t) => {
  const { adapter, connector, factory } = fixture();
  t.after(() => adapter.close());
  await adapter.start();

  const agent = connector.upserts.at(-1);
  assert.equal(agent.provider, "claude_code");
  assert.deepEqual(agent.capabilities.modes, ["manual", "plan", "accept_edits", "auto"]);
  assert.deepEqual(agent.capabilities.models, ["sonnet", "opus"]);
  assert.deepEqual(agent.capabilities.efforts, ["low", "medium", "high", "max"]);
  assert.deepEqual(agent.capabilities.speeds, ["standard", "fast"]);
  assert.equal(agent.capabilities.supportsResume, true);
  assert.equal(agent.capabilities.supportsFork, true);
  assert.equal(agent.capabilities.supportsBranch, false);
  assert.equal(factory.calls[0].options.permissionMode, "default");
  assert.notEqual(factory.calls[0].options.permissionMode, "bypassPermissions");
});

test("Claude adapter streams prompts and applies runtime controls through the query", async (t) => {
  const { adapter, connector, factory } = fixture();
  t.after(() => adapter.close());
  await adapter.start();
  const query = factory.queries[0];

  connector.actions.push(
    action("set_mode", "plan"),
    action("set_model", "opus"),
    action("set_effort", "high"),
    action("set_speed", "standard"),
    action("prompt", "Review this change"),
  );
  await adapter.poll();

  assert.deepEqual(query.permissionModes, ["plan"]);
  assert.deepEqual(query.models, ["opus"]);
  assert.deepEqual(query.flagSettings, [{ effortLevel: "high" }, { fastMode: false }]);
  assert.deepEqual(await factory.calls[0].prompt.next(), {
    done: false,
    value: {
      type: "user",
      message: { role: "user", content: "Review this change" },
      parent_tool_use_id: null,
    },
  });
  assert.equal(connector.upserts.at(-1).status, "thinking");
});

test("Claude adapter pauses for and resolves the exact pending tool approval", async (t) => {
  const { adapter, connector, factory } = fixture();
  t.after(() => adapter.close());
  await adapter.start();
  const input = { command: "npm test", timeout: 120_000 };
  const decision = factory.calls[0].options.canUseTool("Bash", input, {});
  await eventLoop();

  assert.equal(connector.upserts.at(-1).status, "needs_input");
  assert.match(connector.upserts.at(-1).task, /npm test/);
  connector.actions.push(action("approve"));
  await adapter.poll();
  assert.deepEqual(await decision, { behavior: "allow", updatedInput: input });
  assert.equal(connector.upserts.at(-1).status, "thinking");

  const rejected = factory.calls[0].options.canUseTool("Write", { file_path: "/tmp/out" }, {});
  await eventLoop();
  connector.actions.push(action("reject"));
  await adapter.poll();
  assert.deepEqual(await rejected, { behavior: "deny", message: "User rejected this action in AgentKeys" });
});

test("Claude adapter maps authoritative SDK lifecycle events to AgentKeys states", async (t) => {
  const { adapter, connector, factory } = fixture();
  t.after(() => adapter.close());
  await adapter.start();
  const query = factory.queries[0];

  query.push({
    type: "system",
    subtype: "init",
    session_id: SESSION_ID,
    model: "claude-sonnet-test",
    permissionMode: "acceptEdits",
    fast_mode_state: "on",
  });
  await eventLoop();
  assert.equal(connector.upserts.at(-1).mode, "accept_edits");
  assert.equal(connector.upserts.at(-1).speed, "fast");

  query.push({ type: "system", subtype: "session_state_changed", session_id: SESSION_ID, state: "running" });
  await eventLoop();
  assert.equal(connector.upserts.at(-1).status, "thinking");

  query.push({ type: "result", subtype: "success", session_id: SESSION_ID });
  await eventLoop();
  assert.equal(connector.upserts.at(-1).status, "complete");

  query.push({ type: "system", subtype: "session_state_changed", session_id: SESSION_ID, state: "idle" });
  await eventLoop();
  assert.equal(connector.upserts.at(-1).status, "complete");
});

test("Claude adapter fails closed for structured questions, concurrent requests, and aborts", async (t) => {
  const { adapter, factory } = fixture();
  t.after(() => adapter.close());
  await adapter.start();
  const canUseTool = factory.calls[0].options.canUseTool;

  assert.deepEqual(await canUseTool("AskUserQuestion", { questions: [] }, {}), {
    behavior: "deny",
    message: "AgentKeys cannot represent this structured question yet",
  });

  const controller = new AbortController();
  controller.abort();
  assert.deepEqual(await canUseTool("Bash", { command: "pwd" }, { signal: controller.signal }), {
    behavior: "deny",
    message: "Claude cancelled the permission request",
    interrupt: true,
  });

  const pending = canUseTool("Bash", { command: "git diff" }, {});
  await eventLoop();
  assert.deepEqual(await canUseTool("Write", { file_path: "README.md" }, {}), {
    behavior: "deny",
    message: "Another AgentKeys approval is already pending",
  });
  adapter.close();
  assert.deepEqual(await pending, {
    behavior: "deny",
    message: "AgentKeys adapter closed",
    interrupt: true,
  });
});

test("Claude adapter resumes and forks through SDK session options", async (t) => {
  const { adapter, connector, factory } = fixture();
  t.after(() => adapter.close());
  await adapter.start({ sessionID: SESSION_ID });
  assert.equal(factory.calls[0].options.resume, SESSION_ID);
  assert.equal(factory.calls[0].options.forkSession, false);

  connector.actions.push(action("fork_session"));
  await adapter.poll();
  assert.equal(factory.calls[1].options.resume, SESSION_ID);
  assert.equal(factory.calls[1].options.forkSession, true);
  assert.notEqual(factory.calls[1].options.permissionMode, "bypassPermissions");
});

function fixture() {
  const connector = new FakeConnector();
  const factory = new FakeQueryFactory();
  const adapter = new ClaudeAdapter({
    queryFactory: factory.create,
    connector,
    agentID: AGENT_ID,
    cwd: "/tmp/project",
    logger: { error() {} },
  });
  return { adapter, connector, factory };
}

class FakeConnector {
  actions = [];
  upserts = [];

  async upsert(agent) {
    this.upserts.push(structuredClone(agent));
    return agent;
  }

  async drain() {
    return this.actions.splice(0);
  }
}

class FakeQueryFactory {
  calls = [];
  queries = [];

  create = ({ prompt, options }) => {
    const query = new FakeQuery();
    this.calls.push({ prompt, options });
    this.queries.push(query);
    return query;
  };
}

class FakeQuery {
  permissionModes = [];
  models = [];
  flagSettings = [];
  interrupted = false;
  closed = false;
  #waiter = null;
  #messages = [];

  async initializationResult() {
    return {
      models: [
        {
          value: "sonnet",
          resolvedModel: "claude-sonnet-test",
          displayName: "Sonnet",
          description: "Balanced",
          supportedEffortLevels: ["low", "medium", "high", "max"],
          supportsFastMode: true,
        },
        {
          value: "opus",
          resolvedModel: "claude-opus-test",
          displayName: "Opus",
          description: "Most capable",
          supportedEffortLevels: ["low", "medium", "high"],
          supportsFastMode: false,
        },
      ],
    };
  }

  async setPermissionMode(mode) { this.permissionModes.push(mode); }
  async setModel(model) { this.models.push(model); }
  async applyFlagSettings(settings) { this.flagSettings.push(settings); }
  async interrupt() { this.interrupted = true; }

  push(message) {
    if (this.closed) throw new Error("Fake query is closed");
    if (this.#waiter) {
      const waiter = this.#waiter;
      this.#waiter = null;
      waiter({ value: message, done: false });
    } else {
      this.#messages.push(message);
    }
  }

  close() {
    this.closed = true;
    this.#waiter?.({ value: undefined, done: true });
    this.#waiter = null;
  }

  next() {
    if (this.#messages.length) return Promise.resolve({ value: this.#messages.shift(), done: false });
    if (this.closed) return Promise.resolve({ value: undefined, done: true });
    return new Promise((resolve) => { this.#waiter = resolve; });
  }

  [Symbol.asyncIterator]() { return this; }
}

function action(type, text = null) {
  return { action: type, text, agentID: AGENT_ID, requestID: crypto.randomUUID() };
}

function eventLoop() {
  return new Promise((resolve) => setImmediate(resolve));
}
