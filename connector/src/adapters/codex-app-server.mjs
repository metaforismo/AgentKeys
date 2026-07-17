import { EventEmitter } from "node:events";
import { spawn } from "node:child_process";

const APPROVAL_METHODS = new Set([
  "item/commandExecution/requestApproval",
  "item/fileChange/requestApproval",
]);
const ALLOWED_EFFORTS = new Set(["low", "medium", "high", "xhigh", "max"]);

export class CodexAppServerClient extends EventEmitter {
  #child;
  #buffer = "";
  #nextID = 1;
  #pending = new Map();

  constructor({ binary = "codex", spawnProcess = spawn, logger = console } = {}) {
    super();
    this.logger = logger;
    this.#child = spawnProcess(binary, ["app-server", "--listen", "stdio://"], {
      stdio: ["pipe", "pipe", "pipe"],
    });
    this.#child.stdout.setEncoding("utf8");
    this.#child.stdout.on("data", (chunk) => this.#consume(chunk));
    this.#child.stderr.setEncoding("utf8");
    this.#child.stderr.on("data", (chunk) => logger.error(`[codex app-server] ${chunk.trimEnd()}`));
    this.#child.on("error", (error) => this.#failAll(error));
    this.#child.on("exit", (code, signal) => {
      this.#failAll(new Error(`codex app-server exited (${signal ?? code ?? "unknown"})`));
      this.emit("exit", { code, signal });
    });
  }

  async initialize() {
    const result = await this.request("initialize", {
      clientInfo: { name: "agentkeys", title: "AgentKeys", version: "0.1.0" },
      capabilities: {
        experimentalApi: true,
        requestAttestation: false,
        optOutNotificationMethods: [],
      },
    });
    this.notify("initialized");
    return result;
  }

  request(method, params = {}) {
    const id = this.#nextID++;
    return new Promise((resolve, reject) => {
      this.#pending.set(id, { resolve, reject });
      try {
        this.#write({ method, id, params });
      } catch (error) {
        this.#pending.delete(id);
        reject(error);
      }
    });
  }

  notify(method, params) {
    this.#write(params === undefined ? { method } : { method, params });
  }

  respond(id, result) {
    this.#write({ id, result });
  }

  respondError(id, code, message) {
    this.#write({ id, error: { code, message } });
  }

  close() {
    this.#child.kill("SIGTERM");
  }

  #write(message) {
    if (!this.#child.stdin.writable) throw new Error("codex app-server stdin is closed");
    this.#child.stdin.write(`${JSON.stringify(message)}\n`);
  }

  #consume(chunk) {
    this.#buffer += chunk;
    for (;;) {
      const newline = this.#buffer.indexOf("\n");
      if (newline < 0) return;
      const line = this.#buffer.slice(0, newline).trim();
      this.#buffer = this.#buffer.slice(newline + 1);
      if (!line) continue;
      let message;
      try {
        message = JSON.parse(line);
      } catch {
        this.logger.error("Ignoring invalid JSON from codex app-server");
        continue;
      }
      if (Object.hasOwn(message, "id") && !message.method) {
        const pending = this.#pending.get(message.id);
        if (!pending) continue;
        this.#pending.delete(message.id);
        if (message.error) pending.reject(new Error(message.error.message ?? "Codex request failed"));
        else pending.resolve(message.result);
      } else if (Object.hasOwn(message, "id") && message.method) {
        this.emit("request", message);
      } else if (message.method) {
        this.emit("notification", message);
      }
    }
  }

  #failAll(error) {
    for (const { reject } of this.#pending.values()) reject(error);
    this.#pending.clear();
  }
}

export class AgentKeysConnectorClient {
  constructor({ baseURL, token, fetchImpl = fetch }) {
    this.baseURL = new URL(baseURL);
    this.token = token;
    this.fetchImpl = fetchImpl;
  }

  upsert(agent) {
    return this.#request("PUT", "/v1/integrations/agent", agent);
  }

  async drain(agentID) {
    const result = await this.#request(
      "GET",
      `/v1/integrations/actions?agentID=${encodeURIComponent(agentID)}`,
    );
    return result.actions;
  }

  async #request(method, path, body) {
    const response = await this.fetchImpl(new URL(path, this.baseURL), {
      method,
      headers: {
        "X-AgentKeys-Integration-Token": this.token,
        ...(body ? { "Content-Type": "application/json" } : {}),
      },
      body: body ? JSON.stringify(body) : undefined,
    });
    const payload = await response.json();
    if (!response.ok) throw new Error(`AgentKeys connector rejected request: ${payload.error ?? response.status}`);
    return payload;
  }
}

export class CodexAdapter {
  constructor({
    rpc,
    connector,
    agentID,
    name = "Codex",
    cwd = process.cwd(),
    model = null,
    logger = console,
  }) {
    this.rpc = rpc;
    this.connector = connector;
    this.agentID = agentID;
    this.name = name;
    this.cwd = cwd;
    this.requestedModel = model;
    this.logger = logger;
    this.threadID = null;
    this.turnID = null;
    this.pendingApproval = null;
    this.status = "idle";
    this.task = "Ready for a prompt";
    this.model = model ?? "default";
    this.effort = "medium";
    this.speed = "standard";
    this.catalog = [];
    rpc.on("notification", (message) => this.#handleNotification(message).catch((error) => this.#fail(error)));
    rpc.on("request", (message) => this.#handleServerRequest(message).catch((error) => this.#fail(error)));
    rpc.on("exit", () => this.#fail(new Error("Codex app-server disconnected")));
  }

  async start({ threadID = null } = {}) {
    await this.rpc.initialize();
    await this.#loadCatalog();
    const result = threadID
      ? await this.rpc.request("thread/resume", { threadId: threadID, cwd: this.cwd, excludeTurns: false })
      : await this.rpc.request("thread/start", {
          cwd: this.cwd,
          model: this.requestedModel,
          approvalPolicy: "on-request",
          sandbox: "workspace-write",
        });
    this.#adoptThread(result);
    await this.#publish();
    return { threadID: this.threadID, model: this.model };
  }

  async poll() {
    const actions = await this.connector.drain(this.agentID);
    for (const action of actions) {
      try {
        await this.#apply(action);
      } catch (error) {
        await this.#fail(error);
      }
    }
    return actions.length;
  }

  async #loadCatalog() {
    try {
      const result = await this.rpc.request("model/list", { includeHidden: false, limit: 50 });
      this.catalog = (result?.data ?? []).filter((entry) => !entry.hidden).slice(0, 12);
    } catch (error) {
      this.logger.error(`Model catalog unavailable: ${error.message}`);
      this.catalog = [];
    }
  }

  #adoptThread(result) {
    if (!result?.thread?.id) throw new Error("Codex returned no thread id");
    this.threadID = result.thread.id;
    this.turnID = result.thread.turns?.findLast((turn) => turn.status === "inProgress")?.id ?? null;
    this.pendingApproval = null;
    this.model = result.model ?? this.requestedModel ?? this.catalog.find((entry) => entry.isDefault)?.model ?? "default";
    this.effort = normalizeEffort(result.reasoningEffort, this.#efforts());
    this.speed = result.serviceTier && result.serviceTier === this.#fastTier()?.id ? "fast" : "standard";
    this.status = statusForThread(result.thread.status);
    this.task = "Ready for a prompt";
  }

  async #apply(action) {
    switch (action.action) {
      case "prompt":
        if (this.turnID) throw new Error("A Codex turn is already running");
        this.task = action.text;
        this.status = "thinking";
        await this.#publish();
        {
          const result = await this.rpc.request("turn/start", {
            threadId: this.threadID,
            input: [{ type: "text", text: action.text, text_elements: [] }],
            model: this.model === "default" ? null : this.model,
            effort: this.effort,
            serviceTier: this.speed === "fast" ? this.#fastTier()?.id ?? null : null,
          });
          this.turnID = result.turn.id;
        }
        return;
      case "approve":
        return this.#resolveApproval("accept");
      case "reject":
        return this.#resolveApproval("decline");
      case "interrupt":
        if (!this.turnID) throw new Error("No Codex turn is running");
        await this.rpc.request("turn/interrupt", { threadId: this.threadID, turnId: this.turnID });
        return;
      case "new_chat":
        if (this.pendingApproval || this.turnID) throw new Error("Finish or interrupt the active turn before starting a new chat");
        this.#adoptThread(await this.rpc.request("thread/start", {
          cwd: this.cwd,
          model: this.model === "default" ? null : this.model,
          approvalPolicy: "on-request",
          sandbox: "workspace-write",
        }));
        return this.#publish();
      case "resume_session":
        if (this.turnID) throw new Error("Cannot resume while a turn is running");
        this.#adoptThread(await this.rpc.request("thread/resume", {
          threadId: this.threadID,
          cwd: this.cwd,
          excludeTurns: false,
        }));
        return this.#publish();
      case "fork_session":
        if (this.turnID) throw new Error("Cannot fork while a turn is running");
        this.#adoptThread(await this.rpc.request("thread/fork", {
          threadId: this.threadID,
          cwd: this.cwd,
          excludeTurns: true,
          deferGoalContinuation: true,
        }));
        return this.#publish();
      case "set_model":
        if (!this.#models().includes(action.text)) throw new Error("Unsupported Codex model");
        this.model = action.text;
        return this.#publish();
      case "set_effort":
        if (!this.#efforts().includes(action.text)) throw new Error("Unsupported Codex effort");
        this.effort = action.text;
        return this.#publish();
      case "set_speed":
        if (!this.#speeds().includes(action.text)) throw new Error("Unsupported Codex speed");
        this.speed = action.text;
        return this.#publish();
      default:
        throw new Error(`Codex adapter does not support ${action.action}`);
    }
  }

  async #resolveApproval(decision) {
    const pending = this.pendingApproval;
    if (!pending) throw new Error("No Codex approval is pending");
    const choices = pending.params.availableDecisions;
    if (Array.isArray(choices) && !choices.some((entry) => entry === decision)) {
      throw new Error(`Codex did not offer the ${decision} decision`);
    }
    this.rpc.respond(pending.id, { decision });
    this.pendingApproval = null;
    this.status = "thinking";
    this.task = "Continuing after approval";
    await this.#publish();
  }

  async #handleServerRequest(message) {
    if (!APPROVAL_METHODS.has(message.method)) {
      this.rpc.respondError(message.id, -32601, `AgentKeys does not support ${message.method}`);
      this.status = "error";
      this.task = "Unsupported Codex input request; continue on the Mac";
      await this.#publish();
      return;
    }
    if (message.params?.threadId !== this.threadID || message.params?.turnId !== this.turnID) {
      this.rpc.respondError(message.id, -32602, "Approval does not match the active AgentKeys turn");
      return;
    }
    if (this.pendingApproval) {
      this.rpc.respondError(message.id, -32000, "Another approval is already pending");
      return;
    }
    this.pendingApproval = message;
    this.status = "needs_input";
    this.task = approvalLabel(message);
    await this.#publish();
  }

  async #handleNotification(message) {
    const params = message.params ?? {};
    if (params.threadId && params.threadId !== this.threadID) return;
    switch (message.method) {
      case "turn/started":
        this.turnID = params.turn?.id ?? this.turnID;
        this.status = "thinking";
        return this.#publish();
      case "turn/completed":
        this.turnID = null;
        this.pendingApproval = null;
        this.status = statusForTurn(params.turn?.status);
        this.task = this.status === "complete" ? "Turn completed" : `Turn ${params.turn?.status ?? "failed"}`;
        return this.#publish();
      case "thread/status/changed":
        if (!this.turnID && !this.pendingApproval) {
          const nextStatus = statusForThread(params.status);
          if (!(nextStatus === "idle" && this.status === "complete")) this.status = nextStatus;
          return this.#publish();
        }
        return;
      case "error":
        if (!params.willRetry) return this.#fail(new Error(params.error?.message ?? "Codex turn failed"));
        return;
      default:
        return;
    }
  }

  async #fail(error) {
    this.logger.error(error);
    this.status = "error";
    this.task = truncate(`Codex adapter: ${error.message}`, 500);
    try {
      await this.#publish();
    } catch (publishError) {
      this.logger.error(publishError);
    }
  }

  #models() {
    const models = this.catalog.map((entry) => entry.model).filter(Boolean);
    if (this.model !== "default" && !models.includes(this.model)) models.unshift(this.model);
    return [...new Set(models)].slice(0, 12);
  }

  #efforts() {
    const model = this.catalog.find((entry) => entry.model === this.model);
    const values = model?.supportedReasoningEfforts?.map((entry) => entry.reasoningEffort) ?? [];
    const filtered = values.filter((value) => ALLOWED_EFFORTS.has(value));
    return filtered.length ? [...new Set(filtered)] : ["medium"];
  }

  #speeds() {
    return this.#fastTier() ? ["standard", "fast"] : ["standard"];
  }

  #fastTier() {
    const model = this.catalog.find((entry) => entry.model === this.model);
    return model?.serviceTiers?.find((tier) => {
      return tier.id === "fast" || tier.id === "priority" || /fast|priority/i.test(tier.name ?? "");
    }) ?? null;
  }

  #publish() {
    const models = this.#models();
    return this.connector.upsert({
      id: this.agentID,
      name: this.name,
      harness: "Codex app-server (experimental)",
      provider: "codex",
      task: truncate(this.task, 500),
      status: this.status,
      mode: "manual",
      effort: this.#efforts().includes(this.effort) ? this.effort : this.#efforts()[0],
      speed: this.#speeds().includes(this.speed) ? this.speed : "standard",
      model: models.includes(this.model) ? this.model : models[0] ?? "default",
      webSearchEnabled: false,
      capabilities: {
        modes: ["manual"],
        efforts: this.#efforts(),
        speeds: this.#speeds(),
        models,
        workflows: [],
        supportsBranch: false,
        supportsResume: true,
        supportsFork: true,
        supportsWebSearch: false,
      },
    });
  }
}

function statusForThread(status) {
  if (status?.type === "active") return "thinking";
  if (status?.type === "systemError") return "error";
  return "idle";
}

function statusForTurn(status) {
  if (status === "completed") return "complete";
  if (status === "interrupted") return "idle";
  return status === "inProgress" ? "thinking" : "error";
}

function normalizeEffort(value, supported) {
  return supported.includes(value) ? value : supported.includes("medium") ? "medium" : supported[0];
}

function approvalLabel(message) {
  const detail = message.params?.command ?? message.params?.reason;
  const prefix = message.method.includes("commandExecution") ? "Approve command" : "Approve file changes";
  return truncate(detail ? `${prefix}: ${detail}` : prefix, 500);
}

function truncate(value, length) {
  return value.length <= length ? value : `${value.slice(0, length - 1)}…`;
}
