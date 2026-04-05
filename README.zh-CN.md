# Open Island

**中文** | [English](README.md)

## Human Parts

这部分内容是给人类阅读的。

### 这是什么

这是一个 open-source 的 Vibe Island 替代品，面向 macOS 上的重度 code agent 用户，目前主要聚焦 Claude Code、Codex、Terminal.app 和 Ghostty。

### 动机

我不想在自己的电脑上运行一个闭源、付费的软件来监视我所有的生产过程，所以我 build 了这个开源版本。

> you don't need to pay for a product you can vibe since you are a vibe coder

### 使用方式

- 从 GitHub Releases 下载构建并安装。
- Fork 这个仓库，然后 vibe 你自己的版本。这个项目在尝试应用 harness engineering，所以定制和添加特性应该尽量保持直接、简单。
- 如果你遇到 bug 或使用问题，请先发 issue。我们会优先处理这类问题。
- 如果你希望支持其他 terminal app 或 code agent，请先发 issue。我们会尽可能扩展支持范围。
- 如果你有产品想法或功能需求，也请先发 issue；如果你愿意直接做，欢迎附 demo 发 PR。

### 注意事项

本应用可能会为你的 Claude Code 或 Codex 安装 hooks，因此你可能会在这些会话中看到 hook 相关输出。

### Demo

待补充

## 社区

目前项目还在早期阶段，欢迎 issue 和 pull request。
如果你想现在就开始做贡献，可以先加入微信群：

<img src="docs/images/wechat-group.jpg" alt="Open Island 微信群二维码" width="360">
  
## 路线图

4.6 发布测试版


## Agent Parts

这部分内容是给 agents 阅读的。

这是一个面向终端原生 AI coding 工作流的开源 macOS companion app。

`Open Island` 会在刘海区域或顶部栏放置一个轻量控制界面，让你可以在不中断当前 flow 的前提下观察 live coding agents、跟踪会话进度，并快速跳回正确的 terminal 上下文。

## 为什么会有这个产品

AI coding 正在成为日常开发流程的一部分，但围绕它的控制层仍然经常意味着把你的机器交给一个闭源、收费的 app。

`Open Island` 选择了相反的路线：

- 开源
- local first
- 原生 macOS
- 适配 terminal 工作流，而不是替代它

## 适合谁

这个项目面向已经长期工作在 terminal 里的开发者。他们希望在 macOS 上和 coding agents 协作时拥有更好的上下文感，而不是在工具之间来回丢失状态。

## 你能得到什么

- 一个用于展示 live agent activity 的原生 island
- 对活跃 Codex 会话的快速可见性
- 更快地返回当前活跃 terminal 上下文
- 一个在平时尽量不打扰、但在关键时刻能给出反馈的 companion experience

## 当前产品形态

现在的 `Open Island` 主要专注在一件事上：让 Codex on macOS 的工作流更像原生体验。

当前范围：

- 仅支持 macOS
- 优先支持 Codex
- 提供实验性的 Claude Code usage status
- 从本地 rollout 文件被动读取 Codex account usage status
- live session visibility
- 低噪音的 Codex hook install
- jump-back behavior

## 当前已经可用的能力

目前项目已经可以：

- 在本地接收 Codex hook events
- 在 app 内展示 session 和 approval state
- 从本地 rollout 文件和缓存恢复最近的 Codex sessions
- 从最新的本地 `token_count` rollout event 中读取 Codex 的 5 小时和 7 天 account windows
- 在 `~/.codex` 中安装和卸载受管的 Codex hooks
- 检查 `~/.claude/settings.json`，并在没有自定义 status line 时安装一个受管的 Claude usage bridge
- 在 UI 中读取缓存的 Claude 5 小时和 7 天 usage windows
- 基于 terminal hints 提供 best-effort 的 jump back 行为

受管的 Codex 安装保持低噪音，只默认安装 `SessionStart`、`UserPromptSubmit` 和 `Stop` 这三个 hooks。bridge 仍然支持更丰富的交互式 hooks，但默认不会启用，因为 `PreToolUse` 和 `PostToolUse` 在日常 Codex 使用中会制造大量终端噪音。

Claude bridge 则刻意保持保守。它会把受管的 `statusLine.command` 写入 `~/.open-island/bin/open-island-statusline`，把 `rate_limits` 缓存到 `/tmp/open-island-rl.json`，并且不会自动覆盖已经存在的自定义 Claude status line。

## 快速开始

本地构建并运行：

```bash
zsh scripts/harness.sh
open Package.swift
```

harness 入口在 `scripts/harness.sh`。不带参数时，它会运行当前仓库基线检查：docs checks、`swift test` 和 `swift build`。

连接 Codex：

在 Xcode 中打开这个 package 并运行 macOS app target。启动时，app 会恢复本地缓存，扫描最近的 `~/.codex/sessions/**/rollout-*.jsonl` 文件来恢复已有的 Codex sessions，然后启动 live bridge 以接收新的 hook events。

控制中心还会展示来自 `~/.codex` 的实时 Codex hook install 状态，并且在能定位到本地 `OpenIslandHooks` 可执行文件时，直接安装或卸载受管 hook entries。安装过程会把 helper 复制到 `~/Library/Application Support/OpenIsland/bin/OpenIslandHooks`，这样即使 repo 或 worktree 重命名，也不会破坏已有 hooks。Claude usage setup 也可以在 app 中启用，并且仍然保持 opt-in。

```toml
[features]
codex_hooks = true
```

```bash
swift build -c release --product OpenIslandHooks
swift run OpenIslandSetup install
```

这套安装会启用 `codex_hooks = true`，并安装一组低噪音 hook，和原始 app 的 Codex 集成保持一致：`SessionStart`、`UserPromptSubmit` 和 `Stop`。

之后如果需要检查或移除安装：

```bash
swift run OpenIslandSetup status
swift run OpenIslandSetup uninstall
```

## 仓库导航

- 从 [docs/index.md](docs/index.md) 开始查看当前文档地图。
- 阅读 [docs/quality.md](docs/quality.md) 了解 harness contract 和 verification baseline。
- 如果你想在 macOS 上做确定性的本地 app smoke pass，可以运行 `zsh scripts/harness.sh smoke`。

## 产品方向

目标很简单：让 AI coding 在 macOS 上更像原生体验。

这意味着：

- 更少的上下文切换
- 更少的标签页来回寻找
- 更少的会话感知摩擦
- 更快地回到当前活跃 agent session

## 贡献

目前项目还在早期阶段，欢迎 issue 和 pull request。
