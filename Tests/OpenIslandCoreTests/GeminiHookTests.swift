// Tests/OpenIslandCoreTests/GeminiHookTests.swift
import Testing
import Foundation
@testable import OpenIslandCore

@Suite("GeminiHooks")
struct GeminiHookTests {
    @Test func decodesSessionStartPayload() throws {
        let json = """
        {
          "session_id": "abc-123",
          "hook_event_name": "SessionStart",
          "cwd": "/Users/user/project",
          "model": "gemini-2.0-flash"
        }
        """.data(using: .utf8)!
        let payload = try JSONDecoder().decode(GeminiHookPayload.self, from: json)
        #expect(payload.sessionID == "abc-123")
        #expect(payload.hookEventName == .sessionStart)
        #expect(payload.model == "gemini-2.0-flash")
        #expect(payload.cwd == "/Users/user/project")
    }

    @Test func decodesPreToolUsePayload() throws {
        let json = """
        {
          "session_id": "xyz",
          "hook_event_name": "PreToolUse",
          "cwd": "/tmp",
          "model": "gemini-2.0-flash",
          "tool_name": "bash",
          "tool_input": {"command": "ls -la"}
        }
        """.data(using: .utf8)!
        let payload = try JSONDecoder().decode(GeminiHookPayload.self, from: json)
        #expect(payload.hookEventName == .preToolUse)
        #expect(payload.toolName == "bash")
        #expect(payload.toolInput?.command == "ls -la")
    }

    @Test func encoderReturnsNilForAcknowledged() {
        let result = GeminiHookOutputEncoder.standardOutput(for: .acknowledged)
        #expect(result == nil)
    }

    @Test func optionalFieldsDecodeAsNilWhenAbsent() throws {
        let json = """
        {
          "session_id": "s1",
          "hook_event_name": "Stop",
          "cwd": "/tmp",
          "model": "gemini-2.0-flash"
        }
        """.data(using: .utf8)!
        let payload = try JSONDecoder().decode(GeminiHookPayload.self, from: json)
        #expect(payload.toolName == nil)
        #expect(payload.toolInput == nil)
        #expect(payload.lastAssistantMessage == nil)
    }

    @Test func implicitStartSummaryForAllEvents() {
        let base = GeminiHookPayload(sessionID: "s", hookEventName: .sessionStart, cwd: "/Users/user/myapp", model: "g")
        var p = base
        p = GeminiHookPayload(sessionID: "s", hookEventName: .sessionStart, cwd: "/Users/user/myapp", model: "g")
        #expect(p.implicitStartSummary.contains("Started"))
        p = GeminiHookPayload(sessionID: "s", hookEventName: .preToolUse, cwd: "/Users/user/myapp", model: "g", toolName: "bash")
        #expect(p.implicitStartSummary.contains("bash"))
        p = GeminiHookPayload(sessionID: "s", hookEventName: .postToolUse, cwd: "/Users/user/myapp", model: "g")
        #expect(p.implicitStartSummary.contains("finished"))
        p = GeminiHookPayload(sessionID: "s", hookEventName: .stop, cwd: "/Users/user/myapp", model: "g")
        #expect(p.implicitStartSummary.contains("completed"))
        p = GeminiHookPayload(sessionID: "s", hookEventName: .userPromptSubmit, cwd: "/Users/user/myapp", model: "g")
        #expect(p.implicitStartSummary.contains("prompt"))
    }
}
