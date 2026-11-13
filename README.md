<div align="center">

<img src="docs/assets/icon_master.png" width="112" height="112" alt="InputTimeline App Icon" />

# InputTimeline

**macOS 原生本地输入记录工具 — 监听键盘与剪贴板，将每日输入活动沉淀为结构化 JSON 时间线，供回顾与 AI 复盘。**

[![Website](https://img.shields.io/badge/Website-GitHub%20Pages-0062CC?style=flat-square)](https://lxx-003.github.io/input-time-line/)
[![Platform](https://img.shields.io/badge/macOS-13%2B-1D1D1F?style=flat-square)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6.0-F05138?style=flat-square)](https://swift.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-34C759?style=flat-square)](LICENSE)

[访问项目官网](https://lxx-003.github.io/input-time-line/) &nbsp;&middot;&nbsp; [核心特性](#核心特性) &nbsp;&middot;&nbsp; [系统架构](#系统架构) &nbsp;&middot;&nbsp; [快速开始](#快速开始) &nbsp;&middot;&nbsp; [AI 复盘技能](#ai-复盘技能analyze-input-timeline)

<sub>Swift 6 + SwiftUI + AppKit 原生构建 &nbsp;&middot;&nbsp; 100% 本地离线存储 &nbsp;&middot;&nbsp; 零网络请求与遥测</sub>

</div>

---

> [!IMPORTANT]
> **隐私与权限原则**：InputTimeline 仅通过 `ApplicationServices` 的 **`CGEvent` listen-only tap**（只读监听）接收按键事件，不拦截也不修改任何输入；所有记录仅保存在本机 `~/Library/Application Support/InputTimeline/`，不发起任何网络请求。系统密码框等安全输入域（Secure Input）在开启期间不会被系统分发给监听端。

---

## 核心特性

### 采集与上下文分段
- [x] **键盘静默自动分段** — 捕获连续按键并按静默间隔合并为完整输入段，间隔可在设置中调节 `1–10 秒`（默认 `2 秒`）
- [x] **前台应用感知** — 通过 `NSWorkspace` 读取当前应用名称与图标，切换前台窗口时自动拆分为新段落
- [x] **剪贴板流转记录** — 识别 `⌘C` 复制与 `⌘V` 粘贴快捷键并读取 `NSPasteboard` 文本快照

### 原生时间线交互体验
- [x] **三色语义时间线** — 主界面采用 `NavigationSplitView` 极简布局，以蓝（键盘）、橙（复制）、绿（粘贴）圆点区隔事件类型
- [x] **历史按日浏览与筛选** — 侧栏按「最近 / 近 7 天 / 更早」分组，支持 `全部 / 键盘 / 复制 / 粘贴` 分段切换与关键词、应用名实时检索
- [x] **控制字符可视化与全文检视** — 超长内容支持弹窗查看完整原文，一键切换 `\b→⌫`、`\r→↩`、`\n→↵`、`\t→→`、`ESC→⎋` 控制符可视化并复制原文
- [x] **MenuBarExtra 与开机自启** — 菜单栏实时展示采集状态与当日记录条数，支持随时暂停/恢复及系统登录项开机自启（默认开启）

### 开放数据与 AI 协作
- [x] **按日结构化 JSON 落盘** — 每日独立 JSON 文件，支持一键呼出系统 `NSSavePanel` 导出备份
- [x] **内置 `analyze-input-timeline` 技能** — 仓库自带解析与分块脚本，可直接让 AI Agent 总结你任意一天的输入轨迹与工作模式

---

## 系统架构

![InputTimeline 系统架构](docs/inputtimeline-architecture.png)

<details>
<summary>查看技术栈与模块职责</summary>

| 层级 | 组件 / API | 职责说明 |
|------|-----------|----------|
| 系统能力层 | `CGEvent` listen-only tap | 只读监听全局 `keyDown` 与 `⌘C` / `⌘V`，无需辅助功能拦截权限 |
| 系统能力层 | `NSWorkspace` / `NSPasteboard` | 获取前台应用名与图标、读取系统剪贴板纯文本 |
| 应用核心 | `KeyboardMonitor` / `AppModel` | 事件回调分发、搜索防抖、分页加载与导出编排（`@MainActor`） |
| 持久化 | `TimelineStore` (`actor`) | 按静默间隔合并段并原子化写入按日 JSON 文件 |
| 原生界面 | `ContentView` / `MenuBarExtra` / `SettingsView` | SwiftUI + AppKit 主窗口时间线、菜单栏控制与分组偏好设置 |
| AI 辅助 | `parse_timeline.py` / `chunk_timeline.py` | 控制符清洗、长文本截断与大数据量并行分块 |

</details>

---

## 快速开始

### 环境要求
- **macOS 13.0+**
- **Xcode / Swift 6**（Swift Package Manager）

### 本地构建与运行

```bash
git clone https://github.com/lxx-003/input-time-line.git
cd input-time-line/InputTimeline

# 编译并打包已签名的 Release 应用（产物位于 InputTimeline/dist/InputTimeline.app）
./scripts/build-app.sh

# 直接打开应用（若尚未构建会自动先执行 build-app.sh）
./scripts/open-app.sh
```

<details>
<summary>其他构建选项与权限排查</summary>

```bash
# 切换 Debug 构建
CONFIGURATION=debug ./scripts/build-app.sh

# 仅编译可执行文件（不打包 .app）
swift build -c release

# 从母图重新生成 AppIcon.icns
./scripts/rebuild-icon.sh
```

- **首次授权**：启动后需在「系统设置 → 隐私与安全性 → 输入监控」中允许 `InputTimeline`，切回应用即可自动开始采集（或点击提示栏「重检」）。
- **重编译后监听未建立**：本地重新编译会导致签名变更，请在系统设置「输入监控」中移除旧的 `InputTimeline` 条目后重新添加并勾选。
- **开机自启说明**：登录项需将 `.app` 移入「应用程序」目录；若未自动生效，可在「系统设置 → 通用 → 登录项」中手动允许。

</details>

---

## 数据格式

每日记录保存在 `~/Library/Application Support/InputTimeline/<YYYY-MM-DD>.json`：

```json
{
  "date": "2026-11-13",
  "silenceGapSeconds": 2,
  "items": [
    {
      "kind": "键盘",
      "start": "2026-11-13 10:00:00",
      "end": "2026-11-13 10:00:05",
      "appName": "Cursor",
      "text": "func fetchTimeline()\r"
    },
    {
      "kind": "复制",
      "at": "2026-11-13 10:01:00",
      "text": "copied text"
    },
    {
      "kind": "粘贴",
      "at": "2026-11-13 10:01:03",
      "text": "pasted text"
    }
  ]
}
```

| 字段 | 说明 |
|------|------|
| `kind` | 事件类型：`键盘` / `复制` / `粘贴` |
| `start` / `end` | 键盘输入段的起止时间（仅 `kind = 键盘`） |
| `at` | 复制 / 粘贴事件发生时间点（仅 `kind = 复制 / 粘贴`） |
| `appName` | 发生输入时的前台应用名称（通常存在于 `kind = 键盘` 条目） |
| `text` | 原始文本内容（键盘记录中保留 `\b`、`\r`、`\n`、`\t`、`ESC` 等控制符） |

---

## AI 复盘技能：`analyze-input-timeline`

仓库内置 Agent 技能（位于 `.cursor/skills/analyze-input-timeline/`），用于让 AI 读取任意指定日期的本地输入记录并生成工作复盘。

### 对话触发
在支持 Skills 的 AI 工具中直接提问并指定具体日期（`YYYY-MM-DD`）：
- *"分析我 2026-11-13 的 InputTimeline 输入记录"*
- *"查看 2026-11-12 的输入记录，总结我昨天做了什么"*

### 独立运行命令行脚本

```bash
# 1. 检查当日数据量并判断是否需要分块（默认超过 200,000 字符自动分块）
python3 .cursor/skills/analyze-input-timeline/scripts/chunk_timeline.py 2026-11-13

# 2. 按时间线清洗控制符并输出摘要（默认超过 200 字符截断，首尾各保留 80 字符）
python3 .cursor/skills/analyze-input-timeline/scripts/parse_timeline.py 2026-11-13

# 自定义截断参数
python3 .cursor/skills/analyze-input-timeline/scripts/parse_timeline.py 2026-11-13 --max-chars 300 --keep 100
```

如需迁移到其他 AI 工具（如 Claude Code），将 `analyze-input-timeline/` 目录整体复制到目标工具的 skills 目录（如 `~/.claude/skills/`）即可，无需保留 `.cursor` 路径前缀。

---

## 项目结构

```text
input_time_line/
├── docs/
│   ├── index.html                           # GitHub Pages 官网落地页
│   ├── assets/icon_master.png               # 官网引用应用图标
│   └── inputtimeline-architecture.png       # 系统架构图
├── .cursor/skills/analyze-input-timeline/   # 内置 AI 分析技能（含 parse / chunk 脚本）
└── InputTimeline/
    ├── Package.swift                        # Swift 6 SPM 包定义
    ├── Sources/InputTimeline/
    │   ├── InputTimelineApp.swift           # @main 入口、AppDelegate 与 MenuBarExtra
    │   ├── AppModel.swift                   # 状态管理、分页加载与业务编排
    │   ├── ContentView.swift                # 主窗口 NavigationSplitView 界面
    │   ├── TimelineCardView.swift           # 单条时间线记录渲染与复制/全文操作
    │   ├── TimelineDetailSheet.swift        # 长文本检视弹窗与控制符切换
    │   ├── TimelineFormatters.swift         # 日期分组、耗时格式化与控制符富文本
    │   ├── TimelineModels.swift             # DailyTimeline / TimelineItem 数据模型
    │   ├── TimelineStore.swift              # Actor 并发落盘与按日 JSON 读写
    │   ├── KeyboardMonitor.swift            # CGEvent listen-only tap 监听与 ⌘C/⌘V 识别
    │   ├── AppIconProvider.swift            # 前台应用图标缓存读取
    │   ├── PermissionHelper.swift           # 输入监控权限检测与系统设置跳转
    │   ├── LaunchAtLoginManager.swift       # 登录项 / 开机自启动管理
    │   ├── RecordingPreference.swift        # 记录开关偏好（默认开启）
    │   ├── SettingsView.swift               # 分组偏好设置（1–10s 静默间隔调节）
    │   └── ThinScrollbarModifier.swift      # 细滚动条样式修饰器
    ├── Support/
    │   ├── Info.plist
    │   ├── AppIcon.icns
    │   └── icon_master.png
    └── scripts/
        ├── build-app.sh                     # 编译打包并签名 .app
        ├── open-app.sh                      # 自动构建并启动应用
        └── rebuild-icon.sh                  # 从母图重新生成 .icns
```

---

<div align="center">

[MIT License](LICENSE) &copy; xinhuang.liu

</div>
