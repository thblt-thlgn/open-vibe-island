import Foundation
import Testing
@testable import VibeIslandApp
import VibeIslandCore

struct TerminalSessionAttachmentProbeTests {
    @Test
    func ghosttyKeepsOnlyNewestSessionAttachedPerSnapshot() {
        let now = Date(timeIntervalSince1970: 1_000)
        let probe = TerminalSessionAttachmentProbe()
        let older = ghosttySession(
            id: "older",
            updatedAt: now.addingTimeInterval(-60),
            phase: .completed,
            terminalSessionID: "ghostty-1"
        )
        let newer = ghosttySession(
            id: "newer",
            updatedAt: now,
            phase: .running,
            terminalSessionID: "ghostty-1"
        )

        let updates = probe.attachmentStates(
            for: [older, newer],
            ghosttyAvailability: .available(
                [.init(sessionID: "ghostty-1", workingDirectory: "/tmp/worktree", title: "codex ~/tmp/worktree")],
                appIsRunning: true
            ),
            terminalAvailability: .available([] as [TerminalSessionAttachmentProbe.TerminalTabSnapshot], appIsRunning: false),
            now: now
        )

        #expect(updates["newer"] == .attached)
        #expect(updates["older"] == .stale)
    }

    @Test
    func ghosttyStableIdentifierPreventsWorkingDirectoryFallbackMatches() {
        let now = Date(timeIntervalSince1970: 1_000)
        let probe = TerminalSessionAttachmentProbe()
        let session = ghosttySession(
            id: "session-1",
            updatedAt: now.addingTimeInterval(-30),
            phase: .running,
            terminalSessionID: "ghostty-stale",
            paneTitle: "codex ~/tmp/worktree"
        )

        let updates = probe.attachmentStates(
            for: [session],
            ghosttyAvailability: .available(
                [.init(sessionID: "ghostty-active", workingDirectory: "/tmp/worktree", title: "codex ~/tmp/worktree")],
                appIsRunning: true
            ),
            terminalAvailability: .available([] as [TerminalSessionAttachmentProbe.TerminalTabSnapshot], appIsRunning: false),
            now: now
        )

        #expect(updates["session-1"] == .stale)
    }

    @Test
    func ghosttyRehomesMisbindingWhenRecordedTerminalIsAlreadyClaimed() {
        let now = Date(timeIntervalSince1970: 1_000)
        let probe = TerminalSessionAttachmentProbe()
        let primary = ghosttySession(
            id: "primary",
            updatedAt: now,
            phase: .running,
            terminalSessionID: "ghostty-1",
            workingDirectory: "/tmp/worktree"
        )
        let rehomed = ghosttySession(
            id: "rehomed",
            updatedAt: now.addingTimeInterval(-30),
            phase: .completed,
            terminalSessionID: "ghostty-1",
            paneTitle: "codex ~/tmp/worktree",
            workingDirectory: "/tmp/personal",
            workspaceName: "worktree"
        )

        let resolutions = probe.sessionResolutions(
            for: [primary, rehomed],
            ghosttyAvailability: .available(
                [
                    .init(sessionID: "ghostty-1", workingDirectory: "/tmp/worktree", title: "codex ~/tmp/worktree"),
                    .init(sessionID: "ghostty-2", workingDirectory: "/tmp/personal", title: "codex ~/tmp/personal"),
                ],
                appIsRunning: true
            ),
            terminalAvailability: .available([] as [TerminalSessionAttachmentProbe.TerminalTabSnapshot], appIsRunning: false),
            now: now
        )

        #expect(resolutions["primary"]?.attachmentState == .attached)
        #expect(resolutions["rehomed"]?.attachmentState == .attached)
        #expect(resolutions["rehomed"]?.correctedJumpTarget?.terminalSessionID == "ghostty-2")
        #expect(resolutions["rehomed"]?.correctedJumpTarget?.paneTitle == "codex ~/tmp/personal")
        #expect(resolutions["rehomed"]?.correctedJumpTarget?.workspaceName == "personal")
    }

    @Test
    func explicitTerminalMissDropsRecentlyAttachedSessionOutOfLiveState() {
        let now = Date(timeIntervalSince1970: 1_000)
        let probe = TerminalSessionAttachmentProbe()
        let session = terminalSession(
            id: "session-1",
            updatedAt: now.addingTimeInterval(-30),
            phase: .running,
            tty: "/dev/ttys001",
            codexMetadata: CodexSessionMetadata(currentTool: "Bash")
        )

        let updates = probe.attachmentStates(
            for: [session],
            ghosttyAvailability: .available([] as [TerminalSessionAttachmentProbe.GhosttyTerminalSnapshot], appIsRunning: false),
            terminalAvailability: .available([] as [TerminalSessionAttachmentProbe.TerminalTabSnapshot], appIsRunning: true),
            now: now
        )

        #expect(updates["session-1"] == .stale)
    }

    @Test
    func unavailableGhosttyProbeRetainsRecentGraceState() {
        let now = Date(timeIntervalSince1970: 1_000)
        let probe = TerminalSessionAttachmentProbe()
        let session = ghosttySession(
            id: "session-1",
            updatedAt: now.addingTimeInterval(-30),
            phase: .running,
            terminalSessionID: "ghostty-1"
        )

        let updates = probe.attachmentStates(
            for: [session],
            ghosttyAvailability: .unavailable(appIsRunning: true),
            terminalAvailability: .available([] as [TerminalSessionAttachmentProbe.TerminalTabSnapshot], appIsRunning: false),
            now: now
        )

        #expect(updates["session-1"] == .attached)
    }

    private func ghosttySession(
        id: String,
        updatedAt: Date,
        phase: SessionPhase,
        terminalSessionID: String,
        paneTitle: String = "codex ~/tmp/worktree",
        workingDirectory: String = "/tmp/worktree",
        workspaceName: String = "worktree",
        codexMetadata: CodexSessionMetadata? = nil
    ) -> AgentSession {
        AgentSession(
            id: id,
            title: "Codex · worktree",
            tool: .codex,
            origin: .live,
            attachmentState: .attached,
            phase: phase,
            summary: "Summary",
            updatedAt: updatedAt,
            jumpTarget: JumpTarget(
                terminalApp: "Ghostty",
                workspaceName: workspaceName,
                paneTitle: paneTitle,
                workingDirectory: workingDirectory,
                terminalSessionID: terminalSessionID
            ),
            codexMetadata: codexMetadata
        )
    }

    private func terminalSession(
        id: String,
        updatedAt: Date,
        phase: SessionPhase,
        tty: String,
        codexMetadata: CodexSessionMetadata? = nil
    ) -> AgentSession {
        AgentSession(
            id: id,
            title: "Codex · worktree",
            tool: .codex,
            origin: .live,
            attachmentState: .attached,
            phase: phase,
            summary: "Summary",
            updatedAt: updatedAt,
            jumpTarget: JumpTarget(
                terminalApp: "Terminal",
                workspaceName: "worktree",
                paneTitle: "codex ~/tmp/worktree",
                workingDirectory: "/tmp/worktree",
                terminalTTY: tty
            ),
            codexMetadata: codexMetadata
        )
    }
}
