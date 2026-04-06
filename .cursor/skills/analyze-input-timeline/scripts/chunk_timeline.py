#!/usr/bin/env python3
"""
检查 InputTimeline JSON 文件大小，超过阈值则拆分为多个分段文件。
用法：python3 chunk_timeline.py <YYYY-MM-DD> [--threshold 80000] [--segments N]
输出：JSON 格式，包含是否需要分块、各分段文件路径和时间范围。
"""

import json
import sys
import os
import argparse
import tempfile

DATA_DIR = os.path.expanduser("~/Library/Application Support/InputTimeline")


def truncate_text(text: str, max_chars: int, keep: int) -> str:
    if len(text) <= max_chars:
        return text
    return f"{text[:keep]}…（共 {len(text)} 字符）…{text[-keep:]}"


def preprocess_items(items: list, max_chars: int, keep: int) -> list:
    """预处理：在任何计算/分块之前截断超长文本"""
    for item in items:
        text = item.get("text", "")
        if text:
            item["text"] = truncate_text(text, max_chars, keep)
    return items


def estimate_size(items: list) -> int:
    """粗略估算解析后输出的字符数（文本长度 + 固定格式开销）"""
    total = 0
    for item in items:
        total += len(item.get("text", ""))
        total += 150
    return total


def item_time(item: dict) -> str:
    """取事件的排序时间键"""
    return item.get("at") or item.get("start") or item.get("end") or ""


def main():
    parser = argparse.ArgumentParser(description="检查并拆分 InputTimeline 数据")
    parser.add_argument("date", help="日期，格式 YYYY-MM-DD")
    parser.add_argument(
        "--threshold",
        type=int,
        default=200000,
        help="触发分块的估算字符数阈值（默认 200000，约 6.5 万 token）",
    )
    parser.add_argument(
        "--segments",
        type=int,
        default=0,
        help="强制拆分为 N 段（0 = 按阈值自动计算）",
    )
    parser.add_argument(
        "--max-chars",
        type=int,
        default=200,
        help="超过此字符数的文本触发截断（默认 200）",
    )
    parser.add_argument(
        "--keep",
        type=int,
        default=80,
        help="截断时首尾各保留的字符数（默认 80）",
    )
    args = parser.parse_args()

    path = os.path.join(DATA_DIR, f"{args.date}.json")
    if not os.path.exists(path):
        print(json.dumps({"error": f"文件不存在: {path}"}, ensure_ascii=False))
        sys.exit(1)

    with open(path, encoding="utf-8") as f:
        data = json.load(f)

    items = data.get("items", [])
    preprocess_items(items, args.max_chars, args.keep)
    estimated = estimate_size(items)

    result: dict = {
        "date": args.date,
        "total_items": len(items),
        "estimated_chars": estimated,
        "threshold": args.threshold,
        "needs_chunking": estimated > args.threshold,
    }

    if not result["needs_chunking"]:
        result["segments"] = 1
        result["message"] = "数据量在阈值内，无需分块，直接运行 parse_timeline.py"
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return

    # 计算分段数
    n = args.segments if args.segments > 0 else max(2, (estimated // args.threshold) + 1)
    chunk_size = (len(items) + n - 1) // n

    tmp_dir = tempfile.mkdtemp(prefix="input_timeline_chunks_")
    segment_files = []

    for i in range(n):
        chunk_items = items[i * chunk_size : (i + 1) * chunk_size]
        if not chunk_items:
            continue

        # 计算时间范围
        times = sorted(filter(None, (item_time(it) for it in chunk_items)))
        time_range = f"{times[0][:16]} — {times[-1][:16]}" if times else "—"

        chunk_data = {
            "date": args.date,
            "silenceGapSeconds": data.get("silenceGapSeconds", 30),
            "items": chunk_items,
            "_segment": {"index": i + 1, "total": n, "time_range": time_range},
        }

        out_path = os.path.join(tmp_dir, f"chunk_{i + 1}_of_{n}.json")
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(chunk_data, f, ensure_ascii=False)

        segment_files.append(
            {
                "index": i + 1,
                "path": out_path,
                "items": len(chunk_items),
                "time_range": time_range,
                "estimated_chars": estimate_size(chunk_items),
            }
        )

    result["segments"] = len(segment_files)
    result["segment_files"] = segment_files
    result["tmp_dir"] = tmp_dir
    result["message"] = f"已拆分为 {len(segment_files)} 段，临时文件存放于 {tmp_dir}"
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
