//
//  AgentType.swift
//  ClaudeIsland
//
//  Identifies which AI coding agent a session belongs to.
//

import SwiftUI

enum AgentType: String, Codable, Sendable, Equatable {
    case claudeCode = "claude_code"
    case codex = "codex"

    var displayName: String {
        switch self {
        case .claudeCode: return "Claude Code"
        case .codex: return "Codex"
        }
    }

    var badgeColor: Color {
        switch self {
        case .claudeCode: return .orange
        case .codex: return .cyan
        }
    }
}
