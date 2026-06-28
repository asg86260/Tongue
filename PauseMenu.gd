extends CanvasLayer

# In-game pause overlay. Esc toggles it (and pauses the tree). Runs while paused
# (process_mode ALWAYS). Instanced by Game. Offers Resume / Restart / Settings /
# Quit to Title. Shares the Settings overlay with the Title screen.

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
	dim.color = Color(0.05, 0.06, 0.08, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.custom_minimum_size = Vector2(300, 0)
	center.add_child(box)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	box.add_child(title)

	_add_button(box, "Resume", _resume)
	_add_button(box, "Restart", _restart)
	_add_button(box, "Settings", _open_settings)
	_add_button(box, "Quit to Title", _quit_to_title)

func _add_button(box: VBoxContainer, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 26)
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
