#!/usr/bin/env node
import { query } from "@anthropic-ai/claude-agent-sdk";
import { AsyncInputQueue } from "../src/adapters/claude-agent-sdk.mjs";

const input = new AsyncInputQueue();
const claude = query({
  prompt: input,
  options: {
    cwd: process.cwd(),
    permissionMode: "default",
    ...(process.env.AGENTKEYS_CLAUDE_BINARY
      ? { pathToClaudeCodeExecutable: process.env.AGENTKEYS_CLAUDE_BINARY }
      : {}),
    env: { ...process.env, CLAUDE_AGENT_SDK_CLIENT_APP: "agentkeys-smoke/0.1.0" },
  },
});

const consume = (async () => {
  for await (const message of claude) {
    if (message.type === "system" && message.subtype === "init") {
      console.log(`Claude Code ${message.claude_code_version ?? "unknown"}`);
      console.log(`Session ${message.session_id}`);
    }
  }
})();

try {
  const initialized = await Promise.race([
    claude.initializationResult(),
    new Promise((_, reject) => setTimeout(() => reject(new Error("Claude SDK initialization timed out")), 20_000)),
  ]);
  const models = initialized.models ?? [];
  if (!models.length) throw new Error("Claude SDK returned no models");
  console.log(`Models ${models.map((model) => model.value).join(", ")}`);
  console.log(`Fast ${models.filter((model) => model.supportsFastMode).map((model) => model.value).join(", ") || "none"}`);
  console.log("Claude Agent SDK smoke test passed without starting a model turn");
} finally {
  input.close();
  claude.close();
  await consume;
}
