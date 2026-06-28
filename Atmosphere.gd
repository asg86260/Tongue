extends Control

# Foreground atmosphere: drifting spores/dust in front of the world plus a soft
# vignette. A Control that Game parents under a CanvasLayer above the world but below
# the HUD. Reads `target` (the player) for a touch of parallax.

var target: Node2D
var t := 0.0
var motes: Array = []
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
			"warm": rng.randf() < 0.35,              # some are amber (ember-like)
		})
	set_process(true)

func _process(d: float) -> void:
	t += d
	queue_redraw()

func _draw() -> void:
	var vp := get_viewport().get_visible_rect().size
	var cam := target.global_position if target else Vector2.ZERO
	for m in motes:
		var y: float = fmodp(m.fy * vp.y - t * m.spd + cam.y * 0.18, vp.y + 60.0) - 30.0
		var x: float = fmodp(m.fx * vp.x + sin(t * m.swf + m.phase) * m.amp + cam.x * 0.18, vp.x + 60.0) - 30.0
		var a: float = m.a * (0.55 + 0.45 * sin(t * 1.7 + m.phase))
		var col := Color(0.95, 0.72, 0.38, a) if m.warm else Color(0.72, 0.9, 0.62, a)
		draw_rect(Rect2(x, y, m.r, m.r), col)
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
