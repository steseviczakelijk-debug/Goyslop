extends RefCounted
## A simple automatic player, used to smoke-test levels and measure balance.

const B = preload("res://scripts/balance.gd")
const Sim = preload("res://scripts/sim.gd")


static func steer(sim: Sim, dt: float) -> void:
	var target: float = sim.squad_x
	var best: Sim.Gate = null
	for g in sim.gates:
		if g.z > -14.0 and (best == null or (g.pair == best.pair and g.apply(sim.soldiers) > best.apply(sim.soldiers))):
			best = g
	if best != null:
		target = (best.x0 + best.x1) * 0.5
	else:
		var near := -1
		for i in sim.e_count:
			if sim.e_z[i] > -B.BULLET_RANGE and (near < 0 or sim.e_z[i] > sim.e_z[near]):
				near = i
		if near >= 0:
			target = sim.e_x[near]
		elif sim.boss_active:
			target = sim.boss_x
		elif not sim.gates.is_empty():
			var g: Sim.Gate = sim.gates[0]
			for q in sim.gates:
				if q.pair == g.pair and q.apply(sim.soldiers) > g.apply(sim.soldiers):
					g = q
			target = (g.x0 + g.x1) * 0.5
	sim.move_squad(move_toward(sim.squad_x, target, 9.0 * dt) - sim.squad_x)
