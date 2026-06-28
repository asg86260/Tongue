extends Control

# Procedural "overgrown ruins" backdrop. A Control (so it can draw) that Game parents
# under a CanvasLayer(layer -10) so it sits behind the world and ignores the camera.
# Gradient sky (deep base, hazy light up top — you climb toward the light), two parallax
# layers of ruined stone gateways receding into mist, and slow amber light-shafts.
# Reads `target` (the player) for parallax scroll.

var target: Node2D        # the frog — its position drives parallax
var t := 0.0

# overgrown-ruins palette: deep green base, dusty lit haze above, stone-grey ruins, amber light
const SKY_TOP := Color("27332b")   # hazy, lit (climbing toward it)
const SKY_BOT := Color("0b100d")   # deep dark base
const RUIN_FAR := Color("18211b")  # distant stone, barely above the sky
const RUIN_MID := Color("222e25")  # nearer stone
const MIST := Color(0.36, 0.46, 0.40, 0.10)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _process(d: float) -> void:
	t += d
	queue_redraw()

func _draw() -> void:
	var vp := get_viewport().get_visible_rect().size
	var cam := target.global_position if target else Vector2.ZERO

	# sky gradient (top lighter)
	draw_polygon(
		PackedVector2Array([Vector2(0, 0), Vector2(vp.x, 0), Vector2(vp.x, vp.y), Vector2(0, vp.y)]),
		PackedColorArray([SKY_TOP, SKY_TOP, SKY_BOT, SKY_BOT]))

	# drifting amber light-shafts (god rays from above)
	for i in 3:
		var sx := fmodp(i * 0.41 * vp.x + t * 9.0, vp.x + 360.0) - 180.0
		var w := 70.0 + i * 26.0
		var skew := 150.0
		var top := Color(0.96, 0.78, 0.42, 0.06)
		var bot := Color(0.96, 0.78, 0.42, 0.0)
		draw_polygon(
			PackedVector2Array([Vector2(sx, 0), Vector2(sx + w, 0),
				Vector2(sx + w - skew, vp.y), Vector2(sx - skew, vp.y)]),
			PackedColorArray([top, top, bot, bot]))

	# parallax ruin layers (gateways receding up the tower) — gentle drift
	_ruin_layer(vp, cam, 0.05, 540.0, 0.70, RUIN_FAR)
	_ruin_layer(vp, cam, 0.13, 400.0, 1.0, RUIN_MID)

	# soft mist band low on screen
	draw_polygon(
		PackedVector2Array([Vector2(0, vp.y * 0.6), Vector2(vp.x, vp.y * 0.6),
			Vector2(vp.x, vp.y), Vector2(0, vp.y)]),
		PackedColorArray([Color(MIST.r, MIST.g, MIST.b, 0.0), Color(MIST.r, MIST.g, MIST.b, 0.0), MIST, MIST]))

# a vertically-tiled layer of broken stone gateways, parallax-scrolled by the camera.
# Each gateway's shape is seeded by its ABSOLUTE world tile index, so shapes stay fixed
# and only slide as you climb (no morphing when the scroll wraps).
func _ruin_layer(vp: Vector2, cam: Vector2, f: float, period: float, scale: float, col: Color) -> void:
	var scroll := cam.y * f
	var ox := -cam.x * f * 0.5
	var base := int(floor(scroll / period))
	var rows := int(vp.y / period) + 3
	for k in range(-1, rows):
		var tile := base + k                       # absolute, world-anchored
		var y := tile * period - scroll + 60.0     # smooth projection to screen
		# two gateways per row, staggered, each with a stable per-tile shape
		_gateway(vp.x * 0.30 + ox, y, scale, col, tile)
		_gateway(vp.x * 0.74 + ox, y + period * 0.45, scale * 0.85, col, tile * 7 + 3)

# a ruined stone gateway silhouette: two pillars + a broken lintel
func _gateway(cx: float, y: float, s: float, col: Color, seed: int) -> void:
	var pw := 30.0 * s
	var ph := (150.0 + posmod(seed, 3) * 26.0) * s
	var gap := 110.0 * s
	draw_rect(Rect2(cx - gap * 0.5 - pw, y, pw, ph), col)
	draw_rect(Rect2(cx + gap * 0.5, y, pw, ph * 0.86), col)   # one pillar broken shorter
	# lintel across the top, with a chunk missing on the right (ruined)
	draw_rect(Rect2(cx - gap * 0.5 - pw, y - 24.0 * s, gap + pw * 1.4, 24.0 * s), col)

# positive modulo (GDScript fmod can return negative)
static func fmodp(a: float, b: float) -> float:
	return fmod(fmod(a, b) + b, b)
