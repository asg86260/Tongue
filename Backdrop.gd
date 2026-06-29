extends ParallaxBackground

# Per-biome parallax SCENES with height crossfades (Jump-King zones):
#   Woods  — misty green forest (tiles vertically; trees repeat up the climb)
#   Ruins  — purple misty peaks  (Mountain-Dusk B)
#   Cliffs — red dusk mountains + moon (Mountain-Dusk A)
#   Peak   — orange canyon summit (Mountain-Dusk C)
# Every biome's layers are always present; each biome's alpha fades in as you reach
# its band and sits OPAQUE on top of the one below (sky layers are opaque), so the
# scene visibly transforms as you climb and reverses if you fall.
#
# Tiling: all sky layers are h-seamless + opaque (pinned, no vertical tiling). The
# mountain/tree layers are h-seamless with transparent tops and sit near the horizon
# at low vertical parallax — so they never need vertical tiling (no seams). The forest
# is the exception: its tree layers tile vertically (with a gap so foliage isn't clipped).

const SPAWN_Y := -40.0
const FADE_M := 4.0   # crossfade over the last 4m before a biome's start height

var target: Node2D
var _biomes: Array = []   # each: { "start": float, "sprites": Array[Sprite2D] }

# layer def = [texture, motion:Vector2, scale:float, vtile:float]  (vtile 0 = no v-tiling)
# Woods, treated like the mountain scenes: a non-repeating backdrop (no vertical
# tiling) so its gradient/trees never seam or cut. Sky pinned, trees near the horizon.
func _woods() -> Array: return [
	[preload("res://assets/bg/mist-back.png"),       Vector2(0.04, 0.00), 3.4, 0.0],
	[preload("res://assets/bg/mist-back-trees.png"), Vector2(0.08, 0.05), 3.2, 0.0],
	[preload("res://assets/bg/mist-tree.png"),       Vector2(0.14, 0.10), 3.0, 0.0],
]
func _scene(p: String) -> Array: return [
	[load("res://assets/bg/%s-sky.png" % p),   Vector2(0.04, 0.00), 3.2, 0.0],
	[load("res://assets/bg/%s-mid.png" % p),   Vector2(0.08, 0.05), 3.2, 0.0],
	[load("res://assets/bg/%s-front.png" % p), Vector2(0.14, 0.10), 3.2, 0.0],
]

func _ready() -> void:
	layer = -10
	get_viewport().size_changed.connect(_rebuild)
	_rebuild()

# Rebuild all layers sized to the CURRENT viewport, so the backdrop fills any window
# (windowed or fullscreen) with no cut-off, and no vertical tiling.
func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	_biomes.clear()
	var vp := get_viewport().get_visible_rect().size
	var fill := vp.y / 760.0        # scale layers up so they fill the viewport height
	var span := maxf(vp.x * 1.5, 1800.0)
	_build(0.0, _woods(), fill, span)
	_build(13.0, _scene("ruins"), fill, span)
	_build(27.0, _scene("cliffs"), fill, span)
	_build(40.0, _scene("peak"), fill, span)

func _build(start: float, defs: Array, fill: float, span: float) -> void:
	var sprites: Array = []
	for d in defs:
		var tex: Texture2D = d[0]
		var scl: float = d[2] * fill
		var w := tex.get_width() * scl
		var pl := ParallaxLayer.new()
		pl.motion_scale = d[1]
		# explicit horizontal copies spanning the viewport (count scales with width, so
		# even a 32px gradient fills) — robust coverage with no vertical tiling.
		var num: int = int(ceil(span / w)) + 1
		for i in range(-num, num + 1):
			var spr := Sprite2D.new()
			spr.texture = tex
			spr.centered = false
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			spr.scale = Vector2(scl, scl)
			spr.position = Vector2(i * w, 0)
			pl.add_child(spr)
			sprites.append(spr)
		add_child(pl)
	_biomes.append({ "start": start, "sprites": sprites })

func _process(_d: float) -> void:
	if not target:
		return
	var hm := (SPAWN_Y - target.global_position.y) / 100.0
	for i in _biomes.size():
		var b: Dictionary = _biomes[i]
		var a := 1.0
		if i > 0:
			a = clampf((hm - (b["start"] - FADE_M)) / FADE_M, 0.0, 1.0)
		for s in b["sprites"]:
			s.modulate.a = a
