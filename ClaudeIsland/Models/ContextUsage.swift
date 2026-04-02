//
//  ContextUsage.swift
//  ClaudeIsland
//
//  Context window usage data from Claude Code's statusLine API.
//

import SwiftUI

struct ContextUsage: Equatable, Sendable {
    var contextWindowSize: Int
    var usedPercentage: Double
    var inputTokens: Int
    var outputTokens: Int
    var totalCostUsd: Double
    var modelName: String?

    var formattedPercentage: String {
        "\(Int(usedPercentage))%"
    }

    var formattedCost: String {
        String(format: "$%.2f", totalCostUsd)
    }

    /// green < 50%, yellow 50-70%, red >= 85%, orange in between
    var usageColor: Color {
        if usedPercentage >= 85 {
            return Color(red: 1.0, green: 0.3, blue: 0.3)
        } else if usedPercentage >= 70 {
            return Color(red: 1.0, green: 0.6, blue: 0.2)
        } else if usedPercentage >= 50 {
            return Color(red: 0.9, green: 0.8, blue: 0.2)
        } else {
            return Color(red: 0.3, green: 0.8, blue: 0.4)
        }
    }
}
