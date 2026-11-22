"""
Builds D:\\downpour-godot\\assets\\fonts\\LialoQuill.ttf from scratch using Python + fontTools.
100% original commercial-safe broad-nib medieval calligraphic handwritten TrueType font
for FUJIRA STUDIOS / LIALO with complete Czech & Slovak diacritics, digits, and UI symbols.
"""
import math
import pathlib
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import newTable
from fontTools.ttLib.tables._k_e_r_n import KernTable_format_0

ROOT = pathlib.Path(r"D:\downpour-godot")
OUT_TTF = ROOT / "assets" / "fonts" / "LialoQuill.ttf"
SPECIMEN_PNG = pathlib.Path(
    r"C:\Users\arnos\.gemini\antigravity\brain\a20e3f18-d942-46fa-80e3-721c54108b6d\scratch\lialo_quill_specimen.png"
)

UPM = 1000
ASCENT = 900
DESCENT = -260
SLANT = 0.132  # Natural ~7.5 deg rightward quill slant
NIB_ANGLE = math.radians(34.0)


def _eval_cubic(p0, p1, p2, p3, t: float) -> tuple:
    u = 1.0 - t
    x = u*u*u*p0[0] + 3*u*u*t*p1[0] + 3*u*t*t*p2[0] + t*t*t*p3[0]
    y = u*u*u*p0[1] + 3*u*u*t*p1[1] + 3*u*t*t*p2[1] + t*t*t*p3[1]
    return (x, y)


def _sample_path(seg_list: list, steps_per_seg: int = 16) -> list:
    """
    Converts a list of points/segments into a dense smooth spine.
    Each segment item can be:
      - (x, y) tuple -> straight polyline point
      - ('C', p0, p1, p2, p3) -> cubic Bezier segment
      - ('L', p0, p1) -> linear segment
    """
    pts = []
    if all(isinstance(it, (tuple, list)) and len(it) == 2 and isinstance(it[0], (int, float)) for it in seg_list):
        if len(seg_list) == 2:
            p0, p1 = seg_list[0], seg_list[1]
            for i in range(steps_per_seg + 1):
                t = i / steps_per_seg
                pts.append((p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t))
            return pts
        # Subdivide polyline corners gently via Catmull-like midpoint subdivision
        raw = list(seg_list)
        if len(raw) >= 3:
            sub = [raw[0]]
            for i in range(1, len(raw) - 1):
                ax, ay = raw[i - 1]
                bx, by = raw[i]
                cx, cy = raw[i + 1]
                p_in = (ax * 0.25 + bx * 0.75, ay * 0.25 + by * 0.75)
                p_out = (bx * 0.75 + cx * 0.25, by * 0.75 + cy * 0.25)
                sub.append(p_in)
                # Quadratic fillet around corner B
                for k in range(1, 5):
                    t = k / 5.0
                    u = 1.0 - t
                    qx = u*u*p_in[0] + 2*u*t*bx + t*t*p_out[0]
                    qy = u*u*p_in[1] + 2*u*t*by + t*t*p_out[1]
                    sub.append((qx, qy))
                sub.append(p_out)
            sub.append(raw[-1])
            return sub
        return raw

    for it in seg_list:
        tag = it[0]
        if tag == "C":
            _, p0, p1, p2, p3 = it
            for i in range(steps_per_seg + 1):
                if pts and i == 0:
                    continue
                pts.append(_eval_cubic(p0, p1, p2, p3, i / steps_per_seg))
        elif tag == "L":
            _, p0, p1 = it
            for i in range(steps_per_seg + 1):
                if pts and i == 0:
                    continue
                t = i / steps_per_seg
                pts.append((p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t))
    return pts


def _signed_area(poly: list) -> float:
    a = 0.0
    n = len(poly)
    for i in range(n):
        x0, y0 = poly[i]
        x1, y1 = poly[(i + 1) % n]
        a += x0 * y1 - x1 * y0
    return 0.5 * a


def _stroke_to_cw_contour(spine_specs: list, weight: float = 1.0, cap_start: str = "nib", cap_end: str = "nib", slant: float = SLANT, seed: int = 1) -> list:
    """
    Converts a calligraphic quill spine into a closed strictly-clockwise (solid) TrueType contour
    with broad-nib width contrast (~34 deg chisel angle), organic quill taper, and tiny hand tremor.
    """
    pts_raw = _sample_path(spine_specs, steps_per_seg=14)
    # Deduplicate near-identical consecutive points
    pts = [pts_raw[0]]
    for p in pts_raw[1:]:
        if math.hypot(p[0] - pts[-1][0], p[1] - pts[-1][1]) >= 2.2:
            pts.append(p)
    if len(pts) < 2:
        pts = [pts_raw[0], (pts_raw[0][0] + 12.0, pts_raw[0][1] + 12.0)]

    # Apply subtle handwritten quill slant around x-height baseline pivot
    if slant != 0.0:
        pts = [(x + y * slant, y) for (x, y) in pts]

    n = len(pts)
    left_pts = []
    right_pts = []
    base_hw = 38.0 * weight
    min_hw = 15.5 * weight

    for i in range(n):
        t_frac = i / max(1, n - 1)
        p_prev = pts[max(0, i - 1)]
        p_next = pts[min(n - 1, i + 1)]
        tx = p_next[0] - p_prev[0]
        ty = p_next[1] - p_prev[1]
        L = max(1e-4, math.hypot(tx, ty))
        tx /= L
        ty /= L
        nx, ny = -ty, tx

        ang = math.atan2(ty, tx)
        # Broad-nib variation: thickest on vertical strokes (~90 deg), finest along +34 deg hairlines
        nib_factor = abs(math.sin(ang - NIB_ANGLE))
        hw = min_hw + (base_hw - min_hw) * (0.20 + 0.80 * (nib_factor ** 0.72))

        # Taper start / end slightly so quill lifts look hand-penned
        if cap_start == "taper" and t_frac < 0.14:
            hw *= 0.48 + 0.52 * (t_frac / 0.14)
        elif cap_start == "flare" and t_frac < 0.14:
            hw *= 1.18 - 0.18 * (t_frac / 0.14)
        if cap_end == "taper" and t_frac > 0.86:
            hw *= 0.48 + 0.52 * ((1.0 - t_frac) / 0.14)
        elif cap_end == "flare" and t_frac > 0.86:
            hw *= 1.0 + 0.16 * ((t_frac - 0.86) / 0.14)

        # Tiny deterministic organic edge tremor (makes outlines subtly hand-drawn, never mechanical)
        wob_l = math.sin(i * 1.93 + seed * 0.71) * 1.4
        wob_r = math.cos(i * 2.17 + seed * 1.13) * 1.4

        px, py = pts[i]
        left_pts.append((px + nx * (hw + wob_l), py + ny * (hw + wob_l)))
        right_pts.append((px - nx * (hw + wob_r), py - ny * (hw + wob_r)))

    # Chisel-cut end caps at +/- 34 deg for authentic broad-nib terminal shape
    if cap_start == "nib" and n >= 2:
        dx0, dy0 = pts[1][0] - pts[0][0], pts[1][1] - pts[0][1]
        L0 = max(1e-4, math.hypot(dx0, dy0))
        vx, vy = dx0 / L0, dy0 / L0
        shift0 = 14.0 * weight
        left_pts[0] = (left_pts[0][0] - vx * shift0, left_pts[0][1] - vy * shift0)
        right_pts[0] = (right_pts[0][0] + vx * shift0 * 0.45, right_pts[0][1] + vy * shift0 * 0.45)
    if cap_end == "nib" and n >= 2:
        dx1, dy1 = pts[-1][0] - pts[-2][0], pts[-1][1] - pts[-2][1]
        L1 = max(1e-4, math.hypot(dx1, dy1))
        vx, vy = dx1 / L1, dy1 / L1
        shift1 = 14.0 * weight
        left_pts[-1] = (left_pts[-1][0] - vx * shift1 * 0.45, left_pts[-1][1] - vy * shift1 * 0.45)
        right_pts[-1] = (right_pts[-1][0] + vx * shift1, right_pts[-1][1] + vy * shift1)

    poly = left_pts + right_pts[::-1]
    poly_int = [(int(round(x)), int(round(y))) for (x, y) in poly]
    # Remove adjacent duplicate vertices
    clean = [poly_int[0]]
    for pt in poly_int[1:]:
        if pt != clean[-1]:
            clean.append(pt)
    if len(clean) >= 3 and clean[-1] == clean[0]:
        clean.pop()
    if _signed_area(clean) > 0:
        clean.reverse()
    return clean


def _dot_contour(cx: float, cy: float, r: float = 34.0, kind: str = "diamond", slant: float = SLANT) -> list:
    sx = cx + cy * slant
    if kind == "circle":
        pts = [(sx + math.cos(i * math.tau / 14) * r, cy + math.sin(i * math.tau / 14) * r) for i in range(14)]
    elif kind == "ring_outer":
        pts = [(sx + math.cos(i * math.tau / 16) * r, cy + math.sin(i * math.tau / 16) * r) for i in range(16)]
    elif kind == "ring_inner":
        pts = [(sx + math.cos(i * math.tau / 16) * r, cy + math.sin(i * math.tau / 16) * r) for i in range(16)]
        pts = [(int(round(x)), int(round(y))) for x, y in pts]
        if _signed_area(pts) < 0:
            pts.reverse()  # CCW for hole!
        return pts
    else:
        # Calligraphic rotated diamond ink dot
        pts = [(sx, cy + r * 1.15), (sx + r * 0.92, cy), (sx, cy - r * 1.15), (sx - r * 0.92, cy)]
    pts_int = [(int(round(x)), int(round(y))) for x, y in pts]
    if _signed_area(pts_int) > 0:
        pts_int.reverse()
    return pts_int


def _C(p0, p1, p2, p3):
    return ("C", p0, p1, p2, p3)


def _L(p0, p1):
    return ("L", p0, p1)


def _build_base_glyph_specs() -> dict:
    """
    Defines every base glyph as a list of calligraphic stroke specs: (spine_list, weight, cap_start, cap_end).
    X-height = 465, Cap height = 700, Ascenders = 755, Descenders = -225.
    """
    specs = {}

    # Special .notdef & space
    specs[".notdef"] = [([(90, 0), (90, 680), (410, 680), (410, 0), (90, 0)], 0.72, "nib", "nib")]

    # --- LOWERCASE a..z (Medieval Humanist / Bastarda Calligraphic Script) ---
    specs["a"] = [
        ([_C((85, 395), (175, 480), (315, 480), (328, 360)), _C((328, 360), (332, 240), (330, 95), (345, 22)), _L((345, 22), (382, 46))], 0.94, "flare", "taper"),
        ([_C((325, 295), (185, 315), (58, 255), (55, 140)), _C((55, 140), (52, 32), (175, -18), (325, 92))], 0.92, "taper", "nib"),
    ]
    specs["b"] = [
        ([_L((48, 705), (96, 755)), _C((96, 755), (92, 480), (92, 180), (94, 15))], 0.98, "taper", "nib"),
        ([_C((92, 310), (195, 475), (358, 445), (362, 235)), _C((362, 235), (366, 45), (210, -18), (94, 48))], 0.94, "taper", "nib"),
    ]
    specs["c"] = [
        ([_C((335, 395), (275, 480), (88, 455), (72, 235)), _C((72, 235), (56, 22), (242, -22), (348, 86))], 0.95, "nib", "taper"),
    ]
    specs["d"] = [
        # Uncial-curved Bastarda stem ascending up & curling left over the bowl
        ([_C((320, 465), (326, 610), (265, 735), (155, 755))], 0.94, "taper", "flare"),
        ([_L((324, 520), (328, 22)), _L((328, 22), (372, 52))], 0.96, "nib", "taper"),
        ([_C((322, 365), (195, 475), (58, 410), (58, 220)), _C((58, 220), (58, 26), (205, -16), (325, 92))], 0.94, "taper", "nib"),
    ]
    specs["e"] = [
        ([_C((76, 230), (210, 238), (342, 285), (336, 375)), _C((336, 375), (330, 462), (96, 465), (68, 230)), _C((68, 230), (42, 12), (235, -20), (346, 86))], 0.94, "taper", "taper"),
    ]
    specs["f"] = [
        ([_C((318, 695), (272, 765), (168, 755), (156, 560)), _C((156, 560), (144, 300), (144, 25), (126, -155)), _C((126, -155), (110, -225), (58, -225), (36, -185))], 0.96, "flare", "taper"),
        ([_L((48, 426), (288, 444))], 0.78, "taper", "taper"),
    ]
    specs["g"] = [
        ([_C((316, 415), (196, 482), (62, 410), (62, 235)), _C((62, 235), (62, 60), (204, 15), (326, 130))], 0.94, "nib", "taper"),
        ([_L((326, 450), (318, -75)), _C((318, -75), (310, -210), (162, -245), (56, -168))], 0.96, "flare", "taper"),
    ]
    specs["h"] = [
        ([_L((48, 705), (96, 755)), _L((96, 755), (92, 0))], 0.98, "taper", "nib"),
        ([_C((92, 315), (175, 472), (332, 470), (338, 305)), _C((338, 305), (342, 145), (342, 25), (352, 14)), _L((352, 14), (392, 50))], 0.94, "taper", "taper"),
    ]
    specs["i"] = [
        ([_L((48, 412), (96, 456)), _L((96, 456), (96, 22)), _L((96, 22), (142, 54))], 0.96, "taper", "taper"),
        ("DOT", 98, 568, 36.0, "diamond"),
    ]
    specs["j"] = [
        ([_L((56, 412), (108, 456)), _L((108, 456), (104, -105)), _C((104, -105), (98, -210), (26, -238), (-32, -185))], 0.96, "taper", "taper"),
        ("DOT", 110, 568, 36.0, "diamond"),
    ]
    specs["k"] = [
        ([_L((48, 705), (96, 755)), _L((96, 755), (94, 0))], 0.98, "taper", "nib"),
        ([_L((316, 452), (104, 212)), _L((162, 258), (334, 18)), _L((334, 18), (382, 52))], 0.88, "flare", "taper"),
    ]
    specs["l"] = [
        ([_L((48, 705), (98, 755)), _C((98, 755), (96, 440), (96, 120), (104, 20)), _L((104, 20), (154, 56))], 0.98, "taper", "taper"),
    ]
    specs["m"] = [
        ([_L((44, 412), (86, 456)), _L((86, 456), (86, 0))], 0.94, "taper", "nib"),
        ([_C((86, 325), (152, 470), (275, 470), (282, 310)), _L((282, 310), (282, 0))], 0.92, "taper", "nib"),
        ([_C((282, 325), (348, 470), (470, 470), (476, 308)), _L((476, 308), (480, 18)), _L((480, 18), (522, 52))], 0.92, "taper", "taper"),
    ]
    specs["n"] = [
        ([_L((46, 412), (90, 456)), _L((90, 456), (90, 0))], 0.96, "taper", "nib"),
        ([_C((90, 320), (168, 472), (326, 468), (332, 300)), _L((332, 300), (336, 18)), _L((336, 18), (378, 52))], 0.94, "taper", "taper"),
    ]
    specs["o"] = [
        ([_C((242, 462), (92, 455), (56, 320), (56, 220)), _C((56, 220), (56, 86), (132, -10), (255, -8))], 0.94, "nib", "taper"),
        ([_C((225, 462), (368, 445), (390, 305), (386, 215)), _C((386, 215), (380, 82), (305, -12), (235, -8))], 0.94, "taper", "nib"),
    ]
    specs["p"] = [
        ([_L((48, 412), (92, 458)), _L((92, 458), (88, -220))], 0.98, "taper", "nib"),
        ([_C((92, 320), (185, 475), (360, 445), (360, 225)), _C((360, 225), (360, 40), (205, -12), (94, 48))], 0.94, "taper", "nib"),
    ]
    specs["q"] = [
        ([_C((326, 390), (205, 475), (58, 410), (58, 220)), _C((58, 220), (58, 35), (198, -12), (324, 98))], 0.94, "taper", "nib"),
        ([_L((326, 456), (322, -220)), _L((322, -220), (364, -182))], 0.98, "flare", "taper"),
    ]
    specs["r"] = [
        ([_L((48, 412), (92, 456)), _L((92, 456), (92, 0))], 0.96, "taper", "nib"),
        ([_C((92, 305), (146, 445), (254, 472), (305, 420))], 0.92, "taper", "flare"),
    ]
    specs["s"] = [
        ([_C((302, 415), (242, 472), (76, 456), (76, 352)), _C((76, 352), (76, 232), (318, 222), (318, 104)), _C((318, 104), (318, -8), (142, -22), (56, 52))], 0.95, "flare", "taper"),
    ]
    specs["t"] = [
        ([_L((146, 610), (142, 118)), _C((142, 118), (140, 12), (235, -12), (308, 46))], 0.96, "flare", "taper"),
        ([_L((46, 424), (274, 442))], 0.80, "taper", "taper"),
    ]
    specs["u"] = [
        ([_L((44, 415), (86, 456)), _L((86, 456), (86, 138)), _C((86, 138), (86, -12), (246, -12), (326, 125))], 0.94, "taper", "taper"),
        ([_L((326, 452), (328, 20)), _L((328, 20), (374, 52))], 0.96, "nib", "taper"),
    ]
    specs["v"] = [
        ([_L((42, 422), (78, 456)), _L((78, 456), (195, 16)), _C((195, 16), (254, 155), (305, 315), (328, 456))], 0.94, "taper", "flare"),
    ]
    specs["w"] = [
        ([_L((38, 422), (72, 456)), _L((72, 456), (156, 14)), _L((156, 14), (255, 360)), _L((255, 360), (344, 14)), _C((344, 14), (408, 165), (454, 320), (476, 456))], 0.92, "taper", "flare"),
    ]
    specs["x"] = [
        ([_L((58, 448), (326, 8))], 0.96, "flare", "flare"),
        ([_L((312, 448), (54, 8))], 0.82, "taper", "taper"),
    ]
    specs["y"] = [
        ([_L((42, 422), (78, 456)), _L((78, 456), (198, 26))], 0.94, "taper", "taper"),
        ([_C((326, 456), (262, 205), (186, -28), (118, -172)), _C((118, -172), (82, -238), (36, -228), (16, -196))], 0.92, "flare", "taper"),
    ]
    specs["z"] = [
        ([_L((68, 434), (316, 446)), _L((316, 446), (62, 14)), _L((62, 14), (332, 18))], 0.92, "nib", "flare"),
    ]

    # --- UPPERCASE A..Z (Calligraphic Majuscules, Cap Height ~700) ---
    specs["A"] = [
        ([_C((32, 0), (132, 320), (205, 540), (266, 705))], 0.86, "taper", "flare"),
        ([_C((266, 705), (340, 480), (412, 210), (464, 12)), _L((464, 12), (512, 52))], 1.02, "nib", "taper"),
        ([_L((122, 242), (378, 256))], 0.80, "taper", "taper"),
    ]
    specs["B"] = [
        ([_L((56, 682), (108, 708)), _L((108, 708), (106, 0))], 1.04, "taper", "nib"),
        ([_C((106, 688), (288, 718), (382, 620), (374, 515)), _C((374, 515), (364, 412), (235, 368), (112, 368))], 0.96, "taper", "taper"),
        ([_C((112, 368), (306, 378), (422, 268), (412, 146)), _C((412, 146), (402, 28), (242, -8), (94, 8))], 0.98, "taper", "nib"),
    ]
    specs["C"] = [
        ([_C((424, 616), (344, 718), (96, 692), (76, 355)), _C((76, 355), (56, 26), (298, -24), (446, 108))], 1.02, "flare", "taper"),
    ]
    specs["D"] = [
        ([_L((56, 682), (110, 708)), _L((110, 708), (106, 0))], 1.04, "taper", "nib"),
        ([_C((108, 695), (344, 712), (464, 560), (460, 340)), _C((460, 340), (456, 108), (312, -8), (96, 10))], 1.00, "taper", "nib"),
    ]
    specs["E"] = [
        ([_L((102, 702), (98, 0))], 1.04, "nib", "nib"),
        ([_L((98, 694), (398, 708))], 0.90, "taper", "flare"),
        ([_L((102, 362), (326, 372))], 0.80, "taper", "taper"),
        ([_L((98, 10), (414, 18))], 0.92, "taper", "flare"),
    ]
    specs["F"] = [
        ([_L((104, 702), (98, 0))], 1.04, "nib", "nib"),
        ([_L((100, 694), (404, 708))], 0.92, "taper", "flare"),
        ([_L((102, 362), (324, 372))], 0.80, "taper", "taper"),
    ]
    specs["G"] = [
        ([_C((426, 616), (344, 718), (94, 692), (74, 350)), _C((74, 350), (54, 18), (298, -22), (434, 88))], 1.02, "flare", "taper"),
        ([_L((434, 88), (434, 312)), _L((275, 312), (446, 316))], 0.92, "nib", "taper"),
    ]
    specs["H"] = [
        ([_L((54, 682), (104, 708)), _L((104, 708), (102, 0))], 1.04, "taper", "nib"),
        ([_L((392, 708), (396, 14)), _L((396, 14), (444, 52))], 1.02, "nib", "taper"),
        ([_L((104, 360), (394, 372))], 0.82, "taper", "taper"),
    ]
    specs["I"] = [
        ([_L((48, 696), (186, 706))], 0.78, "flare", "flare"),
        ([_L((118, 704), (114, 10))], 1.04, "nib", "nib"),
        ([_L((44, 12), (188, 18))], 0.78, "flare", "flare"),
    ]
    specs["J"] = [
        ([_L((154, 688), (206, 708)), _L((206, 708), (202, -45)), _C((202, -45), (192, -190), (88, -228), (16, -162))], 1.04, "taper", "taper"),
    ]
    specs["K"] = [
        ([_L((56, 682), (106, 708)), _L((106, 708), (102, 0))], 1.04, "taper", "nib"),
        ([_L((402, 696), (116, 336)), _L((198, 412), (416, 16)), _L((416, 16), (464, 52))], 0.94, "flare", "taper"),
    ]
    specs["L"] = [
        ([_L((54, 682), (106, 708)), _L((106, 708), (100, 12)), _L((100, 12), (396, 18))], 1.02, "taper", "flare"),
    ]
    specs["M"] = [
        ([_L((56, 0), (102, 706))], 0.94, "nib", "nib"),
        ([_L((102, 706), (272, 224)), _L((272, 224), (448, 706))], 0.88, "taper", "taper"),
        ([_L((448, 706), (456, 16)), _L((456, 16), (504, 52))], 1.04, "nib", "taper"),
    ]
    specs["N"] = [
        ([_L((56, 0), (104, 706))], 0.96, "nib", "nib"),
        ([_L((104, 706), (398, 8))], 1.00, "taper", "taper"),
        ([_L((398, 8), (402, 706))], 0.96, "taper", "flare"),
    ]
    specs["O"] = [
        ([_C((272, 706), (102, 696), (58, 498), (58, 345)), _C((58, 345), (58, 122), (146, -12), (288, -8))], 1.02, "nib", "taper"),
        ([_C((252, 706), (424, 688), (458, 478), (454, 340)), _C((454, 340), (448, 118), (360, -14), (268, -8))], 1.00, "taper", "nib"),
    ]
    specs["P"] = [
        ([_L((54, 682), (106, 708)), _L((106, 708), (102, 0))], 1.04, "taper", "nib"),
        ([_C((106, 694), (336, 718), (416, 586), (410, 478)), _C((410, 478), (402, 362), (244, 314), (106, 326))], 0.98, "taper", "taper"),
    ]
    specs["Q"] = [
        ([_C((272, 706), (102, 696), (58, 498), (58, 345)), _C((58, 345), (58, 122), (146, -12), (288, -8))], 1.02, "nib", "taper"),
        ([_C((252, 706), (424, 688), (458, 478), (454, 340)), _C((454, 340), (448, 118), (360, -14), (268, -8))], 1.00, "taper", "nib"),
        ([_C((275, 112), (355, 22), (432, -88), (506, -116))], 0.92, "taper", "flare"),
    ]
    specs["R"] = [
        ([_L((54, 682), (106, 708)), _L((106, 708), (102, 0))], 1.04, "taper", "nib"),
        ([_C((106, 694), (328, 718), (404, 594), (398, 488)), _C((398, 488), (392, 382), (240, 336), (112, 344))], 0.98, "taper", "taper"),
        ([_L((218, 344), (418, 14)), _L((418, 14), (468, 48))], 0.98, "taper", "taper"),
    ]
    specs["S"] = [
        ([_C((386, 622), (318, 718), (82, 694), (82, 540)), _C((82, 540), (82, 355), (414, 336), (414, 152)), _C((414, 152), (414, -14), (156, -24), (62, 72))], 1.02, "flare", "taper"),
    ]
    specs["T"] = [
        ([_L((36, 690), (436, 708))], 0.94, "flare", "flare"),
        ([_L((234, 698), (228, 0))], 1.04, "nib", "nib"),
    ]
    specs["U"] = [
        ([_L((54, 682), (102, 706)), _L((102, 706), (100, 185)), _C((100, 185), (100, -14), (314, -18), (408, 158))], 1.02, "taper", "taper"),
        ([_L((408, 706), (412, 16)), _L((412, 16), (458, 52))], 1.00, "nib", "taper"),
    ]
    specs["V"] = [
        ([_L((38, 682), (82, 706)), _L((82, 706), (236, 10)), _C((236, 10), (318, 224), (382, 464), (424, 706))], 1.00, "taper", "flare"),
    ]
    specs["W"] = [
        ([_L((36, 682), (76, 706)), _L((76, 706), (176, 12)), _L((176, 12), (298, 528)), _L((298, 528), (412, 12)), _C((412, 12), (484, 240), (544, 468), (582, 706))], 0.96, "taper", "flare"),
    ]
    specs["X"] = [
        ([_L((68, 704), (414, 8))], 1.02, "flare", "flare"),
        ([_L((404, 704), (64, 8))], 0.88, "taper", "taper"),
    ]
    specs["Y"] = [
        ([_L((46, 684), (86, 706)), _L((86, 706), (236, 336)), _L((416, 706), (236, 336)), _L((236, 336), (232, 0))], 1.00, "taper", "nib"),
    ]
    specs["Z"] = [
        ([_L((68, 694), (418, 708)), _L((418, 708), (64, 14)), _L((64, 14), (434, 18))], 0.98, "nib", "flare"),
    ]

    # --- CALLIGRAPHIC DIGITS 0..9 ---
    specs["0"] = [
        ([_C((234, 678), (94, 668), (58, 488), (58, 335)), _C((58, 335), (58, 118), (132, -10), (248, -6))], 0.96, "nib", "taper"),
        ([_C((216, 678), (356, 662), (386, 472), (382, 330)), _C((382, 330), (376, 115), (304, -10), (232, -6))], 0.96, "taper", "nib"),
    ]
    specs["1"] = [
        ([_L((98, 542), (224, 676)), _L((224, 676), (220, 6))], 0.98, "taper", "nib"),
        ([_L((124, 6), (326, 8))], 0.78, "taper", "flare"),
    ]
    specs["2"] = [
        ([_C((76, 548), (144, 686), (344, 686), (348, 505)), _C((348, 505), (352, 342), (174, 178), (64, 12)), _L((64, 12), (378, 16))], 0.96, "taper", "flare"),
    ]
    specs["3"] = [
        ([_C((78, 576), (168, 688), (342, 666), (340, 526)), _C((340, 526), (338, 412), (238, 366), (146, 358))], 0.94, "taper", "taper"),
        ([_C((146, 358), (288, 362), (374, 266), (368, 148)), _C((368, 148), (362, 18), (194, -18), (68, 54))], 0.96, "taper", "taper"),
    ]
    specs["4"] = [
        ([_L((276, 676), (54, 212)), _L((54, 212), (394, 216))], 0.86, "taper", "flare"),
        ([_L((288, 676), (286, 0))], 0.98, "nib", "nib"),
    ]
    specs["5"] = [
        ([_L((336, 664), (108, 660)), _L((108, 660), (96, 384)), _C((96, 384), (242, 418), (364, 330), (360, 178)), _C((360, 178), (356, 20), (196, -18), (66, 56))], 0.96, "flare", "taper"),
    ]
    specs["6"] = [
        ([_C((324, 654), (186, 688), (68, 522), (68, 256)), _C((68, 256), (68, 36), (176, -12), (296, 22)), _C((296, 22), (382, 54), (374, 246), (264, 298)), _C((264, 298), (174, 336), (92, 272), (76, 176))], 0.96, "flare", "taper"),
    ]
    specs["7"] = [
        ([_L((68, 658), (362, 674)), _C((362, 674), (292, 466), (214, 224), (146, 0))], 0.96, "nib", "nib"),
        ([_L((154, 326), (314, 334))], 0.72, "taper", "taper"),
    ]
    specs["8"] = [
        ([_C((222, 674), (96, 664), (72, 530), (146, 424)), _C((146, 424), (232, 310), (374, 258), (368, 126)), _C((368, 126), (362, 8), (222, -16), (124, 26))], 0.96, "taper", "taper"),
        ([_C((222, 674), (344, 654), (352, 522), (272, 422)), _C((272, 422), (182, 312), (62, 248), (68, 118)), _C((68, 118), (72, 16), (154, -14), (228, -4))], 0.92, "taper", "nib"),
    ]
    specs["9"] = [
        ([_C((326, 448), (294, 646), (182, 688), (98, 616)), _C((98, 616), (38, 558), (58, 376), (168, 336)), _C((168, 336), (258, 304), (324, 368), (334, 462))], 0.94, "taper", "taper"),
        ([_C((334, 578), (324, 322), (242, 82), (114, -4))], 0.96, "nib", "taper"),
    ]

    # --- PUNCTUATION & GAME SYMBOLS ---
    specs["space"] = []
    specs["nbspace"] = []
    specs["period"] = [("DOT", 94, 44, 42.0, "diamond")]
    specs["comma"] = [([_C((104, 72), (112, -18), (74, -104), (28, -142))], 0.88, "flare", "taper")]
    specs["exclam"] = [([_L((98, 698), (90, 214))], 0.94, "flare", "taper"), ("DOT", 90, 44, 42.0, "diamond")]
    specs["question"] = [
        ([_C((74, 576), (126, 698), (324, 694), (324, 536)), _C((324, 536), (324, 412), (166, 360), (164, 214))], 0.95, "taper", "taper"),
        ("DOT", 162, 44, 42.0, "diamond"),
    ]
    specs["colon"] = [("DOT", 94, 358, 38.0, "diamond"), ("DOT", 94, 44, 38.0, "diamond")]
    specs["semicolon"] = [("DOT", 96, 358, 38.0, "diamond"), ([_C((104, 72), (112, -18), (74, -104), (28, -142))], 0.88, "flare", "taper")]
    specs["hyphen"] = [([_L((48, 256), (252, 266))], 0.86, "taper", "taper")]
    specs["endash"] = [([_L((44, 256), (382, 266))], 0.86, "taper", "taper")]
    specs["emdash"] = [([_L((36, 256), (596, 268))], 0.86, "taper", "taper")]
    specs["quotesingle"] = [([_C((88, 688), (94, 594), (74, 514), (48, 476))], 0.82, "flare", "taper")]
    specs["quotedbl"] = [
        ([_C((74, 688), (80, 594), (60, 514), (38, 476))], 0.78, "flare", "taper"),
        ([_C((188, 688), (194, 594), (174, 514), (152, 476))], 0.78, "flare", "taper"),
    ]
    specs["quotedblbase"] = [
        ([_C((74, 96), (80, 12), (56, -68), (28, -104))], 0.78, "flare", "taper"),
        ([_C((188, 96), (194, 12), (170, -68), (142, -104))], 0.78, "flare", "taper"),
    ]
    specs["quotedblleft"] = [
        ([_C((108, 688), (76, 616), (62, 542), (88, 476))], 0.78, "taper", "flare"),
        ([_C((222, 688), (190, 616), (176, 542), (202, 476))], 0.78, "taper", "flare"),
    ]
    specs["parenleft"] = [([_C((208, 722), (82, 526), (82, 146), (206, -158))], 0.86, "taper", "taper")]
    specs["parenright"] = [([_C((64, 722), (192, 526), (192, 146), (66, -158))], 0.86, "taper", "taper")]
    specs["bracketleft"] = [([_L((212, 718), (96, 718)), _L((96, 718), (96, -148)), _L((96, -148), (212, -148))], 0.82, "nib", "nib")]
    specs["bracketright"] = [([_L((68, 718), (186, 718)), _L((186, 718), (186, -148)), _L((186, -148), (68, -148))], 0.82, "nib", "nib")]
    specs["slash"] = [([_L((36, -118), (308, 716))], 0.88, "taper", "taper")]
    specs["backslash"] = [([_L((56, 716), (318, -118))], 0.88, "taper", "taper")]
    specs["plus"] = [([_L((56, 272), (384, 282))], 0.84, "taper", "taper"), ([_L((222, 436), (218, 114))], 0.84, "taper", "taper")]
    specs["multiply"] = [([_L((66, 412), (324, 142))], 0.84, "taper", "taper"), ([_L((324, 412), (66, 142))], 0.84, "taper", "taper")]
    specs["equal"] = [([_L((58, 344), (376, 352))], 0.82, "taper", "taper"), ([_L((58, 202), (376, 210))], 0.82, "taper", "taper")]
    specs["asterisk"] = [
        ([_L((166, 668), (166, 424))], 0.72, "taper", "taper"),
        ([_L((62, 608), (270, 486))], 0.72, "taper", "taper"),
        ([_L((270, 608), (62, 486))], 0.72, "taper", "taper"),
    ]
    specs["percent"] = [
        ([_L((78, 16), (376, 676))], 0.86, "taper", "taper"),
        ("DOT", 128, 578, 62.0, "circle"),
        ("DOT", 328, 128, 62.0, "circle"),
    ]
    specs["ampersand"] = [
        ([_C((386, 14), (234, 198), (94, 424), (112, 578)), _C((112, 578), (126, 686), (276, 686), (288, 574)), _C((288, 574), (298, 456), (78, 304), (68, 146)), _C((68, 146), (62, 16), (242, -16), (398, 178))], 0.92, "flare", "taper"),
    ]
    specs["bullet"] = [("DOT", 142, 268, 72.0, "circle")]
    specs["guilsinglright"] = [([_L((68, 422), (218, 256)), _L((218, 256), (68, 86))], 0.86, "taper", "taper")]
    specs["guilsinglleft"] = [([_L((218, 422), (68, 256)), _L((68, 256), (218, 86))], 0.86, "taper", "taper")]
    specs["triagright"] = [([_L((78, 476), (328, 268)), _L((328, 268), (78, 56)), _L((78, 56), (78, 476))], 0.90, "nib", "nib")]
    specs["triagleft"] = [([_L((328, 476), (78, 268)), _L((78, 268), (328, 56)), _L((328, 56), (328, 476))], 0.90, "nib", "nib")]
    specs["star"] = [
        ([_L((240, 620), (140, 260)), _L((140, 260), (420, 480)), _L((420, 480), (60, 480)), _L((60, 480), (340, 260)), _L((340, 260), (240, 620))], 0.82, "nib", "nib"),
    ]
    specs["fourstar"] = [
        ([_L((230, 650), (230, 120))], 0.88, "taper", "taper"),
        ([_L((30, 385), (430, 385))], 0.88, "taper", "taper"),
        ([_L((130, 490), (330, 280))], 0.62, "taper", "taper"),
        ([_L((330, 490), (130, 280))], 0.62, "taper", "taper"),
    ]
    specs["ballotx"] = [([_L((72, 598), (392, 124))], 0.94, "flare", "flare"), ([_L((392, 598), (72, 124))], 0.86, "taper", "taper")]
    specs["checkmark"] = [([_L((56, 264), (186, 62)), _C((186, 62), (274, 240), (366, 444), (476, 646))], 0.96, "taper", "taper")]
    specs["underscore"] = [([_L((32, -88), (416, -82))], 0.78, "taper", "taper")]
    specs["tilde"] = [([_C((68, 286), (138, 366), (218, 212), (298, 294))], 0.78, "taper", "taper")]
    specs["numbersign"] = [
        ([_L((104, 624), (72, 40))], 0.80, "taper", "taper"),
        ([_L((276, 624), (244, 40))], 0.80, "taper", "taper"),
        ([_L((48, 412), (324, 422))], 0.76, "taper", "taper"),
        ([_L((32, 232), (308, 242))], 0.76, "taper", "taper"),
    ]
    return specs


def _diacritic_strokes(mark: str, cx: float, by: float, is_upper: bool = False) -> list:
    s = []
    if mark == "acute":
        s.append(([_L((cx - 26, by + 24), (cx + 76, by + 132))], 0.82, "taper", "flare"))
    elif mark == "caron":
        s.append(([_L((cx - 72, by + 124), (cx + 4, by + 28)), _L((cx + 4, by + 28), (cx + 84, by + 128))], 0.80, "flare", "taper"))
    elif mark == "d_caron":
        # Classic Czech handwritten apostrophe-hook to the right of ascender!
        s.append(([_C((cx + 22, by + 72), (cx + 42, by + 4), (cx + 12, by - 66), (cx - 16, by - 92))], 0.78, "flare", "taper"))
    elif mark == "ring":
        # Open calligraphic ring (2 overlapping CW arcs or outer CW + inner CCW circle)
        r_out = 58.0 if not is_upper else 54.0
        r_in = 24.0 if not is_upper else 22.0
        s.append(("DOT", cx, by + 68, r_out, "ring_outer"))
        s.append(("DOT", cx, by + 68, r_in, "ring_inner"))
    elif mark == "dieresis":
        s.append(("DOT", cx - 54, by + 56, 32.0, "diamond"))
        s.append(("DOT", cx + 54, by + 56, 32.0, "diamond"))
    elif mark == "circumflex":
        s.append(([_L((cx - 72, by + 32), (cx + 2, by + 126)), _L((cx + 2, by + 126), (cx + 78, by + 30))], 0.78, "taper", "taper"))
    return s


UNICODE_TO_GLYPH = {
    0x0020: "space",
    0x00A0: "nbspace",
    0x002E: "period",
    0x002C: "comma",
    0x0021: "exclam",
    0x003F: "question",
    0x003A: "colon",
    0x003B: "semicolon",
    0x002D: "hyphen",
    0x2013: "endash",
    0x2014: "emdash",
    0x0027: "quotesingle",
    0x2019: "quotesingle",
    0x2018: "quotesingle",
    0x0022: "quotedbl",
    0x201E: "quotedblbase",
    0x201A: "comma",
    0x201C: "quotedblleft",
    0x201D: "quotedblleft",
    0x0028: "parenleft",
    0x0029: "parenright",
    0x005B: "bracketleft",
    0x005D: "bracketright",
    0x002F: "slash",
    0x005C: "backslash",
    0x002B: "plus",
    0x00D7: "multiply",
    0x003D: "equal",
    0x002A: "asterisk",
    0x0025: "percent",
    0x0026: "ampersand",
    0x2022: "bullet",
    0x203A: "guilsinglright",
    0x2039: "guilsinglleft",
    0x25B8: "triagright",
    0x25C2: "triagleft",
    0x2605: "star",
    0x2726: "fourstar",
    0x2715: "ballotx",
    0x2713: "checkmark",
    0x005F: "underscore",
    0x007E: "tilde",
    0x0023: "numbersign",
}

ACCENTED_DEFS = [
    # (codepoint, glyph_name, base_char, mark_kind, cx_override, by_override, is_upper)
    (0x00C1, "Aacute", "A", "acute", 252, 730, True),
    (0x010C, "Ccaron", "C", "caron", 255, 730, True),
    (0x010E, "Dcaron", "D", "caron", 248, 730, True),
    (0x00C9, "Eacute", "E", "acute", 242, 730, True),
    (0x011A, "Ecaron", "E", "caron", 242, 730, True),
    (0x00CD, "Iacute", "I", "acute", 125, 730, True),
    (0x0147, "Ncaron", "N", "caron", 245, 730, True),
    (0x00D3, "Oacute", "O", "acute", 256, 730, True),
    (0x0158, "Rcaron", "R", "caron", 244, 730, True),
    (0x0160, "Scaron", "S", "caron", 232, 730, True),
    (0x0164, "Tcaron", "T", "caron", 236, 730, True),
    (0x00DA, "Uacute", "U", "acute", 256, 730, True),
    (0x016E, "Uring",  "U", "ring",  256, 734, True),
    (0x00DD, "Yacute", "Y", "acute", 238, 730, True),
    (0x017D, "Zcaron", "Z", "caron", 244, 730, True),
    (0x00C4, "Adieresis", "A", "dieresis", 252, 730, True),
    (0x00D6, "Odieresis", "O", "dieresis", 256, 730, True),
    (0x00DC, "Udieresis", "U", "dieresis", 256, 730, True),
    (0x00D4, "Ocircumflex", "O", "circumflex", 256, 730, True),
    (0x0139, "Lacute", "L", "acute", 148, 730, True),
    (0x013D, "Lcaron", "L", "d_caron", 240, 695, True),
    (0x0154, "Racute", "R", "acute", 244, 730, True),

    (0x00E1, "aacute", "a", "acute", 198, 504, False),
    (0x010D, "ccaron", "c", "caron", 204, 504, False),
    (0x010F, "dcaron", "d", "d_caron", 365, 704, False),
    (0x00E9, "eacute", "e", "acute", 202, 504, False),
    (0x011B, "ecaron", "e", "caron", 202, 504, False),
    (0x00ED, "iacute", "i", "acute", 104, 514, False),
    (0x0148, "ncaron", "n", "caron", 208, 504, False),
    (0x00F3, "oacute", "o", "acute", 218, 504, False),
    (0x0159, "rcaron", "r", "caron", 196, 504, False),
    (0x0161, "scaron", "s", "caron", 196, 504, False),
    (0x0165, "tcaron", "t", "d_caron", 276, 672, False),
    (0x00FA, "uacute", "u", "acute", 206, 504, False),
    (0x016F, "uring",  "u", "ring",  206, 510, False),
    (0x00FD, "yacute", "y", "acute", 196, 504, False),
    (0x017E, "zcaron", "z", "caron", 196, 504, False),
    (0x00E4, "adieresis", "a", "dieresis", 198, 504, False),
    (0x00F6, "odieresis", "o", "dieresis", 218, 504, False),
    (0x00FC, "udieresis", "u", "dieresis", 206, 504, False),
    (0x00F4, "ocircumflex", "o", "circumflex", 218, 504, False),
    (0x013A, "lacute", "l", "acute", 136, 750, False),
    (0x013E, "lcaron", "l", "d_caron", 232, 706, False),
    (0x0155, "racute", "r", "acute", 196, 504, False),
]


def _render_strokes_to_contours(stroke_items: list, seed_base: int) -> list:
    contours = []
    for si, item in enumerate(stroke_items):
        if isinstance(item, tuple) and item[0] == "DOT":
            _, cx, cy, rad, kind = item
            contours.append(_dot_contour(cx, cy, rad, kind))
        else:
            spine, weight, c0, c1 = item
            contours.append(_stroke_to_cw_contour(spine, weight=weight, cap_start=c0, cap_end=c1, seed=seed_base + si * 7))
    return contours


def build_font() -> None:
    OUT_TTF.parent.mkdir(parents=True, exist_ok=True)
    specs = _build_base_glyph_specs()
    cmap = dict(UNICODE_TO_GLYPH)

    for ch in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789":
        cmap[ord(ch)] = ch

    for cp, gname, base_ch, mark, cx, by, is_up in ACCENTED_DEFS:
        cmap[cp] = gname
        base_items = list(specs[base_ch])
        if base_ch == "i":
            # Replace dot on i cleanly with accent
            base_items = [it for it in base_items if not (isinstance(it, tuple) and it[0] == "DOT")]
        base_items.extend(_diacritic_strokes(mark, cx, by, is_up))
        specs[gname] = base_items

    glyph_order = [".notdef", "space", "nbspace"]
    for g in specs.keys():
        if g not in glyph_order:
            glyph_order.append(g)

    glyphs = {}
    metrics = {}
    SIDE_BEARINGS = {
        "space": (0, 265),
        "nbspace": (0, 265),
        "period": (50, 220),
        "comma": (50, 220),
        "exclam": (55, 250),
        "colon": (50, 230),
        "semicolon": (50, 230),
        "i": (42, 238),
        "l": (42, 252),
        "j": (48, 250),
        "I": (38, 286),
        "emdash": (28, 650),
        "endash": (30, 440),
        "hyphen": (35, 315),
    }

    for gi, gname in enumerate(glyph_order):
        stroke_items = specs.get(gname, [])
        pen = TTGlyphPen(None)
        if not stroke_items:
            glyphs[gname] = pen.glyph()
            lsb, adv = SIDE_BEARINGS.get(gname, (0, 265))
            metrics[gname] = (adv, lsb)
            continue

        contours = _render_strokes_to_contours(stroke_items, seed_base=100 + gi * 13)
        all_xs = [pt[0] for c in contours for pt in c]
        xmin = min(all_xs)
        lsb_target = 36 if gname.islower() else 42
        if gname in SIDE_BEARINGS:
            lsb_target, fixed_adv = SIDE_BEARINGS[gname]
        else:
            fixed_adv = None

        shift_x = lsb_target - xmin
        shifted_contours = []
        for c in contours:
            sc = [(x + shift_x, y) for (x, y) in c]
            shifted_contours.append(sc)
            pen.moveTo(sc[0])
            for pt in sc[1:]:
                pen.lineTo(pt)
            pen.closePath()

        glyph = pen.glyph()
        glyphs[gname] = glyph
        s_xmin = min(pt[0] for c in shifted_contours for pt in c)
        s_xmax = max(pt[0] for c in shifted_contours for pt in c)
        rsb = 34 if gname.islower() else 42
        if gname in ("tcaron", "dcaron", "lcaron"):
            rsb = 18
        adv = fixed_adv if fixed_adv is not None else max(180, s_xmax + rsb)
        metrics[gname] = (adv, s_xmin)

    fb = FontBuilder(UPM, isTTF=True)
    fb.setupGlyphOrder(glyph_order)
    fb.setupCharacterMap(cmap)
    fb.setupGlyf(glyphs)
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=ASCENT, descent=DESCENT)

    fb.setupNameTable({
        "copyright": "Copyright (c) 2026 Fujira Studios. Original commercial font created for LIALO.",
        "familyName": "Lialo Quill",
        "styleName": "Regular",
        "uniqueFontIdentifier": "FujiraStudios-LialoQuill-1.0",
        "fullName": "Lialo Quill Regular",
        "version": "Version 1.000",
        "psName": "LialoQuill-Regular",
        "licenseDescription": "Proprietary commercial license owned exclusively by Fujira Studios.",
    })
    fb.setupOS2(
        sTypoAscender=ASCENT,
        sTypoDescender=DESCENT,
        sTypoLineGap=60,
        usWinAscent=ASCENT + 20,
        usWinDescent=abs(DESCENT) + 20,
        sxHeight=465,
        sCapHeight=700,
    )
    fb.setupPost(italicAngle=-7.5)

    kern_pairs = {
        ("T", "a"): -48, ("T", "e"): -48, ("T", "o"): -52, ("T", "a"): -48, ("T", "u"): -40,
        ("V", "a"): -46, ("V", "e"): -44, ("V", "o"): -46, ("V", "period"): -65,
        ("W", "a"): -38, ("W", "e"): -36, ("W", "o"): -38,
        ("P", "a"): -44, ("P", "e"): -40, ("P", "o"): -44, ("P", "period"): -65,
        ("F", "a"): -44, ("F", "e"): -42, ("F", "o"): -44,
        ("A", "v"): -36, ("A", "y"): -36, ("A", "w"): -32,
        ("L", "V"): -44, ("L", "T"): -44, ("L", "Y"): -48,
        ("r", "period"): -45, ("r", "comma"): -45, ("v", "period"): -42, ("y", "period"): -42,
    }
    valid_kern = {k: v for k, v in kern_pairs.items() if k[0] in glyph_order and k[1] in glyph_order}
    kern_tbl = newTable("kern")
    kern_tbl.version = 0
    kern_sub = KernTable_format_0(0)
    kern_sub.coverage = 1
    kern_sub.format = 0
    kern_sub.kernTable = valid_kern
    kern_tbl.kernTables = [kern_sub]
    fb.font["kern"] = kern_tbl

    fb.save(str(OUT_TTF))
    print(f"Built original commercial font: {OUT_TTF} ({len(glyph_order)} glyphs, {len(cmap)} codepoints)")


def render_specimen() -> None:
    SPECIMEN_PNG.parent.mkdir(parents=True, exist_ok=True)
    img = Image.new("RGB", (1420, 860), (242, 232, 208))
    d = ImageDraw.Draw(img)
    ink = (28, 18, 11)
    accent = (128, 34, 24)

    f44 = ImageFont.truetype(str(OUT_TTF), 44)
    f32 = ImageFont.truetype(str(OUT_TTF), 32)
    f24 = ImageFont.truetype(str(OUT_TTF), 24)

    d.rectangle((18, 18, 1402, 842), outline=(92, 64, 38), width=3)
    d.text((42, 34), "LialoQuill.ttf — Originální středověký rukopis (Fujira Studios)", font=f32, fill=accent)
    d.text((42, 92), "Čau! Vítej v LIALU — hospodské Prší se silami karet.", font=f44, fill=ink)
    d.text((42, 166), "Příliš žluťoučký kůň úpěl ďábelské ódy! 1234567890", font=f32, fill=ink)
    d.text((42, 224), "ÚKOL: Zahraj Sedmičku (+2) nebo Krále! [SPACE] ★ ✦ ✕ ✓", font=f32, fill=ink)
    d.text((42, 290), "ABCDEFGHIJKLMNOPQRSTUVWXYZ", font=f32, fill=ink)
    d.text((42, 344), "abcdefghijklmnopqrstuvwxyz", font=f32, fill=ink)
    d.text((42, 400), "ÁČĎÉĚÍŇÓŘŠŤÚŮÝŽ  •  áčďéěíňóřšťúůýž  •  ÄÖÜÔĽĹŔ äöüôľĺŕ", font=f32, fill=accent)
    d.text((42, 470), "Výborně! Teď máš v ruce karty 7, 8, 9, 10, Spodka, Svrška, Krále a Eso.", font=f24, fill=ink)
    d.text((42, 514), "Když zahraješ Sedmičku (7), soupeř si musí líznout +2 karty — ledaže přebije!", font=f24, fill=ink)
    d.text((42, 558), "Dvě Osmičky v jednom tahu spustí řetězové kombo (+3× násobič) — zkus to!", font=f24, fill=ink)
    d.text((42, 608), "„Síla krčmy spočívá v pevném zápěstí a moudré sázce.“ — Duch hospodského", font=f24, fill=accent)
    d.text((42, 668), "0123456789   .,!?:;-–—'\"„“()[]/+×*%&•›‹▸◂★✦✕✓", font=f32, fill=ink)

    img.save(SPECIMEN_PNG, "PNG")
    print(f"Saved font specimen: {SPECIMEN_PNG}")


if __name__ == "__main__":
    build_font()
    render_specimen()
