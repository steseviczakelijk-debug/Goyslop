extends RefCounted
## Automatic players of three skill levels, used to smoke-test levels and to
## measure balance (see scripts/bench.gd).

const B = preload("res://scripts/balance.gd")
const Sim = preload("res://scripts/sim.gd")

## pick: chance to take the better gate. speed: how fast the squad is dragged.
## shoots_gates: aims at a gate to raise it while nothing else is in range.
## dodges: steps aside when the troll raises his mace.
const SKILLS := {
	"bad": {"pick": 0.5, "speed": 3.0, "shoots_gates": false, "dodges": false},
	"avg": {"pick": 0.8, "speed": 6.0, "shoots_gates": true, "dodges": false},
	"perfect": {"pick": 1.0, "speed": 9.0, "shoots_gates": true, "dodges": true},
}

var skill: Dictionary
var rng := RandomNumberGenerator.new()
var choices := {}  # gate pair -> the gate this player decided to take


func _init(skill_name := "perfect", seed_value := 1) -> void:
	skill = SKILLS[skill_name]
	rng.seed = seed_value


func reset() -> void:
	choices.clear()


func _choose(sim: Sim, pair: int) -> Sim.Gate:
	if choices.has(pair):
		for g in sim.gates:
			if g.id == choices[pair]:
				return g
	var best: Sim.Gate = null
	var worst: Sim.Gate = null
	for g in sim.gates:
		if g.pair == pair:
			if best == null or g.apply(sim.soldiers) > best.apply(sim.soldiers):
				worst = best if worst == null else worst
				best = g
			else:
				worst = g
	var pick := best if (worst == null or rng.randf() < skill.pick) else worst
	choices[pair] = pick.id
	return pick


func steer(sim: Sim, dt: float) -> void:
	var target := sim.squad_x
	var near_gate: Sim.Gate = null
	for g in sim.gates:
		if g.z > -14.0:
			near_gate = g
			break
	if near_gate != null:
		var g := _choose(sim, near_gate.pair)
		target = (g.x0 + g.x1) * 0.5
	else:
		var near := -1
		for i in sim.e_count:
			if sim.e_z[i] > -B.BULLET_RANGE and (near < 0 or sim.e_z[i] > sim.e_z[near]):
				near = i
		if near >= 0:
			target = sim.e_x[near]
		elif sim.boss_active:
			target = sim.boss_x
			if skill.dodges and sim.boss_pose == 1:
				var away := -1.0 if sim.boss_x > 0.0 else 1.0
				target = sim.boss_x + away * (B.BOSS_SMASH_HALF + sim.squad_r + 0.8)
		elif skill.shoots_gates and not sim.gates.is_empty():
			var g := _choose(sim, sim.gates[0].pair)
			target = (g.x0 + g.x1) * 0.5
	sim.move_squad(move_toward(sim.squad_x, target, skill.speed * dt) - sim.squad_x)
