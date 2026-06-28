extends Node

# Autoload singleton (registered as "Save"). Persists best stats + settings to
# user://save.cfg and applies audio/display settings on boot.

const PATH := "user://save.cfg"

# ---- stats ----
var best_time := 0.0       # best (lowest) winning time in seconds; 0.0 = none yet
var best_height := 0       # highest height reached, any run
var flies_found := 0       # most flies snagged in a single run

# ---- settings ----
var volume := 1.0          # master volume, 0..1 linear
var fullscreen := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # F11 must work even while paused
	load_data()
	# defer so the main window exists before we set its mode on boot
	apply_settings.call_deferred()

func _input(event: InputEvent) -> void:
	# global F11 fullscreen toggle (works anywhere, independent of the menus)
	if event.is_action_pressed("fullscreen"):
		set_fullscreen(not fullscreen)

func load_data() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return   # no save yet — keep defaults
	best_time = cfg.get_value("stats", "best_time", 0.0)
	best_height = cfg.get_value("stats", "best_height", 0)
	flies_found = cfg.get_value("stats", "flies_found", 0)
	volume = cfg.get_value("settings", "volume", 1.0)
	fullscreen = cfg.get_value("settings", "fullscreen", false)

func save_data() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("stats", "best_time", best_time)
	cfg.set_value("stats", "best_height", best_height)
	cfg.set_value("stats", "flies_found", flies_found)
	cfg.set_value("settings", "volume", volume)
	cfg.set_value("settings", "fullscreen", fullscreen)
	cfg.save(PATH)

func apply_settings() -> void:
	var db := linear_to_db(volume) if volume > 0.0005 else -80.0
	AudioServer.set_bus_volume_db(0, db)
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)

func set_volume(v: float) -> void:
	volume = clamp(v, 0.0, 1.0)
	apply_settings()
	save_data()

func set_fullscreen(on: bool) -> void:
	fullscreen = on
	apply_settings()
	save_data()

# Record the outcome of a run; persists only if it beat a previous best.
func record_run(height: int, time: float, won: bool, flies: int) -> void:
	var changed := false
	if height > best_height:
		best_height = height
		changed = true
	if won and (best_time == 0.0 or time < best_time):
		best_time = time
		changed = true
	if flies > flies_found:
		flies_found = flies
		changed = true
	if changed:
		save_data()
