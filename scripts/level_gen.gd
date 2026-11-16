extends RefCounted
## Builds the list of things a level throws at the player, from its number alone.

const B = preload("res://scripts/balance.gd")
const Table = preload("res://scripts/level_table.gd")


## Returns {"events": Array, "length": float}. Each event has "s", its distance
## along the track, and a "type" of "gates", "wave" or "boss".
##
## Every level is built around one perfect route. scripts/calibrate.gd plays
## that route once per level and stores, in level_table.gd, how hard the waves
## may be and how big the perfect army is at the troll. `tune` overrides the
## table ({"waves": scale, "army": soldiers}); calibration uses that.
static func generate(level: int, tune := {}) -> Dictionary:
	# Past the measured levels the layouts repeat; pace and toughness are at
	# their ceiling by then, so a repeated level plays exactly as measured.
	var lv := layout_level(level)
	if tune.is_empty() and Table.DATA.has(lv):
		tune = {"waves": Table.DATA[lv][0], "army": Table.DATA[lv][1], "boss_max": Table.DATA[lv][2]}
	var wave_scale: float = tune.get("waves", 1.0)
	var rng := RandomNumberGenerator.new()
	# Extras draw from their own generator so they never shift the layout.
	var extra := RandomNumberGenerator.new()
	extra.seed = 104729 * lv + 7
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
		# Each pair is a close call, and `est` follows the better choice: the
		# army of a player on the perfect route.
		var best := {}
		var other := {}
		var roll := rng.randf()
		if lv > B.EARLY_EASE.size() and est >= 12.0 and roll < 0.15:
			# Two gates that both cost soldiers: pick the lesser evil.
			var loss := maxi(2, int(round(est * rng.randf_range(0.1, 0.2))))
			best = {"op": "add", "value": -loss}
			other = {"op": "add", "value": -maxi(loss + 1, int(round(loss * rng.randf_range(1.2, 1.6))))}
			est -= loss
		elif est >= 6.0 and roll < 0.4:
			# Multiply against a plus worth nearly as much.
			var factor := 3 if rng.randf() < 0.15 else 2
			best = {"op": "mul", "value": factor}
			other = {"op": "add", "value": maxi(1, int(round(est * (factor - 1) * rng.randf_range(0.7, 0.92))))}
			est *= factor
		else:
			var v := maxi(2, int(round(est * rng.randf_range(0.4, 1.0))) + rng.randi_range(1, 3))
			best = {"op": "add", "value": v}
			other = {"op": "add", "value": clampi(int(round(v * rng.randf_range(0.6, 0.9))), 1, maxi(1, v - 1))}
			# The perfect player also shoots the gate up on the way in.
			est += v + maxi(1, int(round(v * B.GATE_STEP_SHARE))) * _expected_steps(est, lv)
		# Sometimes the lesser gate offers a different kind of power instead.
		if lv >= B.BUFF_GATES_FROM_LEVEL and best.op == "add" and best.value > 0 and extra.randf() < B.BUFF_GATE_CHANCE:
			other = {"op": "rate" if extra.randf() < 0.5 else "dmg", "value": B.BUFF_GATE_PERCENT}
		var flip := rng.randf() < 0.5
		events.append({"s": s, "type": "gates", "left": other if flip else best, "right": best if flip else other})
		s += B.SEGMENT_GAP
		if lv >= B.PROPS_FROM_LEVEL and i >= 1 and extra.randf() < B.PROP_CHANCE:
			var chest := extra.randf() < B.CHEST_SHARE
			events.append({
				"s": s - B.SEGMENT_GAP * 0.5, "type": "prop", "kind": "chest" if chest else "barrel",
				"x": (-1.0 if extra.randf() < 0.5 else 1.0) * 2.2,
				"hp": maxf(3.0, est * (B.CHEST_HP if chest else B.BARREL_HP)),
				"reward": extra.randi_range(30, 90) + lv * 5 if chest else maxi(2, int(est * B.BARREL_REWARD)),
			})

		# Armored orcs take more arrows, so a wave that has them is smaller.
		# A small army fires few arrows, so the opening waves are lighter and
		# armored orcs only join once the army can deal with them.
		var opening: float = [0.5, 0.75][i] if i < 2 else 1.0
		var tough: float = share if est >= B.ARMORED_MIN_ARMY else 0.0
		var want: float = est * rng.randf_range(B.WAVE_MIN, B.WAVE_MAX) * growth * opening * wave_scale
		want /= 1.0 + (B.ARMORED_HP - 1.0) * tough
		var hp := maxf(1.0, ceilf(want / B.WAVE_CAP))
		var count := clampi(int(want / hp), 3, B.WAVE_CAP)
		var x0 := -B.ROAD_HALF + 0.5
		var x1 := B.ROAD_HALF - 0.5
		if count < 24:
			if rng.randf() < 0.5:
				x1 = -0.3
			else:
				x0 = 0.3
		events.append({"s": s, "type": "wave", "count": count, "hp": hp, "x0": x0, "x1": x1, "armored": int(round(count * tough)),
			"gold": extra.randi() % count if lv >= B.GOLD_FROM_LEVEL and extra.randf() < B.GOLD_CHANCE else -1})
		var per_row := int((x1 - x0) / B.ENEMY_SPACING) + 1
		s += B.SEGMENT_GAP + ceilf(float(count) / per_row) * B.ENEMY_SPACING
	s += 8.0
	var ease: float = B.EARLY_EASE[lv - 1] if lv <= B.EARLY_EASE.size() else 1.0
	# The troll is sized on the army the perfect route really arrives with.
	var army: float = tune.get("army", 0.0)
	if army <= 0.0:
		army = est * B.PERFECT_KEEPS
	# "boss_max" is the toughest troll the perfect route can still beat; the
	# real one is that much weaker than ALLOWED_DEVIATION says.
	var hp: float = army * B.BOSS_HP_PER_SOLDIER * (1.0 - B.ALLOWED_DEVIATION) * ease
	if tune.has("boss_hp"):
		hp = tune.boss_hp
	elif tune.has("boss_max"):
		hp = tune.boss_max * (1.0 - B.ALLOWED_DEVIATION) * ease
	events.append({"s": s, "type": "boss", "hp": hp, "est": est, "army": army})
	return {"events": events, "length": s}


## Only the boss, tough enough to reach the squad: for checking his attack.
static func boss_only() -> Dictionary:
	return {"events": [{"s": 30.0, "type": "boss", "hp": 1000000.0}], "length": 30.0}


## The measured level whose layout `level` uses: itself up to the end of the
## table, after that one of the repeating levels.
static func layout_level(level: int) -> int:
	if level <= B.CALIBRATED_LEVELS:
		return level
	return B.CYCLE_FROM_LEVEL + (level - B.CYCLE_FROM_LEVEL) % (B.CALIBRATED_LEVELS - B.CYCLE_FROM_LEVEL + 1)


## How many growth steps a perfect player shoots out of a gate on the way in.
## A small army fires few arrows, and a faster march leaves less time.
static func _expected_steps(army: float, lv: int) -> int:
	var seconds := B.BULLET_RANGE / (B.SCROLL_SPEED * B.speed_for(lv))
	var hits := seconds / B.FIRE_INTERVAL * minf(army, B.MAX_SHOOTERS) * B.GATE_AIM_SHARE
	# Steps cost HITS, HITS*g, HITS*g^2, ...: invert that geometric sum.
	var g := B.GATE_COST_GROWTH
	return int(log(1.0 + hits * (g - 1.0) / B.GATE_HITS_PER_POINT) / log(g))


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
