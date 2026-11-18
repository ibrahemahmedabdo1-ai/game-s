#!/usr/bin/env python3
"""Generates original launcher icons (legacy + adaptive), Play Store icon and feature graphic
for every game into store_assets/<game>/. Needs Pillow. Run: python3 scripts/generate_assets.py"""
import os, math
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAMES = {
  'color_reactor':      dict(title='Color Reactor',      tag='Route the colors. Power the core.',   c1=(0,191,165),  c2=(0,60,52)),
  'gravity_switch':     dict(title='Gravity Switch',     tag='Tap. Flip. Survive the corridor.',     c1=(255,112,67), c2=(120,30,10)),
  'shape_eater':        dict(title='Shape Eater',        tag='Eat the right shape.', c1=(236,64,122), c2=(100,10,55)),
  'perfect_drop':       dict(title='Perfect Drop',       tag='Steer every ball into the bin.',      c1=(124,77,255), c2=(35,20,110)),
  'color_merge_lab':    dict(title='Color Merge Lab',    tag='Merge. Chain. Discover.',             c1=(156,204,101), c2=(40,80,20)),
  'mini_puzzle_arcade': dict(title='Mini Puzzle Arcade', tag='Five puzzle games. One app.',         c1=(92,107,192), c2=(22,28,100)),
}
S = 1024

def grad(c1, c2, size=S):
    im = Image.new('RGB', (size, size))
    d = ImageDraw.Draw(im)
    for y in range(size):
        t = y / size
        d.line([(0, y), (size, y)], fill=tuple(int(c1[i] * (1 - t) + c2[i] * t) for i in range(3)))
    return im

def glow(layer, radius=18):
    return Image.alpha_composite(layer.filter(ImageFilter.GaussianBlur(radius)), layer)

def poly(cx, cy, r, n, rot=-math.pi / 2):
    return [(cx + r * math.cos(rot + i * 2 * math.pi / n), cy + r * math.sin(rot + i * 2 * math.pi / n)) for i in range(n)]

W = (255, 255, 255, 255)
def art(game):
    L = Image.new('RGBA', (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(L)
    if game == 'color_reactor':
        cols = [(255, 82, 82, 255), (64, 196, 255, 255), (255, 215, 64, 255)]
        paths = [[(220, 330), (512, 330), (512, 700), (804, 700)], [(220, 512), (804, 512)], [(220, 700), (400, 700), (400, 330), (804, 330)]]
        for c, p in zip(cols, paths):
            d.line(p, fill=c, width=70, joint='curve')
            for q in (p[0], p[-1]):
                d.ellipse([q[0] - 52, q[1] - 52, q[0] + 52, q[1] + 52], fill=c)
        d.ellipse([452, 452, 572, 572], fill=W)
    elif game == 'gravity_switch':
        d.rounded_rectangle([170, 190, 854, 250], 30, fill=(255, 255, 255, 220))
        d.rounded_rectangle([170, 774, 854, 834], 30, fill=(255, 255, 255, 220))
        d.ellipse([392, 392, 632, 632], fill=(38, 198, 218, 255))
        d.ellipse([430, 430, 490, 490], fill=(255, 255, 255, 170))
        d.polygon([(512, 290), (590, 360), (434, 360)], fill=W)
        d.polygon([(512, 734), (590, 664), (434, 664)], fill=W)
    elif game == 'shape_eater':
        d.line([(512, 330), (330, 700), (694, 700), (512, 330)], fill=(255, 255, 255, 200), width=22)
        d.ellipse([382, 190, 642, 450], fill=(255, 202, 40, 255))
        d.rounded_rectangle([200, 600, 450, 850], 46, fill=(38, 198, 218, 255))
        d.polygon(poly(700, 730, 170, 3), fill=(255, 255, 255, 255))
        d.ellipse([452, 252, 572, 372], fill=(255, 255, 255, 120))
    elif game == 'perfect_drop':
        for x, y in [(512, 190), (470, 300), (560, 300)]:
            d.ellipse([x - 40, y - 40, x + 40, y + 40], fill=W)
        d.line([(300, 470), (724, 560)], fill=(255, 255, 255, 255), width=40)
        d.ellipse([280, 450, 320, 490], fill=(255, 215, 64, 255))
        for i, c in enumerate([(255, 255, 255, 90), (255, 215, 64, 255), (255, 255, 255, 90)]):
            x = 230 + i * 190
            d.rounded_rectangle([x, 680, x + 170, 830], 24, fill=c)
    elif game == 'color_merge_lab':
        d.polygon(poly(300, 400, 150, 3), fill=(255, 238, 88, 255))
        d.rounded_rectangle([160, 600, 420, 800], 36, fill=(66, 165, 245, 255))
        d.line([(430, 450), (560, 520)], fill=W, width=34)
        d.line([(430, 700), (560, 630)], fill=W, width=34)
        d.polygon(poly(720, 575, 190, 5), fill=(236, 64, 122, 255))
        d.ellipse([665, 520, 775, 630], fill=(255, 255, 255, 230))
    else:
        cols = [(255, 82, 82), (255, 202, 40), (102, 187, 106), (66, 165, 245), (171, 71, 188), (38, 198, 218)]
        for i, c in enumerate(cols):
            r, k = divmod(i, 2)
            x, y = 210 + k * 320, 200 + r * 210
            d.rounded_rectangle([x, y, x + 280, y + 180], 40, fill=c + (255,))
    return glow(L, 14)

def make(game, g):
    out = f'{ROOT}/store_assets/{game}/icons'; os.makedirs(out, exist_ok=True)
    A = art(game)
    bg = grad(g['c1'], g['c2']).convert('RGBA')
    full = bg.copy(); full.alpha_composite(A.resize((int(S * .86),) * 2), (int(S * .07), int(S * .07)))
    mask = Image.new('L', (S, S), 0); ImageDraw.Draw(mask).rounded_rectangle([0, 0, S, S], S // 5, fill=255)
    legacy = Image.new('RGBA', (S, S), (0, 0, 0, 0)); legacy.paste(full, (0, 0), mask)
    legacy.resize((512, 512), Image.LANCZOS).save(f'{out}/play_store_icon_512.png')
    for n, px in dict(mdpi=48, hdpi=72, xhdpi=96, xxhdpi=144, xxxhdpi=192).items():
        legacy.resize((px, px), Image.LANCZOS).save(f'{out}/ic_launcher_{n}.png')
    # adaptive foreground: art inside the 66% safe zone of a 108dp canvas
    for n, px in dict(mdpi=108, hdpi=162, xhdpi=216, xxhdpi=324, xxxhdpi=432).items():
        fg = Image.new('RGBA', (px, px), (0, 0, 0, 0))
        a = A.resize((int(px * .62),) * 2, Image.LANCZOS)
        fg.alpha_composite(a, ((px - a.width) // 2, (px - a.height) // 2))
        fg.save(f'{out}/adaptive_foreground_{n}.png')
    open(f'{out}/adaptive_background.txt', 'w').write('#%02X%02X%02X\n' % tuple(int(g['c2'][i] * .55 + g['c1'][i] * .45) for i in range(3)))
    # feature graphic 1024x500
    fg = Image.new('RGB', (1024, 500)); d = ImageDraw.Draw(fg)
    for x in range(1024):
        t = x / 1024
        d.line([(x, 0), (x, 500)], fill=tuple(int(g['c2'][i] * (1 - t) * .9 + g['c1'][i] * t * .8) for i in range(3)))
    fg = fg.convert('RGBA'); fg.alpha_composite(A.resize((440, 440), Image.LANCZOS), (540, 30))
    d = ImageDraw.Draw(fg)
    try:
        f1 = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 62)
        f2 = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 30)
    except Exception:
        f1 = f2 = ImageFont.load_default()
    size = 62
    while size > 30 and d.textlength(g['title'], font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', size)) > 470:
        size -= 2
    f1 = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', size)
    d.text((60, 170), g['title'], font=f1, fill='white')
    d.text((62, 265), g['tag'], font=f2, fill=(235, 245, 245))
    d.text((62, 420), 'Casual Games Studio', font=f2, fill=(255, 255, 255, 150))
    fg.convert('RGB').save(f'{ROOT}/store_assets/{game}/feature_graphic_1024x500.png')
    # keep top-level copy for the assets/ folder
    legacy.resize((512, 512), Image.LANCZOS).save(f'{ROOT}/assets/icons/{game}_512.png')
    return open(f'{out}/adaptive_background.txt').read().strip()

if __name__ == '__main__':
    for k, v in GAMES.items():
        bg = make(k, v)
        pp = f'{ROOT}/apps/{k}/app.properties'
        if os.path.exists(pp):
            lines = [l for l in open(pp).read().splitlines() if not l.startswith('ICON_BG=')]
            open(pp, 'w').write('\n'.join(lines) + f'\nICON_BG={bg}\n')
        print('assets ok', k, bg)
