#!/usr/bin/env python3
"""Render Legix's Steam Gaming Mode videos (startup and suspend) as VP8 WebM.

Same choreography as the Plymouth theme (Animation 7): the L fins fade in
bunched where the V will land, the V falls and pushes them out, the gem drops
into the notch with a flash, then the LEGIX wordmark rises in. Frames are drawn
with Pillow from the logo geometry (no SVG renderer needed) and piped to ffmpeg.

  render-videos.py <font.ttf> <out dir>  ->  legix.webm (1280x800, 4 s),
                                            legix-suspend.webm (450x450, 1 s)
"""
import subprocess, sys
from PIL import Image, ImageDraw, ImageFont

FPS = 60
# Pure black, like Bazzite's videos. Steam can't draw these with transparency
# (VP8, no alpha) and puts black around them: the 450x450 suspend video sits
# over a black screen, so any other colour shows up as a box.
BG = (0, 0, 0)
FIN, V, GEM_L, GEM_R = (184, 50, 31), (229, 67, 45), (255, 106, 61), (255, 154, 85)
GLOW_L, GLOW_R, WORD = (255, 196, 154), (255, 224, 196), (236, 238, 241)
PARTS = {  # 200x200-unit logo canvas
    "l_left":  [((6,62),(18,62),(66,156),(54,156)), ((59,142),(80,142),(74,156),(54,156))],
    "l_right": [((194,62),(182,62),(134,156),(146,156)), ((141,142),(120,142),(126,156),(146,156))],
    "v":       [((30,24),(44,24),(100,140),(100,170)), ((170,24),(156,24),(100,140),(100,170))],
    "gem_l":   [((100,44),(80,58),(85,86),(100,98))],
    "gem_r":   [((100,44),(120,58),(115,86),(100,98))],
}

def clamp01(x): return 0.0 if x < 0 else 1.0 if x > 1 else x
def seg(t, a, b): return clamp01((t - a) / (b - a))
def ease_in(x): return x ** 3
def ease_out(x): return 1 - (1 - x) ** 3
def mix(a, b, k): return a + (b - a) * k

# Timeline (seconds), identical to legix.script.
def fin_offset(t):
    if t < 1.56: return 34
    if t < 2.04: return mix(34, -3, ease_out(seg(t, 1.56, 2.04)))
    return mix(-3, 0, ease_out(seg(t, 2.04, 2.40)))
def fin_lift(t): return -4 * (1 - seg(t, 1.56, 2.04))
def v_offset(t):
    if t < 1.56: return mix(-110, 0, ease_in(seg(t, 1.08, 1.56)))
    if t < 1.74: return mix(0, -4, ease_out(seg(t, 1.56, 1.74)))
    return mix(-4, 0, ease_in(seg(t, 1.74, 1.92)))
def gem_offset(t):
    if t < 2.16: return mix(-84, 0, ease_in(seg(t, 1.86, 2.16)))
    if t < 2.28: return mix(0, -5, ease_out(seg(t, 2.16, 2.28)))
    return mix(-5, 0, ease_in(seg(t, 2.28, 2.46)))
def flash(t):
    if t < 2.16: return 0.0
    return 1 - seg(t, 2.16, 2.46)

class Canvas:
    def __init__(self, w, h, ss=2):
        self.w, self.h, self.ss = w, h, ss
    def new(self):
        return Image.new("RGBA", (self.w * self.ss, self.h * self.ss), BG + (255,))
    def poly(self, img, pts, ox, oy, unit, color, alpha):
        if alpha <= 0: return
        layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        s = self.ss
        d.polygon([((ox + x * unit) * s, (oy + y * unit) * s) for x, y in pts],
                  fill=color + (int(255 * alpha),))
        img.alpha_composite(layer)
    def done(self, img):
        return img.resize((self.w, self.h), Image.LANCZOS).convert("RGB")

def draw_logo(cv, img, t, lx, ly, unit, final=False):
    if final:
        t = 99.0
    fa = ease_out(seg(t, 0.36, 0.84))
    fo, fl = fin_offset(t), fin_lift(t)
    for p in PARTS["l_left"]:  cv.poly(img, p, lx + fo * unit, ly + fl * unit, unit, FIN, fa)
    for p in PARTS["l_right"]: cv.poly(img, p, lx - fo * unit, ly + fl * unit, unit, FIN, fa)
    va = seg(t, 0.96, 1.08)
    for p in PARTS["v"]: cv.poly(img, p, lx, ly + v_offset(t) * unit, unit, V, va)
    ga = seg(t, 1.80, 1.86)
    gy = ly + gem_offset(t) * unit
    for p in PARTS["gem_l"]: cv.poly(img, p, lx, gy, unit, GEM_L, ga)
    for p in PARTS["gem_r"]: cv.poly(img, p, lx, gy, unit, GEM_R, ga)
    fla = flash(t) * ga
    for p in PARTS["gem_l"]: cv.poly(img, p, lx, gy, unit, GLOW_L, fla)
    for p in PARTS["gem_r"]: cv.poly(img, p, lx, gy, unit, GLOW_R, fla)

def wordmark(font_path, height_px, ss):
    font = ImageFont.truetype(font_path, int(height_px * ss * 1.4))
    text, track = "LEGIX", 0.22
    em = font.size
    widths = [font.getlength(c) for c in text]
    total = sum(widths) + track * em * (len(text) - 1)
    asc, desc = font.getmetrics()
    img = Image.new("RGBA", (int(total) + 4, asc + desc), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    x = 0.0
    for c, w in zip(text, widths):
        d.text((x, 0), c, font=font, fill=WORD + (255,))
        x += w + track * em
    return img.crop(img.getbbox())

def encode(frames, w, h, out):
    p = subprocess.Popen(["ffmpeg", "-loglevel", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24",
                          "-s", f"{w}x{h}", "-r", str(FPS), "-i", "-",
                          "-c:v", "libvpx", "-b:v", "3M", "-crf", "8", "-auto-alt-ref", "0",
                          "-pix_fmt", "yuv420p", "-an", out], stdin=subprocess.PIPE)
    for f in frames:
        p.stdin.write(f.tobytes())
    p.stdin.close()
    if p.wait() != 0:
        sys.exit(f"ffmpeg failed for {out}")

def startup(font_path, out, w=1280, h=800, seconds=4.0):
    cv = Canvas(w, h)
    size = h * 0.30
    unit = size / 200
    lx, ly = (w - size) / 2, h / 2 - size * 0.62
    wm = wordmark(font_path, size * 0.80 * 0.19, cv.ss)
    ww = int(size * 0.80 * cv.ss)
    wm = wm.resize((ww, int(wm.height * ww / wm.width)), Image.LANCZOS)
    wy = (ly + size + size * 0.10) * cv.ss
    def frames():
        for i in range(int(seconds * FPS)):
            t = i / FPS
            img = cv.new()
            draw_logo(cv, img, t, lx, ly, unit)
            k = ease_out(seg(t, 2.64, 3.36))
            if k > 0:
                layer = wm.copy()
                layer.putalpha(layer.getchannel("A").point(lambda a: int(a * k)))
                img.alpha_composite(layer, (int(w * cv.ss / 2 - ww / 2), int(wy + 8 * unit * cv.ss * (1 - k))))
            yield cv.done(img)
    encode(frames(), w, h, out)

def suspend(out, w=450, h=450, seconds=1.0):
    cv = Canvas(w, h)
    size = w * 0.60
    unit = size / 200
    lx, ly = (w - size) / 2, (h - size) / 2 - size * 0.05
    def frames():
        for i in range(int(seconds * FPS)):
            t = i / FPS
            img = cv.new()
            draw_logo(cv, img, 0, lx, ly, unit, final=True)
            # gem flash, then everything fades to the background
            fl = 1 - seg(t, 0.0, 0.35)
            for p in PARTS["gem_l"]: cv.poly(img, p, lx, ly, unit, GLOW_L, fl)
            for p in PARTS["gem_r"]: cv.poly(img, p, lx, ly, unit, GLOW_R, fl)
            fade = ease_in(seg(t, 0.35, 0.95))
            if fade > 0:
                img.alpha_composite(Image.new("RGBA", img.size, BG + (int(255 * fade),)))
            yield cv.done(img)
    encode(frames(), w, h, out)

if __name__ == "__main__":
    font_path, out_dir = sys.argv[1], sys.argv[2]
    startup(font_path, f"{out_dir}/legix.webm")
    suspend(f"{out_dir}/legix-suspend.webm")
    print("rendered", f"{out_dir}/legix.webm", f"{out_dir}/legix-suspend.webm")
