import SwiftUI
import OpenIslandCore

struct ControlCenterView: View {
    var model: AppModel

    @State private var selectedScenario: IslandDebugScenario = .approvalCard
    @State private var previewModel = AppModel()
    @State private var previewSnapshot = IslandDebugScenario.approvalCard.snapshot()

    var body: some View {
        HStack(spacing: 28) {
            controlColumn
            previewColumn
        }
        .padding(28)
        .frame(width: 1280, height: 820)
        .background(debugBackground)
        .preferredColorScheme(.dark)
        .onAppear {
            refreshPreview(for: selectedScenario)
        }
        .onChange(of: selectedScenario) { _, newValue in
            refreshPreview(for: newValue)
        }
    }

    private var controlColumn: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Open Island Debug")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Mock-driven notch surface harness for validating session list, approval, question, and completion cards.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Scenarios")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.58))

                    ForEach(IslandDebugScenario.allCases) { scenario in
                        scenarioButton(for: scenario)
                    }
                }

                usageDebugCard(
                    title: "Claude Hooks",
                    statusTitle: model.hooks.claudeHookStatusTitle,
                    statusSummary: model.hooks.claudeHookStatusSummary,
                    isActive: model.hooks.claudeHooksInstalled || model.hooks.claudeHookStatus?.hasClaudeIslandHooks == true,
                    accentColor: model.hooks.claudeHooksInstalled ? .mint : (model.hooks.claudeHookStatus?.hasClaudeIslandHooks == true ? .orange : .blue)
                ) {
                    if let status = model.hooks.claudeHookStatus {
                        metadataRow(title: "settings", value: status.settingsURL.path)
                        metadataRow(title: "manifest", value: status.manifestURL.path)
                        if status.hasClaudeIslandHooks {
                            metadataRow(title: "notice", value: "claude-island hooks still present")
                        }
                    }
                } actions: {
                    HStack(spacing: 10) {
                        Button("Refresh") {
                            model.hooks.refreshClaudeHookStatus()
                        }
                        .buttonStyle(DebugActionButtonStyle(kind: .secondary))

                        Button(model.hooks.claudeHooksInstalled ? "Remove Hooks" : "Install Hooks") {
                            if model.hooks.claudeHooksInstalled {
                                model.hooks.uninstallClaudeHooks()
                            } else {
                                model.hooks.installClaudeHooks()
                            }
                        }
                        .buttonStyle(DebugActionButtonStyle(kind: .primary))
                        .disabled(model.hooks.isClaudeHookSetupBusy || model.hooks.hooksBinaryURL == nil)
                    }
                }

                usageDebugCard(
                    title: "Claude Usage",
                    statusTitle: model.hooks.claudeUsageStatusTitle,
                    statusSummary: model.hooks.claudeUsageStatusSummary,
                    isActive: model.hooks.claudeUsageInstalled || model.hooks.claudeStatusLineStatus?.hasConflictingStatusLine == true,
                    accentColor: model.hooks.claudeUsageInstalled ? .mint : (model.hooks.claudeStatusLineStatus?.hasConflictingStatusLine == true ? .orange : .blue)
                ) {
                    if let summary = model.hooks.claudeUsageSummaryText {
                        metadataRow(title: "usage", value: summary)
                    }

                    if let status = model.hooks.claudeStatusLineStatus {
                        metadataRow(title: "settings", value: status.settingsURL.path)
                        metadataRow(title: "script", value: status.scriptURL.path)
                        metadataRow(title: "cache", value: status.cacheURL.path)
                    }
                } actions: {
                    HStack(spacing: 10) {
                        Button("Refresh") {
                            model.hooks.refreshClaudeUsageState()
                        }
                        .buttonStyle(DebugActionButtonStyle(kind: .secondary))

                        Button(model.hooks.claudeUsageInstalled ? "Remove Bridge" : "Install Bridge") {
                            if model.hooks.claudeUsageInstalled {
                                model.hooks.uninstallClaudeUsageBridge()
                            } else {
                                model.hooks.installClaudeUsageBridge()
                            }
                        }
                        .buttonStyle(DebugActionButtonStyle(kind: .primary))
                        .disabled(model.hooks.isClaudeUsageSetupBusy || model.hooks.claudeStatusLineStatus?.hasConflictingStatusLine == true)
                    }
                }

                usageDebugCard(
                    title: "Codex Usage",
                    statusTitle: model.hooks.codexUsageStatusTitle,
                    statusSummary: model.hooks.codexUsageStatusSummary,
                    isActive: model.hooks.codexUsageSnapshot?.isEmpty == false,
                    accentColor: model.hooks.codexUsageSnapshot?.isEmpty == false ? .mint : .blue
                ) {
                    if let summary = model.hooks.codexUsageSummaryText {
                        metadataRow(title: "usage", value: summary)
                    }

                    if let snapshot = model.hooks.codexUsageSnapshot {
                        metadataRow(title: "latest rollout", value: snapshot.sourceFilePath)

                        if let planType = snapshot.planType {
                            metadataRow(title: "plan", value: planType)
                        }

                        if let capturedAt = snapshot.capturedAt {
                            metadataRow(
                                title: "captured",
                                value: capturedAt.formatted(date: .abbreviated, time: .standard)
                            )
                        }
                    }
                } actions: {
                    HStack(spacing: 10) {
                        Button("Refresh") {
                            model.hooks.refreshCodexUsageState()
                        }
                        .buttonStyle(DebugActionButtonStyle(kind: .secondary))
                    }
                }

                actionCard
                transcriptCard
                liveOverlayCard

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollIndicators(.visible)
        .frame(width: 360, alignment: .topLeading)
    }

    private func scenarioButton(for scenario: IslandDebugScenario) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Button {
                selectedScenario = scenario
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(selectedScenario == scenario ? .white.opacity(0.88) : .white.opacity(0.22))
                        .frame(width: 8, height: 8)
                        .padding(.top, 6)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(scenario.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)

                        Text(scenario.summary)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            Button {
                let snapshot = scenario.snapshot()
                model.loadDebugSnapshot(snapshot, presentOverlay: true, autoCollapseNotificationCards: false)
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
            .help("Trigger on island")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(selectedScenario == scenario ? Color.white.opacity(0.08) : Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(selectedScenario == scenario ? .white.opacity(0.18) : .white.opacity(0.05))
        )
    }

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actions")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.58))

            Text("The inline preview is isolated. Use the button below if you want the real top-of-screen island to mirror the current mock.")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button("Mirror To Island") {
                    model.loadDebugSnapshot(previewSnapshot, presentOverlay: true, autoCollapseNotificationCards: false)
                }
                .buttonStyle(DebugActionButtonStyle(kind: .primary))

                Button("Close Island") {
                    model.notchClose()
                }
                .buttonStyle(DebugActionButtonStyle(kind: .secondary))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(debugCardBackground)
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Mock")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.58))

            Text(previewSnapshot.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)

            Text(previewSnapshot.summary)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.52))
                .fixedSize(horizontal: false, vertical: true)

            if let session = activePreviewSession {
                debugLine("Line 1", session.spotlightHeadlineText)
                debugLine("Line 2", session.spotlightPromptLineText ?? "None")
                debugLine("Line 3", session.spotlightActivityLineText ?? session.summary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(debugCardBackground)
    }

    private var liveOverlayCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Live Overlay")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.58))

            debugMetricRow(label: "Visible", value: model.isOverlayVisible ? "Yes" : "No")
            debugMetricRow(label: "Surface", value: liveSurfaceTitle)
            debugMetricRow(label: "Sessions", value: "\(model.sessions.count)")
            debugMetricRow(label: "Message", value: model.lastActionMessage)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(debugCardBackground)
    }

    private var previewColumn: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Inline Preview")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("This preview is stable and ignores live bridge activity.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.48))
                }

                Spacer(minLength: 0)
            }

            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.07, green: 0.07, blue: 0.08),
                                Color(red: 0.03, green: 0.03, blue: 0.04),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(.white.opacity(0.06))
                    )

                VStack(spacing: 0) {
                    IslandPanelView(model: previewModel)
                        .frame(width: 860, height: previewSnapshot.previewHeight, alignment: .top)
                        .allowsHitTesting(false)

                    Spacer(minLength: 0)
                }
                .padding(.top, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var activePreviewSession: AgentSession? {
        previewModel.activeIslandCardSession ?? previewModel.surfacedSessions.first
    }

    private var debugCardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(.white.opacity(0.06))
            )
    }

    private var debugBackground: some View {
        LinearGradient(
            colors: [
                Color.black,
                Color(red: 0.03, green: 0.03, blue: 0.04),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var liveSurfaceTitle: String {
        switch model.islandSurface {
        case .sessionList:
            "Session List"
        case .approvalCard:
            "Approval Card"
        case .questionCard:
            "Question Card"
        case .completionCard:
            "Completion Card"
        }
    }

    private func refreshPreview(for scenario: IslandDebugScenario) {
        let snapshot = scenario.snapshot()
        previewSnapshot = snapshot
        previewModel.loadDebugSnapshot(snapshot)
    }

    private func usageDebugCard<Content: View, Actions: View>(
        title: String,
        statusTitle: String,
        statusSummary: String,
        isActive: Bool,
        accentColor: Color,
        @ViewBuilder content: () -> Content,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.58))

                    Text(statusTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(statusSummary)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Circle()
                    .fill(isActive ? accentColor : accentColor.opacity(0.7))
                    .frame(width: 10, height: 10)
                    .padding(.top, 4)
            }

            content()
            actions()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(debugCardBackground)
    }

    private func debugMetricRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(2)
        }
    }

    private func debugLine(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.38))
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func metadataRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.38))

            Text(value)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct DebugActionButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
    }

    let kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(kind == .primary ? Color.black : .white.opacity(0.78))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(background(configuration: configuration), in: Capsule())
    }

    private func background(configuration: Configuration) -> Color {
        switch kind {
        case .primary:
            return Color.white.opacity(configuration.isPressed ? 0.72 : 0.9)
        case .secondary:
            return Color.white.opacity(configuration.isPressed ? 0.08 : 0.12)
        }
    }
}
