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
var paused := false
var settings := {}
var slowmo := 0.0          # real seconds of slow motion left
var overlay_delay := -1.0  # real seconds until the win/lose panel appears
var overlay_args: Array = []

# Test hooks, set from the command line after "--".
var autoplay := false
var auto_levels := 1
var shot_path := ""
var shot_time := 6.0
var shot_file := ""
var shot_clock := 0.0
var shot_menu := false
var tap_test := false
var tap_step := 0
var tap_sent := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--autoplay":
			autoplay = true
		elif a == "--tap-test":
			tap_test = true
		elif a == "--menu":
			shot_menu = true
		elif a == "--stress":
			autoplay = true
			stress = true
		elif a.begins_with("--levels="):
			auto_levels = int(a.get_slice("=", 1))
		elif a.begins_with("--level="):
			level = int(a.get_slice("=", 1))
		elif a.begins_with("--shot="):
			shot_path = a.get_slice("=", 1)
			shot_file = shot_path
			autoplay = true
		elif a.begins_with("--shot-time="):
			shot_time = float(a.get_slice("=", 1))
	settings = SaveData.read()
	if tap_test:
		settings.vibrate = true  # the self-check must not depend on a saved game
	elif not autoplay:
		level = settings.level
		coins = settings.coins
	world = World.new()
	add_child(world)
	hud = Hud.new()
	add_child(hud)
	hud.stress_requested.connect(_start_stress)
	hud.menu_toggled.connect(func(open): paused = open)
	hud.restart_requested.connect(_restart)
	hud.settings_changed.connect(_on_settings_changed)
	hud.coin_landed.connect(func(): audio.play("coin", -14.0, 0.06, 0.12))
	hud.load_settings(settings.music, settings.sfx, settings.vibrate)
	audio = Audio.new()
	add_child(audio)
	audio.set_volumes(settings.music, settings.sfx)
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


func _restart() -> void:
	_end_slowmo()
	_reset_level()
	_start()


func _on_settings_changed(music: float, sfx: float, vibrate: bool) -> void:
	settings.music = music
	settings.sfx = sfx
	settings.vibrate = vibrate
	audio.set_volumes(music, sfx)
	_save()


func _save() -> void:
	if autoplay or tap_test:
		return
	settings.level = level
	settings.coins = coins
	SaveData.write(settings)


func _notification(what: int) -> void:
	# The Android back button and leaving the app both open the menu.
	if hud != null and (what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED):
		if what == NOTIFICATION_WM_GO_BACK_REQUEST and paused:
			hud.close_menu()
		else:
			hud.open_menu()


func _start_stress() -> void:
	stress = true
	_reset_level()
	_start()


func _unhandled_input(event: InputEvent) -> void:
	if paused or overlay_delay >= 0.0:
		return
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
	_run_timers(dt / Engine.time_scale)
	shot_clock += dt
	if shot_menu and shot_clock > 3.0:
		hud.open_menu()
	if shot_file != "" and shot_clock >= shot_time:
		_take_shot()
	if tap_test:
		_run_tap_test()
	if paused:
		return
	time += dt
	if state == State.PLAY:
		if autoplay:
			Bot.steer(sim, dt)
		sim.tick(dt)
		world.apply_fx(sim)
		_play_fx()
		for at in world.coin_flights:
			hud.fly_coin(at)
		world.coin_flights.clear()
		if sim.outcome != 0:
			_finish(sim.outcome > 0)
	world.render(sim, time)
	hud.set_progress(sim.progress())
	hud.set_coins(coins + (sim.coins_earned if state == State.PLAY else 0))
	hud.update_perf(dt, sim.e_count, sim.b_count)


func _take_shot() -> void:
	var file := shot_file
	shot_file = ""
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(file)
	get_tree().quit()


## Turns this tick's simulation events into sound and vibration.
func _play_fx() -> void:
	for e in sim.fx:
		match e[0]:
			"volley":
				audio.play("shoot", -8.0, 0.0, 0.1)
			"hit":
				_buzz(12, 0.07)
			"kill":
				audio.play("kill", -8.0, 0.05, 0.2)
			"lost":
				audio.play("lost", -4.0, 0.12)
				buzz_ready = 0.0
				_buzz(25)
			"gate":
				audio.play("gate_good" if e[3] else "gate_bad", 0.0, 0.0, 0.03)
				buzz_ready = 0.0
				_buzz(30)
			"grow":
				audio.play("grow", -14.0, 0.05, 0.05)
			"boss_hit":
				audio.play("hit", -8.0, 0.07, 0.2)
				_buzz(12, 0.07)
			"boss_dead":
				audio.play("boss_dead", 2.0)
	if world.stomped:
		world.stomped = false
		audio.play("stomp", -2.0)
		buzz_ready = 0.0
		_buzz(20)


## Phone vibration. `gap` is the minimum time before the next one may start, so
## a hail of arrows ticks steadily instead of buzzing without pause.
func _buzz(ms: int, gap := 0.12) -> void:
	if autoplay or not settings.vibrate or time < buzz_ready:
		return
	buzz_ready = time + gap
	Input.vibrate_handheld(ms)


func _run_timers(real_dt: float) -> void:
	if slowmo > 0.0:
		slowmo -= real_dt
		if slowmo <= 0.0:
			_end_slowmo()
	if overlay_delay >= 0.0:
		overlay_delay -= real_dt
		if overlay_delay < 0.0:
			hud.show_overlay.callv(overlay_args)


func _end_slowmo() -> void:
	slowmo = 0.0
	Engine.time_scale = 1.0


func _finish(win: bool) -> void:
	state = State.WIN if win else State.LOSE
	sim.b_count = 0
	audio.duck_music()
	if win:
		world.celebrate(sim)
		audio.play("win", 0.0, 0.0, 0.0)
		buzz_ready = 0.0
		_buzz(180)
	else:
		world.add_shake(0.5)
		audio.play("lose", 0.0, 0.0, 0.0)
		buzz_ready = 0.0
		_buzz(120)
	overlay_args = ["VICTORY" if win else "DEFEAT", "NEXT LEVEL" if win else "RETRY", ""]
	if autoplay:
		hud.show_overlay.callv(overlay_args)
	else:
		# Let the last blow land in slow motion before the result appears.
		overlay_delay = 0.9 if win else 0.5
		if win:
			slowmo = 0.6
			Engine.time_scale = 0.3
	if autoplay:
		print("RESULT level=%d win=%s soldiers=%d progress=%.2f" % [level, win, sim.soldiers, sim.progress()])
	if stress:
		stress = false
	else:
		coins += sim.coins_earned
		if win:
			level += 1
		_save()
	if autoplay and shot_path == "":
		auto_levels -= 1
		if auto_levels <= 0:
			get_tree().quit()
		else:
			_reset_level()
			_start()


## Self-check for touch routing: taps the play area, the menu button and the
## menu's own buttons, and reports whether each did what it should.
func _run_tap_test() -> void:
	var size := get_viewport().get_visible_rect().size
	var menu_at := func(): return hud.menu_button.get_global_rect().get_center()
	var steps := [
		[0.5, menu_at, "menu button opens menu, game stays in menu state", func(): return paused and state == State.MENU],
		[1.0, func(): return hud.menu_buttons["RESUME"].get_global_rect().get_center(), "resume closes menu", func(): return not paused and state == State.MENU],
		[1.5, func(): return Vector2(size.x * 0.5, size.y * 0.8), "tap on field starts the game", func(): return state == State.PLAY],
		[2.0, menu_at, "menu button pauses play", func(): return paused and state == State.PLAY],
		[2.5, func(): return hud.menu_buttons[""].get_global_rect().get_center(), "vibration toggles off", func(): return settings.vibrate == false],
		[3.0, func(): return hud.menu_buttons["RESTART LEVEL"].get_global_rect().get_center(), "restart closes menu and restarts", func(): return not paused and state == State.PLAY and sim.distance < 5.0],
	]
	if tap_step >= steps.size():
		if shot_clock > 3.7:
			get_tree().quit()
		return
	var step: Array = steps[tap_step]
	if shot_clock < step[0]:
		return
	if tap_step * 2 == tap_sent:
		for pressed in [true, false]:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = pressed
			ev.position = step[1].call()
			ev.global_position = ev.position
			Input.parse_input_event(ev)
		tap_sent += 1
	elif shot_clock > step[0] + 0.25:
		print("TAP %s: %s" % ["ok  " if step[3].call() else "FAIL", step[2]])
		tap_sent += 1
		tap_step += 1
