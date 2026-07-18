import { randomBytes } from "node:crypto";
import { mkdirSync, readFileSync, writeFileSync, chmodSync } from "node:fs";
import { networkInterfaces, homedir } from "node:os";
import { join } from "node:path";

const TOKEN_FILE = "credentials.json";

/**
 * Load stable tokens from disk, creating them on first run. Environment
 * variables always win so deployments can inject their own secrets.
 * Tokens are persisted with 0600 permissions under the config directory
 * so a restart never breaks an existing phone pairing.
 */
export function loadOrCreateTokens({
  configDir = join(homedir(), ".agentkeys"),
  env = process.env,
} = {}) {
  const fromEnv = {
    phoneToken: env.AGENTKEYS_PHONE_TOKEN,
    integrationToken: env.AGENTKEYS_INTEGRATION_TOKEN,
  };
  if (fromEnv.phoneToken && fromEnv.integrationToken) {
    return { ...fromEnv, source: "env" };
  }

  const file = join(configDir, TOKEN_FILE);
  let stored = null;
  try {
    const parsed = JSON.parse(readFileSync(file, "utf8"));
    if (isValidToken(parsed.phoneToken, 12) && isValidToken(parsed.integrationToken, 16)) {
      stored = parsed;
    }
  } catch {
    // Missing or corrupt file: regenerate below.
  }

  if (!stored) {
    stored = {
      phoneToken: randomBytes(18).toString("base64url"),
      integrationToken: randomBytes(24).toString("base64url"),
    };
    mkdirSync(configDir, { recursive: true, mode: 0o700 });
    writeFileSync(file, `${JSON.stringify(stored, null, 2)}\n`, { mode: 0o600 });
    chmodSync(file, 0o600);
  }

  return {
    phoneToken: fromEnv.phoneToken ?? stored.phoneToken,
    integrationToken: fromEnv.integrationToken ?? stored.integrationToken,
    source: "file",
    file,
  };
}

function isValidToken(value, minLength) {
  return typeof value === "string" && value.length >= minLength && /^[A-Za-z0-9_-]+$/.test(value);
}

/**
 * Build the deep link the iOS app understands. Scanning it as a QR code or
 * opening it on the phone fills every connection field at once.
 */
export function pairingURL({ scheme = "http", host, port, token }) {
  if (scheme !== "http" && scheme !== "https") throw new TypeError("scheme must be http or https");
  if (typeof host !== "string" || host.length === 0) throw new TypeError("host is required");
  if (!Number.isInteger(port) || port < 1 || port > 65535) throw new TypeError("invalid port");
  if (!isValidToken(token, 12)) throw new TypeError("invalid token");
  const url = new URL("agentkeys://pair");
  url.searchParams.set("v", "1");
  url.searchParams.set("scheme", scheme);
  url.searchParams.set("host", host);
  url.searchParams.set("port", String(port));
  url.searchParams.set("token", token);
  return url.toString();
}

/**
 * Candidate addresses a phone could reach, best first: Tailscale-style
 * CGNAT addresses (stable, encrypted path) ahead of private LAN ranges.
 */
export function candidateHosts(interfaces = networkInterfaces()) {
  const hosts = [];
  for (const entries of Object.values(interfaces)) {
    for (const entry of entries ?? []) {
      if (entry.internal || entry.family !== "IPv4") continue;
      hosts.push(entry.address);
    }
  }
  return hosts.sort((a, b) => rank(a) - rank(b));
}

function rank(address) {
  if (address.startsWith("100.")) return 0; // Tailscale CGNAT range
  if (address.startsWith("192.168.") || address.startsWith("10.")) return 1;
  return 2;
}
