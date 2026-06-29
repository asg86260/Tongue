extends ParallaxBackground

# Jump-King-style layered parallax, built from the Ansimuz mist-forest background
# (same art family as the platform tiles, so it's cohesive). ParallaxBackground
# auto-follows the active Camera2D; each layer tiles infinitely via motion_mirroring.
# Far layers barely move; nearer layers drift more as you climb.

const L_BACK := preload("res://assets/bg/mist-back.png")
const L_BACKTREES := preload("res://assets/bg/mist-back-trees.png")
const L_TREE := preload("res://assets/bg/mist-tree.png")

func _ready() -> void:
	layer = -10   # ParallaxBackground is a CanvasLayer — sit behind the world
	# Sky gradient is pinned vertically (motion.y = 0, no vertical tiling) so its
	# light-top/dark-bottom gradient never seams while climbing.
	_layer(L_BACK, Vector2(0.06, 0.0), 3.4, false)
	# Transparent tree layers parallax + tile vertically — repeating trees read as
	# a continuous forest the whole way up. Nearer layers move more.
	_layer(L_BACKTREES, Vector2(0.14, 0.09), 3.2, true)
	_layer(L_TREE, Vector2(0.24, 0.16), 3.0, true)

func _layer(tex: Texture2D, motion: Vector2, scl: float, tile_v: bool) -> void:
	var pl := ParallaxLayer.new()
	pl.motion_scale = motion
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2(scl, scl)
	pl.add_child(spr)
	var h := tex.get_height() * scl if tile_v else 0.0
	pl.motion_mirroring = Vector2(tex.get_width() * scl, h)
	add_child(pl)
