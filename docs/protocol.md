# AgentKeys companion protocol v1

The protocol is local-first HTTP with JSON payloads. Version 1 favors inspectability and a narrow action vocabulary over remote shell access.

## Authentication

The companion uses two independent credentials:

- Phone requests: `Authorization: Bearer <phone token>`
- Harness adapter requests: `X-AgentKeys-Integration-Token: <integration token>`

Tokens must be different, randomly generated, and at least 128 bits in production. The reference companion generates ephemeral tokens when environment variables are absent.

## Agent statuses

`idle`, `thinking`, `complete`, `needs_input`, or `error`.

An adapter must only report states it can verify. For example, process exit is not proof that a task completed successfully.

## Phone endpoints

### `GET /v1/snapshot`

Returns the latest revision and active agents.

### `POST /v1/actions`

Queues one semantic action. `requestID` makes retries idempotent.

```json
{
  "agentID": "73659c11-43ed-4aac-8f18-771b977c6901",
  "action": "prompt",
  "text": "Run the focused unit tests",
  "requestID": "0d9c2b37-3e69-44a8-94de-ac196177e6a6"
}
```

Allowed actions are `approve`, `reject`, `interrupt`, `new_chat`, and `prompt`. No `shell`, `keys`, or arbitrary executable action exists.

## Harness adapter endpoints

### `PUT /v1/integrations/agent`

Creates or updates an agent session.

```json
{
  "id": "73659c11-43ed-4aac-8f18-771b977c6901",
  "name": "Codex",
  "harness": "Codex CLI",
  "task": "Run focused tests",
  "status": "thinking"
}
```

### `GET /v1/integrations/actions?agentID=<uuid>`

Atomically drains queued actions for that agent. An adapter should reject unsupported actions locally and surface that result as an agent error or explicit event in a future protocol revision.

## Transport

The reference implementation is plain HTTP because Tailscale already supplies authenticated encryption between enrolled devices. For ordinary Wi-Fi, keep the connector on a trusted network during development; TLS or a mutually authenticated Noise transport is required before treating untrusted LAN use as production-safe.

