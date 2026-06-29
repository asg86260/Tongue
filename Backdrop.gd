extends ParallaxBackground

# Jump-King-style layered parallax, built from the Ansimuz mist-forest background
# (same art family as the platform tiles, so it's cohesive). ParallaxBackground
# auto-follows the active Camera2D; each layer tiles infinitely via motion_mirroring.
# Far layers barely move; nearer layers drift more as you climb.

const L_BACK := preload("res://assets/bg/mist-back.png")
const L_BACKTREES := preload("res://assets/bg/mist-back-trees.png")
const L_TREE := preload("res://assets/bg/mist-tree.png")
const L_ROCKS := preload("res://assets/bg/mist-rocks.png")

func _ready() -> void:
	layer = -10   # ParallaxBackground is a CanvasLayer — sit behind the world
	# far → near: motion_scale grows so nearer layers parallax more
	_layer(L_BACK, Vector2(0.10, 0.06), 3.4)
	_layer(L_BACKTREES, Vector2(0.16, 0.10), 3.4)
	_layer(L_TREE, Vector2(0.26, 0.16), 3.2)
	_layer(L_ROCKS, Vector2(0.40, 0.26), 3.0)

func _layer(tex: Texture2D, motion: Vector2, scl: float) -> void:
	var pl := ParallaxLayer.new()
	pl.motion_scale = motion
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2(scl, scl)
	pl.add_child(spr)
	# tile infinitely in both axes so it always fills, regardless of climb height
	pl.motion_mirroring = Vector2(tex.get_width() * scl, tex.get_height() * scl)
	add_child(pl)
