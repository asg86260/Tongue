extends RefCounted

# Shared biome colour-grading. A height (metres) maps to a tint that the backdrop
# and the platforms both multiply by, so the world visibly shifts mood as you climb:
#   Woods (lush green) → Ruins (cool stone) → Cliffs (warm dusk) → Peak (pale cold).
# Tints lerp across band boundaries for a smooth transition.

# Tints are tuned to harmonise the platforms with each biome's backdrop scene.
const BANDS := [
	{ "h": 0.0,  "tint": Color(1.00, 1.04, 0.96) },   # Woods  — lush green forest
	{ "h": 13.0, "tint": Color(0.90, 0.90, 1.06) },   # Ruins  — cool blue-purple peaks
	{ "h": 27.0, "tint": Color(1.12, 0.86, 0.70) },   # Cliffs — warm red dusk
	{ "h": 40.0, "tint": Color(1.12, 0.94, 0.76) },   # Peak   — warm canyon gold
]

static func index(hm: float) -> int:
	var n := 0
	for i in range(BANDS.size()):
		if hm >= BANDS[i]["h"]:
			n = i
	return n

static func tint(hm: float) -> Color:
	if hm <= BANDS[0]["h"]:
		return BANDS[0]["tint"]
	for i in range(BANDS.size() - 1):
		if hm < BANDS[i + 1]["h"]:
			var t: float = (hm - BANDS[i]["h"]) / (BANDS[i + 1]["h"] - BANDS[i]["h"])
			return (BANDS[i]["tint"] as Color).lerp(BANDS[i + 1]["tint"], t)
	return BANDS[BANDS.size() - 1]["tint"]
