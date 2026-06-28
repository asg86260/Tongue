extends CanvasLayer

# In-game pause overlay. Esc toggles it (and pauses the tree). Runs while paused
# (process_mode ALWAYS). Instanced by Game. Offers Resume / Restart / Settings /
# Quit to Title. Shares the Settings overlay with the Title screen.

const Ui := preload("res://Ui.gd")
const SettingsScene := preload("res://Settings.gd")
const TITLE_PATH := "res://Title.tscn"

var _root: Control
var _settings: Control = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep working while the tree is paused
	layer = 10
	visible = false

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Ui.SCRIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Ui.card_box())
	center.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(300, 0)
	card.add_child(box)

	box.add_child(Ui.heading("PAUSED", Ui.MOSS, 42))

	_add(box, Ui.button("Resume"), _resume)
	_add(box, Ui.button("Restart"), _restart)
	_add(box, Ui.button("Settings"), _open_settings)
	_add(box, Ui.button("Quit to Title", Ui.TONGUE), _quit_to_title)

func _add(box: VBoxContainer, b: Button, cb: Callable) -> void:
	b.pressed.connect(cb)
	box.add_child(b)

func _unhandled_input(event: InputEvent) -> void:
	if _settings != null:
		return   # settings overlay handles its own Esc
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if visible:
			_resume()
		else:
			_pause()

func _pause() -> void:
	visible = true
	get_tree().paused = true

func _resume() -> void:
	visible = false
	get_tree().paused = false

func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _open_settings() -> void:
	_root.visible = false
	_settings = SettingsScene.new()
	_settings.process_mode = Node.PROCESS_MODE_ALWAYS
	_settings.closed.connect(_on_settings_closed)
	add_child(_settings)

func _on_settings_closed() -> void:
	_settings = null
	_root.visible = true

func _quit_to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_PATH)
