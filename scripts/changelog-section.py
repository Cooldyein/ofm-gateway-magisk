#!/usr/bin/env python3
"""从 CHANGELOG.md 里取出指定版本的正文，供 GitHub Actions 生成 Release 说明。

用法：python3 scripts/changelog-section.py 0.4.1 [CHANGELOG.md]
版本段以 `## v0.4.1`（或 `## 0.4.1`）开头，到下一条 `## ` 标题或文件尾为止。
找不到该版本时返回非 0，让工作流明确失败而不是发出一个空正文的 Release。
"""
import re
import sys


def section(text: str, version: str) -> str:
    want = version.lstrip("vV")
    lines = text.splitlines()
    start = None
    for i, line in enumerate(lines):
        m = re.match(r"^##\s+(.+?)\s*$", line)
        if not m:
            continue
        if m.group(1).lstrip("vV").strip() == want:
            start = i + 1
            break
    if start is None:
        return ""
    end = len(lines)
    for j in range(start, len(lines)):
        if re.match(r"^##\s+", lines[j]):
            end = j
            break
    return "\n".join(lines[start:end]).strip()


def main() -> int:
    if len(sys.argv) < 2:
        sys.stderr.write("用法：changelog-section.py <版本> [CHANGELOG 路径]\n")
        return 2
    version = sys.argv[1]
    path = sys.argv[2] if len(sys.argv) > 2 else "CHANGELOG.md"
    with open(path, encoding="utf-8") as f:
        body = section(f.read(), version)
    if not body:
        sys.stderr.write(f"CHANGELOG 里找不到版本 {version} 的段落\n")
        return 1
    sys.stdout.write(body + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
