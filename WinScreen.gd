extends CanvasLayer

# Shown when the frog tongues the summit fly. A translucent card (the celebration
# still plays behind it) with the run's stats and Retry / Quit to Title.
# Instanced hidden by Game; revealed via show_win(...).

const TITLE_PATH := "res://Title.tscn"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 12
	visible = false

func show_win(time: float, flies: int, fly_total: int, height: int, new_best: bool) -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE   # let the celebration show; only buttons grab
	add_child(root)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.09, 0.11, 0.88)
	sb.set_content_margin_all(28)
	sb.set_corner_radius_all(8)
	card.add_theme_stylebox_override("panel", sb)
	center.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(300, 0)
	card.add_child(box)

	var title := Label.new()
	title.text = "GOT THE FLY!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.6, 0.95, 0.55))
	box.add_child(title)

	if new_best:
		var nb := Label.new()
		nb.text = "★ NEW BEST ★"
		nb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nb.add_theme_font_size_override("font_size", 22)
		nb.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		box.add_child(nb)

	var stats := Label.new()
	stats.text = "time  %.2fs\nheight  %dm\nflies  %d / %d" % [time, height, flies, fly_total]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 22)
	box.add_child(stats)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	box.add_child(spacer)

	_add_button(box, "Retry", _retry)
	_add_button(box, "Quit to Title", _quit_to_title)

	visible = true

func _add_button(box: VBoxContainer, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(cb)
	box.add_child(b)

func _retry() -> void:
	get_tree().reload_current_scene()

func _quit_to_title() -> void:
	get_tree().change_scene_to_file(TITLE_PATH)
