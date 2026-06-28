extends RefCounted

# Shared menu styling so every screen reads as one game. Arcade pixel-slabs on slate:
# moss-green (the frog) leads, amber (grapple knobs) marks data, tongue-pink warns.
# Hard edges, no rounding, a thick bottom border for slab depth.

const INK := Color("12161a")        # background slate
const PANEL := Color("1b2128")      # slab fill
const PANEL_HI := Color("232c34")   # slab fill, hovered
const PANEL_LO := Color("0f1318")   # slab fill, pressed
const CARD := Color(0.08, 0.10, 0.13, 0.95)   # overlay card
const SCRIM := Color(0.04, 0.05, 0.07, 0.78)  # dim behind overlays
const MOSS := Color("6bd46b")       # primary (the frog)
const MOSS_DIM := Color("3f7a45")   # quiet borders
const AMBER := Color("f2a63f")      # data / highlights (grapple knobs)
const TONGUE := Color("f2728c")     # danger / quit
const MIST := Color("9aa6b2")       # muted text
const BONE := Color("e8edf2")       # bright text

static func _box(bg: Color, border: Color, top := 8, bottom := 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(0)        # arcade hard edges
	s.set_border_width_all(2)
	s.border_width_bottom = 4         # slab depth
	s.border_color = border
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.content_margin_top = top
	s.content_margin_bottom = bottom
	return s

# A slab button. `accent` recolors the border/hover text (TONGUE for Quit, etc.).
static func button(text: String, accent := MOSS) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", BONE)
	b.add_theme_color_override("font_hover_color", accent)
	b.add_theme_color_override("font_focus_color", accent)
	b.add_theme_color_override("font_pressed_color", accent)
	b.add_theme_stylebox_override("normal", _box(PANEL, MOSS_DIM))
	b.add_theme_stylebox_override("hover", _box(PANEL_HI, accent))
	b.add_theme_stylebox_override("pressed", _box(PANEL_LO, accent, 10, 4))
	b.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), accent))
	return b

# The wordmark: chunky moss with a hard pixel drop-shadow.
static func wordmark(text: String, size := 96) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", MOSS)
	l.add_theme_color_override("font_shadow_color", Color("08110a"))
	l.add_theme_constant_override("shadow_offset_x", 5)
	l.add_theme_constant_override("shadow_offset_y", 6)
	l.add_theme_constant_override("shadow_outline_size", 0)
	return l

# Smaller heading for overlay panels (PAUSED / SETTINGS).
static func heading(text: String, col := BONE, size := 38) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

static func text(s: String, col := MIST, size := 18) -> Label:
	var l := Label.new()
	l.text = s
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

static func card_box() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = CARD
	s.set_corner_radius_all(0)
	s.set_border_width_all(2)
	s.border_width_bottom = 5
	s.border_color = MOSS_DIM
	s.set_content_margin_all(34)
	return s

# A thin tongue-pink rule — the signature mark under the wordmark.
static func tongue_rule(width: int) -> Control:
	var r := ColorRect.new()
	r.color = TONGUE
	r.custom_minimum_size = Vector2(width, 5)
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return r
