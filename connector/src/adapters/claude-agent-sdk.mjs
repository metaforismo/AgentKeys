const MODES = ["manual", "plan", "accept_edits", "auto"];
const ALLOWED_EFFORTS = new Set(["low", "medium", "high", "xhigh", "max"]);
const WORKFLOWS = {
  review_pr: "Review the current changes as a pull request. Prioritize correctness, regressions, security, and missing tests.",
  debug: "Debug the current problem. Reproduce it first, identify the root cause, implement the narrowest safe fix, and verify it.",
  refactor: "Refactor the selected area without changing behavior. Keep the change focused and verify existing behavior.",
  tests: "Run the relevant tests, diagnose any failures, and make the smallest justified fixes needed for a clean result.",
};

export class ClaudeAdapter {
  constructor({
    queryFactory,
    connector,
    agentID,
    name = "Claude Code",
    cwd = process.cwd(),
    model = null,
    claudeBinary = null,
    logger = console,
  }) {
    this.queryFactory = queryFactory;
    this.connector = connector;
    this.agentID = agentID;
    this.name = name;
    this.cwd = cwd;
    this.model = model;
    this.claudeBinary = claudeBinary;
    this.logger = logger;
    this.query = null;
    this.input = null;
    this.sessionID = null;
    this.pendingApproval = null;
    this.catalog = [];
    this.mode = "manual";
    this.effort = "high";
    this.speed = "standard";
    this.status = "idle";
    this.task = "Ready for a prompt";
    this.generation = 0;
  }

  async start({ sessionID = null, fork = false } = {}) {
    await this.#open({ resume: sessionID, fork });
    return { sessionID: this.sessionID, model: this.model };
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

  close() {
    this.generation += 1;
    this.#denyPending("AgentKeys adapter closed", true);
    this.input?.close();
    this.query?.close();
    this.input = null;
    this.query = null;
  }

  async #open({ resume = null, fork = false } = {}) {
    this.close();
    this.sessionID = resume;
    const generation = this.generation;
    const input = new AsyncInputQueue();
    const options = {
      cwd: this.cwd,
      permissionMode: sdkMode(this.mode),
      effort: this.effort,
      model: this.model ?? undefined,
      resume: resume ?? undefined,
      forkSession: resume ? fork : false,
      canUseTool: (toolName, toolInput, context) => this.#requestApproval(toolName, toolInput, context),
      ...(this.claudeBinary ? { pathToClaudeCodeExecutable: this.claudeBinary } : {}),
      env: { ...process.env, CLAUDE_AGENT_SDK_CLIENT_APP: "agentkeys/0.1.0" },
    };
    const query = this.queryFactory({ prompt: input, options });
    this.input = input;
    this.query = query;
    this.status = "idle";
    this.task = resume ? (fork ? "Forking Claude session" : "Resuming Claude session") : "Ready for a prompt";
    void this.#consume(query, generation);

    const initialized = await query.initializationResult();
    if (generation !== this.generation) throw new Error("Claude session initialization was superseded");
    this.catalog = (initialized.models ?? []).filter(validModelInfo).slice(0, 12);
    if (!this.model) this.model = this.catalog[0]?.value ?? "sonnet";
    if (!this.#efforts().includes(this.effort)) this.effort = this.#efforts()[0];
    if (!this.#supportsFast()) this.speed = "standard";
    await this.#publish();
  }

  async #apply(action) {
    switch (action.action) {
      case "prompt":
        this.task = this.status === "thinking" ? `Queued: ${action.text}` : action.text;
        this.status = "thinking";
        this.input.push(userMessage(action.text));
        return this.#publish();
      case "approve":
        return this.#resolveApproval(true);
      case "reject":
        return this.#resolveApproval(false);
      case "interrupt":
        this.#denyPending("User interrupted the turn", true);
        await this.query.interrupt();
        this.status = "idle";
        this.task = "Turn interrupted";
        return this.#publish();
      case "new_chat":
        this.#requireIdle("start a new chat");
        this.sessionID = null;
        return this.#open({});
      case "resume_session":
        this.#requireIdle("resume the session");
        if (!this.sessionID) throw new Error("Claude has not published a resumable session id");
        return this.#open({ resume: this.sessionID });
      case "fork_session":
        this.#requireIdle("fork the session");
        if (!this.sessionID) throw new Error("Claude has not published a forkable session id");
        return this.#open({ resume: this.sessionID, fork: true });
      case "set_mode":
        if (!MODES.includes(action.text)) throw new Error("Unsupported Claude permission mode");
        await this.query.setPermissionMode(sdkMode(action.text));
        this.mode = action.text;
        return this.#publish();
      case "set_model":
        if (!this.#models().includes(action.text)) throw new Error("Unsupported Claude model");
        await this.query.setModel(action.text);
        this.model = action.text;
        if (!this.#efforts().includes(this.effort)) this.effort = this.#efforts()[0];
        if (!this.#supportsFast()) this.speed = "standard";
        return this.#publish();
      case "set_effort":
        if (!this.#efforts().includes(action.text)) throw new Error("Unsupported Claude effort");
        await this.query.applyFlagSettings({ effortLevel: action.text });
        this.effort = action.text;
        return this.#publish();
      case "set_speed":
        if (!this.#speeds().includes(action.text)) throw new Error("Unsupported Claude speed");
        await this.query.applyFlagSettings({ fastMode: action.text === "fast" });
        this.speed = action.text;
        return this.#publish();
      case "workflow":
        if (!WORKFLOWS[action.text]) throw new Error("Unsupported Claude workflow");
        this.task = `Workflow: ${action.text.replaceAll("_", " ")}`;
        this.status = "thinking";
        this.input.push(userMessage(WORKFLOWS[action.text]));
        return this.#publish();
      default:
        throw new Error(`Claude adapter does not support ${action.action}`);
    }
  }

  async #requestApproval(toolName, toolInput, { signal } = {}) {
    if (toolName === "AskUserQuestion") {
      this.status = "error";
      this.task = "Claude asked a structured question; continue on the Mac";
      await this.#publish();
      return { behavior: "deny", message: "AgentKeys cannot represent this structured question yet" };
    }
    if (this.pendingApproval) {
      return { behavior: "deny", message: "Another AgentKeys approval is already pending" };
    }
    if (signal?.aborted) {
      return { behavior: "deny", message: "Claude cancelled the permission request", interrupt: true };
    }

    let finish;
    let abort;
    const decision = new Promise((resolve) => {
      let settled = false;
      finish = (result) => {
        if (settled) return;
        settled = true;
        signal?.removeEventListener("abort", abort);
        if (this.pendingApproval?.finish === finish) this.pendingApproval = null;
        resolve(result);
      };
      abort = () => finish({ behavior: "deny", message: "Claude cancelled the permission request", interrupt: true });
      signal?.addEventListener("abort", abort, { once: true });
    });
    this.pendingApproval = { toolName, toolInput, finish };
    this.status = "needs_input";
    this.task = approvalLabel(toolName, toolInput);
    try {
      await this.#publish();
    } catch (error) {
      finish({ behavior: "deny", message: "AgentKeys could not publish the approval request" });
      throw error;
    }
    return decision;
  }

  async #resolveApproval(approved) {
    const pending = this.pendingApproval;
    if (!pending) throw new Error("No Claude approval is pending");
    pending.finish(approved
      ? { behavior: "allow", updatedInput: pending.toolInput }
      : { behavior: "deny", message: "User rejected this action in AgentKeys" });
    this.status = "thinking";
    this.task = approved ? "Continuing after approval" : "Continuing after rejection";
    await this.#publish();
  }

  #denyPending(message, interrupt = false) {
    this.pendingApproval?.finish({ behavior: "deny", message, interrupt });
  }

  async #consume(query, generation) {
    try {
      for await (const message of query) {
        if (generation !== this.generation) return;
        await this.#handleMessage(message);
      }
      if (generation === this.generation && this.query === query) {
        await this.#fail(new Error("Claude session ended unexpectedly"));
      }
    } catch (error) {
      if (generation === this.generation) await this.#fail(error);
    }
  }

  async #handleMessage(message) {
    if (message.session_id) this.sessionID = message.session_id;
    if (message.type === "system" && message.subtype === "init") {
      this.model = message.model ?? this.model;
      this.mode = appMode(message.permissionMode);
      this.speed = message.fast_mode_state === "on" ? "fast" : "standard";
      return this.#publish();
    }
    if (message.type === "system" && message.subtype === "session_state_changed") {
      if (message.state === "running") this.status = "thinking";
      if (message.state === "requires_action") this.status = "needs_input";
      if (message.state === "idle" && this.status !== "complete" && this.status !== "error") this.status = "idle";
      return this.#publish();
    }
    if (message.type === "assistant") {
      this.status = message.error ? "error" : "thinking";
      if (message.error) this.task = `Claude error: ${message.error}`;
      return this.#publish();
    }
    if (message.type === "result") {
      this.pendingApproval = null;
      this.status = message.subtype === "success" ? "complete" : "error";
      this.task = message.subtype === "success" ? "Turn completed" : truncate(message.errors?.join("; ") || message.subtype, 500);
      return this.#publish();
    }
    if (message.type === "system" && message.subtype === "permission_denied") {
      this.task = `Permission denied: ${message.tool_name}`;
      return this.#publish();
    }
  }

  async #fail(error) {
    this.logger.error(error);
    this.#denyPending("Claude adapter failed", true);
    this.status = "error";
    this.task = truncate(`Claude adapter: ${error.message}`, 500);
    try {
      await this.#publish();
    } catch (publishError) {
      this.logger.error(publishError);
    }
  }

  #requireIdle(operation) {
    if (this.pendingApproval || this.status === "thinking") throw new Error(`Cannot ${operation} while Claude is active`);
  }

  #models() {
    const values = this.catalog.map((entry) => entry.value);
    if (this.model && validModel(this.model) && !values.includes(this.model)) values.unshift(this.model);
    return [...new Set(values)].slice(0, 12);
  }

  #currentModel() {
    return this.catalog.find((entry) => entry.value === this.model || entry.resolvedModel === this.model);
  }

  #efforts() {
    const levels = this.#currentModel()?.supportedEffortLevels ?? ["low", "medium", "high"];
    const filtered = levels.filter((level) => ALLOWED_EFFORTS.has(level));
    return filtered.length ? [...new Set(filtered)] : ["medium"];
  }

  #supportsFast() {
    return this.#currentModel()?.supportsFastMode === true;
  }

  #speeds() {
    return this.#supportsFast() ? ["standard", "fast"] : ["standard"];
  }

  #publish() {
    const models = this.#models();
    const efforts = this.#efforts();
    const speeds = this.#speeds();
    return this.connector.upsert({
      id: this.agentID,
      name: this.name,
      harness: "Claude Agent SDK",
      provider: "claude_code",
      task: truncate(this.task, 500),
      status: this.status,
      mode: MODES.includes(this.mode) ? this.mode : "manual",
      effort: efforts.includes(this.effort) ? this.effort : efforts[0],
      speed: speeds.includes(this.speed) ? this.speed : "standard",
      model: models.includes(this.model) ? this.model : models[0] ?? "sonnet",
      webSearchEnabled: false,
      capabilities: {
        modes: MODES,
        efforts,
        speeds,
        models,
        workflows: Object.keys(WORKFLOWS),
        supportsBranch: false,
        supportsResume: true,
        supportsFork: true,
        supportsWebSearch: false,
      },
    });
  }
}

export class AsyncInputQueue {
  #values = [];
  #waiters = [];
  #closed = false;

  push(value) {
    if (this.#closed) throw new Error("Claude input stream is closed");
    const waiter = this.#waiters.shift();
    if (waiter) waiter({ value, done: false });
    else this.#values.push(value);
  }

  close() {
    this.#closed = true;
    for (const waiter of this.#waiters.splice(0)) waiter({ value: undefined, done: true });
  }

  next() {
    if (this.#values.length) return Promise.resolve({ value: this.#values.shift(), done: false });
    if (this.#closed) return Promise.resolve({ value: undefined, done: true });
    return new Promise((resolve) => this.#waiters.push(resolve));
  }

  [Symbol.asyncIterator]() {
    return this;
  }
}

function userMessage(text) {
  return { type: "user", message: { role: "user", content: text }, parent_tool_use_id: null };
}

function sdkMode(mode) {
  return mode === "accept_edits" ? "acceptEdits" : mode === "manual" ? "default" : mode;
}

function appMode(mode) {
  return mode === "acceptEdits" ? "accept_edits" : mode === "default" ? "manual" : mode;
}

function approvalLabel(toolName, input) {
  const detail = input.command ?? input.file_path ?? input.path ?? input.description;
  return truncate(detail ? `Approve ${toolName}: ${detail}` : `Approve ${toolName}`, 500);
}

function validModelInfo(entry) {
  return entry && validModel(entry.value);
}

function validModel(value) {
  return typeof value === "string" && /^[A-Za-z0-9._:\-\[\]]{1,80}$/.test(value);
}

function truncate(value, length) {
  const text = String(value);
  return text.length <= length ? text : `${text.slice(0, length - 1)}…`;
}
