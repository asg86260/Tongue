extends Control

# Title screen (boot scene). Shows the game name + best stats and offers
# Play / Settings / Quit. Built in code; shares the Settings overlay with pause.

const SettingsScene := preload("res://Settings.gd")
const GAME_PATH := "res://Main.tscn"

var _menu: Control
var _settings: Control = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.11, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_menu = Control.new()
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_menu)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(320, 0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	var title := Label.new()
	title.text = "TONGUE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 88)
	title.add_theme_color_override("font_color", Color(0.55, 0.9, 0.55))
	box.add_child(title)

	var sub := Label.new()
	sub.text = "swing the tower. tongue the fly at the top."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	box.add_child(sub)

	var stats := Label.new()
	stats.text = _stats_text()
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 16)
	stats.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	box.add_child(stats)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	box.add_child(spacer)

	_add_button(box, "Play", _play)
	_add_button(box, "Settings", _open_settings)
	_add_button(box, "Quit", _quit)

func _stats_text() -> String:
	if Save.best_height <= 0 and Save.best_time <= 0.0:
		return "no climbs yet — get to the top!"
	var t := "best time —" if Save.best_time <= 0.0 else "best time %.2fs" % Save.best_time
	return "best height %d    %s    flies %d" % [Save.best_height, t, Save.flies_found]

func _add_button(box: VBoxContainer, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 28)
	b.pressed.connect(cb)
	box.add_child(b)

func _play() -> void:
	get_tree().change_scene_to_file(GAME_PATH)

func _quit() -> void:
	get_tree().quit()

func _open_settings() -> void:
	_menu.visible = false
	_settings = SettingsScene.new()
	_settings.closed.connect(_on_settings_closed)
	add_child(_settings)

func _on_settings_closed() -> void:
	_settings = null
	_menu.visible = true
