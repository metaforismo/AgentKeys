#!/usr/bin/env node
import { randomBytes } from "node:crypto";
import { createConnectorServer } from "./server.mjs";

const args = new Set(process.argv.slice(2));
const host = option("--host") ?? "127.0.0.1";
const port = Number(option("--port") ?? "7777");
const demo = args.has("--demo");
const phoneToken = process.env.AGENTKEYS_PHONE_TOKEN ?? randomBytes(18).toString("base64url");
const integrationToken = process.env.AGENTKEYS_INTEGRATION_TOKEN ?? randomBytes(24).toString("base64url");

if (!Number.isInteger(port) || port < 1 || port > 65535) {
  console.error("--port must be between 1 and 65535");
  process.exit(2);
}
if (host !== "127.0.0.1" && host !== "::1" && !args.has("--allow-network")) {
  console.error("Refusing to bind beyond loopback without --allow-network. Prefer a Tailscale address over 0.0.0.0.");
  process.exit(2);
}

const { server } = createConnectorServer({ phoneToken, integrationToken, demo });
server.listen(port, host, () => {
  console.log(`AgentKeys connector listening on http://${host}:${port}`);
  console.log(`Phone pairing token: ${phoneToken}`);
  console.log(`Integration token: ${integrationToken}`);
  console.log("Tokens are generated in memory and are not persisted. Set AGENTKEYS_*_TOKEN to keep them stable.");
});

function option(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : undefined;
}

