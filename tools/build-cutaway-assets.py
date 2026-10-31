#!/usr/bin/env python3
"""
Deterministic Geometry-Authoritative 2D Asset Builder for Behind the Lanterns.
Reads `dev/art/building_fixture_spec.json`, projects 3D architectural geometry
through the locked fixed elevated 3/4 oblique orthographic projection
(pixel_x = x - origin_x, pixel_y = y - z - origin_y, NOT true isometric),
stylizes into readable pixel-art passes, and writes PNG assets + manifest JSON
into `dev/art/cutaway_fixture/`.

Zero external runtime dependencies (pure Python 3 standard library `zlib`/`struct`).
"""
from __future__ import annotations

import json
import math
import struct
import zlib
from pathlib import Path


def parse_hex_color(hex_str: str, alpha: int = 255) -> tuple[int, int, int, int]:
    s = hex_str.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), alpha)


class Canvas:
    def __init__(self, width: int, height: int) -> None:
        self.width = width
        self.height = height
        self.buf = bytearray(width * height * 4)

    def set_px(self, x: int, y: int, color: tuple[int, int, int, int]) -> None:
        if x < 0 or y < 0 or x >= self.width or y >= self.height:
            return
        idx = (y * self.width + x) * 4
        sr, sg, sb, sa = color
        if sa >= 255 or self.buf[idx + 3] == 0:
            self.buf[idx] = sr
            self.buf[idx + 1] = sg
            self.buf[idx + 2] = sb
            self.buf[idx + 3] = sa
        elif sa > 0:
            da = self.buf[idx + 3]
            inv = 255 - sa
            out_a = sa + (da * inv) // 255
            if out_a > 0:
                self.buf[idx] = (sr * sa + self.buf[idx] * inv) // out_a
                self.buf[idx + 1] = (sg * sa + self.buf[idx + 1] * inv) // out_a
                self.buf[idx + 2] = (sb * sa + self.buf[idx + 2] * inv) // out_a
                self.buf[idx + 3] = out_a

    def fill_rect(self, x: int, y: int, w: int, h: int, color: tuple[int, int, int, int]) -> None:
        x0 = max(0, x)
        y0 = max(0, y)
        x1 = min(self.width, x + w)
        y1 = min(self.height, y + h)
        if x0 >= x1 or y0 >= y1:
            return
        for py in range(y0, y1):
            for px in range(x0, x1):
                self.set_px(px, py, color)

    def stroke_rect(self, x: int, y: int, w: int, h: int, color: tuple[int, int, int, int], thickness: int = 1) -> None:
        self.fill_rect(x, y, w, thickness, color)
        self.fill_rect(x, y + h - thickness, w, thickness, color)
        self.fill_rect(x, y, thickness, h, color)
        self.fill_rect(x + w - thickness, y, thickness, h, color)

    def fill_circle(self, cx: int, cy: int, r: int, color: tuple[int, int, int, int]) -> None:
        r2 = r * r
        for py in range(cy - r, cy + r + 1):
            for px in range(cx - r, cx + r + 1):
                if (px - cx) ** 2 + (py - cy) ** 2 <= r2:
                    self.set_px(px, py, color)

    def to_png_bytes(self) -> bytes:
        raw_rows = bytearray()
        stride = self.width * 4
        for y in range(self.height):
            raw_rows.append(0)  # Filter type 0 (None)
            start = y * stride
            raw_rows.extend(self.buf[start : start + stride])

        def chunk(tag: bytes, data: bytes) -> bytes:
            crc = zlib.crc32(tag + data) & 0xFFFFFFFF
            return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)

        ihdr = struct.pack(">IIBBBBB", self.width, self.height, 8, 6, 0, 0, 0)
        idat = zlib.compress(bytes(raw_rows), level=9)
        return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", idat) + chunk(b"IEND", b"")

    def save_png(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(self.to_png_bytes())


def project(wx: float, wy: float, wz: float, ox: float, oy: float) -> tuple[int, int]:
    """Fixed elevated 3/4 oblique orthographic projection (non-isometric)."""
    return (int(round(wx - ox)), int(round(wy - wz - oy)))


def draw_oblique_box(
    canvas: Canvas,
    ox: float,
    oy: float,
    bx: float,
    by: float,
    bz: float,
    bw: float,
    bh: float,
    bd: float,
    top_color: tuple[int, int, int, int],
    front_color: tuple[int, int, int, int],
    border_color: tuple[int, int, int, int],
) -> None:
    """
    Projects a 3D axis-aligned box [bx, bx+bw] x [by, by+bh] x [bz, bz+bd]
    into the 3/4 oblique view:
    - Top face at z = bz + bd spans (bx..bx+bw, by - (bz+bd) .. by+bh - (bz+bd))
    - Front (south) face at y = by + bh spans (bx..bx+bw, by+bh - (bz+bd) .. by+bh - bz)
    """
    tx, ty = project(bx, by, bz + bd, ox, oy)
    tw, th = int(round(bw)), int(round(bh))
    canvas.fill_rect(tx, ty, tw, th, top_color)
    canvas.stroke_rect(tx, ty, tw, th, border_color, 1)

    if bd > 0:
        fx, fy = project(bx, by + bh, bz + bd, ox, oy)
        fw, fh = int(round(bw)), int(round(bd))
        canvas.fill_rect(fx, fy, fw, fh, front_color)
        canvas.stroke_rect(fx, fy, fw, fh, border_color, 1)


def draw_masonry_courses(
    canvas: Canvas,
    x0: int,
    y0: int,
    w: int,
    h: int,
    mortar: tuple[int, int, int, int],
    brick_alt: tuple[int, int, int, int],
    course_h: int = 8,
    brick_w: int = 24,
) -> None:
    for row_idx, py in enumerate(range(y0, y0 + h, course_h)):
        canvas.fill_rect(x0, py, w, 1, mortar)
        offset = (brick_w // 2) if (row_idx % 2 == 1) else 0
        for px in range(x0 + offset, x0 + w, brick_w):
            canvas.fill_rect(px, py, 1, min(course_h, y0 + h - py), mortar)
            if ((px // brick_w + row_idx) % 3 == 0) and px + 2 < x0 + w and py + 2 < y0 + h:
                canvas.fill_rect(
                    px + 2,
                    py + 2,
                    min(brick_w - 3, x0 + w - px - 2),
                    min(course_h - 3, y0 + h - py - 2),
                    brick_alt,
                )


def draw_mashrabiya_window(
    canvas: Canvas,
    ox: float,
    oy: float,
    wx: float,
    wy: float,
    wz_bottom: float,
    wz_top: float,
    width: float,
    timber: tuple[int, int, int, int],
    timber_dark: tuple[int, int, int, int],
    glow: tuple[int, int, int, int],
) -> None:
    px, py = project(wx, wy, wz_top, ox, oy)
    w = int(round(width))
    h = int(round(wz_top - wz_bottom))
    canvas.fill_rect(px, py, w, h, timber_dark)
    canvas.stroke_rect(px, py, w, h, timber, 2)
    # Lattice grid
    for gx in range(px + 4, px + w - 2, 6):
        canvas.fill_rect(gx, py + 2, 2, h - 4, timber)
    for gy in range(py + 4, py + h - 2, 5):
        canvas.fill_rect(px + 2, gy, w - 4, 1, timber)
    # Warm interior lantern glow through lattice bays
    for gx in range(px + 6, px + w - 4, 6):
        for gy in range(py + 5, py + h - 3, 5):
            canvas.fill_rect(gx, gy, 2, 2, glow)


def build_shell_layer(spec: dict, ox: float, oy: float, cw: int, ch: int) -> Canvas:
    c = Canvas(cw, ch)
    fp = spec["footprint"]
    t = spec["wall_thickness"]
    h = spec["floors"][0]["wall_height"]
    pal = spec["palette"]
    stone_light = parse_hex_color(pal["limestone_light"])
    stone_mid = parse_hex_color(pal["limestone_mid"])
    stone_dark = parse_hex_color(pal["limestone_dark"])
    mortar = parse_hex_color(pal["mortar_line"])
    shadow = parse_hex_color("#0c1618", 95)

    # Ground drop shadow around building footprint
    sx, sy = project(fp["x"] - 4, fp["y"] - 2, 0, ox, oy)
    c.fill_rect(sx, sy, fp["width"] + 12, fp["height"] + 10, shadow)

    # Outer stone plinth at z = 0
    px, py = project(fp["x"] - 2, fp["y"] - 2, 0, ox, oy)
    c.fill_rect(px, py, fp["width"] + 4, fp["height"] + 4, stone_dark)
    c.stroke_rect(px, py, fp["width"] + 4, fp["height"] + 4, mortar, 2)

    # North wall (back wall)
    draw_oblique_box(c, ox, oy, fp["x"], fp["y"], 0, fp["width"], t, h, stone_light, stone_mid, mortar)
    nfx, nfy = project(fp["x"], fp["y"] + t, h, ox, oy)
    draw_masonry_courses(c, nfx + 2, nfy + 2, fp["width"] - 4, h - 4, mortar, stone_dark)

    # West wall
    draw_oblique_box(c, ox, oy, fp["x"], fp["y"], 0, t, fp["height"], h, stone_light, stone_mid, mortar)
    # East wall
    draw_oblique_box(
        c, ox, oy, fp["x"] + fp["width"] - t, fp["y"], 0, t, fp["height"], h, stone_light, stone_mid, mortar
    )

    # Corner buttress piers
    for bx in (fp["x"], fp["x"] + fp["width"] - 16):
        for by in (fp["y"], fp["y"] + fp["height"] - 16):
            draw_oblique_box(c, ox, oy, bx, by, 0, 16, 16, h + 2, stone_light, stone_dark, mortar)
    return c


def build_interior_layer(spec: dict, ox: float, oy: float, cw: int, ch: int) -> Canvas:
    c = Canvas(cw, ch)
    fp = spec["footprint"]
    t = spec["wall_thickness"]
    h = spec["floors"][0]["wall_height"]
    pal = spec["palette"]
    plaster = parse_hex_color(pal["plaster_warm"])
    plaster_sh = parse_hex_color(pal["plaster_shadow"])
    mortar = parse_hex_color(pal["mortar_line"])
    timber = parse_hex_color(pal["timber_cedar"])
    timber_dark = parse_hex_color(pal["timber_dark"])
    terracotta = parse_hex_color(pal["tile_terracotta"])
    ochre = parse_hex_color(pal["tile_ochre"])
    slate = parse_hex_color(pal["tile_slate"])
    grout = parse_hex_color(pal["tile_grout"])
    glow = parse_hex_color(pal["lantern_glow"], 210)

    # Interior courtyard/room floor area matching exact interior footprint
    ix = fp["x"] + t
    iy = fp["y"] + t
    iw = fp["width"] - 2 * t
    ih = fp["height"] - 2 * t
    fx, fy = project(ix, iy, 0, ox, oy)
    c.fill_rect(fx, fy, iw, ih, ochre)

    # Courtyards/room patterned tile floor (terracotta & ochre check with slate border)
    tile_step = 20
    for ty_idx, py in enumerate(range(fy, fy + ih, tile_step)):
        for tx_idx, px in enumerate(range(fx, fx + iw, tile_step)):
            tw = min(tile_step, fx + iw - px)
            th = min(tile_step, fy + ih - py)
            is_border = (
                px < fx + tile_step
                or px + tile_step >= fx + iw
                or py < fy + tile_step
                or py + tile_step >= fy + ih
            )
            col = slate if is_border else (terracotta if (tx_idx + ty_idx) % 2 == 0 else ochre)
            c.fill_rect(px, py, tw, th, col)
            c.stroke_rect(px, py, tw, th, grout, 1)

    # Readable North interior elevation (visible in 3/4 oblique view)
    nwx, nwy = project(ix, iy, h - 2, ox, oy)
    c.fill_rect(nwx, nwy, iw, h - 2, plaster)
    c.fill_rect(nwx, nwy + h - 10, iw, 8, timber)
    c.stroke_rect(nwx, nwy, iw, h - 2, mortar, 1)

    # North wall ventilation window (matching spec openings.north_vent_window)
    nv = spec["openings"]["north_vent_window"]
    draw_mashrabiya_window(
        c, ox, oy, nv["x"], fp["y"] + t, nv["z_bottom"], nv["z_top"], nv["width"], timber, timber_dark, glow
    )

    # Architectural structural wall niches (built into masonry, not detachable furniture)
    for niche_x in (110, 560):
        nx, ny = project(niche_x, fp["y"] + t, 24, ox, oy)
        c.fill_rect(nx, ny, 28, 14, plaster_sh)
        c.stroke_rect(nx, ny, 28, 14, mortar, 1)

    # South doorway threshold stone (matching `a:inn-door` and `a:inn-exit` horizontal alignment)
    door = spec["openings"]["courtyard_door"]
    dx, dy = project(door["x"], fp["y"] + fp["height"] - t - 6, 0, ox, oy)
    c.fill_rect(dx, dy, door["width"] + 16, 18, parse_hex_color(pal["limestone_light"]))
    c.stroke_rect(dx, dy, door["width"] + 16, 18, mortar, 1)

    return c


def build_front_wall_layer(spec: dict, ox: float, oy: float, cw: int, ch: int) -> Canvas:
    c = Canvas(cw, ch)
    fp = spec["footprint"]
    t = spec["wall_thickness"]
    h = spec["floors"][0]["wall_height"]
    pal = spec["palette"]
    stone_light = parse_hex_color(pal["limestone_light"])
    stone_mid = parse_hex_color(pal["limestone_mid"])
    stone_dark = parse_hex_color(pal["limestone_dark"])
    plaster = parse_hex_color(pal["plaster_warm"])
    mortar = parse_hex_color(pal["mortar_line"])
    timber = parse_hex_color(pal["timber_cedar"])
    timber_dark = parse_hex_color(pal["timber_dark"])
    timber_hi = parse_hex_color(pal["timber_highlight"])
    awning_teal = parse_hex_color(pal["awning_teal"])
    awning_gold = parse_hex_color(pal["awning_gold"])
    brass = parse_hex_color(pal["brass_lantern"])
    glow = parse_hex_color(pal["lantern_glow"])

    south_y = fp["y"] + fp["height"] - t

    # South facade wall box
    draw_oblique_box(c, ox, oy, fp["x"], south_y, 0, fp["width"], t, h, stone_light, plaster, mortar)
    sfx, sfy = project(fp["x"], fp["y"] + fp["height"], h, ox, oy)
    # Lower limestone masonry course + upper warm plaster facade
    c.fill_rect(sfx + 2, sfy + h // 2, fp["width"] - 4, h // 2 - 1, stone_mid)
    draw_masonry_courses(c, sfx + 2, sfy + h // 2, fp["width"] - 4, h // 2 - 1, mortar, stone_dark, 6, 20)
    # Decorative timber stringcourse beam across facade
    c.fill_rect(sfx + 1, sfy + h // 2 - 2, fp["width"] - 2, 3, timber)

    # Carved courtyard doorway (`a:inn-door` at x=40, y=60 / `a:inn-exit` threshold)
    door = spec["openings"]["courtyard_door"]
    dpx, dpy = project(door["x"], fp["y"] + fp["height"], door["z_top"], ox, oy)
    dw = int(round(door["width"]))
    dh = int(round(door["z_top"] - door["z_bottom"]))
    c.fill_rect(dpx - 3, dpy - 3, dw + 6, dh + 3, stone_dark)
    c.fill_rect(dpx, dpy, dw, dh, timber_dark)
    c.stroke_rect(dpx, dpy, dw, dh, timber_hi, 2)
    # Double door leaves & brass ring
    c.fill_rect(dpx + dw // 2 - 1, dpy + 2, 2, dh - 2, timber)
    c.fill_rect(dpx + dw // 2 - 4, dpy + dh // 2, 2, 3, brass)
    c.fill_rect(dpx + dw // 2 + 2, dpy + dh // 2, 2, 3, brass)

    # North-side entrance archway on the top-left corner where `a:inn-door` sits at (40, 60)
    # So both the north entry porch (40, 60) and south facade read coherently!
    npx, npy = project(door["x"] - 4, fp["y"] + 46, 28, ox, oy)
    c.fill_rect(npx, npy, dw + 8, 28, timber_dark)
    c.stroke_rect(npx, npy, dw + 8, 28, stone_light, 2)
    # Striped fabric awning over the courtyard entrance at (40, 60)
    aw_x, aw_y = project(door["x"] - 8, fp["y"] + 28, 30, ox, oy)
    for stripe in range(0, dw + 16, 6):
        col = awning_teal if (stripe // 6) % 2 == 0 else awning_gold
        c.fill_rect(aw_x + stripe, aw_y, min(6, dw + 16 - stripe), 16, col)
    c.stroke_rect(aw_x, aw_y, dw + 16, 16, timber_dark, 1)
    # Hanging brass lantern beside entrance
    lx, ly = project(door["x"] + dw + 10, fp["y"] + 46, 20, ox, oy)
    c.fill_circle(lx, ly, 5, glow)
    c.fill_rect(lx - 2, ly - 3, 4, 6, brass)

    # South facade mashrabiya lattice windows
    for win_key in ("south_mashrabiya_west", "south_mashrabiya_east"):
        wspec = spec["openings"][win_key]
        draw_mashrabiya_window(
            c,
            ox,
            oy,
            wspec["x"],
            fp["y"] + fp["height"],
            wspec["z_bottom"],
            wspec["z_top"],
            wspec["width"],
            timber,
            timber_dark,
            glow,
        )

    return c


def build_roof_layer(spec: dict, ox: float, oy: float, cw: int, ch: int) -> Canvas:
    c = Canvas(cw, ch)
    fp = spec["footprint"]
    h = spec["floors"][0]["wall_height"]
    pal = spec["palette"]
    stone_light = parse_hex_color(pal["limestone_light"])
    stone_mid = parse_hex_color(pal["limestone_mid"])
    stone_dark = parse_hex_color(pal["limestone_dark"])
    plaster = parse_hex_color(pal["plaster_warm"])
    plaster_sh = parse_hex_color(pal["plaster_shadow"])
    mortar = parse_hex_color(pal["mortar_line"])
    timber = parse_hex_color(pal["timber_cedar"])
    timber_dark = parse_hex_color(pal["timber_dark"])
    awning_crimson = parse_hex_color(pal["awning_crimson"])
    awning_gold = parse_hex_color(pal["awning_gold"])

    # Flat plastered roof slab with overhanging timber cornice at z = h..h+6
    draw_oblique_box(
        c,
        ox,
        oy,
        fp["x"] - 4,
        fp["y"] - 4,
        h,
        fp["width"] + 8,
        fp["height"] + 8,
        6,
        plaster,
        stone_mid,
        mortar,
    )

    # Roof surface beams & drainage channels
    rx, ry = project(fp["x"], fp["y"], h + 6, ox, oy)
    c.stroke_rect(rx + 6, ry + 6, fp["width"] - 12, fp["height"] - 12, plaster_sh, 2)
    for bx in range(rx + 48, rx + fp["width"] - 24, 64):
        c.fill_rect(bx, ry + 8, 4, fp["height"] - 16, plaster_sh)

    # Projected timber rafters along south eave
    efx, efy = project(fp["x"] - 4, fp["y"] + fp["height"] + 4, h + 6, ox, oy)
    for tx in range(efx + 8, efx + fp["width"], 24):
        c.fill_rect(tx, efy + 2, 4, 4, timber_dark)

    # Traditional windcatcher (badgir / malqaf) tower on the roof
    draw_oblique_box(
        c, ox, oy, fp["x"] + 270, fp["y"] + 40, h + 6, 120, 88, 22, stone_light, stone_mid, mortar
    )
    wfx, wfy = project(fp["x"] + 270, fp["y"] + 128, h + 28, ox, oy)
    for louver_x in range(wfx + 12, wfx + 108, 20):
        c.fill_rect(louver_x, wfy + 4, 12, 14, timber_dark)
        c.stroke_rect(louver_x, wfy + 4, 12, 14, timber, 1)

    # Shaded rooftop canopy cloth over west roof terrace
    cx, cy = project(fp["x"] + 40, fp["y"] + 44, h + 14, ox, oy)
    for stripe in range(0, 144, 12):
        col = awning_crimson if (stripe // 12) % 2 == 0 else awning_gold
        c.fill_rect(cx + stripe, cy, 12, 84, col)
    c.stroke_rect(cx, cy, 144, 84, timber_dark, 2)

    return c


def build_upper_floor_layer(spec: dict, ox: float, oy: float, cw: int, ch: int) -> Canvas:
    c = Canvas(cw, ch)
    fp = spec["footprint"]
    t = spec["wall_thickness"]
    f1 = spec["floors"][1]
    z0 = f1["z_base"]
    wh = f1["wall_height"]
    pal = spec["palette"]
    stone_light = parse_hex_color(pal["limestone_light"])
    stone_mid = parse_hex_color(pal["limestone_mid"])
    mortar = parse_hex_color(pal["mortar_line"])
    timber = parse_hex_color(pal["timber_cedar"])
    terracotta = parse_hex_color(pal["tile_terracotta"])
    ochre = parse_hex_color(pal["tile_ochre"])

    # Upper terrace walkway ring and crenellated parapet walls (floor_index == 1)
    ux, uy = project(fp["x"] + t, fp["y"] + t, z0, ox, oy)
    c.stroke_rect(ux, uy, fp["width"] - 2 * t, fp["height"] - 2 * t, terracotta, 14)
    c.stroke_rect(ux + 14, uy + 14, fp["width"] - 2 * t - 28, fp["height"] - 2 * t - 28, timber, 2)

    # North, West, East, and South low parapet walls at z = z0..z0+wh
    draw_oblique_box(c, ox, oy, fp["x"], fp["y"], z0, fp["width"], t, wh, stone_light, stone_mid, mortar)
    draw_oblique_box(c, ox, oy, fp["x"], fp["y"], z0, t, fp["height"], wh, stone_light, stone_mid, mortar)
    draw_oblique_box(
        c, ox, oy, fp["x"] + fp["width"] - t, fp["y"], z0, t, fp["height"], wh, stone_light, stone_mid, mortar
    )
    draw_oblique_box(
        c, ox, oy, fp["x"], fp["y"] + fp["height"] - t, z0, fp["width"], t, wh, stone_light, ochre, mortar
    )
    return c


def build_furnishing_sprite(item_id: str, fspec: dict, pal: dict) -> Canvas:
    cw = int(fspec["canvas_width"])
    ch = int(fspec["canvas_height"])
    ox = int(fspec["origin_x"])
    oy = int(fspec["origin_y"])
    w = int(fspec["footprint_width"])
    h = int(fspec["footprint_height"])
    elev = int(fspec["elevation_height"])
    c = Canvas(cw, ch)

    timber = parse_hex_color(pal["timber_cedar"])
    timber_dark = parse_hex_color(pal["timber_dark"])
    timber_hi = parse_hex_color(pal["timber_highlight"])
    brass = parse_hex_color(pal["brass_lantern"])
    glow = parse_hex_color(pal["lantern_glow"])
    crimson = parse_hex_color(pal["awning_crimson"])
    teal = parse_hex_color(pal["awning_teal"])
    shadow = parse_hex_color("#0c1618", 90)

    # Contact shadow on floor
    c.fill_rect(ox - w // 2 + 2, oy - h // 2 + 3, w, h, shadow)

    if fspec["kind"] == "chest":
        # Cedar travelling chest with brass bands and lockplate
        draw_oblique_box(
            c,
            -ox,
            -oy,
            -w / 2.0,
            -h / 2.0,
            0,
            w,
            h,
            elev,
            timber_hi,
            timber,
            timber_dark,
        )
        # Brass straps & lock
        top_x = ox - w // 2
        top_y = oy - h // 2 - elev
        c.fill_rect(top_x + 6, top_y, 3, h + elev, brass)
        c.fill_rect(top_x + w - 9, top_y, 3, h + elev, brass)
        c.fill_rect(ox - 3, oy + h // 2 - elev // 2 - 2, 6, 5, brass)
    elif fspec["kind"] == "lamp":
        # Brass standing oil lamp with warm glow halo
        c.fill_circle(ox, oy - elev + 4, 11, (glow[0], glow[1], glow[2], 95))
        draw_oblique_box(
            c,
            -ox,
            -oy,
            -7,
            -7,
            0,
            14,
            14,
            4,
            brass,
            timber_dark,
            timber_dark,
        )
        c.fill_rect(ox - 2, oy - elev + 6, 4, elev - 6, brass)
        c.fill_circle(ox, oy - elev + 4, 5, glow)
        c.stroke_rect(ox - 5, oy - elev - 1, 10, 10, brass, 1)
    elif fspec["kind"] == "cushion":
        # Woven crimson & gold floor cushion with corner tassels
        draw_oblique_box(
            c,
            -ox,
            -oy,
            -w / 2.0,
            -h / 2.0,
            0,
            w,
            h,
            elev,
            crimson,
            teal,
            timber_dark,
        )
        tx = ox - w // 2
        ty = oy - h // 2 - elev
        c.stroke_rect(tx + 4, ty + 4, w - 8, h - 8, brass, 2)
        c.fill_rect(ox - 3, ty + h // 2 - 3, 6, 6, brass)

    return c


def build_composite_proof_sheet(
    spec: dict,
    layers: dict[str, Canvas],
    furnishings: dict[str, Canvas],
    out_dir: Path,
) -> Path:
    """
    Produces a single side-by-side 2x2 visual proof sheet (`cutaway_proof_sheet.png`)
    showing:
      1. Normal Exterior (shell + front_wall + roof)
      2. Eave Occlusion Fade (player behind doorway awning/roof eave)
      3. Interior Cutaway (Floor 0: shell + interior + detachable furnishings + faded south wall)
      4. Global Floor 1 Selection (Upper roof terrace & parapet visibility)
    """
    lw = layers["shell"].width
    lh = layers["shell"].height
    pad = 16
    sheet = Canvas(lw * 2 + pad * 3, lh * 2 + pad * 3)
    sheet.fill_rect(0, 0, sheet.width, sheet.height, parse_hex_color("#101e22"))

    def blit(dst: Canvas, src: Canvas, dx: int, dy: int, alpha_scale: float = 1.0) -> None:
        for y in range(src.height):
            for x in range(src.width):
                idx = (y * src.width + x) * 4
                sa = src.buf[idx + 3]
                if sa == 0:
                    continue
                eff_a = int(round(sa * alpha_scale))
                if eff_a <= 0:
                    continue
                dst.set_px(
                    dx + x,
                    dy + y,
                    (src.buf[idx], src.buf[idx + 1], src.buf[idx + 2], eff_a),
                )

    # Panel 1 (Top-Left): Normal Exterior
    p1x, p1y = pad, pad
    blit(sheet, layers["shell"], p1x, p1y, 1.0)
    blit(sheet, layers["front_wall"], p1x, p1y, 1.0)
    blit(sheet, layers["roof"], p1x, p1y, 1.0)

    # Panel 2 (Top-Right): Exterior Eave Occlusion Fade (player at doorway x=40, y=60)
    p2x, p2y = lw + pad * 2, pad
    blit(sheet, layers["shell"], p2x, p2y, 1.0)
    blit(sheet, layers[" interior"], p2x, p2y, 1.0)
    # Player marker at doorway
    sheet.fill_circle(p2x + 40, p2y + 80, 9, parse_hex_color("#8bd0d1"))
    blit(sheet, layers["front_wall"], p2x, p2y, 0.35)
    blit(sheet, layers["roof"], p2x, p2y, 0.28)

    # Panel 3 (Bottom-Left): Interior Cutaway (Floor 0) + Detachable Furnishings
    p3x, p3y = pad, lh + pad * 2
    blit(sheet, layers["shell"], p3x, p3y, 1.0)
    blit(sheet, layers[" interior"], p3x, p3y, 1.0)
    # Blit detachable furniture at cells (208,60), (308,60), (508,60)
    placements = [
        ("a:housing-chest", 208, 60),
        ("a:lamp", 308, 60),
        ("a:cushion", 508, 60),
    ]
    for fid, fx, fy in placements:
        fspec = spec["detachable_furnishings"][fid]
        fc = furnishings[fid]
        blit(sheet, fc, p3x + fx - fspec["origin_x"], p3y + fy + 36 - fspec["origin_y"], 1.0)
    # Player marker inside room
    sheet.fill_circle(p3x + 208, p3y + 136, 9, parse_hex_color("#8bd0d1"))
    blit(sheet, layers["front_wall"], p3x, p3y, 0.22)

    # Panel 4 (Bottom-Right): Global Floor 1 Selection (Upper Terrace & Parapet)
    p4x, p4y = lw + pad * 2, lh + pad * 2
    blit(sheet, layers["shell"], p4x, p4y, 1.0)
    blit(sheet, layers[" interior"], p4x, p4y, 0.45)
    blit(sheet, layers["front_wall"], p4x, p4y, 0.65)
    blit(sheet, layers["upper_floor"], p4x, p4y, 1.0)
    blit(sheet, layers["roof"], p4x, p4y, 0.35)

    out_path = out_dir / "cutaway_proof_sheet.png"
    sheet.save_png(out_path)
    return out_path


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent
    spec_path = repo_root / "dev" / "art" / "building_fixture_spec.json"
    out_dir = repo_root / "dev" / "art" / "cutaway_fixture"
    spec = json.loads(spec_path.read_text(encoding="utf-8"))

    fp = spec["footprint"]
    max_z = 64.0
    margin = 12.0
    ox = fp["x"] - margin
    oy = fp["y"] - max_z - margin
    cw = int(round(fp["width"] + margin * 2))
    ch = int(round(fp["height"] + max_z + margin * 2))

    shell = build_shell_layer(spec, ox, oy, cw, ch)
    interior = build_interior_layer(spec, ox, oy, cw, ch)
    front_wall = build_front_wall_layer(spec, ox, oy, cw, ch)
    roof = build_roof_layer(spec, ox, oy, cw, ch)
    upper_floor = build_upper_floor_layer(spec, ox, oy, cw, ch)

    layer_files = {
        "shell": "layer_shell.png",
        "interior": "layer_interior.png",
        "front_wall": "layer_front_wall.png",
        "roof": "layer_roof.png",
        "upper_floor": "layer_upper_floor.png",
    }
    canvases = {
        "shell": shell,
        " interior": interior,
        "interior": interior,
        "front_wall": front_wall,
        "roof": roof,
        "upper_floor": upper_floor,
    }
    for key, filename in layer_files.items():
        canvases[key].save_png(out_dir / filename)

    furnishing_canvases: dict[str, Canvas] = {}
    furnishing_manifest: dict[str, dict] = {}
    for fid, fspec in spec["detachable_furnishings"].items():
        fc = build_furnishing_sprite(fid, fspec, spec["palette"])
        furnishing_canvases[fid] = fc
        fname = f"prop_{fspec['kind']}.png"
        fc.save_png(out_dir / fname)
        furnishing_manifest[fid] = {
            "kind": fspec["kind"],
            "texture": f"res://dev/art/cutaway_fixture/{fname}",
            "width": fspec["canvas_width"],
            "height": fspec["canvas_height"],
            "origin": {"x": fspec["origin_x"], "y": fspec["origin_y"]},
            "footprint": {"width": fspec["footprint_width"], "height": fspec["footprint_height"]},
        }

    proof_path = build_composite_proof_sheet(spec, canvases, furnishing_canvases, out_dir)

    manifest = {
        "schema_version": 1,
        "fixture_id": spec["fixture_id"],
        "noncanonical": True,
        "projection": spec["projection"],
        "canvas": {
            "origin_world": {"x": ox, "y": oy},
            "width": cw,
            "height": ch,
        },
        "footprint": fp,
        "regions": spec["regions"],
        "floors": spec["floors"],
        "openings": spec["openings"],
        "occlusion_zones": spec["occlusion_zones"],
        "layers": {
            k: f"res://dev/art/cutaway_fixture/{v}" for k, v in layer_files.items()
        },
        "furnishings": furnishing_manifest,
        "proof_sheet": f"res://dev/art/cutaway_fixture/{proof_path.name}",
    }
    manifest_path = out_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Generated {len(layer_files)} building layers, {len(furnishing_manifest)} detachable props, and {proof_path.name} in {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
