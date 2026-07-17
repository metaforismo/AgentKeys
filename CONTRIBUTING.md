# Contributing to AgentKeys

Thanks for helping make agent control more open, tactile, and interoperable. Participation in this project is governed by the [code of conduct](CODE_OF_CONDUCT.md).

## Before opening code

- Use the feature, bug, or adapter issue template to describe the problem first.
- Open an issue before changing the protocol or trust boundary.
- Keep credentials, private prompts, provisioning profiles, and machine-specific paths out of reports and commits.
- Back adapter compatibility claims with a reproducible test against an exact coding-harness version.

## Local setup

Requirements are macOS, Xcode 26 or newer, iOS 17 or newer, Node.js 20 or newer, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
git clone https://github.com/metaforismo/AgentKeys.git
cd AgentKeys
xcodegen generate
open AgentKeys.xcodeproj
```

The iOS app starts in demo mode. The companion has no runtime dependencies and can be tested independently:

```sh
cd connector
npm test
```

## Pull requests

1. Keep the change focused and explain why it is needed.
2. Include tests for protocol, state, transport, or adapter behavior.
3. Run the Node.js connector tests and the `AgentKeys` Xcode test scheme.
4. Update documentation when behavior, security assumptions, or compatibility changes.
5. Complete the pull-request template, including the trust-boundary section.

UI changes should preserve Dynamic Type, VoiceOver labels, contrast, Reduce Motion behavior, and meaning without color alone. Screenshots should come from a real build and must not contain credentials or private prompt content.

## Adapter requirements

An adapter must:

- derive status from a documented or reproducibly verified lifecycle surface;
- map only the semantic actions it actually supports;
- preserve the coding harness's native approval and denial boundaries;
- reject unsupported actions explicitly;
- never convert phone input into an unrestricted shell command.

Experimental adapters are welcome when their limitations are visible in code, tests, and documentation.
