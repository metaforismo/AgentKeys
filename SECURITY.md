# Security policy and trust model

## Supported versions

Only the latest release and `main` receive security fixes during the pre-1.0 phase.

## Trust boundary

The iPhone is a remote control, not a remote shell. The companion accepts only five semantic actions, validates all identifiers and sizes, uses constant-time token comparison, rejects unknown actions, limits request bodies, and separates phone credentials from harness credentials.

The reference companion binds to `127.0.0.1` by default. Binding to another interface requires `--allow-network`. Prefer a specific Tailscale address; do not port-forward the companion to the public internet.

Approval is harness-specific. An adapter must preserve the harness's native permission policy and must not treat a generic “approve” action as authorization for a broader class of future operations.

## Known pre-1.0 limitations

- Phone tokens are entered manually and are not yet stored in Keychain.
- Plain HTTP is intended for loopback or Tailscale; untrusted Wi-Fi is out of scope.
- The in-memory queue is not durable across companion restarts.
- Rate limiting and device revocation are planned before a production release.

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting for this repository. Do not open a public issue containing credentials or an exploitable proof of concept.

