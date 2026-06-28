extends Control

# Reusable settings overlay (volume + fullscreen), built in code. Instanced by both
# the Title screen and the in-game pause menu. Emits `closed` when the player backs out.
# Reads/writes the Save autoload so changes persist immediately.

const Ui := preload("res://Ui.gd")

signal closed

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # swallow clicks meant for the menu

	var dim := ColorRect.new()
	dim.color = Ui.SCRIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Ui.card_box())
	center.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	box.custom_minimum_size = Vector2(380, 0)
	card.add_child(box)

	box.add_child(Ui.heading("SETTINGS"))

	# volume row
	var vrow := HBoxContainer.new()
	vrow.add_theme_constant_override("separation", 14)
	box.add_child(vrow)
	var vlabel := Ui.text("Volume", Ui.MIST, 22)
	vlabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vlabel.custom_minimum_size = Vector2(130, 0)
	vrow.add_child(vlabel)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = Save.volume
	slider.custom_minimum_size = Vector2(200, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(func(v): Save.set_volume(v))
	vrow.add_child(slider)

	# fullscreen row
	var frow := HBoxContainer.new()
	frow.add_theme_constant_override("separation", 14)
	box.add_child(frow)
	var flabel := Ui.text("Fullscreen", Ui.MIST, 22)
	flabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	flabel.custom_minimum_size = Vector2(130, 0)
	frow.add_child(flabel)
	var check := CheckButton.new()
	check.button_pressed = Save.fullscreen
	check.toggled.connect(func(on): Save.set_fullscreen(on))
	frow.add_child(check)

	var back := Ui.button("Back")
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
