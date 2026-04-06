---
name: analyze-input-timeline
description: 分析指定日期的 InputTimeline 输入记录数据，读取 ~/Library/Application Support/InputTimeline/<date>.json，按时间线展示键盘输入、复制、粘贴事件，并对超长文本进行截断处理。支持大数据量自动分块 + subagent 并行分析汇总。当用户要求"分析某天的输入记录"、"查看 InputTimeline 数据"、"分析我今天/昨天做了什么"时使用。必须指定具体日期。
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
    { "kind": "键盘", "start": "...", "end": "...", "appName": "Cursor", "text": "..." },
    { "kind": "复制", "at": "...", "appName": "Safari", "text": "..." },
    { "kind": "粘贴", "at": "...", "appName": "Cursor", "text": "..." }
  ]
}
```

字段说明：
- `kind`：事件类型，值为 `键盘` / `复制` / `粘贴`
- `start` / `end`：键盘输入的开始和结束时间
- `at`：复制/粘贴事件的时间点
- `appName`：发生事件时的前台应用名称（可选，旧数据可能不含此字段）
- `text`：原始文本内容（键盘输入包含退格符 `\b`、回车 `\r`、Escape 等控制字符）

---

## 分析流程

### 第一步：确认日期并检查文件

用户必须提供具体日期（格式 `YYYY-MM-DD`）。若文件不存在，列出可用日期：

```bash
ls ~/Library/Application\ Support/InputTimeline/
```

### 第二步：预处理 + 检查数据量（决定是否分块）

运行分块检查脚本（`$SKILL_ROOT` 为本技能根目录）：

```bash
python3 "$SKILL_ROOT/scripts/chunk_timeline.py" <YYYY-MM-DD>
```

此脚本是整个流程的**入口**，执行顺序：
1. 加载原始数据
2. **预处理**（`preprocess_items`）：截断所有超长文本
3. 基于已截断数据计算统计和分块判断

输出 JSON 包含 `stats` 字段（基于预处理后数据）：

```json
{
  "stats": {
    "total_items": 520,
    "keyboard": 380,
    "copy": 60,
    "paste": 80,
    "active_range": "2026-04-04 09:12 — 2026-04-04 23:45",
    "app_distribution": { "Cursor": 210, "Safari": 95, "..." : "..." }
  },
  "needs_chunking": false
}
```

查看输出中的 `needs_chunking` 字段：

- **`false`** → 数据量小，走 **[路径 A：直接分析]**
- **`true`** → 数据量大，走 **[路径 B：分块并行分析]**

可选参数：
- `--threshold N`：自定义触发分块的字符数阈值（默认 200000）
- `--segments N`：强制拆分为 N 段（默认自动计算）
- `--max-chars N`：超过 N 字符的文本触发截断（默认 200）
- `--keep N`：截断时首尾各保留 N 字符（默认 80）

---

## 路径 A：直接分析（数据量小）

运行解析脚本并直接分析：

```bash
python3 "$SKILL_ROOT/scripts/parse_timeline.py" <YYYY-MM-DD>
```

可选参数：
- `--max-chars N`：超过 N 字符时触发截断（默认 200）
- `--keep N`：首尾各保留 N 字符（默认 80）

脚本输出时间线详情后，进入 **[第四步：汇总分析]**。

---

## 路径 B：分块并行 subagent 分析（数据量大）

### 第三步：并行启动 subagent 逐段分析

从 `chunk_timeline.py` 的输出中读取 `segment_files` 数组，**同时**（parallel）为每个分段启动一个 subagent（使用 Task 工具），每个 subagent 的任务描述如下：

> 任务：分析 InputTimeline 第 X/N 段数据
>
> 请执行：
> ```bash
> python3 "$SKILL_ROOT/scripts/parse_timeline.py" --from-file "<segment_path>"
> ```
> 然后根据输出，撰写该时段的活动摘要，格式为：
>
> ```
> ## 第 X/N 段摘要（<time_range>）
>
> ### 主要活动
> [按时间顺序描述用户在该时段的主要行为，2-5 条]
>
> ### 关键内容
> [提取有意义的文本片段，推断工作内容]
> ```
>
> 仅返回上述摘要，不需要输出完整时间线。

**并行度**：所有分段同时启动，不要等待前一个完成。

### 第四步：汇总所有分段结果

收集所有 subagent 返回的摘要后，整合为完整的日活动报告：

```
# 📅 <date> 完整活动报告

## 全天概览
[总结当天的整体工作模式和主要成就，3-5 句话]

## 应用使用分布
[列出各应用的事件数，推断在哪些工具上花了多少时间]

## 活动模式分析
[按时段（上午/下午/晚上）归纳用户主要做了什么，结合 appName 说明切换规律]

## 各时段详情
[拼接所有分段摘要]

## 关键洞察
[提炼 2-3 条有价值的推断，例如专注时段、应用切换频率、工作内容规律等]
```

---

## 注意事项

- 日期**必须**由用户明确指定，不得自行猜测或默认今天
- 超长文本截断在 `chunk_timeline.py` 的 `preprocess_items` 中最先执行，后续所有统计、分块估算、输出展示均基于已截断的数据
- 分块文件带有 `_preprocessed: true` 标记，`parse_timeline.py` 读取后不会重复截断
- 键盘输入文本通常包含控制字符，展示前需替换（脚本已自动处理）
- 重复的粘贴内容可合并展示，注明次数
- 对用户的活动进行有价值的推断，例如"在 14:00-16:00 期间大量复制代码片段，可能在进行代码开发"
- 分块分析完毕后，临时文件存放在 `/tmp/input_timeline_chunks_*`，无需手动清理
