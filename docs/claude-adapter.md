# Claude Agent SDK adapter

AgentKeys includes an experimental adapter built on Anthropic's official [Claude Agent SDK for TypeScript](https://code.claude.com/docs/en/agent-sdk/typescript). It uses one persistent streaming query for prompts and lifecycle events. It does not scrape terminal output, inject keystrokes, or enable permission bypass.

## Supported controls

- send and queue prompts in the active session;
- interrupt the active turn;
- approve or reject the exact pending `canUseTool` request;
- select a permission mode: `manual`, `plan`, `accept_edits`, or `auto`;
- select a model from the SDK's live model catalog;
- select an effort level and fast mode only when the active model advertises them;
- start a new session, resume the current session, or fork it;
- send the bounded PR review, debugging, refactoring, and test workflow prompts.

AgentKeys never exposes `bypassPermissions`. Approval handling is single-flight and fail-closed. `AskUserQuestion` is currently denied with a prompt to continue on the Mac because its structured answers cannot be represented faithfully by protocol v1. Worktree creation and web-search toggles are not advertised by this adapter yet.

Anthropic documents persistent streaming queries as the interactive Agent SDK mode, and documents `canUseTool` as the callback that pauses a tool request until the host returns allow or deny. See [streaming input](https://code.claude.com/docs/en/agent-sdk/streaming-vs-single-mode) and [user input and approvals](https://code.claude.com/docs/en/agent-sdk/user-input).

## Run it

Install the locked connector dependencies and start the local companion:

```sh
cd connector
npm ci
export AGENTKEYS_PHONE_TOKEN='replace-with-a-long-random-phone-token'
export AGENTKEYS_INTEGRATION_TOKEN='replace-with-a-different-integration-token'
npm start
```

In a second terminal, reuse only the integration token:

```sh
cd connector
export AGENTKEYS_INTEGRATION_TOKEN='replace-with-a-different-integration-token'
npm run start:claude -- --workspace /absolute/path/to/project
```

Useful options:

- `--session <id>` resumes a Claude session at startup;
- `--fork` forks the session passed with `--session`;
- `--model <alias>` requests an initial model;
- `--agent-id <uuid>` preserves the same AgentKeys key identity across restarts;
- `--name <label>` changes the key label;
- `--claude <path>` selects a Claude Code executable;
- `--connector <url>` points to a non-default local connector.

Anthropic says that starting June 15, 2026, Agent SDK usage on subscription plans draws from a separate monthly Agent SDK credit. Review the current [Agent SDK overview](https://code.claude.com/docs/en/agent-sdk/overview) before sustained use.

## Compatibility evidence

The no-turn smoke test initializes the real SDK and reads its model catalog:

```sh
cd connector
npm run smoke:claude
```

Set `AGENTKEYS_CLAUDE_BINARY=/absolute/path/to/claude` to test a particular installed Claude Code build. The first verified local run used Claude Code `2.1.209` with `@anthropic-ai/claude-agent-sdk` `0.3.212` on macOS. Its live catalog returned `default`, `opus[1m]`, `claude-fable-5[1m]`, `sonnet`, and `haiku`; `default` and `opus[1m]` advertised fast mode. This is a dated compatibility observation, not a permanent model promise.

The contract suite covers capability negotiation, prompt streaming, runtime mode/model/effort/fast controls, exact approval and rejection, abort behavior, unsupported structured questions, resume, fork, and the explicit absence of bypass mode:

```sh
npm test
```

## Compatibility matrix

| Adapter | Structured lifecycle | Exact approval | Interrupt | Model / effort | Fast | Resume / fork | Branch / worktree | Search |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Codex app-server | Yes | Yes | Yes | Yes | Yes | Yes | Not advertised | Not advertised |
| Claude Agent SDK | Yes | Yes | Yes | Yes | Model-dependent | Yes | Not advertised | Not advertised |

Capabilities shown in the iOS deck come from the active adapter. Missing features remain hidden rather than being approximated with terminal commands.
