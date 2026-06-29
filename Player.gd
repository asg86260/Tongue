extends RigidBody2D

# The frog. Owns its physics, the tongue state machine, locomotion and animation.
# It talks to the Game controller (set as `controller`) for world queries and juice:
#   controller.catch_at(tip) -> 0 none / 1 fly / 2 goal   (marks the fly, plays fx)
#   controller.gulp(is_goal, mouth_pos)                   (count / win / fx)
#   controller.add_pop / add_shake / play_sfx             (juice owned by Game)
# Game reads this node's public state (tstate, tlen, anchor, mouth, trail, ...) to draw.

# ---- TUNING (the whole game is in these numbers) ----
const MAX_LEN := 400.0       # hard cap on how far the tongue can reach to stick
const SPRING_K := 55.0       # pull strength per pixel of stretch (elastic tongue)
const DAMP := 5.0            # radial damping (kills jitter/bounce)
const CONTRACT_SPEED := 240.0 # px/sec the tongue reels in after sticking (higher = quicker pull)
const PULL_FACTOR := 0.60    # reels in to this fraction of grab length
const CAP_STIFFEN := 5.0     # rope gets this much stiffer past its max (grab) length
const AIR_NUDGE := 380.0     # small left/right air control while swinging
const AIR_STRAFE_MAX := 190.0 # cap on horizontal speed you can build by strafing in free air
const BODY_MASS := 1.0
const TONGUE_SPEED := 2600.0 # px/sec the tongue shoots out & retracts (its travel time)
const JUMP_IMPULSE := 560.0  # frog-leap takeoff speed (px/s upward)
const JUMP_DIR := 150.0      # horizontal kick added to a leap when holding A/D
const WALK_SPEED := 95.0     # ground stroll
const RUN_SPEED := 215.0     # ground sprint (hold A/D)
const GROUND_ACCEL := 1400.0 # how fast ground speed ramps (px/s^2)
const RUN_ANIM_AT := 150.0   # |vx| above this shows the run animation
const BODY_RADIUS := 18.0
const FROG_DIR := "res://assets/FROGLET_16x16_Sprite/green/PNG/"

var controller            # the Game node (juice/catch callbacks + phase flags)
var active := true        # false while god-cam or after winning (stops control logic)

# ---- tongue state ----
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
var has_tongue := true   # one tongue per airtime; recharges on touching ground
# ---- anim / juice ----
var face_dir := Vector2.RIGHT   # smoothed facing for the frog sprite
var mouth := Vector2.ZERO       # where the tongue fires from
var was_grounded := false
var grounded := false
var land_squash := 0.0          # brief squash-onto-feet pop when landing
var frog: AnimatedSprite2D
var frog_base_scale := Vector2(2.6, 2.6)
var _frog_tex_cache := {}   # sheet name -> imported Texture2D
var trail: Array[Vector2] = []
# ---- fly eating ----
var carrying := false         # the tongue is retracting with a fly stuck to its tip
var carrying_goal := false    # ...and that fly is the goal fly (win on the gulp)
var chomp := 0.0              # swallow-squash timer, decays

func _ready() -> void:
	mass = BODY_MASS
	linear_damp = 0.15
	angular_damp = 2.0
	can_sleep = false
	collision_layer = 2
	collision_mask = 1
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE  # stop fast swings tunneling thru platforms
	lock_rotation = true   # it's a frog, not a ball — never roll/spin
	# low friction so swings slide off platform corners instead of snagging on them
	# (ground movement is velocity-driven, so this doesn't make walking feel slippery)
	var pm := PhysicsMaterial.new()
	pm.friction = 0.0
	pm.bounce = 0.0
	physics_material_override = pm
	max_contacts_reported = 4
	contact_monitor = true
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 18.0
	cs.shape = shape
	add_child(cs)
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
	add_child(frog)

func is_grounded() -> bool:
	var space := get_world_2d().direct_space_state
	var from := global_position
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, BODY_RADIUS + 7.0), 1)
	q.exclude = [get_rid()]
	return not space.intersect_ray(q).is_empty()

func _fire() -> void:
	var aim := (get_global_mouse_position() - global_position)
	if aim.length() < 1.0:
		return
	aim_dir = aim.normalized()
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(
		global_position, global_position + aim_dir * MAX_LEN, 1)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	tlen = 0.0
	tstate = 1                # start extending; the hit isn't confirmed until the tip arrives
	if hit.is_empty():
		thit = false
	else:
		thit = true
		anchor = hit["position"]

func _physics_process(delta: float) -> void:
	if not active:
		return

	# tongue recharges the moment you touch ground (one tongue per airtime)
	grounded = is_grounded()
	if grounded and not has_tongue:
		has_tongue = true

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
		var kind: int = controller.catch_at(tip)
		if kind != 0:
			carrying = true
			carrying_goal = (kind == 2)
			tstate = 3
			if kind == 1 and not grounded:
				has_tongue = false   # eating a fly mid-air spends your one tongue this jump
		else:
			if thit:
				var d := global_position.distance_to(anchor)
				if tlen >= d:      # tip reached the target -> now it sticks
					grab_len = d
					rest_len = grab_len
					attached = true
					tstate = 2
					if not grounded:
						has_tongue = false   # a SUCCESSFUL airborne grab is your one per jump
					controller.add_shake(7.0)
					controller.play_sfx("stick")
			elif tlen >= MAX_LEN:  # whiffed -> snap back
				tstate = 3
	elif tstate == 3:
		tlen -= TONGUE_SPEED * delta
		if tlen <= 0.0:
			tlen = 0.0
			tstate = 0
			if carrying:
				chomp = 0.22
				controller.gulp(carrying_goal, mouth)   # the fly reached the mouth — eat it
				carrying = false
				carrying_goal = false

	if attached:
		# the tongue gently retracts toward a fraction of the grab length (pulls in "a little")
		rest_len = move_toward(rest_len, grab_len * PULL_FACTOR, CONTRACT_SPEED * delta)
		# elastic pull toward the anchor (springy, with give)
		var to_anchor := anchor - global_position
		var dist := to_anchor.length()
		if dist > 0.01:
			var ndir := to_anchor / dist
			var stretch := dist - rest_len
			if stretch > 0.0:
				# stiffen hard past the max (grab) length so it behaves like a rope cap
				var k := SPRING_K
				if dist > grab_len:
					k *= CAP_STIFFEN
				var v_radial := linear_velocity.dot(ndir)
				apply_central_force(ndir * (stretch * k) - ndir * (v_radial * DAMP))

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
		linear_velocity.x = move_toward(linear_velocity.x, target, GROUND_ACCEL * delta)
	elif ix != 0.0:
		# Swing steering is uncapped (pump the pendulum). In FREE air, only nudge while
		# under AIR_STRAFE_MAX so strafing can't keep building horizontal speed — swing
		# momentum already past the cap is preserved (we never actively brake).
		if attached or ix * linear_velocity.x < AIR_STRAFE_MAX:
			apply_central_force(Vector2(ix * AIR_NUDGE, 0))

	# frog-leap whenever standing on something — allowed even with the tongue attached
	# (jump off the ground into a swing); the tongue stays stuck.
	var jump := Input.is_action_pressed("jump")
	if jump and not jump_was and grounded:
		linear_velocity.y = -JUMP_IMPULSE
		linear_velocity.x += ix * JUMP_DIR   # directional hop when holding A/D
		if attached:
			# let the rope breathe so the spring doesn't instantly yank you back down
			rest_len = max(rest_len, global_position.distance_to(anchor))
		controller.play_sfx("hop")
	jump_was = jump

	# facing: player input flips L/R INSTANTLY (no easing); with no input, lead with
	# the swing while airborne, else hold the last facing. Never tracks the cursor.
	var fvel := linear_velocity
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
		controller.add_shake(3.5)
	was_grounded = grounded
	land_squash = move_toward(land_squash, 0.0, delta * 2.4)

	# speed trail (used by Game._draw); keep a short fading history
	trail.append(global_position)
	if trail.size() > 14:
		trail.remove_at(0)

func _process(d: float) -> void:
	_update_frog()
	# swallow-squash decay (the gulp puff)
	chomp = move_toward(chomp, 0.0, d * 5.0)

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
	var vx := absf(linear_velocity.x)
	if controller.won:
		want = "croak"
	elif tstate == 1:
		want = "attack"          # tongue lashing out
	elif not grounded:
		if attached:
			# swinging: legs-extended when carrying speed, relaxed/standing when hanging still
			want = "fly" if linear_velocity.length() > 80.0 else "idle"
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
	mouth = global_position + face_dir * 16.0 + Vector2(0, -2)
