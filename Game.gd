extends Node2D

const LevelData := preload("res://LevelData.gd")

# ---- TUNING (the whole game is in these numbers) ----
const MAX_LEN := 400.0       # hard cap on how far the tongue can reach to stick
const SPRING_K := 55.0       # pull strength per pixel of stretch (elastic tongue)
const DAMP := 5.0            # radial damping (kills jitter/bounce)
const CONTRACT_SPEED := 240.0 # px/sec the tongue reels in after sticking (higher = quicker pull)
const PULL_FACTOR := 0.60    # reels in to this fraction of grab length
const CAP_STIFFEN := 5.0     # rope gets this much stiffer past its max (grab) length
const AIR_NUDGE := 380.0     # small left/right air control while swinging
const BODY_MASS := 1.0
const TONGUE_SPEED := 2600.0 # px/sec the tongue shoots out & retracts (its travel time)
const JUMP_IMPULSE := 560.0  # frog-leap takeoff speed (px/s upward)
const JUMP_DIR := 150.0      # horizontal kick added to a leap when holding A/D
const WALK_SPEED := 95.0     # ground stroll
const RUN_SPEED := 215.0     # ground sprint (hold A/D)
const GROUND_ACCEL := 1400.0 # how fast ground speed ramps (px/s^2)
const RUN_ANIM_AT := 150.0   # |vx| above this shows the run animation
const BODY_RADIUS := 18.0

# ---- state ----
var body: RigidBody2D
var cam: Camera2D
var label: Label
var anchor := Vector2.ZERO
var attached := false        # true only while the tongue is stuck
var rest_len := 0.0
var grab_len := 0.0          # the tongue's max length, locked at the moment you stick
var was_pressed := false
# tongue projectile state: 0 idle, 1 extending, 2 attached, 3 retracting
var tstate := 0
var tlen := 0.0              # current visible tongue length
var thit := false           # will this shot connect once it reaches the target?
var aim_dir := Vector2.RIGHT
var jump_was := false
var start_y := 0.0
var best := 0.0
# ---- run / goal state ----
var goal_pos := Vector2.ZERO
var goal_r := 46.0
const GOAL_CATCH_R := 36.0    # tongue must touch this close to the goal fly to win
const FLY_CATCH_R := 26.0     # tongue snag radius for collectible flies
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
var face_dir := Vector2.RIGHT   # smoothed facing for the frog sprite
var mouth := Vector2.ZERO       # where the tongue fires from
var was_grounded := false
var grounded := false
var has_tongue := true   # one tongue per airtime; recharges on touching ground
var land_squash := 0.0          # brief squash-onto-feet pop when landing
var frog: AnimatedSprite2D
var frog_base_scale := Vector2(2.6, 2.6)
const FROG_DIR := "res://assets/FROGLET_16x16_Sprite/green/PNG/"
var _frog_tex_cache := {}   # sheet name -> imported Texture2D
var trail: Array[Vector2] = []
var pops: Array = []          # each: {pos:Vector2, t:float, life:float, col:Color}
var sfx_stick: AudioStreamPlayer
var sfx_hop: AudioStreamPlayer
var sfx_win: AudioStreamPlayer
var sfx_eat: AudioStreamPlayer
# ---- fly eating ----
var carrying := false         # the tongue is retracting with a fly stuck to its tip
var carrying_goal := false    # ...and that fly is the goal fly (win on the gulp)
var chomp := 0.0              # swallow-squash timer, decays
# ---- free-cam / god mode (inspect the level) ----
var freecam: Camera2D
var free_mode := false
var free_was := false
var free_zoom := 1.0
# ---- level decoration ----
var anchor_knobs: Array = []   # Vector2 positions of grapple-only knobs (drawn as amber rings)

func _ready() -> void:
	_build_level()
	_build_chameleon()
	_build_camera()
	_build_ui()
	_build_sfx()

func _build_chameleon() -> void:
	body = RigidBody2D.new()
	body.mass = BODY_MASS
	body.linear_damp = 0.15
	body.angular_damp = 2.0
	body.can_sleep = false
	body.collision_layer = 2
	body.collision_mask = 1
	body.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE  # stop fast swings tunneling thru platforms
	body.lock_rotation = true   # it's a frog, not a ball — never roll/spin
	# low friction so swings slide off platform corners instead of snagging on them
	# (ground movement is velocity-driven, so this doesn't make walking feel slippery)
	var pm := PhysicsMaterial.new()
	pm.friction = 0.0
	pm.bounce = 0.0
	body.physics_material_override = pm
	body.max_contacts_reported = 4
	body.contact_monitor = true
	body.position = level_spawn
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 18.0
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	start_y = body.position.y
	_build_frog()

# load a frog sheet as a normally-imported texture (cached). Using load() instead of
# Image.load_from_file means it works in exported builds AND doesn't spam import warnings.
func _frog_tex(sheet: String) -> Texture2D:
	if _frog_tex_cache.has(sheet):
		return _frog_tex_cache[sheet]
	var tex: Texture2D = load(FROG_DIR + sheet)
	if tex == null:
		push_warning("missing frog sheet: " + sheet)
	_frog_tex_cache[sheet] = tex
	return tex

func _frog_anim(frames: SpriteFrames, anim: String, sheet: String, count: int, fps: float, loop: bool) -> void:
	var tex := _frog_tex(sheet)
	if tex == null:
		return
	frames.add_animation(anim)
	frames.set_animation_loop(anim, loop)
	frames.set_animation_speed(anim, fps)
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * 16, 0, 16, 16)
		frames.add_frame(anim, at)

# register a single held frame (e.g. the legs-extended pose pulled out of the jump sheet)
func _frog_frame(frames: SpriteFrames, anim: String, sheet: String, index: int) -> void:
	var tex := _frog_tex(sheet)
	if tex == null:
		return
	frames.add_animation(anim)
	frames.set_animation_loop(anim, true)
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(index * 16, 0, 16, 16)
	frames.add_frame(anim, at)

func _build_frog() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	_frog_anim(frames, "idle",   "froglet_frog_green_sheet_idle.png",   8, 7.0, true)
	_frog_anim(frames, "croak",  "froglet_frog_green_sheet_croak.png", 11, 9.0, false)
	_frog_anim(frames, "jump",   "froglet_frog_green_sheet_jump.png",  11, 11.0, false)
	_frog_frame(frames, "fly",   "froglet_frog_green_sheet_jump.png",  5)   # legs-extended air pose
	_frog_anim(frames, "attack", "froglet_frog_green_sheet_attack.png",11, 18.0, false)
	_frog_anim(frames, "duck",   "froglet_frog_green_sheet_duck.png",   8, 12.0, false)
	_frog_anim(frames, "walk",   "froglet_frog_green_sheet_walk.png",   8, 10.0, true)
	_frog_anim(frames, "run",    "froglet_frog_green_sheet_run.png",    5, 14.0, true)
	_frog_anim(frames, "death",  "froglet_frog_green_sheet_death.png",  8, 9.0, false)
	frog = AnimatedSprite2D.new()
	frog.sprite_frames = frames
	frog.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # crisp pixels
	frog.scale = frog_base_scale
	frog.position = Vector2(0, -3)   # nudge so the frog's feet sit on the body's base
	frog.z_index = 1
	frog.play("idle")
	body.add_child(frog)

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
	# catch perches: wide safe rests, mossy-green so "safe" reads at a glance
	for p in lv.get("perches", []):
		_make_static(Vector2(p[0], p[1]), Vector2(p[2], p[3]), Color(0.26, 0.40, 0.28))
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

func _build_camera() -> void:
	cam = Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	body.add_child(cam)
	cam.make_current()
	# detached free-cam lives on the scene root (god-mode inspection)
	freecam = Camera2D.new()
	freecam.position = body.position
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

func _pop(pos: Vector2, life: float, col: Color) -> void:
	pops.append({"pos": pos, "t": 0.0, "life": life, "col": col})

func _grounded() -> bool:
	var space := get_world_2d().direct_space_state
	var from := body.global_position
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, BODY_RADIUS + 7.0), 1)
	q.exclude = [body.get_rid()]
	return not space.intersect_ray(q).is_empty()

# If the extending tongue tip reaches a fly, grab it: the tongue STOPS and snaps back
# (tstate 3) carrying the fly to the mouth. Returns true if a fly was grabbed this frame.
func _try_catch_fly(tip: Vector2) -> bool:
	for f in flies:
		if not f["caught"] and tip.distance_to(f["pos"]) < FLY_CATCH_R:
			f["caught"] = true
			carrying = true
			carrying_goal = false
			tstate = 3
			if not grounded:
				has_tongue = false   # eating a fly mid-air spends your one tongue this jump
			shake = max(shake, 4.0)
			_pop(f["pos"], 0.28, Color(0.7, 0.95, 0.5))
			if sfx_stick: sfx_stick.play()
			return true
	if tip.distance_to(goal_pos) < GOAL_CATCH_R:
		carrying = true
		carrying_goal = true
		win_time = run_time          # freeze the clock at the catch (the skill moment)
		tstate = 3
		shake = max(shake, 8.0)
		_pop(goal_pos, 0.4, Color(0.6, 0.9, 0.4))
		if sfx_stick: sfx_stick.play()
		return true
	return false

# the carried fly reached the mouth — swallow it (belly puff + count/win)
func _gulp() -> void:
	chomp = 0.22
	shake = max(shake, 4.0)
	_pop(mouth, 0.3, Color(1.0, 1.0, 0.85))
	if carrying_goal:
		won = true
		shake = max(shake, 16.0)
		_pop(mouth, 0.6, Color(1.0, 1.0, 0.7))
		if sfx_win: sfx_win.play()
	else:
		fly_count += 1
		if sfx_eat: sfx_eat.play()
	carrying = false
	carrying_goal = false

func _fire() -> void:
	var aim := (get_global_mouse_position() - body.global_position)
	if aim.length() < 1.0:
		return
	aim_dir = aim.normalized()
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(
		body.global_position, body.global_position + aim_dir * MAX_LEN, 1)
	q.exclude = [body.get_rid()]
	var hit := space.intersect_ray(q)
	tlen = 0.0
	tstate = 1                # start extending; the hit isn't confirmed until the tip arrives
	if hit.is_empty():
		thit = false
	else:
		thit = true
		anchor = hit["position"]

func _physics_process(delta: float) -> void:
	flap += delta
	if Input.is_action_pressed("reset"):
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
		if not run_started and not _grounded() and body.global_position.y < start_y - 30.0:
			run_started = true
	if won:
		queue_redraw()
		return

	# tongue recharges the moment you touch ground (one tongue per airtime)
	grounded = _grounded()
	if grounded and not has_tongue:
		has_tongue = true
		_pop(body.global_position, 0.25, Color(0.45, 1.0, 0.55))   # recharge flash

	# fire on click edge / release to let go
	var pressed := Input.is_action_pressed("fire")
	if pressed and not was_pressed and tstate == 0 and has_tongue:
		_fire()
	if not pressed:
		if tstate == 2:        # let go of a grip
			attached = false
			tstate = 0
		elif tstate == 1:      # cancel a shot mid-flight -> retract
			tstate = 3

	was_pressed = pressed

	# tongue travel
	if tstate == 1:
		tlen += TONGUE_SPEED * delta
		var tip := mouth + aim_dir * tlen   # the tip as it shoots out
		# FLY CATCH takes priority: if the tip reaches a fly, the tongue STOPS and
		# snaps back carrying it (a fly-catch spends your one airborne tongue).
		if not _try_catch_fly(tip):
			if thit:
				var d := body.global_position.distance_to(anchor)
				if tlen >= d:      # tip reached the target -> now it sticks
					grab_len = d
					rest_len = grab_len
					attached = true
					tstate = 2
					if not grounded:
						has_tongue = false   # a SUCCESSFUL airborne grab is your one per jump
					shake = max(shake, 7.0)
					_pop(anchor, 0.22, Color(0.95, 0.45, 0.55))
					if sfx_stick: sfx_stick.play()
			elif tlen >= MAX_LEN:  # whiffed -> snap back
				tstate = 3
	elif tstate == 3:
		tlen -= TONGUE_SPEED * delta
		if tlen <= 0.0:
			tlen = 0.0
			tstate = 0
			if carrying:
				_gulp()            # the fly reached the mouth — eat it

	if attached:
		# the tongue gently retracts toward a fraction of the grab length (pulls in "a little")
		rest_len = move_toward(rest_len, grab_len * PULL_FACTOR, CONTRACT_SPEED * delta)
		# elastic pull toward the anchor (springy, with give)
		var to_anchor := anchor - body.global_position
		var dist := to_anchor.length()
		if dist > 0.01:
			var ndir := to_anchor / dist
			var stretch := dist - rest_len
			if stretch > 0.0:
				# stiffen hard past the max (grab) length so it behaves like a rope cap
				var k := SPRING_K
				if dist > grab_len:
					k *= CAP_STIFFEN
				var v_radial := body.linear_velocity.dot(ndir)
				body.apply_central_force(ndir * (stretch * k) - ndir * (v_radial * DAMP))

	# horizontal input
	var ix := 0.0
	if Input.is_action_pressed("move_left"):
		ix -= 1.0
	if Input.is_action_pressed("move_right"):
		ix += 1.0

	# locomotion: walk/run on the ground (velocity-driven, no rolling),
	# air-nudge only while swinging/airborne for swing steering.
	if grounded and not attached:
		var target := ix * RUN_SPEED
		body.linear_velocity.x = move_toward(body.linear_velocity.x, target, GROUND_ACCEL * delta)
	elif ix != 0.0:
		body.apply_central_force(Vector2(ix * AIR_NUDGE, 0))

	# frog-leap whenever standing on something — allowed even with the tongue attached
	# (jump off the ground into a swing); the tongue stays stuck.
	var jump := Input.is_action_pressed("jump")
	if jump and not jump_was and grounded:
		body.linear_velocity.y = -JUMP_IMPULSE
		body.linear_velocity.x += ix * JUMP_DIR   # directional hop when holding A/D
		if attached:
			# let the rope breathe so the spring doesn't instantly yank you back down
			rest_len = max(rest_len, body.global_position.distance_to(anchor))
		if sfx_hop: sfx_hop.play()
	jump_was = jump

	# facing: player input flips L/R INSTANTLY (no easing); with no input, lead with
	# the swing while airborne, else hold the last facing. Never tracks the cursor.
	var fvel := body.linear_velocity
	if ix != 0.0:
		face_dir = Vector2(ix, 0.0)               # snap immediately to A/D
	elif not grounded and fvel.length() > 60.0:
		face_dir = face_dir.lerp(fvel.normalized(), 0.12)
	if face_dir.length() < 0.01:
		face_dir = Vector2.RIGHT
	face_dir = face_dir.normalized()

	# landing pop: squash onto the feet the instant we touch down
	if grounded and not was_grounded and fvel.y > 30.0:
		land_squash = 0.45
		shake = max(shake, 3.5)
	was_grounded = grounded
	land_squash = move_toward(land_squash, 0.0, delta * 2.4)

	# speed trail (used by _draw); keep a short fading history
	trail.append(body.global_position)
	if trail.size() > 14:
		trail.remove_at(0)

	var h := (start_y - body.global_position.y) / 100.0
	best = max(best, h)
	queue_redraw()

func _toggle_freecam() -> void:
	free_mode = not free_mode
	body.freeze = free_mode      # park the frog while inspecting
	if free_mode:
		freecam.position = body.global_position
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
	if not free_mode:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			free_zoom = minf(free_zoom * 1.12, 4.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			free_zoom = maxf(free_zoom * 0.88, 0.06)
		freecam.zoom = Vector2(free_zoom, free_zoom)

func _draw() -> void:
	var bpos := body.global_position
	var col := Color(0.95, 0.45, 0.55)
	# speed trail: faded pixel ghost behind the body, brighter the faster you move
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
	if carrying and tstate == 3:
		var mp := mouth + aim_dir * tlen
		var mw: int = 1 if sin(flap * 60.0) > 0.0 else 2   # fast panicked flap
		_pixel_dot(mp + Vector2(-5, 0), mw, Color(0.85, 0.92, 1.0, 0.9))
		_pixel_dot(mp + Vector2(5, 0), mw, Color(0.85, 0.92, 1.0, 0.9))
		_pixel_dot(mp, 1, Color(0.12, 0.12, 0.15))
	# the goal fly: bobbing pixel bug + flapping wings (gone once snatched/eaten)
	if not carrying_goal and not won:
		var bob := roundf(sin(flap * 3.0) * 6.0)
		var fpos := goal_pos + Vector2(0, bob)
		var wing: int = 1 if sin(flap * 30.0) > 0.0 else 2   # 2-frame wing flap
		_pixel_ring(fpos, goal_r, Color(0.55, 0.85, 0.4, 0.18), 28)   # catch halo (dotted)
		_pixel_dot(fpos + Vector2(-9, 0), wing, Color(0.8, 0.9, 1.0, 0.8))
		_pixel_dot(fpos + Vector2(9, 0), wing, Color(0.8, 0.9, 1.0, 0.8))
		_pixel_dot(fpos, 2, Color(0.14, 0.14, 0.17))
		_pixel_dot(fpos + Vector2(0, -6), 1, Color(0.22, 0.22, 0.26))
	# (the frog itself is an AnimatedSprite2D child of the body, updated in _process)
	# reach cap ring + aim line (only when idle AND you still have your tongue)
	if tstate == 0 and not won and has_tongue:
		_pixel_ring(bpos, MAX_LEN, Color(1, 1, 1, 0.16), 80)   # dotted reach guide
		var dir := (get_global_mouse_position() - mouth)
		if dir.length() > 1.0:
			_pixel_line_dotted(mouth, dir.normalized(), MAX_LEN, Color(1, 1, 1, 0.30), 2)
	# tongue
	if tstate == 2:
		# stretch makes the tongue thinner + brighter, like it's under tension
		var dist := bpos.distance_to(anchor)
		var tension: float = clamp((dist - grab_len * PULL_FACTOR) / max(grab_len, 1.0), 0.0, 1.0)
		var w: float = lerp(7.0, 3.0, tension)
		var tc := col.lerp(Color(1.0, 0.7, 0.8), tension)
		_draw_tongue(mouth, anchor, tc, w)
		_pixel_dot(anchor, 2, tc)
		_pixel_dot(anchor, 1, Color(1, 1, 1, 0.9))   # sticky tip highlight
	elif tstate == 1 or tstate == 3:
		var tip: Vector2
		if thit and tstate == 1:
			tip = mouth + (anchor - mouth).normalized() * min(tlen, mouth.distance_to(anchor))
		else:
			tip = mouth + aim_dir * tlen
		_draw_tongue(mouth, tip, col, 5.0)
		_pixel_dot(tip, 2, col)

# the tongue, rasterized into pixel blocks sized to match the frog's pixels (scale 2.6),
# so it reads as part of the same pixel-art (no smooth anti-aliased line)
func _draw_tongue(from: Vector2, to: Vector2, col: Color, width: float) -> void:
	var pix := frog_base_scale.x
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
	var pix := frog_base_scale.x
	var cx := int(floor(center.x / pix))
	var cy := int(floor(center.y / pix))
	for dy in range(-radius_cells, radius_cells + 1):
		for dx in range(-radius_cells, radius_cells + 1):
			if dx * dx + dy * dy <= radius_cells * radius_cells + 1:
				draw_rect(Rect2((cx + dx) * pix, (cy + dy) * pix, pix, pix), col, true)

# a ring of pixel cells; pass `dots` > 0 for a spaced/dotted ring (cheaper, reads as a guide)
func _pixel_ring(center: Vector2, radius: float, col: Color, dots := 0) -> void:
	var pix := frog_base_scale.x
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
	var pix := frog_base_scale.x
	var n := int(length / pix)
	for i in range(0, n, gap):
		var p := from + dir * (float(i) * pix)
		draw_rect(Rect2(floor(p.x / pix) * pix, floor(p.y / pix) * pix, pix, pix), col, true)

func _update_frog() -> void:
	if not frog:
		return
	# face with movement (eye/cursor no longer relevant — sprite just flips L/R)
	frog.flip_h = face_dir.x < 0.0
	# landing squash + a swallow puff when gulping a fly (belly bulges briefly)
	var sq := land_squash
	frog.scale = Vector2(frog_base_scale.x * (1.0 + sq * 0.30 + chomp * 0.22),
		frog_base_scale.y * (1.0 - sq * 0.42 + chomp * 0.16))
	# pick the animation from physics state
	var want := "idle"
	var vx := absf(body.linear_velocity.x)
	if won:
		want = "croak"
	elif tstate == 1:
		want = "attack"          # tongue lashing out
	elif not grounded:
		if attached:
			# swinging: legs-extended when carrying speed, relaxed/standing when hanging still
			want = "fly" if body.linear_velocity.length() > 80.0 else "idle"
		else:
			want = "fly"         # free flight (jumping/falling) = legs extended
	elif land_squash > 0.05:
		want = "duck"            # just landed
	elif vx > RUN_ANIM_AT:
		want = "run"
	elif vx > 12.0:
		want = "walk"
	else:
		want = "idle"
	if frog.animation != want:
		frog.play(want)
	# mouth: front of the frog, where the tongue fires from
	mouth = body.global_position + face_dir * 16.0 + Vector2(0, -2)

func _process(d: float) -> void:
	_update_frog()
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

	# swallow-squash decay (the gulp puff)
	chomp = move_toward(chomp, 0.0, d * 5.0)
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
		label.text = "TONGUE   (%d fps)   %s   flies %d/%d\nLEFT-CLICK tongue & swing  |  A/D walk/run  |  SPACE leap  |  R reset  |  F god cam\nHeight: %d   Best: %d   Tongue the fly at the top!" % [Engine.get_frames_per_second(), clock, fly_count, fly_total, int((start_y - body.global_position.y) / 100.0), int(best)]
