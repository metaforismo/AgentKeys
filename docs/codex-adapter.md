# Codex app-server adapter

AgentKeys includes an experimental, dependency-free adapter for Codex. It uses the structured JSONL lifecycle exposed by `codex app-server`; it does not scrape terminal output, inject keystrokes, or turn phone text into arbitrary shell commands.

> [!WARNING]
> OpenAI documents [app-server](https://developers.openai.com/codex/app-server/) as experimental. Its protocol can change between Codex releases. Run the compatibility smoke test after upgrading Codex, and keep the Mac available for request types the phone UI does not support.

## Supported controls

The adapter advertises only capabilities it can execute through the current protocol:

- start a prompt in the active thread;
- start a new thread;
- interrupt the active turn;
- accept or decline the exact pending command or file-change approval request;
- select a model, reasoning effort, and service tier for the next turn when the model catalog advertises them;
- resume the active thread from disk;
- fork the active thread into a new Codex thread.

Branch/worktree creation, web-search toggles, collaboration modes, structured user-input questions, dynamic tools, and other server requests are not advertised by this adapter. Unknown server requests receive a protocol error and the agent key enters `error`; continue that interaction on the Mac.

Approval handling is deliberately single-flight. An approval is accepted only when its request ID, thread ID, and turn ID match the active AgentKeys session. **Approve** sends `accept`; **Reject** sends `decline`. AgentKeys never chooses session-wide permission amendments.

## Run it

Use two different random tokens. Start the companion first:

```sh
cd connector
export AGENTKEYS_PHONE_TOKEN='replace-with-a-long-random-phone-token'
export AGENTKEYS_INTEGRATION_TOKEN='replace-with-a-different-integration-token'
npm start
```

In a second terminal, export the same integration token and start the adapter for a workspace:

```sh
cd connector
export AGENTKEYS_INTEGRATION_TOKEN='replace-with-a-different-integration-token'
npm run start:codex -- --workspace /absolute/path/to/project
```

Useful options:

- `--thread <id>` resumes an existing Codex thread during adapter startup;
- `--model <id>` requests a specific model for a new thread;
- `--agent-id <uuid>` keeps the same AgentKeys key identity across restarts;
- `--name <label>` changes the key label;
- `--codex <path>` selects a Codex binary;
- `--connector <url>` points at a non-default local connector.

The adapter creates new Codex threads with `workspace-write` sandboxing and `on-request` approval policy. It never enables `danger-full-access` or `never` approval mode.

## Compatibility check

The smoke test initializes app-server and reads at most two catalog entries. It does not start a thread or model turn:

```sh
cd connector
npm run smoke:codex
```

The adapter contract suite uses a fake app-server to cover JSONL framing, lifecycle state, approval routing, capability negotiation, resume, and fork:

```sh
npm test
```

The first verified local smoke test used `codex-cli 0.145.0-alpha.18` on macOS. That is evidence for this revision, not a promise that future alpha or stable releases retain the same experimental protocol.
