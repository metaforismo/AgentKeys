#!/usr/bin/env node
import qrcode from "qrcode-terminal";
import { createConnectorServer } from "./server.mjs";
import { candidateHosts, loadOrCreateTokens, pairingURL } from "./pairing.mjs";

const args = new Set(process.argv.slice(2));
const host = option("--host") ?? "127.0.0.1";
const port = Number(option("--port") ?? "7777");
const demo = args.has("--demo");
const showQR = !args.has("--no-qr");

// Explicit, deliberate disclosure only: the integration token authorizes
// adapter writes, so it must never appear in routine startup logs.
if (args.has("--show-integration-token")) {
  const { integrationToken } = loadOrCreateTokens();
  process.stdout.write(`${integrationToken}\n`);
  process.exit(0);
}

if (!Number.isInteger(port) || port < 1 || port > 65535) {
  console.error("--port must be between 1 and 65535");
  process.exit(2);
}
if (host !== "127.0.0.1" && host !== "::1" && !args.has("--allow-network")) {
  console.error("Refusing to bind beyond loopback without --allow-network. Prefer a Tailscale address over 0.0.0.0.");
  process.exit(2);
}

const tokens = loadOrCreateTokens();
const { phoneToken, integrationToken } = tokens;

const { server } = createConnectorServer({ phoneToken, integrationToken, demo });
server.listen(port, host, () => {
  console.log(`AgentKeys connector listening on http://${host}:${port}`);
  if (tokens.source === "file") {
    console.log(`Tokens loaded from ${tokens.file} (chmod 600). Set AGENTKEYS_*_TOKEN to override.`);
  } else {
    console.log("Tokens loaded from environment.");
  }
  console.log("Adapters on this machine read the integration token automatically.");
  console.log("For a remote adapter, run `agentkeys --show-integration-token` (prints the secret, then exits).");

  const reachableHost = pairableHost();
  if (!reachableHost) {
    console.log("\nBound to loopback only — the phone cannot reach this address directly.");
    console.log("Run with --host <tailscale-ip> --allow-network, then pair from the app.");
    return;
  }

  const link = pairingURL({ scheme: "http", host: reachableHost, port, token: phoneToken });
  console.log("\nPair your iPhone: AgentKeys → settings → Scan QR, or open this link on the phone:");
  console.log(`  ${link}`);
  if (showQR && process.stdout.isTTY) {
    qrcode.generate(link, { small: true });
  }
});

function pairableHost() {
  if (host !== "127.0.0.1" && host !== "::1" && host !== "0.0.0.0") return host;
  if (host === "0.0.0.0") return candidateHosts()[0] ?? null;
  return null;
}

function option(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : undefined;
}
