<div align="center">
  <img src="ClaudeIsland/Assets.xcassets/AppIcon.appiconset/icon_128x128.png" alt="Logo" width="100" height="100">
  <h3 align="center">Notch Island</h3>
  <p align="center">
    A macOS notch overlay that monitors Claude Code and Codex CLI sessions.
  </p>
</div>

## Features

- **Notch UI** — Animated overlay that expands from the MacBook notch
- **Live Session Monitoring** — Track multiple Claude Code and Codex CLI sessions in real-time
- **Permission Approvals** — Approve or deny tool executions directly from the notch (Claude Code)
- **Chat History** — View full conversation history with markdown rendering
- **Auto-Setup** — Hooks install automatically on first launch for both agents
- **Zero Outbound Network Connections** — No analytics, no telemetry, no update checks

## Requirements

- macOS 15.6+
- Claude Code CLI and/or Codex CLI

## Install

Download the latest release or build from source:

```bash
xcodebuild -scheme ClaudeIsland -configuration Release build
```

## How It Works

Notch Island installs hooks into `~/.claude/hooks/` and `~/.codex/hooks/` that communicate session state via a Unix socket. The app listens for events and displays them in the notch overlay.

When Claude Code needs permission to run a tool, the notch expands with approve/deny buttons — no need to switch to the terminal. Codex sessions are monitored for status and tool activity.

## Credits

Forked from [claude-island](https://github.com/farouqaldori/claude-island) by farouqaldori (Apache 2.0).

## License

Apache 2.0
