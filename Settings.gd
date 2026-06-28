extends Control

# Reusable settings overlay (volume + fullscreen), built in code. Instanced by both
# the Title screen and the in-game pause menu. Emits `closed` when the player backs out.
# Reads/writes the Save autoload so changes persist immediately.

signal closed

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # swallow clicks meant for the menu

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.06, 0.08, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.custom_minimum_size = Vector2(360, 0)
	center.add_child(box)

	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	box.add_child(title)

	# volume row
	var vrow := HBoxContainer.new()
	vrow.add_theme_constant_override("separation", 12)
	box.add_child(vrow)
	var vlabel := Label.new()
	vlabel.text = "Volume"
	vlabel.custom_minimum_size = Vector2(130, 0)
	vlabel.add_theme_font_size_override("font_size", 22)
	vrow.add_child(vlabel)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = Save.volume
	slider.custom_minimum_size = Vector2(200, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(v): Save.set_volume(v))
	vrow.add_child(slider)

	# fullscreen row
	var frow := HBoxContainer.new()
	frow.add_theme_constant_override("separation", 12)
	box.add_child(frow)
	var flabel := Label.new()
	flabel.text = "Fullscreen"
	flabel.custom_minimum_size = Vector2(130, 0)
	flabel.add_theme_font_size_override("font_size", 22)
	frow.add_child(flabel)
	var check := CheckButton.new()
	check.button_pressed = Save.fullscreen
	check.toggled.connect(func(on): Save.set_fullscreen(on))
	frow.add_child(check)

	# back
	var back := Button.new()
	back.text = "Back"
	back.add_theme_font_size_override("font_size", 24)
	back.pressed.connect(_close)
	box.add_child(back)

func _close() -> void:
	closed.emit()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	# Esc backs out of settings (handled here so it doesn't bubble to pause toggle)
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_close()
