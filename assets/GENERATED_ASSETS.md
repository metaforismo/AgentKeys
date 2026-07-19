# Generated visual assets

The AgentKeys app icon, repository hero, five agent-status elements, and three onboarding illustrations were generated for this project with OpenAI image generation on 2026-07-17, then processed locally for their target formats.

They use the project's original terminal-key visual identity and contain no third-party logos or copied product text. Source references were supplied only for the requested tactile material, lighting, and translucent-keycap style.

## Files

- `AgentKeys/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` — 1024×1024 iOS app icon
- `AgentKeys/Resources/Assets.xcassets/Status*.imageset/*.png` — five 512×512 transparent, single-element status assets
- `AgentKeys/Resources/Assets.xcassets/Onboarding*.imageset/*.png` — three 1024×1024 transparent, single-object onboarding illustrations
- `assets/agentkeys-hero.png` — 1280×640 README/social hero

The status and onboarding exports contain a real alpha channel. `scripts/process_status_icon.swift` reproducibly removes the status generator's baked transparency preview and crops each file to its single circular element. The onboarding images were generated on a flat `#ff00ff` chroma background and processed with the installed image-generation skill's soft-matte, despill-aware chroma removal helper.

All generated files are distributed under the repository's MIT License.

## Product screenshots

`agentkeys-onboarding.png`, `agentkeys-simulator.png`, `agentkeys-controls.png`, and `agentkeys-claude-controls.png` are native-resolution captures from the real SwiftUI app on an iPhone 17 Pro simulator. `agentkeys-ipad.png` is a native-resolution capture from an iPad Pro 11-inch simulator. They are not generated UI concepts. Refresh a product screenshot only after a successful simulator build, with demo data that contains no credentials or private prompts.

The DEBUG-only launch arguments keep captures deterministic:

- `-ui-testing` — onboarding
- `-ui-testing -ui-testing-onboarded` — deck
- add `-ui-testing-controls` — selected provider controls
- add `-ui-testing-claude` — select the Claude Code demo agent

Use `xcrun simctl status_bar <device> override --time 09:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4` before capture, and retain the native 1206×2622 PNG output.
