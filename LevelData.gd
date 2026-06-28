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
	# DIFFICULTY CURVE (100px = 1m; jump apex ≈ 1.4m, tongue reach = MAX_LEN 400):
	#   0–20m  : every rise ≤ ~135px so a NORMAL JUMP clears it. Wide ledges, gentle
	#            zigzag that slowly widens + narrows — no grapple-only anchors yet.
	#   20–30m : gaps grow past jump range (forcing grapples) + the first knob swings.
	#   30–43m : full swings — an overhang to grapple under, a lateral traverse, narrower.
	#   43–51m : climax — sparse knobs, narrowest ledges, the summit fly.
	# "perches" are the band-boundary landings (also the dev warp targets, keys 1–5).
	# Every grapple distance below is < MAX_LEN, and stays so on purpose.
	return {
		"spawn": Vector2(0, -40),
		"ground": [0, 80, 1000, 60],
		"goal": Vector2(40, -5120),
		"perches": [
			[   0, -1050, 240, 40],   # 1: ~10m breather
			[ -20, -2000, 200, 40],   # 2: ~20m — end of the easy jump section
			[  40, -3060, 190, 40],   # 3: ~30m — after the first swings
			[  40, -4480, 180, 40],   # 4: ~44m — after the traverse
			[  40, -5020, 150, 36],   # 5: ~50m — summit landing under the fly
		],
		"platforms": [
			# --- 0–20m: a JUMP-ONLY staircase. Rises ~110px (under the ~142px jump apex),
			#     tiny ±60 offsets, wide overlapping ledges — clearable by jumping alone.
			#     Swinging is optional here; you never need the tongue until ~20m. ---
			[  60, -60, 250, 36],
			[ -60, -170, 250, 36],
			[  60, -280, 250, 36],
			[ -60, -390, 250, 34],
			[  60, -500, 250, 34],
			[ -60, -610, 240, 34],
			[  60, -720, 240, 34],
			[ -60, -830, 240, 32],
			[  60, -940, 240, 32],
			# (perch 1 at -1050)
			[ -60, -1160, 240, 32],
			[  60, -1270, 230, 32],
			[ -60, -1380, 230, 32],
			[  60, -1490, 230, 30],
			[ -60, -1600, 220, 30],
			[  60, -1710, 220, 30],
			[ -60, -1820, 220, 30],
			[  60, -1930, 220, 30],
			# (perch 2 at -2000)
			# --- 20–30m: bigger gaps (grapple) + first knob swings ---
			[-160, -2190, 170, 30],
			[ 180, -2460, 160, 28],
			[-150, -2640, 150, 28],
			[ 190, -2920, 150, 28],
			# (perch 3 at -3060)
			# --- 30–43m: overhang + lateral traverse, narrower ---
			[ 260, -3320, 140, 26],   # land off the overhang swing
			[-110, -3640, 130, 26],
			[ 130, -3800, 130, 26],
			[ 380, -3920, 140, 26],   # traverse right...
			[ 620, -4030, 140, 28],
			[ 250, -4320, 130, 24],
			# (perch 4 at -4480)
			# --- 43–51m: climax, narrowest ledges to the summit ---
			[ 140, -4790, 120, 24],
		],
		"anchors": [
			# 20–30m knobs
			[  50, -2320, 16],
			[  10, -2780, 16],
			# 30–43m knobs
			[  90, -3500, 18],
			[ 470, -4200, 16],
			# climax knobs
			[-120, -4650, 18],
			[  10, -4930, 16],
		],
		"ceilings": [
			[ 150, -3180, 260, 28],   # the overhang you grapple the underside of (~31m)
		],
		# collectible flies — optional, on risky/offline spots
		"flies": [
			[ 110, -140],    # START: a freebie to teach the catch
			[   0, -880],    # near the first breather
			[-130, -1280],   # mid easy section
			[  90, -2380],   # 20m+ near the first knob
			[ 300, -3320],   # overhang area
			[ 620, -4000],   # far end of the traverse
			[ 140, -4750],   # climax detour
		],
	}
