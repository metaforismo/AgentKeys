import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { candidateHosts, loadOrCreateTokens, pairingURL } from "../src/pairing.mjs";

test("creates tokens on first run and persists them with 0600", () => {
  const configDir = mkdtempSync(join(tmpdir(), "agentkeys-"));
  const first = loadOrCreateTokens({ configDir, env: {} });
  assert.equal(first.source, "file");
  assert.ok(first.phoneToken.length >= 12);
  assert.ok(first.integrationToken.length >= 16);
  assert.equal(statSync(join(configDir, "credentials.json")).mode & 0o777, 0o600);

  const second = loadOrCreateTokens({ configDir, env: {} });
  assert.equal(second.phoneToken, first.phoneToken);
  assert.equal(second.integrationToken, first.integrationToken);
});

test("environment tokens override the stored file", () => {
  const configDir = mkdtempSync(join(tmpdir(), "agentkeys-"));
  loadOrCreateTokens({ configDir, env: {} });
  const env = {
    AGENTKEYS_PHONE_TOKEN: "phone-token-from-env",
    AGENTKEYS_INTEGRATION_TOKEN: "integration-token-from-env",
  };
  const tokens = loadOrCreateTokens({ configDir, env });
  assert.equal(tokens.phoneToken, "phone-token-from-env");
  assert.equal(tokens.integrationToken, "integration-token-from-env");
  assert.equal(tokens.source, "env");
});

test("regenerates tokens when the stored file is corrupt", () => {
  const configDir = mkdtempSync(join(tmpdir(), "agentkeys-"));
  writeFileSync(join(configDir, "credentials.json"), "not-json");
  const tokens = loadOrCreateTokens({ configDir, env: {} });
  assert.ok(tokens.phoneToken.length >= 12);
  assert.doesNotThrow(() => JSON.parse(readFileSync(join(configDir, "credentials.json"), "utf8")));
});

test("pairing URL round-trips every field", () => {
  const link = pairingURL({ scheme: "https", host: "100.100.1.2", port: 7777, token: "abcdefghijkl" });
  const url = new URL(link);
  assert.equal(url.protocol, "agentkeys:");
  assert.equal(url.host, "pair");
  assert.equal(url.searchParams.get("v"), "1");
  assert.equal(url.searchParams.get("scheme"), "https");
  assert.equal(url.searchParams.get("host"), "100.100.1.2");
  assert.equal(url.searchParams.get("port"), "7777");
  assert.equal(url.searchParams.get("token"), "abcdefghijkl");
});

test("pairing URL rejects bad input", () => {
  assert.throws(() => pairingURL({ scheme: "ftp", host: "a", port: 1, token: "abcdefghijkl" }));
  assert.throws(() => pairingURL({ scheme: "http", host: "", port: 1, token: "abcdefghijkl" }));
  assert.throws(() => pairingURL({ scheme: "http", host: "a", port: 0, token: "abcdefghijkl" }));
  assert.throws(() => pairingURL({ scheme: "http", host: "a", port: 1, token: "short" }));
});

test("candidateHosts prefers Tailscale-style addresses", () => {
  const hosts = candidateHosts({
    en0: [
      { address: "192.168.1.20", family: "IPv4", internal: false },
      { address: "fe80::1", family: "IPv6", internal: false },
    ],
    lo0: [{ address: "127.0.0.1", family: "IPv4", internal: true }],
    utun3: [{ address: "100.101.102.103", family: "IPv4", internal: false }],
  });
  assert.deepEqual(hosts, ["100.101.102.103", "192.168.1.20"]);
});
