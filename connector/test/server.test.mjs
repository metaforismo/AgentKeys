import assert from "node:assert/strict";
import test from "node:test";
import { once } from "node:events";
import { createConnectorServer } from "../src/server.mjs";

const phoneToken = "phone-token-for-tests";
const integrationToken = "integration-token-for-tests";

test("protects snapshots and queues semantic actions", async (t) => {
  const { server } = createConnectorServer({ phoneToken, integrationToken, demo: true });
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  t.after(() => server.close());
  const { port } = server.address();
  const base = `http://127.0.0.1:${port}`;

  assert.equal((await fetch(`${base}/v1/snapshot`)).status, 401);

  const snapshotResponse = await fetch(`${base}/v1/snapshot`, { headers: { Authorization: `Bearer ${phoneToken}` } });
  assert.equal(snapshotResponse.status, 200);
  const snapshot = await snapshotResponse.json();
  assert.equal(snapshot.agents.length, 5);

  const agentID = snapshot.agents[0].id;
  const requestID = "0d9c2b37-3e69-44a8-94de-ac196177e6a6";
  const actionResponse = await fetch(`${base}/v1/actions`, {
    method: "POST",
    headers: { Authorization: `Bearer ${phoneToken}`, "Content-Type": "application/json" },
    body: JSON.stringify({ agentID, requestID, action: "approve", text: null }),
  });
  assert.equal(actionResponse.status, 202);

  const actionsResponse = await fetch(`${base}/v1/integrations/actions?agentID=${agentID}`, {
    headers: { "x-agentkeys-integration-token": integrationToken },
  });
  assert.deepEqual((await actionsResponse.json()).actions.map((action) => action.action), ["approve"]);
});

test("rejects arbitrary actions and oversized prompt bodies", async (t) => {
  const { server } = createConnectorServer({ phoneToken, integrationToken, demo: true });
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  t.after(() => server.close());
  const { port } = server.address();
  const base = `http://127.0.0.1:${port}`;
  const headers = { Authorization: `Bearer ${phoneToken}`, "Content-Type": "application/json" };
  const unknown = await fetch(`${base}/v1/actions`, {
    method: "POST",
    headers,
    body: JSON.stringify({ agentID: "73659c11-43ed-4aac-8f18-771b977c6901", requestID: "c173cbe8-4bdd-40e7-a949-0d603108f4c8", action: "shell", text: "rm -rf /" }),
  });
  assert.equal(unknown.status, 400);

  const huge = await fetch(`${base}/v1/actions`, { method: "POST", headers, body: "x".repeat(20_000) });
  assert.equal(huge.status, 413);
});

test("rate limits repeated non-health requests per client", async (t) => {
  const { server } = createConnectorServer({
    phoneToken,
    integrationToken,
    demo: true,
    rateLimit: { windowMs: 60_000, max: 2 },
  });
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  t.after(() => server.close());
  const { port } = server.address();
  const base = `http://127.0.0.1:${port}`;
  const headers = { Authorization: `Bearer ${phoneToken}` };

  assert.equal((await fetch(`${base}/v1/snapshot`, { headers })).status, 200);
  assert.equal((await fetch(`${base}/v1/snapshot`, { headers })).status, 200);
  const limited = await fetch(`${base}/v1/snapshot`, { headers });
  assert.equal(limited.status, 429);
  assert.equal(limited.headers.get("retry-after"), "60");
});
