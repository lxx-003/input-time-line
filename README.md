# InputTimeline

macOS 本地输入记录工具。通过监听键盘事件和剪贴板操作，将每日输入活动保存为结构化 JSON，供后续回顾与分析。

## 功能

- **键盘输入记录** — 捕获普通按键，按静默间隔（默认 2 秒，可调 1–10 秒）自动合并为连续输入段
- **复制 / 粘贴捕获** — 识别 ⌘C / ⌘V 并读取剪贴板文本
- **按日存储** — 每天一个 JSON 文件，路径 `~/Library/Application Support/InputTimeline/<YYYY-MM-DD>.json`
- **历史浏览** — 侧栏选择日期，查看当天时间线
- **JSON 导出** — 通过 NSSavePanel 导出所选日期的记录文件
- **权限引导** — 检测 Input Monitoring 授权状态，可一键跳转系统设置

## 技术栈

| 项目 | 说明 |
|------|------|
| 语言 | Swift 6 |
| 包管理 | Swift Package Manager |
| 平台 | macOS 13+ |
| UI | SwiftUI + AppKit |
| 输入监听 | `ApplicationServices` CGEvent listen-only tap |

## 项目结构

```
InputTimeline/
├── Package.swift
├── Sources/InputTimeline/
│   ├── InputTimelineApp.swift      # @main 入口 + AppDelegate
│   ├── AppModel.swift              # 状态与业务编排
│   ├── ContentView.swift           # SwiftUI 界面
│   ├── KeyboardMonitor.swift       # CGEvent 输入监听
│   ├── PermissionHelper.swift      # 权限检测与请求
│   ├── TimelineModels.swift        # 数据模型
│   └── TimelineStore.swift         # 按日落盘与持久化
├── Support/
│   ├── Info.plist
│   ├── AppIcon.icns
│   └── icon_master.png             # 图标母图
├── scripts/
│   ├── build-app.sh                # 构建 .app 并签名
│   ├── open-app.sh                 # 构建并打开应用
│   └── rebuild-icon.sh             # 从母图重新生成 icns
└── dist/                           # 构建产物（git 忽略）

skills/analyze-input-timeline/
├── SKILL.md                        # AI 技能定义
└── scripts/
    └── parse_timeline.py           # 时间线解析脚本
```

## 构建与运行

```bash
cd InputTimeline

# 构建 .app（默认 release）
./scripts/build-app.sh

# 构建并打开
./scripts/open-app.sh

# 仅编译
swift build -c release
```

构建产物位于 `InputTimeline/dist/InputTimeline.app`。可通过 `CONFIGURATION=debug` 环境变量切换为 debug 构建。

首次运行需在「系统设置 → 隐私与安全性 → 输入监控」中授权 InputTimeline。

## 数据格式

```json
{
  "date": "2026-04-04",
  "silenceGapSeconds": 2,
  "items": [
    { "kind": "键盘", "start": "2026-04-04 10:00:00", "end": "2026-04-04 10:00:05", "text": "hello" },
    { "kind": "复制", "at": "2026-04-04 10:01:00", "text": "copied text" },
    { "kind": "粘贴", "at": "2026-04-04 10:01:03", "text": "pasted text" }
  ]
}
```

| 字段 | 说明 |
|------|------|
| `kind` | 事件类型：`键盘` / `复制` / `粘贴` |
| `start` / `end` | 键盘输入的起止时间 |
| `at` | 复制/粘贴的时间点 |
| `text` | 原始文本（键盘输入可能包含 `\b`、`\r` 等控制字符） |

## AI 技能：analyze-input-timeline

配套的 Cursor Agent 技能，用于分析指定日期的输入记录。

**触发方式：** 告诉 AI「分析我某天的输入记录」或「查看 InputTimeline 数据」，并指定日期。

**工作流程：**

1. 读取 `~/Library/Application Support/InputTimeline/<YYYY-MM-DD>.json`
2. 运行 `parse_timeline.py` 将控制字符替换为可读符号（`\b→⌫`、`\r→↩`、`\n→↵`、`\t→→`、`ESC→⎋`），并截断超长文本
3. 按时间线输出概览与详情，分析活动模式与关键内容

**解析脚本可独立使用：**

```bash
# 默认：超过 200 字符截断，首尾各保留 80 字符
python3 skills/analyze-input-timeline/scripts/parse_timeline.py 2026-04-04

# 自定义截断参数
python3 skills/analyze-input-timeline/scripts/parse_timeline.py 2026-04-04 --max-chars 300 --keep 100
```
