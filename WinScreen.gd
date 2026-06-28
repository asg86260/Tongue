extends CanvasLayer

# Shown when the frog tongues the summit fly. A translucent card (the celebration
# still plays behind it) with the run's stats and Retry / Quit to Title.
# Instanced hidden by Game; revealed via show_win(...).

const Ui := preload("res://Ui.gd")
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
	card.add_theme_stylebox_override("panel", Ui.card_box())
	center.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(320, 0)
	card.add_child(box)

	box.add_child(Ui.heading("GOT THE FLY", Ui.MOSS, 48))
	box.add_child(Ui.tongue_rule(180))

	if new_best:
		box.add_child(Ui.text("★ NEW BEST ★", Ui.AMBER, 22))

	box.add_child(Ui.text("time  %.2fs" % time, Ui.BONE, 22))
	box.add_child(Ui.text("height  %dm     flies  %d / %d" % [height, flies, fly_total], Ui.AMBER, 18))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	box.add_child(spacer)

	_add(box, Ui.button("Retry"), _retry)
	_add(box, Ui.button("Quit to Title", Ui.TONGUE), _quit_to_title)

	visible = true

func _add(box: VBoxContainer, b: Button, cb: Callable) -> void:
	b.pressed.connect(cb)
	box.add_child(b)

func _retry() -> void:
	get_tree().reload_current_scene()

func _quit_to_title() -> void:
	get_tree().change_scene_to_file(TITLE_PATH)
