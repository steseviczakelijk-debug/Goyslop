extends Node3D
## Bowbridge: Archer Legion. Drag to move your archers along the bridge; shooting
## is automatic. This script only wires the parts together: rules live in
## scripts/sim.gd, drawing in scripts/world.gd, interface in scripts/hud.gd and
## every tunable number in scripts/balance.gd.

const B = preload("res://scripts/balance.gd")
const Sim = preload("res://scripts/sim.gd")
const World = preload("res://scripts/world.gd")
const Hud = preload("res://scripts/hud.gd")
const SaveData = preload("res://scripts/save_data.gd")
const Bot = preload("res://scripts/bot.gd")
const Audio = preload("res://scripts/audio.gd")

enum State { MENU, PLAY, WIN, LOSE }

var state := State.MENU
var level := 1
var coins := 0
var time := 0.0
var stress := false
var sim := Sim.new()
var world: World
var hud: Hud
var audio: Audio
var buzz_ready := 0.0

# Test hooks, set from the command line after "--".
var autoplay := false
var auto_levels := 1
var shot_path := ""
var shot_time := 6.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--autoplay":
			autoplay = true
		elif a == "--stress":
			autoplay = true
			stress = true
		elif a.begins_with("--levels="):
			auto_levels = int(a.get_slice("=", 1))
		elif a.begins_with("--level="):
			level = int(a.get_slice("=", 1))
		elif a.begins_with("--shot="):
			shot_path = a.get_slice("=", 1)
			autoplay = true
		elif a.begins_with("--shot-time="):
			shot_time = float(a.get_slice("=", 1))
	if not autoplay:
		var data := SaveData.read()
		level = data.level
		coins = data.coins
	world = World.new()
	add_child(world)
	hud = Hud.new()
	add_child(hud)
	hud.stress_requested.connect(_start_stress)
	audio = Audio.new()
	add_child(audio)
	_reset_level()
	if autoplay:
		_start()


func _reset_level() -> void:
	if stress:
		sim.reset_stress()
	else:
		sim.reset(level)
	state = State.MENU
	world.end_celebration()
	hud.set_level(level)
	hud.show_overlay("", "PLAY", "Drag to move your archers")


func _start() -> void:
	state = State.PLAY
	hud.hide_overlay()
	audio.play("click")
	audio.start_music()


func _start_stress() -> void:
	stress = true
	_reset_level()
	_start()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenDrag and state == State.PLAY:
		var w := get_viewport().get_visible_rect().size.x
		sim.move_squad(event.relative.x * (B.ROAD_HALF * 2.0 / w) * B.DRAG_SENSITIVITY)
	elif event is InputEventScreenTouch and event.pressed:
		match state:
			State.MENU:
				_start()
			State.WIN, State.LOSE:
				_reset_level()
				_start()


func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	time += dt
	if state == State.PLAY:
		if autoplay:
			Bot.steer(sim, dt)
		sim.tick(dt)
		world.apply_fx(sim)
		_play_fx()
		if sim.outcome != 0:
			_finish(sim.outcome > 0)
	world.render(sim, time)
	hud.set_progress(sim.progress())
	hud.set_coins(coins + (sim.coins_earned if state == State.PLAY else 0))
	hud.update_perf(dt, sim.e_count, sim.b_count)
	if shot_path != "" and time >= shot_time:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot_path)
		get_tree().quit()


## Turns this tick's simulation events into sound and vibration.
func _play_fx() -> void:
	for e in sim.fx:
		match e[0]:
			"shot":
				audio.play("shoot", -16.0, 0.11, 0.15)
			"kill":
				audio.play("kill", -8.0, 0.05, 0.2)
				audio.play("coin", -18.0, 0.25, 0.1)
			"lost":
				audio.play("lost", -4.0, 0.12)
				_buzz(25)
			"gate":
				audio.play("gate_good" if e[3] else "gate_bad", 0.0, 0.0, 0.03)
				_buzz(30)
			"grow":
				audio.play("grow", -14.0, 0.05, 0.05)
			"boss_hit":
				audio.play("hit", -8.0, 0.07, 0.2)
			"boss_dead":
				audio.play("boss_dead", 2.0)
	if world.stomped:
		world.stomped = false
		audio.play("stomp", -2.0)
		_buzz(20)


## Short phone vibration, limited so heavy fights do not buzz non-stop.
func _buzz(ms: int) -> void:
	if autoplay or time < buzz_ready:
		return
	buzz_ready = time + 0.15
	Input.vibrate_handheld(ms)


func _finish(win: bool) -> void:
	state = State.WIN if win else State.LOSE
	sim.b_count = 0
	audio.duck_music()
	if win:
		world.celebrate(sim)
		audio.play("win", 0.0, 0.0, 0.0)
		_buzz(180)
	else:
		world.add_shake(0.5)
		audio.play("lose", 0.0, 0.0, 0.0)
		_buzz(120)
	hud.show_overlay("VICTORY" if win else "DEFEAT", "NEXT LEVEL" if win else "RETRY", "")
	if autoplay:
		print("RESULT level=%d win=%s soldiers=%d progress=%.2f" % [level, win, sim.soldiers, sim.progress()])
	if stress:
		stress = false
	else:
		coins += sim.coins_earned
		if win:
			level += 1
		if not autoplay:
			SaveData.write(level, coins)
	if autoplay and shot_path == "":
		auto_levels -= 1
		if auto_levels <= 0:
			get_tree().quit()
		else:
			_reset_level()
			_start()
