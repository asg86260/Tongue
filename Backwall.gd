extends Node2D

# A near structural layer: dark, biome-tinted rock masses behind the ledges (no
# collision) so the ledges read as growing from a cliff structure instead of floating
# in void — gaps between the masses keep the parallax vista visible. Each mass is a
# stack of width-varying, shade-varying trapezoids so it reads as rough rock, not a bar.
# Drawn once; static. In front of the parallax (CanvasLayer -10), behind the ledges.

const Biome := preload("res://Biome.gd")
const SPAWN_Y := -40.0
const TOPY := -5320.0
const BOTY := 240.0
const COLS := [-340.0, -80.0, 200.0, 490.0, 800.0]

func _ready() -> void:
	z_index = -4
	queue_redraw()

func _draw() -> void:
	for i in COLS.size():
		_mass(COLS[i], 116.0 + (i % 3) * 18.0, float(i) * 2.3, int(COLS[i]) * 31 + 7)

func _mass(cx: float, base_hw: float, phase: float, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var step := 60.0
	var y := BOTY
	var pl := cx - base_hw
	var pr := cx + base_hw
	while y > TOPY:
		var midy := y - step * 0.5
		var col := _rock((SPAWN_Y - midy) / 100.0)
		var hw := base_hw * (0.66 + 0.34 * sin(midy * 0.006 + phase)) + rng.randf_range(-16.0, 16.0)
		var l := cx - hw
		var r := cx + hw
		# per-segment shade variation gives a rough rock surface
		var shade: Color = col.lightened(rng.randf_range(0.0, 0.14)) if rng.randf() < 0.45 else col.darkened(rng.randf_range(0.0, 0.22))
		draw_colored_polygon(
			PackedVector2Array([Vector2(pl, y), Vector2(pr, y), Vector2(r, y - step), Vector2(l, y - step)]),
			shade)
		pl = l
		pr = r
		y -= step

func _rock(hm: float) -> Color:
	var t := Biome.tint(hm)
	return Color(0.19 * t.r, 0.18 * t.g, 0.17 * t.b, 1.0)
