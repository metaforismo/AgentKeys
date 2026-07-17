import { createServer } from "node:http";
import { timingSafeEqual } from "node:crypto";
import { ConnectorState } from "./state.mjs";

const MAX_BODY_BYTES = 16_384;

export function createConnectorServer({ phoneToken, integrationToken, demo = false, logger = console }) {
  if (!phoneToken || phoneToken.length < 12) throw new TypeError("phoneToken must be at least 12 characters");
  if (!integrationToken || integrationToken.length < 16) throw new TypeError("integrationToken must be at least 16 characters");
  const state = new ConnectorState({ demo });

  const server = createServer(async (request, response) => {
    response.setHeader("Cache-Control", "no-store");
    response.setHeader("Content-Type", "application/json; charset=utf-8");
    response.setHeader("X-Content-Type-Options", "nosniff");

    try {
      const url = new URL(request.url ?? "/", "http://connector.local");
      if (request.method === "GET" && url.pathname === "/health") {
        return send(response, 200, { ok: true });
      }

      if (request.method === "GET" && url.pathname === "/v1/snapshot") {
        requireBearer(request, phoneToken);
        return send(response, 200, state.snapshot());
      }

      if (request.method === "POST" && url.pathname === "/v1/actions") {
        requireBearer(request, phoneToken);
        const result = state.enqueueAction(await readJSON(request));
        return send(response, result.duplicate ? 200 : 202, { ok: true, duplicate: result.duplicate });
      }

      if (request.method === "PUT" && url.pathname === "/v1/integrations/agent") {
        requireIntegrationToken(request, integrationToken);
        const agent = state.upsertAgent(await readJSON(request));
        return send(response, 200, agent);
      }

      if (request.method === "GET" && url.pathname === "/v1/integrations/actions") {
        requireIntegrationToken(request, integrationToken);
        return send(response, 200, { actions: state.drainActions(url.searchParams.get("agentID")) });
      }

      return send(response, 404, { error: "not_found" });
    } catch (error) {
      const status = error.statusCode ?? (error instanceof RangeError ? 404 : 400);
      if (status >= 500) logger.error(error);
      return send(response, status, { error: status === 401 ? "unauthorized" : error.message });
    }
  });

  return { server, state };
}

function requireBearer(request, expected) {
  const value = request.headers.authorization;
  if (typeof value !== "string" || !value.startsWith("Bearer ") || !constantTimeEqual(value.slice(7), expected)) {
    throw httpError(401, "unauthorized");
  }
}

function requireIntegrationToken(request, expected) {
  const value = request.headers["x-agentkeys-integration-token"];
  if (typeof value !== "string" || !constantTimeEqual(value, expected)) throw httpError(401, "unauthorized");
}

function constantTimeEqual(actual, expected) {
  const left = Buffer.from(actual);
  const right = Buffer.from(expected);
  return left.length === right.length && timingSafeEqual(left, right);
}

async function readJSON(request) {
  const chunks = [];
  let size = 0;
  for await (const chunk of request) {
    size += chunk.length;
    if (size > MAX_BODY_BYTES) throw httpError(413, "request_too_large");
    chunks.push(chunk);
  }
  try {
    return JSON.parse(Buffer.concat(chunks).toString("utf8"));
  } catch {
    throw httpError(400, "invalid_json");
  }
}

function send(response, status, body) {
  if (response.writableEnded) return;
  response.statusCode = status;
  response.end(JSON.stringify(body));
}

function httpError(statusCode, message) {
  return Object.assign(new Error(message), { statusCode });
}

