# Generated visual assets

The AgentKeys app icon, repository hero, and five agent-status elements were generated for this project with OpenAI image generation on 2026-07-17, then resized and cropped locally for their target formats.

They use the project's original terminal-key visual identity and contain no third-party logos or copied product text. Source references were supplied only for the requested tactile material, lighting, and translucent-keycap style.

## Files

- `AgentKeys/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` — 1024×1024 iOS app icon
- `AgentKeys/Resources/Assets.xcassets/Status*.imageset/*.png` — five 512×512 transparent, single-element status assets
- `assets/agentkeys-hero.png` — 1280×640 README/social hero

The status exports contain a real alpha channel. `scripts/process_status_icon.swift` reproducibly removes the generator's baked transparency preview and crops each file to its single circular element.

Both files are distributed under the repository's MIT License.
