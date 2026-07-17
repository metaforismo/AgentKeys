# Security policy and trust model

## Supported versions

Only the latest release and `main` receive security fixes during the pre-1.0 phase.

## Trust boundary

The iPhone is a remote control, not a remote shell. The companion accepts only a closed semantic action vocabulary, validates advertised capabilities, identifiers, values, branch names, and sizes, uses constant-time token comparison, rejects unknown or unsupported actions, caps registered agents and queued actions, rate limits clients, limits request bodies, and separates phone credentials from harness credentials.

The reference companion binds to `127.0.0.1` by default. Binding to another interface requires `--allow-network`. Prefer a specific Tailscale address; do not port-forward the companion to the public internet.

Approval is harness-specific. An adapter must preserve the harness's native permission policy and must not treat a generic “approve” action as authorization for a broader class of future operations.

Claude Code's permission-bypass mode is deliberately excluded. Provider adapters may narrow the published capability profile, but cannot expand the connector's built-in enum vocabulary or turn a semantic value into executable text.

The Claude adapter keeps at most one `canUseTool` request pending. Approval returns the original, SDK-provided tool input for that request only; rejection returns a scoped denial. Concurrent permission requests, aborted requests, and structured questions the phone cannot represent are denied. Closing or interrupting the adapter also denies the pending request.

## Known pre-1.0 limitations

- Phone tokens are entered manually and are not yet stored in Keychain.
- Plain HTTP is intended only for loopback or a private Tailscale connection. Prefer HTTPS when a TLS endpoint is available; untrusted Wi-Fi is out of scope.
- The in-memory queue is not durable across companion restarts.
- Device revocation is planned before a production release.

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting for this repository. Do not open a public issue containing credentials or an exploitable proof of concept.
