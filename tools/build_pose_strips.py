"""把现有单张像素图裁成 48px 横条循环。

来源仍是仓库里的原画，只做整数缩小和局部错帧，所以角色还是原来那个。
待机只动下摆或翅膀，移动才换整个人的落点。
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
def content(path: Path, fit_longest: int) -> Image.Image:
	im = Image.open(path).convert("RGBA")
	box = im.getbbox()
	if box is None:
		raise SystemExit(f"empty sprite: {path}")
	cropped = im.crop(box)
	longest = max(cropped.size)
	factor = max(1, round(longest / fit_longest))
	return cropped.resize(
		(max(1, cropped.width // factor), max(1, cropped.height // factor)),
		Image.Resampling.NEAREST,
	)


def blank(cell: int) -> Image.Image:
	return Image.new("RGBA", (cell, cell), (0, 0, 0, 0))


def blit(frame: Image.Image, part: Image.Image, x: int, y: int) -> None:
	frame.alpha_composite(part, (x, y))


def centered_origin(sprite: Image.Image, cell: int) -> tuple[int, int]:
	return ((cell - sprite.width) // 2, (cell - sprite.height) // 2)


def idle_cloak(src: Image.Image, cell: int = 48) -> list[Image.Image]:
	"""下摆左右错 1 像素，身体不动。"""
	cut = int(src.height * 0.62)
	top = src.crop((0, 0, src.width, cut))
	bot = src.crop((0, cut, src.width, src.height))
	ox, oy = centered_origin(src, cell)
	frames = []
	for shift in (0, 1, 0, -1):
		frame = blank(cell)
		blit(frame, top, ox, oy)
		blit(frame, bot, ox + shift, oy + cut)
		frames.append(frame)
	return frames


def step_cycle(src: Image.Image, count: int, cell: int = 48) -> list[Image.Image]:
	"""落点和身体压扁交替，避免整张图只是平移。"""
	ox, oy = centered_origin(src, cell)
	frames = []
	for i in range(count):
		frame = blank(cell)
		dx = (0, 1, 0, -1, 0, 1)[i % 6]
		dy = (0, 1, 0, 1, 0, 1)[i % 6]
		if i % 2 == 0:
			body = src.resize((src.width + 1, max(1, src.height - 1)), Image.Resampling.NEAREST)
		else:
			body = src.resize((max(1, src.width - 1), src.height + 1), Image.Resampling.NEAREST)
		bx = ox + dx + (src.width - body.width) // 2
		by = oy + dy + (src.height - body.height)
		blit(frame, body, bx, by)
		frames.append(frame)
	return frames


def wing_flap(src: Image.Image, lifts: tuple[int, ...], cell: int = 48) -> list[Image.Image]:
	mid = src.width // 2
	left = src.crop((0, 0, mid, src.height))
	right = src.crop((mid, 0, src.width, src.height))
	ox, oy = centered_origin(src, cell)
	frames = []
	for lift in lifts:
		frame = blank(cell)
		blit(frame, left, ox, oy - lift)
		blit(frame, right, ox + mid, oy + lift)
		frames.append(frame)
	return frames


def lunge(src: Image.Image, cell: int = 48) -> list[Image.Image]:
	"""上半身前探，用来做出拉弓或前冲，播完应回到待机。"""
	cut = max(1, int(src.height * 0.55))
	top = src.crop((0, 0, src.width, cut))
	bot = src.crop((0, cut, src.width, src.height))
	ox, oy = centered_origin(src, cell)
	frames = []
	for shift in (0, 2, 3, 1):
		frame = blank(cell)
		blit(frame, bot, ox, oy + cut)
		blit(frame, top, ox + shift, oy)
		frames.append(frame)
	return frames


def swell(src: Image.Image, cell: int = 48) -> list[Image.Image]:
	ox, oy = centered_origin(src, cell)
	frames = []
	for grow in (0, 2, 4, 6):
		frame = blank(cell)
		body = src.resize((src.width + grow, src.height + grow), Image.Resampling.NEAREST)
		blit(frame, body, ox - grow // 2, oy - grow // 2)
		frames.append(frame)
	return frames


def fade(src: Image.Image, cell: int = 48, rising: bool = False) -> list[Image.Image]:
	alphas = (255, 170, 80, 0) if not rising else (0, 80, 170, 255)
	frames = []
	for alpha in alphas:
		frame = blank(cell)
		ghost = src.copy()
		band = ghost.getchannel("A").point(lambda a, alpha=alpha: a * alpha // 255)
		ghost.putalpha(band)
		ox, oy = centered_origin(src, cell)
		blit(frame, ghost, ox, oy)
		frames.append(frame)
	return frames


def to_gray(src: Image.Image, cell: int = 48) -> list[Image.Image]:
	gray = src.convert("LA").convert("RGBA")
	frames = []
	for mix in (0.0, 0.35, 0.7, 1.0):
		frame = blank(cell)
		blended = Image.blend(src, gray, mix)
		ox, oy = centered_origin(src, cell)
		blit(frame, blended, ox, oy)
		frames.append(frame)
	return frames


def save_strip(frames: list[Image.Image], path: Path, cell: int) -> None:
	strip = Image.new("RGBA", (cell * len(frames), cell), (0, 0, 0, 0))
	for i, frame in enumerate(frames):
		strip.alpha_composite(frame, (i * cell, 0))
	path.parent.mkdir(parents=True, exist_ok=True)
	strip.save(path)
	print(f"{path} {strip.size}")


def main() -> None:
	# 已经写成横条的不再读，避免缩第二次。
	done = {
		"assets/sprites/player/player_idle.png",
		"assets/sprites/player/player_run.png",
		"assets/sprites/enemies/bat_fly.png",
		"assets/sprites/enemies/zombie_walk.png",
		"assets/sprites/enemies/vampire_idle.png",
		"assets/sprites/enemies/werewolf_idle.png",
	}
	small = [
		("assets/sprites/enemies/skeleton_idle.png", lambda im: idle_cloak(im, 48), 40, 48),
		("assets/sprites/enemies/exploder_walk.png", lambda im: step_cycle(im, 4, 48), 40, 48),
		("assets/sprites/enemies/elite_vampire_idle.png", lambda im: idle_cloak(im, 48), 40, 48),
		("assets/sprites/enemies/summoner_cast.png", lambda im: idle_cloak(im, 48), 40, 48),
		("assets/sprites/enemies/mage_cast.png", lambda im: idle_cloak(im, 48), 40, 48),
		("assets/sprites/enemies/gargoyle_idle.png", lambda im: wing_flap(im, (0, -1), 48), 40, 48),
		("assets/sprites/enemies/prince_idle.png", lambda im: idle_cloak(im, 48), 40, 48),
		("assets/sprites/enemies/prince_rage.png", lambda im: idle_cloak(im, 48), 40, 48),
		("assets/sprites/boss/boss_idle.png", lambda im: idle_cloak(im, 96), 84, 96),
		("assets/sprites/boss/boss_enraged.png", lambda im: idle_cloak(im, 96), 84, 96),
		("assets/sprites/enemies/skeleton_shoot.png", lambda im: lunge(im, 48), 40, 48),
		("assets/sprites/enemies/werewolf_charge.png", lambda im: lunge(im, 48), 40, 48),
		("assets/sprites/enemies/exploder_explode.png", lambda im: swell(im, 48), 40, 48),
		("assets/sprites/enemies/mage_teleport.png", lambda im: fade(im, 48, False), 40, 48),
		("assets/sprites/enemies/gargoyle_petrify.png", lambda im: to_gray(im, 48), 40, 48),
		("assets/sprites/enemies/gargoyle_wake.png", lambda im: fade(im, 48, True), 40, 48),
		("assets/sprites/enemies/prince_dash.png", lambda im: lunge(im, 48), 40, 48),
		("assets/sprites/boss/boss_attack3.png", lambda im: lunge(im, 96), 84, 96),
		("assets/sprites/boss/boss_death.png", lambda im: fade(im, 96, False), 84, 96),
	]
	loaded = []
	for rel, build, fit, cell in small:
		if rel in done:
			continue
		src = ROOT / rel
		with Image.open(src) as existing:
			if existing.height == cell and existing.width % cell == 0 and existing.width > cell:
				print(f"skip {rel}")
				continue
		loaded.append((content(src, fit), src, build, cell))
	for image, dest, build, cell in loaded:
		save_strip(build(image), dest, cell)


if __name__ == "__main__":
	main()
