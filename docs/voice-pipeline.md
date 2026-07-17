# Voice pipeline evaluation

AgentKeys 0.1 uses Apple's native Speech framework. The phone is the microphone, partial transcripts populate the prompt field, and the user explicitly taps send. This is a strong baseline because it adds no AgentKeys speech service, account, API key, or audio retention layer.

We should move to a WhisprFlow-like pipeline only if a reproducible comparison shows a meaningful daily-use improvement.

## Test matrix

Run the same 30 prompts through each candidate on a supported physical iPhone:

- 10 short coding commands
- 10 long prompts with filenames, symbols, and technical vocabulary
- 5 corrections such as “replace the last sentence”
- 5 noisy-room prompts

Record:

- time to first partial transcript
- time from release to final transcript
- word error rate, with a separate technical-token error count
- punctuation and paragraph-editing corrections required
- peak memory and battery impact over a 15-minute session
- offline behavior and network bytes sent
- whether raw audio or transcripts leave the device, where they go, and retention policy

## Decision gate

Keep native Speech unless another pipeline delivers at least one of these without materially weakening privacy or battery life:

- 25% lower technical-token error rate
- 300 ms faster median finalization
- reliable voice editing that removes at least half of manual transcript corrections

Publish the anonymized aggregate results and device/OS versions before changing the default.
