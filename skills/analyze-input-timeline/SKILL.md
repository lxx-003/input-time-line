---
name: analyze-input-timeline
description: 分析指定日期的 InputTimeline 输入记录数据，读取 ~/Library/Application Support/InputTimeline/<date>.json，按时间线展示键盘输入、复制、粘贴事件，并对超长文本进行截断处理。当用户要求"分析某天的输入记录"、"查看 InputTimeline 数据"、"分析我今天/昨天做了什么"时使用。必须指定具体日期。
---

# 分析 InputTimeline 日记录

## 数据来源

文件路径：`~/Library/Application Support/InputTimeline/<YYYY-MM-DD>.json`

## 数据结构

```json
{
  "date": "2026-04-04",
  "silenceGapSeconds": 30,
  "items": [
    { "kind": "键盘", "start": "...", "end": "...", "text": "..." },
    { "kind": "复制", "at": "...", "text": "..." },
    { "kind": "粘贴", "at": "...", "text": "..." }
  ]
}
```

字段说明：
- `kind`：事件类型，值为 `键盘` / `复制` / `粘贴`
- `start` / `end`：键盘输入的开始和结束时间
- `at`：复制/粘贴事件的时间点
- `text`：原始文本内容（键盘输入包含退格符 `\b`、回车 `\r`、Escape 等控制字符）

## 分析流程

### 第一步：确认日期并读取文件

用户必须提供具体日期（格式 `YYYY-MM-DD`）。使用 Shell 工具读取文件：

```bash
cat ~/Library/Application\ Support/InputTimeline/<YYYY-MM-DD>.json
```

若文件不存在，告知用户并列出可用日期：

```bash
ls ~/Library/Application\ Support/InputTimeline/
```

### 第二步：运行解析脚本

使用 Shell 工具执行脚本，脚本会自动完成控制字符替换和文本截断：

```bash
python3 ~/.cursor/skills/analyze-input-timeline/scripts/parse_timeline.py <YYYY-MM-DD>
```

可选参数：
- `--max-chars N`：超过 N 字符时触发截断（默认 200）
- `--keep N`：首尾各保留 N 字符（默认 80）

示例：
```bash
# 默认截断规则
python3 ~/.cursor/skills/analyze-input-timeline/scripts/parse_timeline.py 2026-04-04

# 自定义截断阈值
python3 ~/.cursor/skills/analyze-input-timeline/scripts/parse_timeline.py 2026-04-04 --max-chars 300 --keep 100
```

脚本处理逻辑：
- 控制字符替换：`\b→⌫`、`\r→↩`、`\n→↵`、`\u001b→⎋`、`\u001d→⌃]`
- 超长文本格式：`前N字符…（共 X 字符）…后N字符`

### 第三步：按时间线汇总分析

脚本输出时间线详情后，基于其内容进行以下分析：

```
## 活动模式分析
[按小时归组，描述用户在各时段主要做什么]

## 关键内容摘要
[提取复制/粘贴中有意义的文本片段，推断用户的工作内容]
```

## 注意事项

- 日期**必须**由用户明确指定，不得自行猜测或默认今天
- 键盘输入文本通常包含控制字符，展示前需替换
- 重复的粘贴内容可合并展示，注明次数
- 对用户的活动进行有价值的推断，例如"在 14:00-16:00 期间大量复制代码片段，可能在进行代码开发"
