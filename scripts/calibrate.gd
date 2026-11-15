extends SceneTree
## Plays the perfect route of every level once and writes level_table.gd:
## per level, how much the waves must be scaled so that route keeps most of its
## army, and how big that army is when the troll appears. Run after changing
## anything that affects how levels play:
##   godot --headless -s scripts/calibrate.gd

const B = preload("res://scripts/balance.gd")
const Sim = preload("res://scripts/sim.gd")
const Bot = preload("res://scripts/bot.gd")
const LevelGen = preload("res://scripts/level_gen.gd")

const DT := 1.0 / 30.0


const AVG_RUNS := 8


func _average_reaches(sim: Sim, level: int, data: Dictionary) -> int:
	var reached := 0
	for run in AVG_RUNS:
		var bot := Bot.new("avg", level * 1000 + 500 + run)
		sim.reset_with(level, data)
		var ticks := 0
		while sim.outcome == 0 and not sim.boss_active and ticks < 30 * 300:
			bot.steer(sim, DT)
			sim.tick(DT)
			ticks += 1
		if sim.boss_active:
			reached += 1
	return reached


func _init() -> void:
	var sim := Sim.new()
	var lines := PackedStringArray()
	var eased := 0
	for level in range(1, B.CALIBRATED_LEVELS + 1):
		var scale := 1.0
		var army := 0
		for attempt in 30:
			var data := LevelGen.generate(level, {"waves": scale, "army": 1.0})
			var bot := Bot.new("perfect", level)
			sim.reset_with(level, data)
			var ticks := 0
			while sim.outcome == 0 and not sim.boss_active and ticks < 30 * 300:
				bot.steer(sim, DT)
				sim.tick(DT)
				ticks += 1
			army = sim.soldiers if sim.boss_active else 0
			# The waves are right when the perfect route keeps most of its army
			# and an average player usually makes it to the troll.
			if army >= data.events[-1].est * B.PERFECT_KEEPS and _average_reaches(sim, level, data) >= AVG_RUNS - 1:
				break
			scale *= 0.88
		if scale < 1.0:
			eased += 1
		lines.append("\t%d: [%.3f, %d]," % [level, scale, army])
	var f := FileAccess.open("res://scripts/level_table.gd", FileAccess.WRITE)
	f.store_string("extends RefCounted\n## Written by scripts/calibrate.gd. Do not edit by hand.\n## level: [wave scale, army of the perfect route at the troll]\nconst DATA := {\n%s\n}\n" % "\n".join(lines))
	f.close()
	print("CALIBRATED %d levels, %d needed lighter waves" % [B.CALIBRATED_LEVELS, eased])
	quit()
