extends SceneTree
## Balance benchmark: plays levels with a bot, without drawing anything, and
## prints how often it wins. Run from the project folder:
##   godot --headless -s scripts/bench.gd -- --bot=avg --levels=1-10 --runs=10

const B = preload("res://scripts/balance.gd")
const Sim = preload("res://scripts/sim.gd")
const Bot = preload("res://scripts/bot.gd")

const DT := 1.0 / 30.0


func _init() -> void:
	var bot_name := "avg"
	var first := 1
	var last := 10
	var runs := 10
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bot="):
			bot_name = a.get_slice("=", 1)
		elif a.begins_with("--levels="):
			first = int(a.get_slice("=", 1).get_slice("-", 0))
			last = int(a.get_slice("=", 1).get_slice("-", 1))
		elif a.begins_with("--runs="):
			runs = int(a.get_slice("=", 1))
	var sim := Sim.new()
	var total_wins := 0
	for level in range(first, last + 1):
		var wins := 0
		var army := 0.0     # soldiers when the boss appears, over runs that got there
		var reached := 0
		var fight := 0.0    # seconds the boss fight lasted, over wins
		var est := 0.0
		for run in runs:
			var bot := Bot.new(bot_name, level * 1000 + run)
			sim.reset(level)
			est = sim.events[-1].est
			var seen_boss := false
			var boss_time := 0.0
			var ticks := 0
			while sim.outcome == 0 and ticks < 30 * 300:
				bot.steer(sim, DT)
				sim.tick(DT)
				ticks += 1
				if sim.boss_active:
					if not seen_boss:
						seen_boss = true
						reached += 1
						army += sim.soldiers
					boss_time += DT
			if sim.outcome > 0:
				wins += 1
				fight += boss_time
		total_wins += wins
		print("BENCH bot=%s level=%d wins=%d/%d reached_boss=%d army=%.0f expected=%.0f fight=%.1fs" % [
			bot_name, level, wins, runs, reached, army / maxf(reached, 1), est, fight / maxf(wins, 1)])
	print("BENCH bot=%s total=%d/%d" % [bot_name, total_wins, runs * (last - first + 1)])
	quit()
