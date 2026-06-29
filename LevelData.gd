extends RefCounted

# Pure level DATA — no engine logic here. Edit the tower by editing numbers.
# 100px = 1m. Jump apex ≈ 1.4m (142px). Tongue reach = MAX_LEN (400px).
#
# FOUR BIOMES, each built on the same rhythm — land safe → climb risk → commit:
#   1. SOFT CHECKPOINT: a WIDE floor ledge at the biome's base catches almost any
#      fall in that biome, so a slip costs the biome at most, never the whole climb.
#   2. RISKY STRETCH: narrow ledges + grapple swings over the void back down to that
#      floor. The higher you get in a biome, the more a miss costs.
#   3. COMMIT: a leap/swing up onto the NEXT biome's floor.
# Falling off a floor's edge drops you a whole biome (the punishing fall).
#
# Biome bands (height m / world y):
#   Woods  0–13   (y 80 .. -1340)   jump-only, gentle, organic
#   Ruins  13–27  (-1340 .. -2740)  grapple swings begin
#   Cliffs 27–40  (-2740 .. -4040)  long swings, an overhang, a traverse
#   Peak   40–51  (-4040 .. -5120)  sparse, precise, the summit fly
#
# "perches" are the wide checkpoint floors + the summit (also the warp targets, keys 1–4).

static func tower() -> Dictionary:
	return {
		"spawn": Vector2(0, -40),
		"ground": [0, 80, 1100, 60],          # the Woods floor (full width)
		"goal": Vector2(40, -5120),
		"perches": [
			[ 100, -1340, 700, 44],            # 1: Ruins floor  (~13m checkpoint)
			[   0, -2740, 700, 44],            # 2: Cliffs floor (~27m checkpoint)
			[  50, -4040, 600, 44],            # 3: Peak floor   (~40m checkpoint)
			[  40, -5020, 220, 36],            # 4: Summit landing (~50m)
		],
		"platforms": [
			# --- WOODS 0–13m: jump-only, organic (rises ≤130, offsets ≤160) ---
			[  85,  -65, 260, 36],
			[ -55, -180, 240, 36],
			[ 120, -295, 200, 34],
			[ 135, -410, 175, 34],   # same-side step-up
			[ -45, -525, 250, 36],   # swing back across, wide
			[-185, -640, 180, 32],   # reach left
			[ -50, -755, 215, 32],
			[ 110, -870, 185, 30],
			[  20, -985, 200, 30],
			[ -90, -1110, 200, 32],
			[  60, -1230, 200, 32],  # last woods ledge — jump up onto the Ruins floor
			# --- RUINS 13–27m: narrow ledges + knob swings over the floor ---
			[ 380, -1500, 150, 28],
			[-120, -1660, 150, 28],
			[ 200, -1830, 140, 28],
			[-180, -2000, 140, 28],
			[ 120, -2180, 140, 26],
			[ -80, -2360, 150, 28],
			[ 180, -2540, 140, 26],
			[ -40, -2640, 160, 28],  # top of Ruins — commit up to the Cliffs floor
			# --- CLIFFS 27–40m: an overhang, long swings, a rightward traverse ---
			[ 250, -2900, 140, 26],
			[-180, -3120, 140, 26],
			[ 120, -3300, 130, 26],
			[ 380, -3440, 140, 26],
			[ 600, -3580, 150, 28],  # traverse far right
			[ 380, -3760, 130, 24],
			[ 130, -3900, 140, 26],
			[ -60, -3960, 150, 26],  # top of Cliffs — commit up to the Peak floor
			# --- PEAK 40–51m: sparse, narrowest, to the summit ---
			[-120, -4220, 120, 24],
			[ 200, -4400, 120, 24],
			[ -60, -4580, 120, 24],
			[ 120, -4760, 120, 24],
			[ -40, -4900, 130, 24],
		],
		"anchors": [
			# Ruins knobs
			[ 200, -1420, 16],
			[ -20, -1740, 18],
			[  60, -2090, 16],
			[-130, -2470, 16],
			# Cliffs knobs
			[ 180, -2860, 18],
			[  30, -3180, 16],
			[ 500, -3460, 16],
			[ 620, -3700, 16],
			[ 240, -3840, 18],
			# Peak knobs
			[  30, -4320, 18],
			[  80, -4500, 16],
			[  20, -4680, 16],
			[ -60, -4830, 18],
		],
		"ceilings": [
			[ 100, -3000, 280, 28],            # Cliffs overhang (grapple the underside)
		],
		# collectible flies — optional, on risky/offline lines
		"flies": [
			[ 110, -140],    # Woods: freebie at the start
			[ -50, -700],    # Woods
			[ 380, -1560],   # Ruins
			[-180, -2060],   # Ruins
			[ 300, -3320],   # Cliffs
			[ 600, -3640],   # Cliffs far traverse
			[ 120, -4820],   # Peak
		],
	}
