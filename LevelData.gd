extends RefCounted

# Pure level DATA — no engine logic lives here. Edit the tower by editing numbers.
# A level is:
#   spawn:     Vector2 where the frog starts
#   ground:    [x, y, w, h] the starting floor
#   goal:      Vector2 where the fly sits (the top)
#   platforms: [x, y, w, h] standable grab ledges (purple)
#   perches:   [x, y, w, h] wide safe rests between sections (green)
#   anchors:   [x, y, r]    grapple-ONLY knobs you can't stand on (amber rings)
#   ceilings:  [x, y, w, h] overhead slabs you grapple the underside of (stone)
#   flies:     [x, y]       optional collectibles, snag with the tongue
# Design rules of thumb (match the validated feel — don't make it globally harder):
#   gaps ~190-260 vertical, offsets within MAX_LEN (400). Each ledge is both an anchor
#   to swing from AND a spot to land on (landing recharges your one tongue).

static func tower() -> Dictionary:
	# Sectioned rage design with a VARIED VOCABULARY (not just ledge-to-ledge zigzag).
	# No checkpoints — a fall drops you to the green perch below, costing a section.
	# Because of the one-tongue-per-airtime rule, every grapple must end in a landing,
	# so variety comes from WHAT you grab and the shape of each leap->swing->land.
	return {
		"spawn": Vector2(0, -40),
		"ground": [0, 80, 900, 60],
		"goal": Vector2(40, -5120),
		# "perches" are NOT safe rests anymore — they're narrow skill-check landings
		# (Jump-King style). Miss one and you plummet. They stay load-bearing (you must
		# land to recharge the tongue) but are tight, and drawn like normal ledges.
		"perches": [
			[ -10, -640, 120, 40],    # landing 1 (after warmup)
			[  10, -1650, 120, 40],   # landing 2 (after anchor knobs)
			[ -20, -2270, 120, 40],   # landing 3 (after the chasm pendulum)
			[   0, -3250, 120, 40],   # landing 4 (after the overhangs)
			[ 760, -3700, 120, 40],   # landing 5 (end of the lateral traverse, far right)
			[  40, -5000, 150, 36],   # summit landing under the fly
		],
		"platforms": [
			# --- S1 Warmup: plain ledge swings (teach the rhythm) ---
			[ 190, -190, 200, 32],
			[-190, -410, 200, 32],
			# --- S2 Anchor knobs: commit to empty-space points, fling to small ledges ---
			[-170, -1020, 170, 28],
			[ 190, -1420, 170, 28],
			# --- S3 Chasm pendulum: see anchors below; land far & low ---
			[-250, -2040, 200, 30],   # far landing, only via a real arc
			# --- S4 Overhang dive: grapple a ceiling, swing under to a tucked ledge ---
			[ 250, -2640, 150, 26],   # tucked under/right of the first ceiling
			[-250, -3020, 150, 26],   # tucked under/left of the second ceiling
			# --- S5 Lateral traverse: march RIGHT, not up (breaks the vertical grind) ---
			[ 230, -3360, 150, 26],
			[ 430, -3430, 150, 26],
			[ 760, -3480, 160, 28],
			# --- S6 Climax: sparse anchors + long reaches back up & left to the fly ---
			[ 420, -4140, 130, 24],
			[  60, -4560, 130, 24],
		],
		"anchors": [
			# S2 knobs
			[ 160, -840, 16],
			[ -40, -1230, 16],
			# S3 the "money" central anchor (bigger) for the chasm pendulum
			[  30, -1880, 18],
			# S5 a knob to fling further right across the traverse
			[ 600, -3300, 16],
			# S6 climax knobs
			[ 600, -3940, 16],
			[ 240, -4360, 16],
			[-120, -4780, 18],
		],
		"ceilings": [
			[ 150, -2480, 260, 28],   # S4 first overhead slab
			[-150, -2860, 260, 28],   # S4 second overhead slab
		],
		# collectible flies — snag with the tongue. Placed on risky/optional lines so
		# going for them costs you safety. (caught count shown in UI; not required to win)
		"flies": [
			[ 110, -110],    # START: a freebie right in front of spawn — teaches the catch
			[  40, -930],    # S2: between the two knob ledges
			[-180, -1330],   # S2: out past the second knob
			[-110, -1980],   # S3: dangling in the chasm void — grab mid-pendulum
			[ 150, -2560],   # S4: tucked under the first overhang
			[ 530, -3380],   # S5: hanging over the traverse gap
			[ 360, -4300],   # S6: off the climax line, a detour
		],
	}
