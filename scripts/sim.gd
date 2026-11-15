extends RefCounted
## The game rules, with no drawing or input: the squad, arrows, enemies, gates and
## boss, advanced one frame at a time. The world view only reads this state.

const B = preload("res://scripts/balance.gd")
const LevelGen = preload("res://scripts/level_gen.gd")

const N_BUCKETS := 22
const BUCKET_WIDTH := 0.5


class Gate:
	var id: int
	var x0: float
	var x1: float
	var z: float
	var op: String
	var value: int
	var hits := 0
	var pair: int

	func apply(n: int) -> int:
		return n * value if op == "mul" else n + value


var soldiers := 1
var squad_x := 0.0
var squad_r := 0.3
var distance := 0.0
var level_length := 1.0
var scroll := 0.0
var fire_timer := 0.0
var events: Array = []
var next_event := 0
var outcome := 0  # 0 while playing, 1 on win, -1 on loss
## What happened this tick, for the view and audio to react to. Each entry is
## [kind, ...]: ["volley"], ["shot", slot], ["hit"], ["kill", x, z], ["lost", x, z, count],
## ["gate", x, gained, good], ["grow", gate_id], ["boss_hit"], ["boss_dead", x, z],
## ["windup"], ["smash", x, z, hit].
var fx: Array = []
var coins_earned := 0

var e_x := PackedFloat32Array()
var e_z := PackedFloat32Array()
var e_hp := PackedFloat32Array()
var e_flash := PackedFloat32Array()
var e_seed := PackedFloat32Array()  # 0..1 per orc: size and step timing
var e_count := 0
var buckets: Array = []

var b_x := PackedFloat32Array()
var b_z := PackedFloat32Array()
var b_dmg := PackedFloat32Array()
var b_left := PackedFloat32Array()
var b_count := 0

var gates: Array = []
var next_pair := 0
var next_gate_id := 0

var boss_active := false
var boss_hp := 0.0
var boss_max := 1.0
var boss_x := 0.0
var boss_z := 0.0
var boss_flash := 0.0
var boss_pose := 0     # 0 walking, 1 mace raised, 2 mace on the ground
var boss_timer := 0.0

var formation := PackedVector2Array()
var rng := RandomNumberGenerator.new()


func _init() -> void:
	e_x.resize(B.MAX_ENEMIES)
	e_z.resize(B.MAX_ENEMIES)
	e_hp.resize(B.MAX_ENEMIES)
	e_flash.resize(B.MAX_ENEMIES)
	e_seed.resize(B.MAX_ENEMIES)
	b_x.resize(B.MAX_BULLETS)
	b_z.resize(B.MAX_BULLETS)
	b_dmg.resize(B.MAX_BULLETS)
	b_left.resize(B.MAX_BULLETS)
	for i in N_BUCKETS:
		buckets.append(PackedInt32Array())
	for i in B.MAX_SHOWN:
		var r := B.FORMATION_SPACING * sqrt(float(i))
		var a := i * 2.39996
		formation.append(Vector2(cos(a) * r, sin(a) * r))


func reset(level: int) -> void:
	_load(LevelGen.generate(level), 1)
	rng.seed = level


func reset_boss_test() -> void:
	_load(LevelGen.boss_only(), 60)


func reset_stress() -> void:
	_load(LevelGen.stress(), 100000)


func _load(data: Dictionary, start_soldiers: int) -> void:
	events = data.events
	level_length = data.length
	gates.clear()
	e_count = 0
	b_count = 0
	boss_active = false
	soldiers = start_soldiers
	squad_x = 0.0
	distance = 0.0
	next_event = 0
	fire_timer = 0.0
	scroll = B.SCROLL_SPEED
	outcome = 0
	coins_earned = 0


func move_squad(dx: float) -> void:
	squad_x = clampf(squad_x + dx, -B.ROAD_HALF + 0.4, B.ROAD_HALF - 0.4)


func progress() -> float:
	return clampf(distance / level_length, 0.0, 1.0)


func _spawn(ev: Dictionary) -> void:
	var z: float = -(ev.s - distance)
	match ev.type:
		"gates":
			_spawn_gate(ev.left, -B.ROAD_HALF, 0.0, z)
			_spawn_gate(ev.right, 0.0, B.ROAD_HALF, z)
			next_pair += 1
		"wave":
			var per_row := int((ev.x1 - ev.x0) / B.ENEMY_SPACING) + 1
			for i in ev.count:
				if e_count >= B.MAX_ENEMIES:
					break
				# A little disorder makes it a horde instead of a parade.
				e_x[e_count] = ev.x0 + (i % per_row) * B.ENEMY_SPACING + rng.randf_range(-0.14, 0.14)
				e_z[e_count] = z - (i / per_row) * B.ENEMY_SPACING + rng.randf_range(-0.18, 0.18)
				e_seed[e_count] = rng.randf()
				e_hp[e_count] = ev.hp
				e_flash[e_count] = 0.0
				e_count += 1
		"boss":
			boss_active = true
			# Never let an oversized army delete the boss instantly.
			boss_hp = maxf(ev.hp, soldiers * B.BOSS_HP_PER_SOLDIER)
			boss_max = boss_hp
			boss_x = 0.0
			boss_z = z
			boss_pose = 0
			boss_timer = 0.0


func _spawn_gate(def: Dictionary, x0: float, x1: float, z: float) -> void:
	var g := Gate.new()
	g.id = next_gate_id
	next_gate_id += 1
	g.x0 = x0
	g.x1 = x1
	g.z = z
	g.op = def.op
	g.value = def.value
	g.pair = next_pair
	gates.append(g)


func tick(dt: float) -> void:
	fx.clear()
	distance += scroll * dt
	while next_event < events.size() and events[next_event].s - distance <= B.SPAWN_AHEAD:
		_spawn(events[next_event])
		next_event += 1
	squad_r = 0.3 + B.FORMATION_SPACING * sqrt(float(mini(soldiers, B.MAX_SHOWN)))

	fire_timer -= dt
	if fire_timer <= 0.0:
		fire_timer += B.FIRE_INTERVAL
		_fire()

	_update_bullets(dt)
	_update_enemies(dt)
	_update_gates(dt)
	_update_boss(dt)

	if soldiers <= 0 and outcome == 0:
		soldiers = 0
		outcome = -1


func _fire() -> void:
	var shown := mini(soldiers, B.MAX_SHOWN)
	var shooters := mini(soldiers, B.MAX_SHOOTERS)
	var dmg := float(soldiers) / shooters
	fx.append(["volley"])
	for i in shooters:
		if b_count >= B.MAX_BULLETS:
			return
		var slot := rng.randi() % shown
		var f := formation[slot]
		fx.append(["shot", slot])
		b_x[b_count] = clampf(squad_x + f.x, -B.ROAD_HALF + 0.1, B.ROAD_HALF - 0.1)
		b_z[b_count] = f.y - 0.5
		b_dmg[b_count] = dmg
		b_left[b_count] = B.BULLET_RANGE
		b_count += 1


func _update_bullets(dt: float) -> void:
	for k in N_BUCKETS:
		buckets[k].clear()
	for i in e_count:
		if e_z[i] > -B.BULLET_RANGE - 2.0:
			var k := clampi(int((e_x[i] + B.ROAD_HALF + 1.5) / BUCKET_WIDTH), 0, N_BUCKETS - 1)
			buckets[k].append(i)

	var step := B.BULLET_SPEED * dt
	var any_hit := false
	var i := 0
	while i < b_count:
		var x := b_x[i]
		var z_old := b_z[i]
		var z_new := z_old - step
		var dmg := b_dmg[i]

		for g in gates:
			if g.op == "add" and g.z <= z_old and g.z >= z_new and x >= g.x0 and x < g.x1:
				g.hits += 1
				if g.hits % B.GATE_HITS_PER_POINT == 0:
					g.value += 1
					fx.append(["grow", g.id])
				dmg = 0.0
				break

		if dmg > 0.0 and boss_active and absf(x - boss_x) < B.BOSS_R and boss_z <= z_old + 1.0 and boss_z >= z_new - 1.0:
			boss_hp -= dmg
			boss_flash = 1.0
			fx.append(["boss_hit"])
			dmg = 0.0

		if dmg > 0.0:
			var kc := int((x + B.ROAD_HALF + 1.5) / BUCKET_WIDTH)
			for k in range(maxi(kc - 1, 0), mini(kc + 2, N_BUCKETS)):
				for j in buckets[k]:
					if e_hp[j] > 0.0 and absf(e_x[j] - x) < B.ENEMY_R and e_z[j] <= z_old + B.ENEMY_R and e_z[j] >= z_new - B.ENEMY_R:
						var d := minf(dmg, e_hp[j])
						e_hp[j] -= d
						e_flash[j] = 1.0
						any_hit = true
						if e_hp[j] <= 0.0:
							fx.append(["kill", e_x[j], e_z[j]])
						dmg -= d
						if dmg <= 0.001:
							break
				if dmg <= 0.001:
					break

		b_left[i] -= step
		if dmg <= 0.001 or b_left[i] <= 0.0:
			b_count -= 1
			b_x[i] = b_x[b_count]
			b_z[i] = b_z[b_count]
			b_dmg[i] = b_dmg[b_count]
			b_left[i] = b_left[b_count]
		else:
			b_z[i] = z_new
			b_dmg[i] = dmg
			i += 1
	if any_hit:
		fx.append(["hit"])


func _update_enemies(dt: float) -> void:
	var dz := (scroll + B.ENEMY_SPEED) * dt
	var steer := B.ENEMY_STEER * dt
	var i := 0
	while i < e_count:
		var remove := e_hp[i] <= 0.0
		if remove:
			coins_earned += B.COINS_PER_KILL
		else:
			var z := e_z[i] + dz
			var x := e_x[i]
			e_flash[i] = maxf(0.0, e_flash[i] - dt * 9.0)
			if z > -B.ENEMY_STEER_RANGE:
				x = move_toward(x, squad_x, steer)
				e_x[i] = x
			e_z[i] = z
			if z > -squad_r - B.ENEMY_R and absf(x - squad_x) < squad_r + B.ENEMY_R:
				var cost := int(ceilf(e_hp[i]))
				soldiers -= cost
				fx.append(["lost", x, z, cost])
				remove = true
			elif z > 6.0:
				remove = true
		if remove:
			e_count -= 1
			e_x[i] = e_x[e_count]
			e_z[i] = e_z[e_count]
			e_hp[i] = e_hp[e_count]
			e_flash[i] = e_flash[e_count]
			e_seed[i] = e_seed[e_count]
		else:
			i += 1


func _update_gates(dt: float) -> void:
	var taken := -1
	for g in gates:
		g.z += scroll * dt
		if g.z >= -0.2 and squad_x >= g.x0 and squad_x < g.x1:
			var before := soldiers
			soldiers = clampi(g.apply(soldiers), 0, B.MAX_SOLDIERS)
			fx.append(["gate", (g.x0 + g.x1) * 0.5, soldiers - before, soldiers >= before])
			taken = g.pair
	if taken >= 0 or (not gates.is_empty() and gates[0].z > 4.0):
		var drop: int = taken if taken >= 0 else gates[0].pair
		gates = gates.filter(func(q): return q.pair != drop)


func _update_boss(dt: float) -> void:
	if not boss_active:
		return
	if boss_z > -B.BOSS_STOP_DISTANCE:
		scroll = 0.0
	boss_flash = maxf(0.0, boss_flash - dt * 9.0)
	if boss_hp <= 0.0:
		boss_active = false
		coins_earned += B.COINS_PER_BOSS
		fx.append(["boss_dead", boss_x, boss_z])
		outcome = 1
		return
	boss_x = move_toward(boss_x, squad_x, B.BOSS_STEER * dt)
	match boss_pose:
		0:
			# Walk up until the squad is within reach of the mace.
			boss_z += (scroll + B.BOSS_SPEED) * dt
			if boss_z > -squad_r - B.BOSS_REACH:
				boss_pose = 1
				boss_timer = B.BOSS_WINDUP
				fx.append(["windup"])
		1:
			boss_timer -= dt
			if boss_timer <= 0.0:
				# The mace lands where the troll is facing now: step aside in
				# time and it misses.
				var hit := absf(squad_x - boss_x) < B.BOSS_SMASH_HALF + squad_r * 0.5
				fx.append(["smash", boss_x, boss_z + B.BOSS_REACH, hit])
				if hit:
					var loss := mini(soldiers, maxi(B.BOSS_SMASH_MIN, int(ceilf(soldiers * B.BOSS_SMASH_SHARE))))
					soldiers -= loss
					fx.append(["lost", squad_x, -squad_r, loss])
				boss_pose = 2
				boss_timer = B.BOSS_RECOVER
		2:
			boss_timer -= dt
			if boss_timer <= 0.0:
				boss_pose = 0
