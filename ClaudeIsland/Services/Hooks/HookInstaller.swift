//
//  HookInstaller.swift
//  ClaudeIsland
//
//  Auto-installs Claude Code hooks on app launch
//

import Foundation

struct HookInstaller {

    /// Install hook script and update settings.json on app launch
    static func installIfNeeded() {
        let claudeDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")
        let hooksDir = claudeDir.appendingPathComponent("hooks")
        let pythonScript = hooksDir.appendingPathComponent("claude-island-state.py")
        let settings = claudeDir.appendingPathComponent("settings.json")

        try? FileManager.default.createDirectory(
            at: hooksDir,
            withIntermediateDirectories: true
        )

        if let bundled = Bundle.main.url(forResource: "claude-island-state", withExtension: "py") {
            try? FileManager.default.removeItem(at: pythonScript)
            try? FileManager.default.copyItem(at: bundled, to: pythonScript)
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: pythonScript.path
            )
        }

        updateSettings(at: settings)
        installStatusLineIfNeeded(settingsURL: settings, hooksDir: hooksDir)
    }

    // MARK: - StatusLine

    /// Install statusLine script and register in settings.json (chains to existing if present)
    private static func installStatusLineIfNeeded(settingsURL: URL, hooksDir: URL) {
        let statusScript = hooksDir.appendingPathComponent("claude-island-status.py")
        let originalCmdFile = hooksDir.appendingPathComponent(".original-statusline-command")

        // Copy bundled script
        if let bundled = Bundle.main.url(forResource: "claude-island-status", withExtension: "py") {
            try? FileManager.default.removeItem(at: statusScript)
            try? FileManager.default.copyItem(at: bundled, to: statusScript)
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: statusScript.path
            )
        }

        // Read current settings
        var json: [String: Any] = [:]
        if let data = try? Data(contentsOf: settingsURL),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            json = existing
        }

        let python = detectPython()
        let ourCommand = "\(python) ~/.claude/hooks/claude-island-status.py"

        // Check for existing statusLine config
        if let existing = json["statusLine"] as? [String: Any],
           let existingCmd = existing["command"] as? String,
           !existingCmd.contains("claude-island-status.py") {
            // User has their own statusLine — chain to it
            try? existingCmd.write(to: originalCmdFile, atomically: true, encoding: .utf8)

            let escapedCmd = existingCmd.replacingOccurrences(of: "'", with: "'\\''")
            json["statusLine"] = [
                "type": "command",
                "command": "NOTCH_ISLAND_CHAIN_CMD='\(escapedCmd)' \(ourCommand)"
            ] as [String: Any]
        } else if let existing = json["statusLine"] as? [String: Any],
                  let existingCmd = existing["command"] as? String,
                  existingCmd.contains("claude-island-status.py") {
            // Already installed — skip
            return
        } else {
            // No existing statusLine — install ours directly
            json["statusLine"] = [
                "type": "command",
                "command": ourCommand
            ] as [String: Any]
        }

        if let data = try? JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted, .sortedKeys]
        ) {
            try? data.write(to: settingsURL)
        }
    }

    /// Remove statusLine config and restore original if one was chained
    static func uninstallStatusLine() {
        let claudeDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")
        let hooksDir = claudeDir.appendingPathComponent("hooks")
        let statusScript = hooksDir.appendingPathComponent("claude-island-status.py")
        let originalCmdFile = hooksDir.appendingPathComponent(".original-statusline-command")
        let settings = claudeDir.appendingPathComponent("settings.json")

        try? FileManager.default.removeItem(at: statusScript)

        guard let data = try? Data(contentsOf: settings),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        // Restore original statusLine if we saved one
        if let originalCmd = try? String(contentsOf: originalCmdFile, encoding: .utf8),
           !originalCmd.isEmpty {
            json["statusLine"] = [
                "type": "command",
                "command": originalCmd
            ] as [String: Any]
            try? FileManager.default.removeItem(at: originalCmdFile)
        } else {
            json.removeValue(forKey: "statusLine")
        }

        if let data = try? JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted, .sortedKeys]
        ) {
            try? data.write(to: settings)
        }
    }

    private static func updateSettings(at settingsURL: URL) {
        var json: [String: Any] = [:]
        if let data = try? Data(contentsOf: settingsURL),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            json = existing
        }

        let python = detectPython()
        let command = "\(python) ~/.claude/hooks/claude-island-state.py"
        let hookEntry: [[String: Any]] = [["type": "command", "command": command]]
        let hookEntryWithTimeout: [[String: Any]] = [["type": "command", "command": command, "timeout": 86400]]
        let withMatcher: [[String: Any]] = [["matcher": "*", "hooks": hookEntry]]
        let withMatcherAndTimeout: [[String: Any]] = [["matcher": "*", "hooks": hookEntryWithTimeout]]
        let withoutMatcher: [[String: Any]] = [["hooks": hookEntry]]
        let preCompactConfig: [[String: Any]] = [
            ["matcher": "auto", "hooks": hookEntry],
            ["matcher": "manual", "hooks": hookEntry]
        ]

        var hooks = json["hooks"] as? [String: Any] ?? [:]

        let hookEvents: [(String, [[String: Any]])] = [
            ("UserPromptSubmit", withoutMatcher),
            ("PreToolUse", withMatcher),
            ("PostToolUse", withMatcher),
            ("PermissionRequest", withMatcherAndTimeout),
            ("Notification", withMatcher),
            ("Stop", withoutMatcher),
            ("SubagentStop", withoutMatcher),
            ("SessionStart", withoutMatcher),
            ("SessionEnd", withoutMatcher),
            ("PreCompact", preCompactConfig),
        ]

        for (event, config) in hookEvents {
            if var existingEvent = hooks[event] as? [[String: Any]] {
                let hasOurHook = existingEvent.contains { entry in
                    if let entryHooks = entry["hooks"] as? [[String: Any]] {
                        return entryHooks.contains { h in
                            let cmd = h["command"] as? String ?? ""
                            return cmd.contains("claude-island-state.py")
                        }
                    }
                    return false
                }
                if !hasOurHook {
                    existingEvent.append(contentsOf: config)
                    hooks[event] = existingEvent
                }
            } else {
                hooks[event] = config
            }
        }

        json["hooks"] = hooks

        if let data = try? JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted, .sortedKeys]
        ) {
            try? data.write(to: settingsURL)
        }
    }

    /// Check if hooks are currently installed
    static func isInstalled() -> Bool {
        let claudeDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")
        let settings = claudeDir.appendingPathComponent("settings.json")

        guard let data = try? Data(contentsOf: settings),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hooks = json["hooks"] as? [String: Any] else {
            return false
        }

        for (_, value) in hooks {
            if let entries = value as? [[String: Any]] {
                for entry in entries {
                    if let entryHooks = entry["hooks"] as? [[String: Any]] {
                        for hook in entryHooks {
                            if let cmd = hook["command"] as? String,
                               cmd.contains("claude-island-state.py") {
                                return true
                            }
                        }
                    }
                }
            }
        }
        return false
    }

    /// Uninstall hooks from settings.json and remove script
    static func uninstall() {
        let claudeDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")
        let hooksDir = claudeDir.appendingPathComponent("hooks")
        let pythonScript = hooksDir.appendingPathComponent("claude-island-state.py")
        let settings = claudeDir.appendingPathComponent("settings.json")

        try? FileManager.default.removeItem(at: pythonScript)

        guard let data = try? Data(contentsOf: settings),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var hooks = json["hooks"] as? [String: Any] else {
            return
        }

        for (event, value) in hooks {
            if var entries = value as? [[String: Any]] {
                entries.removeAll { entry in
                    if let entryHooks = entry["hooks"] as? [[String: Any]] {
                        return entryHooks.contains { hook in
                            let cmd = hook["command"] as? String ?? ""
                            return cmd.contains("claude-island-state.py")
                        }
                    }
                    return false
                }

                if entries.isEmpty {
                    hooks.removeValue(forKey: event)
                } else {
                    hooks[event] = entries
                }
            }
        }

        if hooks.isEmpty {
            json.removeValue(forKey: "hooks")
        } else {
            json["hooks"] = hooks
        }

        if let data = try? JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted, .sortedKeys]
        ) {
            try? data.write(to: settings)
        }
    }

    // MARK: - Codex Hooks

    /// Install Codex hook script, update hooks.json, and enable feature flag
    static func installCodexIfNeeded() {
        let codexDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex")
        let codexHooksDir = codexDir.appendingPathComponent("hooks")
        let codexScript = codexHooksDir.appendingPathComponent("codex-island-state.py")
        let codexHooksConfig = codexDir.appendingPathComponent("hooks.json")
        let codexConfig = codexDir.appendingPathComponent("config.toml")

        try? FileManager.default.createDirectory(
            at: codexHooksDir,
            withIntermediateDirectories: true
        )

        if let bundled = Bundle.main.url(forResource: "codex-island-state", withExtension: "py") {
            try? FileManager.default.removeItem(at: codexScript)
            try? FileManager.default.copyItem(at: bundled, to: codexScript)
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: codexScript.path
            )
        }

        updateCodexHooks(at: codexHooksConfig)
        enableCodexHooksFeatureFlag(at: codexConfig)
    }

    private static func updateCodexHooks(at hooksURL: URL) {
        var json: [String: Any] = [:]
        if let data = try? Data(contentsOf: hooksURL),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            json = existing
        }

        let python = detectPython()
        let command = "\(python) ~/.codex/hooks/codex-island-state.py"
        let hookEntry: [[String: Any]] = [["type": "command", "command": command]]
        let withMatcher: [[String: Any]] = [["matcher": "*", "hooks": hookEntry]]
        let withoutMatcher: [[String: Any]] = [["hooks": hookEntry]]

        let hookEvents: [(String, [[String: Any]])] = [
            ("SessionStart", withoutMatcher),
            ("UserPromptSubmit", withoutMatcher),
            ("PreToolUse", withMatcher),
            ("PostToolUse", withMatcher),
            ("Stop", withoutMatcher),
        ]

        for (event, config) in hookEvents {
            if var existingEvent = json[event] as? [[String: Any]] {
                let hasOurHook = existingEvent.contains { entry in
                    if let entryHooks = entry["hooks"] as? [[String: Any]] {
                        return entryHooks.contains { h in
                            let cmd = h["command"] as? String ?? ""
                            return cmd.contains("codex-island-state.py")
                        }
                    }
                    return false
                }
                if !hasOurHook {
                    existingEvent.append(contentsOf: config)
                    json[event] = existingEvent
                }
            } else {
                json[event] = config
            }
        }

        if let data = try? JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted, .sortedKeys]
        ) {
            try? data.write(to: hooksURL)
        }
    }

    private static func enableCodexHooksFeatureFlag(at configURL: URL) {
        var content = (try? String(contentsOf: configURL, encoding: .utf8)) ?? ""

        if content.contains("codex_hooks") {
            // Replace existing value
            content = content.replacingOccurrences(
                of: "codex_hooks\\s*=\\s*false",
                with: "codex_hooks = true",
                options: .regularExpression
            )
        } else {
            // Append to file
            if !content.isEmpty && !content.hasSuffix("\n") {
                content += "\n"
            }
            content += "codex_hooks = true\n"
        }

        try? content.write(to: configURL, atomically: true, encoding: .utf8)
    }

    /// Check if Codex hooks are currently installed
    static func isCodexInstalled() -> Bool {
        let codexDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex")
        let hooksConfig = codexDir.appendingPathComponent("hooks.json")

        guard let data = try? Data(contentsOf: hooksConfig),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }

        for (_, value) in json {
            if let entries = value as? [[String: Any]] {
                for entry in entries {
                    if let entryHooks = entry["hooks"] as? [[String: Any]] {
                        for hook in entryHooks {
                            if let cmd = hook["command"] as? String,
                               cmd.contains("codex-island-state.py") {
                                return true
                            }
                        }
                    }
                }
            }
        }
        return false
    }

    /// Uninstall Codex hooks from hooks.json and remove script
    static func uninstallCodex() {
        let codexDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex")
        let codexHooksDir = codexDir.appendingPathComponent("hooks")
        let codexScript = codexHooksDir.appendingPathComponent("codex-island-state.py")
        let hooksConfig = codexDir.appendingPathComponent("hooks.json")

        try? FileManager.default.removeItem(at: codexScript)

        guard let data = try? Data(contentsOf: hooksConfig),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        for (event, value) in json {
            if var entries = value as? [[String: Any]] {
                entries.removeAll { entry in
                    if let entryHooks = entry["hooks"] as? [[String: Any]] {
                        return entryHooks.contains { hook in
                            let cmd = hook["command"] as? String ?? ""
                            return cmd.contains("codex-island-state.py")
                        }
                    }
                    return false
                }

                if entries.isEmpty {
                    json.removeValue(forKey: event)
                } else {
                    json[event] = entries
                }
            }
        }

        if let data = try? JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted, .sortedKeys]
        ) {
            try? data.write(to: hooksConfig)
        }
    }

    private static func detectPython() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["python3"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                return "python3"
            }
        } catch {}

        return "python"
    }
}
