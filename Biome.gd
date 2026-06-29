extends RefCounted

# Shared biome colour-grading. A height (metres) maps to a tint that the backdrop
# and the platforms both multiply by, so the world visibly shifts mood as you climb:
#   Woods (lush green) → Ruins (cool stone) → Cliffs (warm dusk) → Peak (pale cold).
# Tints lerp across band boundaries for a smooth transition.

const BANDS := [
	{ "h": 0.0,  "tint": Color(1.00, 1.04, 0.96) },   # Woods  — lush green
	{ "h": 13.0, "tint": Color(0.84, 0.91, 0.95) },   # Ruins  — cool desaturated stone
	{ "h": 27.0, "tint": Color(1.08, 0.93, 0.74) },   # Cliffs — warm golden dusk
	{ "h": 40.0, "tint": Color(0.82, 0.95, 1.14) },   # Peak   — pale cold blue
]

static func tint(hm: float) -> Color:
	if hm <= BANDS[0]["h"]:
		return BANDS[0]["tint"]
	for i in range(BANDS.size() - 1):
		if hm < BANDS[i + 1]["h"]:
			var t := (hm - BANDS[i]["h"]) / (BANDS[i + 1]["h"] - BANDS[i]["h"])
			return (BANDS[i]["tint"] as Color).lerp(BANDS[i + 1]["tint"], t)
	return BANDS[BANDS.size() - 1]["tint"]
