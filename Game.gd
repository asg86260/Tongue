extends Node2D

# Controller: builds the level and the player, owns the camera/UI/SFX, the run clock
# and win state, and does all the world drawing. The frog lives in Player.gd and calls
# back into here for fly-catching and juice (catch_at / gulp / add_pop / add_shake / play_sfx).

const LevelData := preload("res://LevelData.gd")
const PlayerScene := preload("res://Player.gd")  # also used as the type of `player`
const PauseMenuScene := preload("res://PauseMenu.gd")
const WinScreenScene := preload("res://WinScreen.gd")

const PIX := 2.6              # pixel-cell size for the chunky pixel-art draw helpers
const GOAL_CATCH_R := 36.0    # tongue must touch this close to the goal fly to win
const FLY_CATCH_R := 26.0     # tongue snag radius for collectible flies

var player: PlayerScene
var win_screen: CanvasLayer
var cam: Camera2D
var label: Label
var start_y := 0.0
var best := 0.0
# ---- height milestones ----
const MILESTONE_M := 10        # draw a marker line every this many metres (100px = 1m)
var start_best := 0            # the saved best height at run start (for the "new best" flourish)
var milestone_reached := 0     # highest milestone metre we've already celebrated this run
var beat_best := false         # fired the "new best" flourish yet?
var best_flash := 0.0          # HUD "NEW BEST" banner timer
# ---- run / goal state ----
var goal_pos := Vector2.ZERO
var goal_r := 46.0
var flies: Array = []         # each {pos:Vector2, caught:bool} — snag with the tongue
var fly_count := 0
var fly_total := 0
var level_spawn := Vector2(0, -40)   # where the frog starts (set from level data)
var won := false
var run_started := false
var run_time := 0.0
var win_time := 0.0
var flap := 0.0
# ---- juice ----
var shake := 0.0
var pops: Array = []          # each: {pos:Vector2, t:float, life:float, col:Color}
var sfx_stick: AudioStreamPlayer
var sfx_hop: AudioStreamPlayer
var sfx_win: AudioStreamPlayer
var sfx_eat: AudioStreamPlayer
# ---- free-cam / god mode (inspect the level) ----
var freecam: Camera2D
var free_mode := false
var free_was := false
var free_zoom := 1.0
# ---- level decoration ----
var anchor_knobs: Array = []   # Vector2 positions of grapple-only knobs (drawn as amber rings)
var warp_points: Array[Vector2] = []   # dev tool: number keys teleport to each landing

func _ready() -> void:
	_build_level()
	_build_player()
	_build_camera()
	_build_ui()
	_build_sfx()
	add_child(PauseMenuScene.new())
	win_screen = WinScreenScene.new()
	add_child(win_screen)
	start_best = Save.best_height

func _make_static(pos: Vector2, size: Vector2, col := Color(0.30, 0.27, 0.33)) -> void:
	var sb := StaticBody2D.new()
	sb.position = pos
	sb.collision_layer = 1
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	cs.shape = shape
	sb.add_child(cs)
	var poly := Polygon2D.new()
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	poly.polygon = PackedVector2Array([
		Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)])
	poly.color = col
	sb.add_child(poly)
	add_child(sb)

func _make_anchor(pos: Vector2, r: float) -> void:
	# a small circular grapple-only knob: real collision (so the tongue sticks),
	# too small to land on, drawn as an amber pixel ring in _draw()
	var sb := StaticBody2D.new()
	sb.position = pos
	sb.collision_layer = 1
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = r
	cs.shape = shape
	sb.add_child(cs)
	add_child(sb)
	anchor_knobs.append(pos)

func _build_level() -> void:
	var lv := LevelData.tower()
	level_spawn = lv["spawn"]
	var g = lv["ground"]
	_make_static(Vector2(g[0], g[1]), Vector2(g[2], g[3]), Color(0.22, 0.30, 0.24))
	for p in lv["platforms"]:
		_make_static(Vector2(p[0], p[1]), Vector2(p[2], p[3]))
	# overhead slabs you grapple the underside of (stone grey-blue)
	for c in lv.get("ceilings", []):
		_make_static(Vector2(c[0], c[1]), Vector2(c[2], c[3]), Color(0.34, 0.34, 0.40))
	# landings: narrow skill-check ledges (no safe-rest affordance — drawn like platforms)
	for p in lv.get("perches", []):
		_make_static(Vector2(p[0], p[1]), Vector2(p[2], p[3]))
		warp_points.append(Vector2(p[0], p[1] - p[3] * 0.5 - 30))   # just above the ledge
	# grapple-only knobs
	for a in lv.get("anchors", []):
		_make_anchor(Vector2(a[0], a[1]), a[2])
	# collectible flies
	flies.clear()
	for f in lv.get("flies", []):
		flies.append({"pos": Vector2(f[0], f[1]), "caught": false})
	fly_total = flies.size()
	fly_count = 0
	goal_pos = lv["goal"]

func _build_player() -> void:
	player = PlayerScene.new()
	player.controller = self
	player.position = level_spawn
	add_child(player)
	start_y = player.position.y

func _build_camera() -> void:
	cam = Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	player.add_child(cam)
	cam.make_current()
	# detached free-cam lives on the scene root (god-mode inspection)
	freecam = Camera2D.new()
	freecam.position = player.position
	add_child(freecam)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	label = Label.new()
	label.position = Vector2(16, 12)
	label.add_theme_color_override("font_color", Color.WHITE)
	layer.add_child(label)

# ---- procedural SFX (no asset files) ----
func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clamp(samples[i], -1.0, 1.0) * 32767.0)
		bytes[i * 2] = v & 0xFF
		bytes[i * 2 + 1] = (v >> 8) & 0xFF
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 22050
	w.stereo = false
	w.data = bytes
	return w

func _tone_player(stream: AudioStreamWAV, vol_db := -6.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = vol_db
	add_child(p)
	return p

func _build_sfx() -> void:
	var sr := 22050.0
	# thwck: short noisy click with a downward pitch, snappy decay
	var s1 := PackedFloat32Array()
	var n1 := int(sr * 0.09)
	for i in n1:
		var t := i / sr
		var env: float = exp(-t * 38.0)
		var f: float = 420.0 - 1800.0 * t
		var tone := sin(TAU * f * t)
		var noise := randf_range(-1.0, 1.0) * 0.5
		s1.append((tone * 0.6 + noise * 0.4) * env)
	# hop: quick rising blip
	var s2 := PackedFloat32Array()
	var n2 := int(sr * 0.12)
	for i in n2:
		var t := i / sr
		var env: float = exp(-t * 16.0)
		var f: float = 260.0 + 520.0 * t
		s2.append(sin(TAU * f * t) * env * 0.7)
	# win: little 3-note arpeggio chime
	var s3 := PackedFloat32Array()
	var notes := [523.25, 659.25, 880.0]   # C5 E5 A5
	var seg := 0.16
	var n3 := int(sr * seg * notes.size())
	for i in n3:
		var t := i / sr
		var idx: int = min(int(t / seg), notes.size() - 1)
		var lt := t - idx * seg
		var env: float = exp(-lt * 7.0)
		s3.append(sin(TAU * notes[idx] * lt) * env * 0.6)
	# gulp: short low downward blip (swallowing the fly)
	var s4 := PackedFloat32Array()
	var n4 := int(sr * 0.08)
	for i in n4:
		var t := i / sr
		var env: float = exp(-t * 24.0)
		var f: float = 200.0 - 700.0 * t
		s4.append(sin(TAU * maxf(f, 40.0) * t) * env * 0.7)
	sfx_stick = _tone_player(_wav(s1))
	sfx_hop = _tone_player(_wav(s2))
	sfx_win = _tone_player(_wav(s3), -2.0)
	sfx_eat = _tone_player(_wav(s4), -4.0)

func _height() -> int:
	return int((start_y - player.global_position.y) / 100.0)

# ---- callbacks the Player uses ----
func add_pop(pos: Vector2, life: float, col: Color) -> void:
	pops.append({"pos": pos, "t": 0.0, "life": life, "col": col})

func add_shake(amount: float) -> void:
	shake = max(shake, amount)

func play_sfx(name: String) -> void:
	var p: AudioStreamPlayer = null
	match name:
		"stick": p = sfx_stick
		"hop":   p = sfx_hop
		"win":   p = sfx_win
		"eat":   p = sfx_eat
	if p:
		p.play()

# The extending tongue tip reached `tip`: try to snag a fly or the goal. Marks the fly
# caught and plays the catch fx here; returns 0 none, 1 fly, 2 goal (Player handles carry).
func catch_at(tip: Vector2) -> int:
	for f in flies:
		if not f["caught"] and tip.distance_to(f["pos"]) < FLY_CATCH_R:
			f["caught"] = true
			add_shake(4.0)
			add_pop(f["pos"], 0.28, Color(0.7, 0.95, 0.5))
			play_sfx("stick")
			return 1
	if tip.distance_to(goal_pos) < GOAL_CATCH_R:
		win_time = run_time          # freeze the clock at the catch (the skill moment)
		add_shake(8.0)
		add_pop(goal_pos, 0.4, Color(0.6, 0.9, 0.4))
		play_sfx("stick")
		return 2
	return 0

# the carried fly reached the mouth — swallow it (belly puff handled on the Player)
func gulp(is_goal: bool, mouth_pos: Vector2) -> void:
	add_shake(4.0)
	add_pop(mouth_pos, 0.3, Color(1.0, 1.0, 0.85))
	if is_goal:
		won = true
		player.active = false
		add_shake(16.0)
		add_pop(mouth_pos, 0.6, Color(1.0, 1.0, 0.7))
		play_sfx("win")
		var h := _height()
		var new_best := h > Save.best_height or Save.best_time == 0.0 or win_time < Save.best_time
		Save.record_run(h, win_time, true, fly_count)
		win_screen.show_win(win_time, fly_count, fly_total, h, new_best)
	else:
		fly_count += 1
		play_sfx("eat")

func _physics_process(delta: float) -> void:
	flap += delta
	if Input.is_action_pressed("reset"):
		Save.record_run(_height(), 0.0, false, fly_count)   # bank progress before wiping
		get_tree().reload_current_scene()
		return

	# free-cam / god mode toggle (F): freeze the frog, fly the camera around
	if Input.is_action_pressed("godcam") and not free_was:
		_toggle_freecam()
	free_was = Input.is_action_pressed("godcam")
	if free_mode:
		_freecam_update(delta)
		queue_redraw()
		return

	# run clock: starts the moment you leave the ground for real
	if not won:
		if run_started:
			run_time += delta
		if not run_started and not player.is_grounded() and player.global_position.y < start_y - 30.0:
			run_started = true
	if won:
		queue_redraw()
		return

	var h := (start_y - player.global_position.y) / 100.0
	best = max(best, h)
	_check_milestones(int(h))
	queue_redraw()

# fire a small flourish each new MILESTONE_M climbed, and a big one when beating the saved best
func _check_milestones(hm: int) -> void:
	while hm >= milestone_reached + MILESTONE_M:
		milestone_reached += MILESTONE_M
		add_pop(player.global_position, 0.45, Color(0.6, 0.95, 0.6))
		add_shake(2.5)
		play_sfx("hop")
	if not beat_best and start_best > 0 and hm > start_best:
		beat_best = true
		best_flash = 2.0
		add_pop(player.global_position, 0.7, Color(1.0, 0.95, 0.5))
		add_shake(8.0)
		play_sfx("win")

func _warp_to(i: int) -> void:
	player.global_position = warp_points[i]
	player.linear_velocity = Vector2.ZERO
	player.tstate = 0
	player.tlen = 0.0
	player.attached = false
	player.carrying = false
	player.carrying_goal = false
	player.has_tongue = true

func _toggle_freecam() -> void:
	free_mode = not free_mode
	player.freeze = free_mode      # park the frog while inspecting
	player.active = (not free_mode) and (not won)
	if free_mode:
		freecam.position = player.global_position
		freecam.zoom = Vector2(free_zoom, free_zoom)
		freecam.make_current()
	else:
		cam.make_current()

func _freecam_update(delta: float) -> void:
	var v := Vector2.ZERO
	if Input.is_action_pressed("move_left"):  v.x -= 1.0
	if Input.is_action_pressed("move_right"): v.x += 1.0
	if Input.is_action_pressed("move_up"):    v.y -= 1.0
	if Input.is_action_pressed("move_down"):  v.y += 1.0
	# pan speed scales inversely with zoom so it feels constant on screen
	freecam.position += v * (1100.0 * delta / free_zoom)
	if Input.is_action_pressed("zoom_in"):  free_zoom = minf(free_zoom * (1.0 + delta * 1.6), 4.0)
	if Input.is_action_pressed("zoom_out"): free_zoom = maxf(free_zoom * (1.0 - delta * 1.6), 0.06)
	freecam.zoom = Vector2(free_zoom, free_zoom)

func _unhandled_input(event: InputEvent) -> void:
	# dev tool: number keys 1..N warp the frog to each landing to drill a single section
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		var idx: int = k.physical_keycode - KEY_1
		if k.physical_keycode >= KEY_1 and k.physical_keycode <= KEY_9 and idx < warp_points.size():
			_warp_to(idx)
			return
	if not free_mode:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			free_zoom = minf(free_zoom * 1.12, 4.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			free_zoom = maxf(free_zoom * 0.88, 0.06)
		freecam.zoom = Vector2(free_zoom, free_zoom)

func _draw_milestones() -> void:
	# faint dotted height lines up the tower, labelled in metres (100px = 1m)
	var font := ThemeDB.fallback_font
	var top_m := int((start_y - goal_pos.y) / 100.0) + MILESTONE_M
	var m := MILESTONE_M
	while m <= top_m:
		var y := start_y - m * 100.0
		var passed := _height() >= m
		var line_col := Color(0.7, 0.9, 0.7, 0.14) if passed else Color(1, 1, 1, 0.07)
		_pixel_line_dotted(Vector2(-420, y), Vector2(1, 0), 1340, line_col, 3)
		if font:
			draw_string(font, Vector2(-470, y + 5), "%dm" % m,
				HORIZONTAL_ALIGNMENT_RIGHT, 44, 16, Color(0.8, 0.85, 0.9, 0.45))
		m += MILESTONE_M

func _draw() -> void:
	_draw_milestones()
	var bpos := player.global_position
	var col := Color(0.95, 0.45, 0.55)
	# speed trail: faded pixel ghost behind the body, brighter the faster you move
	var trail := player.trail
	if trail.size() > 2:
		for i in range(1, trail.size()):
			var a := float(i) / trail.size()
			var seg := (trail[i] - trail[i - 1]).length()
			var bright: float = clamp(seg / 18.0, 0.0, 1.0)
			if bright > 0.05:
				_draw_tongue(trail[i - 1], trail[i],
					Color(0.4, 0.85, 0.5, a * 0.5 * bright), 1.0 + a * 4.0)
	# pop rings (stick + win bursts)
	for p in pops:
		var k: float = p.t / p.life
		var r: float = 6.0 + k * 70.0
		var c: Color = p.col
		c.a = (1.0 - k) * 0.8
		_pixel_ring(p.pos, r, c)
	# grapple-only knobs: amber rings with a soft pulse (read as "aim here, don't land")
	var pulse: float = 13.0 + sin(flap * 4.0) * 2.0
	for kn in anchor_knobs:
		_pixel_ring(kn, pulse, Color(0.95, 0.65, 0.25, 0.85), 12)
		_pixel_dot(kn, 2, Color(1.0, 0.82, 0.4))
		_pixel_dot(kn, 1, Color(1.0, 0.95, 0.7))
	# collectible flies: small bobbing bugs (uncaught only), out-of-phase per fly
	for f in flies:
		if f["caught"]:
			continue
		var fp: Vector2 = f["pos"]
		var ph: float = fp.x * 0.05
		var cb := roundf(sin(flap * 3.5 + ph) * 4.0)
		var cpos := fp + Vector2(0, cb)
		var cw: int = 1 if sin(flap * 30.0 + ph) > 0.0 else 2
		_pixel_ring(cpos, 16.0, Color(0.8, 0.95, 0.6, 0.20), 10)   # faint catch halo
		_pixel_dot(cpos + Vector2(-6, 0), cw, Color(0.8, 0.9, 1.0, 0.8))
		_pixel_dot(cpos + Vector2(6, 0), cw, Color(0.8, 0.9, 1.0, 0.8))
		_pixel_dot(cpos, 1, Color(0.14, 0.14, 0.17))
	# the carried fly: stuck to the tongue tip as it snaps back, wings buzzing in panic
	if player.carrying and player.tstate == 3:
		var mp := player.mouth + player.aim_dir * player.tlen
		var mw: int = 1 if sin(flap * 60.0) > 0.0 else 2   # fast panicked flap
		_pixel_dot(mp + Vector2(-5, 0), mw, Color(0.85, 0.92, 1.0, 0.9))
		_pixel_dot(mp + Vector2(5, 0), mw, Color(0.85, 0.92, 1.0, 0.9))
		_pixel_dot(mp, 1, Color(0.12, 0.12, 0.15))
	# the goal fly: bobbing pixel bug + flapping wings (gone once snatched/eaten)
	if not player.carrying_goal and not won:
		var bob := roundf(sin(flap * 3.0) * 6.0)
		var fpos := goal_pos + Vector2(0, bob)
		var wing: int = 1 if sin(flap * 30.0) > 0.0 else 2   # 2-frame wing flap
		_pixel_ring(fpos, goal_r, Color(0.55, 0.85, 0.4, 0.18), 28)   # catch halo (dotted)
		_pixel_dot(fpos + Vector2(-9, 0), wing, Color(0.8, 0.9, 1.0, 0.8))
		_pixel_dot(fpos + Vector2(9, 0), wing, Color(0.8, 0.9, 1.0, 0.8))
		_pixel_dot(fpos, 2, Color(0.14, 0.14, 0.17))
		_pixel_dot(fpos + Vector2(0, -6), 1, Color(0.22, 0.22, 0.26))
	# (the frog itself is an AnimatedSprite2D child of the Player body)
	# reach cap ring + aim line (only when idle AND you still have your tongue)
	if player.tstate == 0 and not won and player.has_tongue:
		_pixel_ring(bpos, player.MAX_LEN, Color(1, 1, 1, 0.16), 80)   # dotted reach guide
		var dir := (get_global_mouse_position() - player.mouth)
		if dir.length() > 1.0:
			_pixel_line_dotted(player.mouth, dir.normalized(), player.MAX_LEN, Color(1, 1, 1, 0.30), 2)
	# tongue
	if player.tstate == 2:
		# stretch makes the tongue thinner + brighter, like it's under tension
		var dist := bpos.distance_to(player.anchor)
		var tension: float = clamp((dist - player.grab_len * player.PULL_FACTOR) / max(player.grab_len, 1.0), 0.0, 1.0)
		var w: float = lerp(7.0, 3.0, tension)
		var tc := col.lerp(Color(1.0, 0.7, 0.8), tension)
		_draw_tongue(player.mouth, player.anchor, tc, w)
		_pixel_dot(player.anchor, 2, tc)
		_pixel_dot(player.anchor, 1, Color(1, 1, 1, 0.9))   # sticky tip highlight
	elif player.tstate == 1 or player.tstate == 3:
		var tip: Vector2
		if player.thit and player.tstate == 1:
			tip = player.mouth + (player.anchor - player.mouth).normalized() * min(player.tlen, player.mouth.distance_to(player.anchor))
		else:
			tip = player.mouth + player.aim_dir * player.tlen
		_draw_tongue(player.mouth, tip, col, 5.0)
		_pixel_dot(tip, 2, col)

# the tongue, rasterized into pixel blocks sized to match the frog's pixels (scale 2.6),
# so it reads as part of the same pixel-art (no smooth anti-aliased line)
func _draw_tongue(from: Vector2, to: Vector2, col: Color, width: float) -> void:
	var pix := PIX
	var d := to - from
	var L := d.length()
	if L < 0.5:
		return
	var dir := d / L
	var perp := Vector2(-dir.y, dir.x)
	var nthick: int = max(1, int(round(width / pix)))
	var off0 := (nthick - 1) * 0.5
	var steps := int(ceil(L / pix))
	var seen := {}
	for i in steps + 1:
		var along: Vector2 = from + dir * minf(float(i) * pix, L)
		for t in nthick:
			var wpt: Vector2 = along + perp * ((t - off0) * pix)
			var cell := Vector2i(int(floor(wpt.x / pix)), int(floor(wpt.y / pix)))
			if not seen.has(cell):
				seen[cell] = true
				draw_rect(Rect2(cell.x * pix, cell.y * pix, pix, pix), col, true)

# a round-ish blob of pixel cells (for tongue tips / sticky points)
func _pixel_dot(center: Vector2, radius_cells: int, col: Color) -> void:
	var pix := PIX
	var cx := int(floor(center.x / pix))
	var cy := int(floor(center.y / pix))
	for dy in range(-radius_cells, radius_cells + 1):
		for dx in range(-radius_cells, radius_cells + 1):
			if dx * dx + dy * dy <= radius_cells * radius_cells + 1:
				draw_rect(Rect2((cx + dx) * pix, (cy + dy) * pix, pix, pix), col, true)

# a ring of pixel cells; pass `dots` > 0 for a spaced/dotted ring (cheaper, reads as a guide)
func _pixel_ring(center: Vector2, radius: float, col: Color, dots := 0) -> void:
	var pix := PIX
	var steps: int = dots if dots > 0 else max(24, int(TAU * radius / pix))
	var seen := {}
	for i in steps:
		var a := TAU * float(i) / steps
		var p := center + Vector2(cos(a), sin(a)) * radius
		var cell := Vector2i(int(floor(p.x / pix)), int(floor(p.y / pix)))
		if not seen.has(cell):
			seen[cell] = true
			draw_rect(Rect2(cell.x * pix, cell.y * pix, pix, pix), col, true)

# a dashed line of single pixel cells (for the aim guide)
func _pixel_line_dotted(from: Vector2, dir: Vector2, length: float, col: Color, gap := 2) -> void:
	var pix := PIX
	var n := int(length / pix)
	for i in range(0, n, gap):
		var p := from + dir * (float(i) * pix)
		draw_rect(Rect2(floor(p.x / pix) * pix, floor(p.y / pix) * pix, pix, pix), col, true)

func _process(d: float) -> void:
	# camera shake (applied on top of smoothing)
	if cam:
		if shake > 0.05:
			cam.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
			shake = move_toward(shake, 0.0, d * 60.0)
		else:
			cam.offset = Vector2.ZERO
	# advance pop rings
	for p in pops:
		p.t += d
	pops = pops.filter(func(p): return p.t < p.life)
	best_flash = max(best_flash - d, 0.0)
	queue_redraw()

	if not label:
		return
	if won:
		label.text = "GOT THE FLY!  time %.2fs   flies %d/%d\nLEFT-CLICK tongue & swing  |  A/D walk/run  |  SPACE leap  |  R reset" % [win_time, fly_count, fly_total]
	else:
		if free_mode:
			label.text = "GOD CAM (F to exit)   zoom %.2f\nWASD/arrows pan  |  Q/E or wheel zoom out/in  |  F return to frog" % free_zoom
			return
		var clock := "ready — leave the ground to start" if not run_started else "%.2fs" % run_time
		var banner := "★ NEW BEST ★\n" if best_flash > 0.0 else ""
		label.text = "%sTONGUE   (%d fps)   %s   flies %d/%d\nLEFT-CLICK tongue & swing  |  A/D walk/run  |  SPACE leap  |  R reset  |  F god cam  |  1-6 warp\nHeight: %d   Best: %d   Tongue the fly at the top!" % [banner, Engine.get_frames_per_second(), clock, fly_count, fly_total, _height(), int(best)]
