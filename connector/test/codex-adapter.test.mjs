import test from "node:test";
import assert from "node:assert/strict";
import { EventEmitter } from "node:events";
import { PassThrough } from "node:stream";
import {
  CodexAdapter,
  CodexAppServerClient,
} from "../src/adapters/codex-app-server.mjs";

const THREAD_ID = "019f71ca-248e-7cf2-a0a1-76dc7e660c9f";
const TURN_ID = "019f71ca-3300-7f03-a925-63e626103dd3";
const AGENT_ID = "90f9c233-70fc-43fb-a1ac-71b966c6eb35";

test("Codex app-server client uses JSONL requests, initialization, and exact response ids", async () => {
  const child = fakeChild();
  const client = new CodexAppServerClient({ spawnProcess: () => child, logger: silentLogger });

  const initialized = client.initialize();
  const request = JSON.parse(await nextLine(child.stdin));
  assert.equal(request.method, "initialize");
  assert.equal(request.id, 1);
  assert.equal(request.params.capabilities.experimentalApi, true);

  child.stdout.write(`${JSON.stringify({ id: 1, result: { userAgent: "codex-test" } })}\n`);
  assert.equal((await initialized).userAgent, "codex-test");
  assert.deepEqual(JSON.parse(await nextLine(child.stdin)), { method: "initialized" });

  const serverRequest = onceEvent(client, "request");
  child.stdout.write(`${JSON.stringify({ method: "item/fileChange/requestApproval", id: "approval-7", params: {} })}\n`);
  assert.equal((await serverRequest).id, "approval-7");
  client.respond("approval-7", { decision: "decline" });
  assert.deepEqual(JSON.parse(await nextLine(child.stdin)), {
    id: "approval-7",
    result: { decision: "decline" },
  });
  client.close();
});

test("adapter publishes conservative capabilities and applies next-turn controls", async () => {
  const { adapter, rpc, connector } = fixture();
  const session = await adapter.start();

  assert.equal(session.threadID, THREAD_ID);
  const initial = connector.upserts.at(-1);
  assert.equal(initial.status, "idle");
  assert.deepEqual(initial.capabilities.modes, ["manual"]);
  assert.deepEqual(initial.capabilities.models, ["gpt-test"]);
  assert.deepEqual(initial.capabilities.efforts, ["low", "medium", "high"]);
  assert.deepEqual(initial.capabilities.speeds, ["standard", "fast"]);
  assert.equal(initial.capabilities.supportsBranch, false);
  assert.equal(initial.capabilities.supportsResume, true);
  assert.equal(initial.capabilities.supportsFork, true);
  assert.equal(initial.capabilities.supportsWebSearch, false);

  connector.actions.push(
    action("set_model", "gpt-test"),
    action("set_effort", "high"),
    action("set_speed", "fast"),
    action("prompt", "Review the staged diff"),
  );
  await adapter.poll();

  const turn = rpc.calls.find((call) => call.method === "turn/start");
  assert.deepEqual(turn.params, {
    threadId: THREAD_ID,
    input: [{ type: "text", text: "Review the staged diff", text_elements: [] }],
    model: "gpt-test",
    effort: "high",
    serviceTier: "priority",
  });
  assert.equal(connector.upserts.at(-1).status, "thinking");
});

test("adapter forwards only the active approval id and lifecycle state", async () => {
  const { adapter, rpc, connector } = fixture();
  await adapter.start();
  connector.actions.push(action("prompt", "Run the tests"));
  await adapter.poll();

  rpc.emit("request", {
    method: "item/commandExecution/requestApproval",
    id: "request-42",
    params: {
      threadId: THREAD_ID,
      turnId: TURN_ID,
      command: "npm test",
      availableDecisions: ["accept", "decline"],
    },
  });
  await eventLoop();
  assert.equal(connector.upserts.at(-1).status, "needs_input");
  assert.match(connector.upserts.at(-1).task, /npm test/);

  connector.actions.push(action("approve"));
  await adapter.poll();
  assert.deepEqual(rpc.responses, [{ id: "request-42", result: { decision: "accept" } }]);
  assert.equal(connector.upserts.at(-1).status, "thinking");

  rpc.emit("notification", {
    method: "turn/completed",
    params: { threadId: THREAD_ID, turn: { id: TURN_ID, status: "completed" } },
  });
  await eventLoop();
  assert.equal(connector.upserts.at(-1).status, "complete");

  rpc.emit("notification", {
    method: "thread/status/changed",
    params: { threadId: THREAD_ID, status: { type: "idle" } },
  });
  await eventLoop();
  assert.equal(connector.upserts.at(-1).status, "complete");
});

test("adapter fails closed for unsupported server requests and mismatched approvals", async () => {
  const { adapter, rpc, connector } = fixture();
  await adapter.start();

  rpc.emit("request", {
    method: "item/tool/requestUserInput",
    id: 91,
    params: { threadId: THREAD_ID, turnId: TURN_ID },
  });
  await eventLoop();
  assert.deepEqual(rpc.errors.at(-1), {
    id: 91,
    code: -32601,
    message: "AgentKeys does not support item/tool/requestUserInput",
  });
  assert.equal(connector.upserts.at(-1).status, "error");

  rpc.emit("request", {
    method: "item/fileChange/requestApproval",
    id: 92,
    params: { threadId: "different-thread", turnId: TURN_ID },
  });
  await eventLoop();
  assert.equal(rpc.errors.at(-1).code, -32602);
});

test("adapter resumes and forks through app-server instead of synthesizing sessions", async () => {
  const { adapter, rpc, connector } = fixture();
  await adapter.start({ threadID: THREAD_ID });
  assert.equal(rpc.calls.some((call) => call.method === "thread/resume"), true);

  connector.actions.push(action("fork_session"));
  await adapter.poll();
  const fork = rpc.calls.find((call) => call.method === "thread/fork");
  assert.equal(fork.params.threadId, THREAD_ID);
  assert.equal(adapter.threadID, "019f71ca-9999-7f03-a925-63e626103dd3");
});

function fixture() {
  const rpc = new FakeRPC();
  const connector = new FakeConnector();
  const adapter = new CodexAdapter({
    rpc,
    connector,
    agentID: AGENT_ID,
    cwd: "/tmp/project",
    logger: silentLogger,
  });
  return { adapter, rpc, connector };
}

class FakeRPC extends EventEmitter {
  calls = [];
  responses = [];
  errors = [];

  async initialize() {
    return { userAgent: "codex-test" };
  }

  async request(method, params) {
    this.calls.push({ method, params });
    if (method === "model/list") {
      return {
        data: [{
          model: "gpt-test",
          hidden: false,
          isDefault: true,
          supportedReasoningEfforts: ["low", "medium", "high"].map((reasoningEffort) => ({ reasoningEffort })),
          serviceTiers: [{ id: "priority", name: "Priority" }],
        }],
      };
    }
    if (method === "turn/start") return { turn: { id: TURN_ID, status: "inProgress" } };
    if (method === "thread/fork") return threadResult("019f71ca-9999-7f03-a925-63e626103dd3");
    if (method === "thread/start" || method === "thread/resume") return threadResult(THREAD_ID);
    return {};
  }

  respond(id, result) {
    this.responses.push({ id, result });
  }

  respondError(id, code, message) {
    this.errors.push({ id, code, message });
  }
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

function threadResult(id) {
  return {
    thread: { id, status: { type: "idle" } },
    model: "gpt-test",
    reasoningEffort: "medium",
    serviceTier: null,
  };
}

function action(type, text = null) {
  return { action: type, text, agentID: AGENT_ID, requestID: crypto.randomUUID() };
}

function fakeChild() {
  const child = new EventEmitter();
  child.stdin = new LineSink();
  child.stdout = new PassThrough();
  child.stderr = new PassThrough();
  child.kill = () => child.emit("exit", 0, "SIGTERM");
  return child;
}

async function nextLine(stream) {
  return stream.nextLine();
}

class LineSink {
  writable = true;
  #lines = [];
  #waiters = [];

  write(chunk) {
    for (const line of chunk.toString().split("\n").filter(Boolean)) {
      const waiter = this.#waiters.shift();
      if (waiter) waiter(line);
      else this.#lines.push(line);
    }
    return true;
  }

  nextLine() {
    if (this.#lines.length) return Promise.resolve(this.#lines.shift());
    return new Promise((resolve) => this.#waiters.push(resolve));
  }
}

function onceEvent(emitter, name) {
  return new Promise((resolve) => emitter.once(name, resolve));
}

function eventLoop() {
  return new Promise((resolve) => setImmediate(resolve));
}

const silentLogger = { error() {}, log() {} };
