#!/usr/bin/env node
import { randomUUID } from "node:crypto";
import { resolve } from "node:path";
import { query } from "@anthropic-ai/claude-agent-sdk";
import { ClaudeAdapter } from "./adapters/claude-agent-sdk.mjs";
import { AgentKeysConnectorClient } from "./integration-client.mjs";

const connectorURL = option("--connector") ?? "http://127.0.0.1:7777";
const token = process.env.AGENTKEYS_INTEGRATION_TOKEN;
const agentID = option("--agent-id") ?? process.env.AGENTKEYS_AGENT_ID ?? randomUUID();
const cwd = resolve(option("--workspace") ?? process.cwd());
const sessionID = option("--session") ?? null;
const pollMs = Number(option("--poll-ms") ?? "500");

if (!token || token.length < 16) {
  console.error("AGENTKEYS_INTEGRATION_TOKEN must match the running connector");
  process.exit(2);
}
if (!Number.isInteger(pollMs) || pollMs < 100 || pollMs > 60_000) {
  console.error("--poll-ms must be between 100 and 60000");
  process.exit(2);
}

const connector = new AgentKeysConnectorClient({ baseURL: connectorURL, token });
const adapter = new ClaudeAdapter({
  queryFactory: query,
  connector,
  agentID,
  name: option("--name") ?? "Claude Code",
  cwd,
  model: option("--model") ?? null,
  claudeBinary: option("--claude") ?? process.env.AGENTKEYS_CLAUDE_BINARY ?? null,
});

try {
  const session = await adapter.start({ sessionID, fork: hasFlag("--fork") });
  console.log(`AgentKeys Claude adapter connected as ${agentID}`);
  console.log(`Claude session: ${session.sessionID ?? "waiting for first session event"}`);
  console.log(`Workspace: ${cwd}`);
  for (;;) {
    await adapter.poll();
    await delay(pollMs);
  }
} catch (error) {
  console.error(error.message);
  adapter.close();
  process.exit(1);
}

function option(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : undefined;
}

function hasFlag(name) {
  return process.argv.includes(name);
}

function delay(ms) {
  return new Promise((resolveDelay) => setTimeout(resolveDelay, ms));
}
