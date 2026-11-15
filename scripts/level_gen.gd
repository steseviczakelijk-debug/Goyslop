extends RefCounted
## Builds the list of things a level throws at the player, from its number alone.

const B = preload("res://scripts/balance.gd")


## Returns {"events": Array, "length": float}. Each event has "s", its distance
## along the track, and a "type" of "gates", "wave" or "boss".
static func generate(lv: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * lv + 13
	var events: Array = []
	var est := 1.0  # army size a player who picks well should have by now
	var s := B.FIRST_SEGMENT_AT
	var segments := mini(B.BASE_SEGMENTS + lv, B.MAX_SEGMENTS)
	var growth := minf(1.0 + lv * B.GROWTH_PER_LEVEL, B.GROWTH_MAX)
	if lv <= B.EARLY_EASE.size():
		growth *= B.EARLY_EASE[lv - 1]
	var share := 0.0  # part of each wave that is armored
	if lv >= B.ARMORED_FROM_LEVEL:
		share = minf(B.ARMORED_SHARE + (lv - B.ARMORED_FROM_LEVEL) * B.ARMORED_SHARE_GROWTH, B.ARMORED_SHARE_MAX)
	for i in segments:
		var best := {}
		if est >= 4.0 and rng.randf() < 0.25:
			best = {"op": "mul", "value": 3 if rng.randf() < 0.15 else 2}
		else:
			best = {"op": "add", "value": int(round(est * rng.randf_range(0.4, 1.0))) + rng.randi_range(1, 3)}
		var other := {}
		# The two learning levels have no gates that take soldiers away.
		if rng.randf() < 0.5 and lv > B.EARLY_EASE.size():
			other = {"op": "add", "value": -maxi(1, int(round(est * rng.randf_range(0.2, 0.5))))}
		else:
			other = {"op": "add", "value": rng.randi_range(1, 3)}
		var flip := rng.randf() < 0.5
		events.append({"s": s, "type": "gates", "left": other if flip else best, "right": best if flip else other})
		if best.op == "mul":
			est *= best.value
		else:
			# A good player also shoots the gate about halfway to its maximum.
			est += best.value + 0.5 * maxf(B.GATE_GROW_MIN, absf(best.value) * B.GATE_GROW_SHARE)
		s += B.SEGMENT_GAP

		# Armored orcs take more arrows, so a wave that has them is smaller.
		var want := est * rng.randf_range(B.WAVE_MIN, B.WAVE_MAX) * growth * (0.5 if i == 0 else 1.0)
		want /= 1.0 + (B.ARMORED_HP - 1.0) * share
		var hp := maxf(1.0, ceilf(want / B.WAVE_CAP))
		var count := clampi(int(want / hp), 3, B.WAVE_CAP)
		var x0 := -B.ROAD_HALF + 0.5
		var x1 := B.ROAD_HALF - 0.5
		if count < 24:
			if rng.randf() < 0.5:
				x1 = -0.3
			else:
				x0 = 0.3
		events.append({"s": s, "type": "wave", "count": count, "hp": hp, "x0": x0, "x1": x1, "armored": int(round(count * share))})
		var per_row := int((x1 - x0) / B.ENEMY_SPACING) + 1
		s += B.SEGMENT_GAP + ceilf(float(count) / per_row) * B.ENEMY_SPACING
		est *= 0.85
	s += 8.0
	events.append({"s": s, "type": "boss", "hp": est * B.BOSS_HP_FACTOR * growth, "est": est})
	return {"events": events, "length": s}


## Only the boss, tough enough to reach the squad: for checking his attack.
static func boss_only() -> Dictionary:
	return {"events": [{"s": 30.0, "type": "boss", "hp": 1000000.0}], "length": 30.0}


## A deliberately brutal level for measuring performance on a phone.
static func stress() -> Dictionary:
	var events: Array = []
	var s := 30.0
	for i in 12:
		events.append({"s": s, "type": "wave", "count": B.WAVE_CAP, "hp": 40.0, "x0": -B.ROAD_HALF + 0.5, "x1": B.ROAD_HALF - 0.5})
		s += 12.0
	s += 60.0
	events.append({"s": s, "type": "boss", "hp": 1.0})
	return {"events": events, "length": s}
