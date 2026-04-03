import Foundation
import Testing
@testable import VibeIslandApp
import VibeIslandCore

@MainActor
struct AppModelSessionListTests {
    @Test
    func islandListSessionsOnlyIncludeLiveAttachedSessions() {
        let now = Date(timeIntervalSince1970: 2_000)
        let model = AppModel()
        model.state = SessionState(
            sessions: [
                AgentSession(
                    id: "live-session",
                    title: "Claude · active",
                    tool: .claudeCode,
                    origin: .live,
                    attachmentState: .attached,
                    phase: .running,
                    summary: "Running",
                    updatedAt: now,
                    jumpTarget: JumpTarget(
                        terminalApp: "Ghostty",
                        workspaceName: "active",
                        paneTitle: "claude ~/active",
                        workingDirectory: "/tmp/active",
                        terminalSessionID: "ghostty-1"
                    ),
                    claudeMetadata: ClaudeSessionMetadata(
                        transcriptPath: "/tmp/live.jsonl",
                        currentTool: "Task"
                    )
                ),
                AgentSession(
                    id: "recent-session",
                    title: "Claude · recent",
                    tool: .claudeCode,
                    origin: .live,
                    attachmentState: .stale,
                    phase: .completed,
                    summary: "Finished",
                    updatedAt: now.addingTimeInterval(-300),
                    jumpTarget: JumpTarget(
                        terminalApp: "Ghostty",
                        workspaceName: "recent",
                        paneTitle: "claude ~/recent",
                        workingDirectory: "/tmp/recent",
                        terminalSessionID: "ghostty-2"
                    ),
                    claudeMetadata: ClaudeSessionMetadata(
                        transcriptPath: "/tmp/recent.jsonl",
                        lastAssistantMessage: "Finished"
                    )
                ),
            ]
        )

        #expect(model.surfacedSessions.map(\.id) == ["live-session"])
        #expect(model.recentSessions.map(\.id) == ["recent-session"])
        #expect(model.islandListSessions.map(\.id) == ["live-session"])
    }

    @Test
    func hoverOpenedSessionListAutoCollapsesOnPointerExit() {
        let model = AppModel()
        model.notchStatus = .opened
        model.notchOpenReason = .hover
        model.islandSurface = .sessionList

        #expect(model.shouldAutoCollapseOnMouseLeave)

        model.handlePointerExitedIslandSurface()

        #expect(model.notchStatus == .closed)
        #expect(model.notchOpenReason == nil)
        #expect(model.islandSurface == .sessionList)
    }

    @Test
    func clickedSessionListDoesNotAutoCollapseOnPointerExit() {
        let model = AppModel()
        model.notchStatus = .opened
        model.notchOpenReason = .click
        model.islandSurface = .sessionList

        #expect(!model.shouldAutoCollapseOnMouseLeave)

        model.notePointerInsideIslandSurface()
        model.handlePointerExitedIslandSurface()

        #expect(model.notchStatus == .opened)
        #expect(model.notchOpenReason == .click)
        #expect(model.islandSurface == .sessionList)
    }

    @Test
    func completionNotificationRequiresSurfaceEntryBeforePointerExitCollapse() {
        let model = AppModel()
        model.notchStatus = .opened
        model.notchOpenReason = .notification
        model.islandSurface = .completionCard(sessionID: "session-1")

        #expect(model.shouldAutoCollapseOnMouseLeave)

        model.handlePointerExitedIslandSurface()

        #expect(model.notchStatus == .opened)
        #expect(model.notchOpenReason == .notification)

        model.notePointerInsideIslandSurface()
        model.handlePointerExitedIslandSurface()

        #expect(model.notchStatus == .closed)
        #expect(model.notchOpenReason == nil)
    }

    @Test
    func mergeDiscoveredClaudeSessionsPreservesRegistryJumpTargetAndAddsTranscriptMetadata() {
        let now = Date(timeIntervalSince1970: 2_000)
        let model = AppModel()
        model.state = SessionState(
            sessions: [
                AgentSession(
                    id: "claude-session",
                    title: "Claude · vibe-island",
                    tool: .claudeCode,
                    origin: .live,
                    attachmentState: .stale,
                    phase: .completed,
                    summary: "Recovered from registry",
                    updatedAt: now.addingTimeInterval(-60),
                    jumpTarget: JumpTarget(
                        terminalApp: "Ghostty",
                        workspaceName: "vibe-island",
                        paneTitle: "claude ~/vibe-island",
                        workingDirectory: "/tmp/vibe-island",
                        terminalSessionID: "ghostty-claude",
                        terminalTTY: "/dev/ttys002"
                    )
                ),
            ]
        )

        let merged = model.mergeDiscoveredSessions([
            AgentSession(
                id: "claude-session",
                title: "Claude · vibe-island",
                tool: .claudeCode,
                origin: .live,
                attachmentState: .stale,
                phase: .running,
                summary: "Recovered from transcript",
                updatedAt: now,
                jumpTarget: JumpTarget(
                    terminalApp: "Unknown",
                    workspaceName: "vibe-island",
                    paneTitle: "Claude deadbeef",
                    workingDirectory: "/tmp/vibe-island"
                ),
                claudeMetadata: ClaudeSessionMetadata(
                    transcriptPath: "/tmp/claude.jsonl",
                    lastUserPrompt: "Check the Claude session registry.",
                    currentTool: "Task"
                )
            ),
        ])

        #expect(merged.count == 1)
        #expect(merged.first?.jumpTarget?.terminalApp == "Ghostty")
        #expect(merged.first?.jumpTarget?.terminalSessionID == "ghostty-claude")
        #expect(merged.first?.claudeMetadata?.transcriptPath == "/tmp/claude.jsonl")
        #expect(merged.first?.claudeMetadata?.lastUserPrompt == "Check the Claude session registry.")
        #expect(merged.first?.phase == .running)
    }
}
