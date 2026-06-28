extends Control

# Title screen (boot scene). Shows the game name + best stats and offers
# Play / Settings / Quit. Built in code; shares the Settings overlay with pause.

const Ui := preload("res://Ui.gd")
const SettingsScene := preload("res://Settings.gd")
const GAME_PATH := "res://Main.tscn"

var _menu: Control
var _settings: Control = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Ui.INK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_menu = Control.new()
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_menu)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(340, 0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	box.add_child(Ui.wordmark("TONGUE", 100))
	box.add_child(Ui.tongue_rule(220))

	var sub := Ui.text("swing the tower. tongue the fly at the top.", Ui.MIST, 18)
	box.add_child(sub)

	box.add_child(_stats_label())

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	box.add_child(spacer)

	_add(box, Ui.button("Play", Ui.MOSS), _play)
	_add(box, Ui.button("Settings", Ui.MOSS), _open_settings)
	_add(box, Ui.button("Quit", Ui.TONGUE), _quit)

func _stats_label() -> Label:
	var s: String
	if Save.best_height <= 0 and Save.best_time <= 0.0:
		s = "no climbs yet — get to the top"
	else:
		var t := "—" if Save.best_time <= 0.0 else "%.2fs" % Save.best_time
		s = "best  %dm     time  %s     flies  %d" % [Save.best_height, t, Save.flies_found]
	return Ui.text(s, Ui.AMBER, 16)

func _add(box: VBoxContainer, b: Button, cb: Callable) -> void:
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
