#!/usr/bin/env python3
"""
解析 InputTimeline JSON 文件，输出可读的时间线文本。
用法：
  python3 parse_timeline.py <YYYY-MM-DD> [--max-chars 200] [--keep 80]
  python3 parse_timeline.py --from-file /path/to/chunk.json [--max-chars 200] [--keep 80]
"""

import json
import sys
import os
import argparse
from datetime import datetime

DATA_DIR = os.path.expanduser("~/Library/Application Support/InputTimeline")

CTRL_MAP = {
    "\b": "⌫",
    "\r": "↩",
    "\n": "↵",
    "\t": "→",
    "\x1b": "⎋",
    "\x1d": "⌃]",
}


def replace_ctrl(text: str) -> str:
    for ch, sym in CTRL_MAP.items():
        text = text.replace(ch, sym)
    return text


def truncate(text: str, max_chars: int, keep: int) -> str:
    if len(text) <= max_chars:
        return text
    return f"{text[:keep]}…（共 {len(text)} 字符）…{text[-keep:]}"


def fmt_time(ts: str) -> str:
    """取时间戳中的 HH:MM 部分"""
    try:
        return datetime.strptime(ts, "%Y-%m-%d %H:%M:%S").strftime("%H:%M")
    except Exception:
        return ts


def duration_seconds(start: str, end: str) -> int:
    try:
        s = datetime.strptime(start, "%Y-%m-%d %H:%M:%S")
        e = datetime.strptime(end, "%Y-%m-%d %H:%M:%S")
        return max(0, int((e - s).total_seconds()))
    except Exception:
        return 0


def main():
    parser = argparse.ArgumentParser(description="解析 InputTimeline 日记录")
    parser.add_argument("date", nargs="?", help="日期，格式 YYYY-MM-DD（与 --from-file 二选一）")
    parser.add_argument("--from-file", metavar="PATH", help="直接指定分块 JSON 文件路径（由 chunk_timeline.py 生成）")
    parser.add_argument("--max-chars", type=int, default=200, help="触发截断的字符数阈值（默认 200）")
    parser.add_argument("--keep", type=int, default=80, help="首尾各保留的字符数（默认 80）")
    args = parser.parse_args()

    if args.from_file:
        # 从分块文件读取
        path = args.from_file
        if not os.path.exists(path):
            print(f"❌ 分块文件不存在：{path}")
            sys.exit(1)
    elif args.date:
        path = os.path.join(DATA_DIR, f"{args.date}.json")
        if not os.path.exists(path):
            available = sorted(
                f.replace(".json", "")
                for f in os.listdir(DATA_DIR)
                if f.endswith(".json")
            )
            print(f"❌ 文件不存在：{path}")
            if available:
                print(f"可用日期：{', '.join(available)}")
            sys.exit(1)
    else:
        print("❌ 请提供日期参数或 --from-file 路径")
        parser.print_help()
        sys.exit(1)

    with open(path, encoding="utf-8") as f:
        data = json.load(f)

    items = data.get("items", [])
    for item in items:
        text = item.get("text", "")
        if text:
            item["text"] = truncate(text, args.max_chars, args.keep)

    date = data.get("date", args.date)

    # 统计
    kb_items = [i for i in items if i.get("kind") == "键盘"]
    copy_items = [i for i in items if i.get("kind") == "复制"]
    paste_items = [i for i in items if i.get("kind") == "粘贴"]

    kb_seconds = sum(duration_seconds(i.get("start", ""), i.get("end", "")) for i in kb_items)

    all_times = []
    for i in items:
        for key in ("at", "start", "end"):
            if key in i:
                all_times.append(i[key])
    all_times.sort()
    active_range = f"{fmt_time(all_times[0])} — {fmt_time(all_times[-1])}" if all_times else "—"

    segment_info = data.get("_segment")
    segment_header = ""
    if segment_info:
        segment_header = f"（第 {segment_info['index']}/{segment_info['total']} 段，{segment_info['time_range']}）"

    # 按 app 统计事件数
    app_counter: dict = {}
    for i in items:
        app = i.get("appName") or "（未知）"
        app_counter[app] = app_counter.get(app, 0) + 1
    app_summary = "、".join(
        f"{a}({n})" for a, n in sorted(app_counter.items(), key=lambda x: -x[1])
    )

    lines = []
    lines.append(f"# 📅 {date} 输入时间线分析 {segment_header}\n")
    lines.append("## 概览")
    lines.append(f"- 总事件数：{len(items)} 条")
    lines.append(f"- 键盘输入：{len(kb_items)} 条，合计输入时长 {kb_seconds // 60} 分 {kb_seconds % 60} 秒")
    lines.append(f"- 复制：{len(copy_items)} 次")
    lines.append(f"- 粘贴：{len(paste_items)} 次")
    lines.append(f"- 活跃时间段：{active_range}")
    if app_summary:
        lines.append(f"- 涉及应用：{app_summary}")
    lines.append("\n---\n")
    lines.append("## 时间线详情\n")

    for item in items:
        kind = item.get("kind", "未知")
        raw_text = item.get("text", "")
        app_name = item.get("appName") or ""
        app_tag = f" ｜ 🖥 {app_name}" if app_name else ""

        if kind == "键盘":
            start = item.get("start", "")
            end = item.get("end", "")
            secs = duration_seconds(start, end)
            display = replace_ctrl(raw_text)
            lines.append(f"### {fmt_time(start)} — {fmt_time(end)} ｜ ⌨️ 键盘输入{app_tag}")
            lines.append(f"**时长**：{secs} 秒")
            lines.append(f"**内容**：`{display}`")
        else:
            at = item.get("at", "")
            icon = "📋" if kind == "复制" else "📌"
            lines.append(f"### {fmt_time(at)} ｜ {icon} {kind}{app_tag}")
            lines.append(f"**内容**：`{raw_text}`")

        lines.append("\n---\n")

    print("\n".join(lines))


if __name__ == "__main__":
    try:
        main()
    except BrokenPipeError:
        sys.exit(0)
