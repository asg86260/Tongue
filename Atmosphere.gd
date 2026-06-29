extends Control

# Foreground atmosphere: drifting motes + a soft vignette, in front of the world but
# below the HUD. Biome-aware: the motes recolour and pick up wind as you climb —
# green spores (Woods) → cold mist (Ruins) → warm embers (Cliffs) → blowing sand (Peak).

const Biome := preload("res://Biome.gd")
const SPAWN_Y := -40.0

# per-biome mote colour + horizontal wind (px/s); smoothly lerped at transitions
const MOTE_COLS := [
	Color(0.70, 0.90, 0.55),   # Woods  — green spores
	Color(0.72, 0.83, 0.98),   # Ruins  — cold pale mist
	Color(0.98, 0.62, 0.30),   # Cliffs — warm embers
	Color(0.93, 0.85, 0.62),   # Peak   — blowing sand
]
const MOTE_WIND := [5.0, 9.0, 16.0, 46.0]

var target: Node2D
var t := 0.0
var motes: Array = []
var _col := MOTE_COLS[0]
var _wind := MOTE_WIND[0]
var _idx := 0
const N := 54

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 9173
	for i in N:
		motes.append({
			"fx": rng.randf(), "fy": rng.randf(),
			"r": rng.randf_range(2.0, 5.0),
			"spd": rng.randf_range(6.0, 22.0),       # rise speed
			"swf": rng.randf_range(0.4, 1.3),        # sway freq
			"amp": rng.randf_range(8.0, 26.0),       # sway amplitude
			"phase": rng.randf() * TAU,
			"a": rng.randf_range(0.05, 0.18),
		})
	set_process(true)

func _process(d: float) -> void:
	t += d
	if target:
		_idx = Biome.index((SPAWN_Y - target.global_position.y) / 100.0)
		_col = _col.lerp(MOTE_COLS[_idx], clampf(d * 1.5, 0.0, 1.0))
		_wind = lerpf(_wind, MOTE_WIND[_idx], clampf(d * 1.5, 0.0, 1.0))
	queue_redraw()

func _draw() -> void:
	var vp := get_viewport().get_visible_rect().size
	var cam := target.global_position if target else Vector2.ZERO
	for m in motes:
		var y: float = fmodp(m.fy * vp.y - t * m.spd + cam.y * 0.18, vp.y + 60.0) - 30.0
		var x: float = fmodp(m.fx * vp.x + sin(t * m.swf + m.phase) * m.amp + t * _wind + cam.x * 0.18, vp.x + 60.0) - 30.0
		var a: float = m.a * (0.55 + 0.45 * sin(t * 1.7 + m.phase))
		draw_rect(Rect2(x, y, m.r, m.r), Color(_col.r, _col.g, _col.b, a))
	# CLIFFS wind streaks: fast warm dashes blowing with the gust (telegraphs the wind force)
	if _idx == 2:
		var gust := absf(sin(t * 0.5))
		var dir := signf(sin(t * 0.5))
		if dir == 0.0:
			dir = 1.0
		for i in 12:
			var sy := fmodp(i * 71.0 + t * 26.0, vp.y + 20.0)
			var sx := fmodp(i * 137.0 + t * (360.0 * dir + 90.0), vp.x + 80.0) - 40.0
			var a := 0.08 + 0.20 * gust
			draw_line(Vector2(sx, sy), Vector2(sx + dir * (30.0 + 50.0 * gust), sy), Color(0.98, 0.72, 0.42, a), 2.0)
	_vignette(vp)

# darken the top and bottom edges for focus/mood
func _vignette(vp: Vector2) -> void:
	var h := vp.y * 0.18
	var dark := Color(0.02, 0.03, 0.02, 0.55)
	var clear := Color(0.02, 0.03, 0.02, 0.0)
	draw_polygon(
		PackedVector2Array([Vector2(0, 0), Vector2(vp.x, 0), Vector2(vp.x, h), Vector2(0, h)]),
		PackedColorArray([dark, dark, clear, clear]))
	draw_polygon(
		PackedVector2Array([Vector2(0, vp.y - h), Vector2(vp.x, vp.y - h), Vector2(vp.x, vp.y), Vector2(0, vp.y)]),
		PackedColorArray([clear, clear, dark, dark]))

static func fmodp(a: float, b: float) -> float:
	return fmod(fmod(a, b) + b, b)
