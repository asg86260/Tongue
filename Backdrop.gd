extends ParallaxBackground

# Layered parallax forest (Ansimuz mist-forest), cohesive with the platform tiles.
# Tiling is handled carefully:
#   - sky (mist-back): light-top/dark-bottom gradient → PINNED vertically (no v-tiling),
#     tiled horizontally (it's h-seamless). Never seams while climbing.
#   - back-trees: fully seamless (transparent edges) → tiled tight both axes.
#   - tree (big tree): foliage touches its top edge, so tiling it tight CLIPS the
#     foliage. Tiled with a vertical GAP (period > height) so trees are spaced by sky
#     and the foliage is never cut.
# The layer sprites are tinted each frame by Biome.tint(height) so the forest shifts
# mood as you climb (Woods → Ruins → Cliffs → Peak).

const Biome := preload("res://Biome.gd")
const L_BACK := preload("res://assets/bg/mist-back.png")
const L_BACKTREES := preload("res://assets/bg/mist-back-trees.png")
const L_TREE := preload("res://assets/bg/mist-tree.png")
const SPAWN_Y := -40.0   # matches LevelData spawn; height ≈ (SPAWN_Y - y)/100

var target: Node2D
var _sprites: Array[Sprite2D] = []

func _ready() -> void:
	layer = -10
	_layer(L_BACK, Vector2(0.06, 0.0), 3.4, 0.0)        # pinned sky, no vertical tiling
	_layer(L_BACKTREES, Vector2(0.13, 0.10), 3.2, 1.0)  # seamless → tile tight
	_layer(L_TREE, Vector2(0.24, 0.18), 3.0, 1.45)      # big tree → vertical gap, no clip

# vtile: 0 = no vertical tiling; >0 = vertical repeat period as a multiple of height
# (>1 leaves a transparent sky gap between stacked copies so foliage isn't clipped).
func _layer(tex: Texture2D, motion: Vector2, scl: float, vtile: float) -> void:
	var pl := ParallaxLayer.new()
	pl.motion_scale = motion
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2(scl, scl)
	pl.add_child(spr)
	_sprites.append(spr)
	var vh := tex.get_height() * scl * vtile if vtile > 0.0 else 0.0
	pl.motion_mirroring = Vector2(tex.get_width() * scl, vh)
	add_child(pl)

func _process(_d: float) -> void:
	if not target:
		return
	var t := Biome.tint((SPAWN_Y - target.global_position.y) / 100.0)
	for s in _sprites:
		s.modulate = t
