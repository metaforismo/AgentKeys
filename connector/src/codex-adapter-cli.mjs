#!/usr/bin/env node
import { randomUUID } from "node:crypto";
import { resolve } from "node:path";
import {
  AgentKeysConnectorClient,
  CodexAdapter,
  CodexAppServerClient,
} from "./adapters/codex-app-server.mjs";

const connectorURL = option("--connector") ?? "http://127.0.0.1:7777";
const token = process.env.AGENTKEYS_INTEGRATION_TOKEN;
const agentID = option("--agent-id") ?? process.env.AGENTKEYS_AGENT_ID ?? randomUUID();
const cwd = resolve(option("--workspace") ?? process.cwd());
const threadID = option("--thread") ?? null;
const model = option("--model") ?? null;
const pollMs = Number(option("--poll-ms") ?? "500");

if (!token || token.length < 16) {
  console.error("AGENTKEYS_INTEGRATION_TOKEN must match the running connector");
  process.exit(2);
}
if (!Number.isInteger(pollMs) || pollMs < 100 || pollMs > 60_000) {
  console.error("--poll-ms must be between 100 and 60000");
  process.exit(2);
}

const rpc = new CodexAppServerClient({ binary: option("--codex") ?? "codex" });
const connector = new AgentKeysConnectorClient({ baseURL: connectorURL, token });
const adapter = new CodexAdapter({
  rpc,
  connector,
  agentID,
  name: option("--name") ?? "Codex",
  cwd,
  model,
});

try {
  const session = await adapter.start({ threadID });
  console.log(`AgentKeys Codex adapter connected as ${agentID}`);
  console.log(`Codex thread: ${session.threadID}`);
  console.log(`Workspace: ${cwd}`);
  for (;;) {
    await adapter.poll();
    await delay(pollMs);
  }
} catch (error) {
  console.error(error.message);
  rpc.close();
  process.exit(1);
}

function option(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : undefined;
}

function delay(ms) {
  return new Promise((resolveDelay) => setTimeout(resolveDelay, ms));
}
