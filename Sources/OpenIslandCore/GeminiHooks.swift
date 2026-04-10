// Sources/OpenIslandCore/GeminiHooks.swift
import Foundation

public enum GeminiHookEventName: String, Codable, Sendable {
    case sessionStart = "SessionStart"
    case preToolUse = "PreToolUse"
    case postToolUse = "PostToolUse"
    case stop = "Stop"
    case userPromptSubmit = "UserPromptSubmit"
}

public struct GeminiHookToolInput: Equatable, Codable, Sendable {
    public var command: String

    public init(command: String) {
        self.command = command
    }
}

public struct GeminiHookPayload: Equatable, Codable, Sendable {
    public var sessionID: String
    public var hookEventName: GeminiHookEventName
    public var cwd: String
    public var model: String
    public var toolName: String?
    public var toolInput: GeminiHookToolInput?
    public var lastAssistantMessage: String?

    private enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case hookEventName = "hook_event_name"
        case cwd
        case model
        case toolName = "tool_name"
        case toolInput = "tool_input"
        case lastAssistantMessage = "last_assistant_message"
    }

    public init(
        sessionID: String,
        hookEventName: GeminiHookEventName,
        cwd: String,
        model: String,
        toolName: String? = nil,
        toolInput: GeminiHookToolInput? = nil,
        lastAssistantMessage: String? = nil
    ) {
        self.sessionID = sessionID
        self.hookEventName = hookEventName
        self.cwd = cwd
        self.model = model
        self.toolName = toolName
        self.toolInput = toolInput
        self.lastAssistantMessage = lastAssistantMessage
    }
}

public extension GeminiHookPayload {
    var workspaceName: String {
        WorkspaceNameResolver.workspaceName(for: cwd)
    }

    var sessionTitle: String {
        "Gemini CLI · \(workspaceName)"
    }

    var implicitStartSummary: String {
        switch hookEventName {
        case .sessionStart:
            return "Started Gemini CLI session in \(workspaceName)."
        case .preToolUse:
            let tool = toolName ?? "tool"
            return "Gemini CLI is running \(tool) in \(workspaceName)."
        case .postToolUse:
            return "Gemini CLI finished a tool call in \(workspaceName)."
        case .stop:
            return "Gemini CLI completed a turn in \(workspaceName)."
        case .userPromptSubmit:
            return "Gemini CLI received a new prompt in \(workspaceName)."
        }
    }
}

public enum GeminiHookOutputEncoder {
    public static func standardOutput(for response: BridgeResponse) -> Data? {
        // Gemini CLI hooks are fire-and-forget — no block/deny directive needed yet.
        return nil
    }
}
