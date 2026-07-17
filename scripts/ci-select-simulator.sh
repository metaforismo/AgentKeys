#!/bin/bash

set -euo pipefail

device_id="$({
  xcrun simctl list devices available --json \
    | jq -r '[.devices[] | .[] | select(.isAvailable and (.name | startswith("iPhone")))] | first | .udid // empty'
} 2>/dev/null)"

if [[ -z "$device_id" ]]; then
  runtime_id="$({
    xcrun simctl list runtimes --json \
      | jq -r '[.runtimes[] | select(.isAvailable and .platform == "iOS")] | last | .identifier // empty'
  } 2>/dev/null)"

  if [[ -z "$runtime_id" ]]; then
    echo "No available iOS Simulator runtime was found." >&2
    xcrun simctl list runtimes >&2
    exit 1
  fi

  device_id="$(xcrun simctl create \
    "AgentKeys CI" \
    "com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro" \
    "$runtime_id")"
fi

xcrun simctl boot "$device_id" 2>/dev/null || true
xcrun simctl bootstatus "$device_id" -b
echo "udid=$device_id" >> "$GITHUB_OUTPUT"
