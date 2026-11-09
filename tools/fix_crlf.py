"""把指定文件统一成 CRLF 行尾（仓库约定）。

只处理"整文件重写"过的文件，避免把仓库里原本的 LF/LF 混排改乱。

用法: python tools/fix_crlf.py a.gd b.gd
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    for rel in sys.argv[1:]:
        p = Path(rel) if Path(rel).is_absolute() else ROOT / rel
        data = p.read_bytes()
        # 先统一成 LF，再全部换成 CRLF（幂等）
        data = data.replace(b"\r\n", b"\n").replace(b"\n", b"\r\n")
        p.write_bytes(data)
        crlf = data.count(b"\r\n")
        print(f"{rel}: {crlf} CRLF")


if __name__ == "__main__":
    main()
