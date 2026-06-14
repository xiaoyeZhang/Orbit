#!/usr/bin/env python3
"""生成 App 图标（1024x1024）：紫粉渐变背景 + 白色定位针。纯标准库，无需 Pillow。"""
import zlib, struct, math, os

W = H = 1024
OUT = os.path.join(os.path.dirname(__file__), "..", "Jagat", "Resources",
                   "Assets.xcassets", "AppIcon.appiconset", "AppIcon1024.png")

# 渐变端点（紫 -> 粉）
C1 = (0x6C, 0x5C, 0xE7)
C2 = (0xFD, 0x79, 0xA8)

# 定位针几何
CX, CY, R = 512, 430, 250        # 头部圆
TX, TY = 512, 884               # 底部尖
K = int(R * 0.84)               # 三角顶边半宽
HOLE_CX, HOLE_CY, HOLE_R = 512, 408, 100  # 针孔


def lerp(a, b, t):
    return int(a + (b - a) * t)


def in_circle(x, y, cx, cy, r):
    return (x - cx) ** 2 + (y - cy) ** 2 <= r * r


def in_triangle(x, y, ax, ay, bx, by, cx, cy):
    def sign(x1, y1, x2, y2, x3, y3):
        return (x1 - x3) * (y2 - y3) - (x2 - x3) * (y1 - y3)
    d1 = sign(x, y, ax, ay, bx, by)
    d2 = sign(x, y, bx, by, cx, cy)
    d3 = sign(x, y, cx, cy, ax, ay)
    has_neg = (d1 < 0) or (d2 < 0) or (d3 < 0)
    has_pos = (d1 > 0) or (d2 > 0) or (d3 > 0)
    return not (has_neg and has_pos)


def pin(x, y):
    if in_circle(x, y, HOLE_CX, HOLE_CY, HOLE_R):
        return False
    if in_circle(x, y, CX, CY, R):
        return True
    return in_triangle(x, y, CX - K, CY, CX + K, CY, TX, TY)


raw = bytearray()
for y in range(H):
    raw.append(0)  # filter type 0
    for x in range(W):
        t = (x + y) / (W + H)
        bg = (lerp(C1[0], C2[0], t), lerp(C1[1], C2[1], t), lerp(C1[2], C2[2], t))
        if pin(x, y):
            raw += b"\xff\xff\xff"
        else:
            raw += bytes(bg)

compressed = zlib.compress(bytes(raw), 9)


def chunk(typ, data):
    return (struct.pack(">I", len(data)) + typ + data +
            struct.pack(">I", zlib.crc32(typ + data) & 0xffffffff))


with open(OUT, "wb") as f:
    f.write(b"\x89PNG\r\n\x1a\n")
    f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0)))
    f.write(chunk(b"IDAT", compressed))
    f.write(chunk(b"IEND", b""))

print("wrote", os.path.abspath(OUT))
