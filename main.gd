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
var panel_open := false   # upgrades or daily reward is covering the game
var daily_index := -1     # today's unclaimed reward, or -1
var settings := {}
var slowmo := 0.0          # real seconds of slow motion left
var overlay_delay := -1.0  # real seconds until the win/lose panel appears
var overlay_args: Array = []
var win_stars := 0
var win_earned := 0

# Test hooks, set from the command line after "--".
var autoplay := false
var auto_levels := 1
var shot_path := ""
var shot_time := 6.0
var shot_file := ""
var shot_clock := 0.0
var shot_menu := false
var tap_test := false
var boss_test := false
var win_test := false   # test runs: show the win screen and spin by itself
var idle_bot := false  # test runs: let the squad stand still
var bot := Bot.new("perfect")
var tap_step := 0
var win_test_step := 0
var meta_shot := ""   # test runs: "start", "upgrades" or "daily"
var tap_sent := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--autoplay":
			autoplay = true
		elif a == "--tap-test":
			tap_test = true
		elif a.begins_with("--meta="):
			meta_shot = a.get_slice("=", 1)
		elif a == "--win-test":
			win_test = true
		elif a == "--menu":
			shot_menu = true
		elif a.begins_with("--bot="):
			bot = Bot.new(a.get_slice("=", 1))
		elif a == "--idle":
			idle_bot = true
		elif a == "--boss-test":
			boss_test = true
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
	if meta_shot != "":
		autoplay = false  # these screenshots need the start screen, not a running level
	settings = SaveData.read()
	if tap_test:
		settings.vibrate = true  # the self-check must not depend on a saved game
		for def in B.UPGRADES:
			settings[def.key] = 0
		coins = 1000
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
	hud.win_screen.sfx.connect(func(sound, pitch): audio.play_pitched(sound, -4.0, pitch))
	hud.win_screen.finished.connect(_on_wheel_done)
	hud.meta.blocking_changed.connect(func(blocked): panel_open = blocked)
	hud.meta.buy_requested.connect(_buy_upgrade)
	hud.meta.buttons["upgrades"].pressed.connect(func(): hud.meta.refresh_upgrades(coins, _upgrade_levels()))
	hud.meta.claim_requested.connect(_claim_daily)
	hud.load_settings(settings.music, settings.sfx, settings.vibrate)
	audio = Audio.new()
	add_child(audio)
	audio.set_volumes(settings.music, settings.sfx)
	_reset_level()
	if autoplay:
		_start()
	elif not tap_test and not win_test and meta_shot in ["", "daily"]:
		_offer_daily()


func _reset_level() -> void:
	_apply_upgrades()
	if boss_test:
		sim.reset_boss_test()
	elif stress:
		sim.reset_stress()
	else:
		sim.reset(level)
	state = State.MENU
	bot.reset()
	world.end_celebration()
	hud.set_level(level)
	hud.show_overlay("", "PLAY", "")
	hud.meta.show_start(_can_buy_any(), level <= 2)


func _start() -> void:
	state = State.PLAY
	hud.meta.hide_start()
	hud.hide_overlay()
	audio.play("click")
	audio.start_music()


## The wheel has stopped: pay out what it added on top of the level's coins.
func _on_wheel_done(multiplier: int) -> void:
	coins += win_earned * (multiplier - 1)
	win_earned = 0
	buzz_ready = 0.0
	_buzz(40 * multiplier)
	_save()


# ---------------------------------------------------------------- upgrades

func _upgrade_levels() -> Array:
	var levels := []
	for def in B.UPGRADES:
		levels.append(0 if autoplay else settings[def.key])
	return levels


## Hands the bought upgrades to the simulation before a level is built.
func _apply_upgrades() -> void:
	var levels := _upgrade_levels()
	sim.start_soldiers = 1 + int(levels[0] * B.UPGRADES[0].step)
	sim.damage_mult = 1.0 + levels[1] * B.UPGRADES[1].step
	sim.rate_mult = 1.0 + levels[2] * B.UPGRADES[2].step


## Coins of the running level, including the coin-bonus upgrade.
func _earned() -> int:
	return int(sim.coins_earned * (1.0 + _upgrade_levels()[3] * B.UPGRADES[3].step))


func _can_buy_any() -> bool:
	var levels := _upgrade_levels()
	for i in levels.size():
		if levels[i] < B.UPGRADE_MAX_LEVEL and coins >= B.upgrade_price(i, levels[i]):
			return true
	return false


func _buy_upgrade(index: int) -> void:
	var key: String = B.UPGRADES[index].key
	var owned: int = settings[key]
	var price := B.upgrade_price(index, owned)
	if state != State.MENU or owned >= B.UPGRADE_MAX_LEVEL or coins < price:
		audio.play("gate_bad", -8.0, 0.1, 0.0)
		return
	coins -= price
	settings[key] = owned + 1
	_save()
	audio.play_pitched("gate_good", -2.0, 1.0 + 0.03 * owned)
	buzz_ready = 0.0
	_buzz(30)
	_reset_level()
	hud.meta.refresh_upgrades(coins, _upgrade_levels())
	hud.meta.pop_card(index)


# ---------------------------------------------------------------- daily reward

func _today() -> int:
	var bias: int = Time.get_time_zone_from_system().bias * 60
	return int((Time.get_unix_time_from_system() + bias) / 86400.0)


## Offers today's reward if it has not been claimed. A day skipped restarts
## the seven-day run.
func _offer_daily() -> void:
	var today := _today()
	if settings.daily_day == today:
		return
	var streak: int = settings.daily_streak + 1 if settings.daily_day == today - 1 else 0
	daily_index = streak % B.DAILY_REWARDS.size()
	hud.meta.show_daily(daily_index)


func _claim_daily() -> void:
	if daily_index < 0:
		return
	coins += B.DAILY_REWARDS[daily_index]
	settings.daily_streak = settings.daily_streak + 1 if settings.daily_day == _today() - 1 else 0
	settings.daily_day = _today()
	daily_index = -1
	_save()
	audio.play_pitched("win", -4.0, 1.2)
	buzz_ready = 0.0
	_buzz(60)
	hud.meta.hide_daily()
	hud.meta.show_start(_can_buy_any(), level <= 2)


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
	if paused or panel_open or overlay_delay >= 0.0:
		return
	if event is InputEventScreenDrag and state == State.PLAY:
		var w := get_viewport().get_visible_rect().size.x
		sim.move_squad(event.relative.x * (B.ROAD_HALF * 2.0 / w) * B.DRAG_SENSITIVITY)
	elif event is InputEventScreenTouch and event.pressed:
		match state:
			State.MENU:
				_start()
			State.WIN, State.LOSE:
				# While the reward plays out a tap spins the wheel; only after
				# that does it move on.
				if hud.win_screen.busy():
					hud.win_screen.tap()
				elif state == State.WIN:
					# Back to the start screen, where the coins can be spent.
					_reset_level()
				else:
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
	if meta_shot == "upgrades" and shot_clock > 1.0 and not panel_open:
		coins = 1234
		hud.meta.refresh_upgrades(coins, _upgrade_levels())
		hud.meta.open_upgrades()
	if win_test:
		if win_test_step == 0 and shot_clock > 0.5:
			win_test_step = 1
			state = State.WIN
			win_earned = 654
			hud.show_win(2, 654, 4)
		elif win_test_step == 1 and shot_clock > 4.2:
			win_test_step = 2
			hud.win_screen.tap()
	if paused:
		return
	time += dt
	if state == State.PLAY:
		if autoplay and not idle_bot:
			bot.steer(sim, dt)
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
	hud.set_coins(coins + (_earned() if state == State.PLAY else 0))
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
			"chop":
				audio.play("hit", 0.0, 0.05, 0.1)
			"windup":
				audio.play("lost", -6.0, 0.0, 0.0)
			"smash":
				audio.play("stomp", 6.0, 0.0, 0.0)
				buzz_ready = 0.0
				_buzz(70)
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
			if state == State.WIN:
				hud.show_win(win_stars, win_earned, level * 7919 + coins)
			else:
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
	if win:
		# Stars compare the surviving army with the level's perfect route.
		var perfect: float = sim.events[-1].get("army", 0.0)
		var kept := sim.soldiers / perfect if perfect > 0.0 else 1.0
		win_stars = 3 if kept >= B.STARS_3 else (2 if kept >= B.STARS_2 else 1)
		win_earned = _earned()
	if stress:
		stress = false
		win_earned = 0
	else:
		coins += _earned()
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
		[0.5, func(): return hud.meta.buttons["upgrades"].get_global_rect().get_center(), "upgrades button opens the panel", func(): return panel_open],
		[1.0, func(): return hud.meta.buttons["card0"].get_global_rect().get_center(), "buying an upgrade takes coins and adds a level", func(): return settings.up_army == 1 and coins == 850 and sim.soldiers == 2],
		[1.5, func(): return hud.meta.buttons["close"].get_global_rect().get_center(), "close closes the panel", func(): return not panel_open and state == State.MENU],
		[2.0, menu_at, "menu button opens menu, game stays in menu state", func(): return paused and state == State.MENU],
		[2.5, func(): return hud.menu_buttons["RESUME"].get_global_rect().get_center(), "resume closes menu", func(): return not paused and state == State.MENU],
		[3.0, func(): return Vector2(size.x * 0.5, size.y * 0.8), "tap on field starts the game", func(): return state == State.PLAY],
		[3.5, menu_at, "menu button pauses play", func(): return paused and state == State.PLAY],
		[4.0, func(): return hud.menu_buttons[""].get_global_rect().get_center(), "vibration toggles off", func(): return settings.vibrate == false],
		[4.5, func(): return hud.menu_buttons["RESTART LEVEL"].get_global_rect().get_center(), "restart closes menu and restarts", func(): return not paused and state == State.PLAY and sim.distance < 5.0],
	]
	if tap_step >= steps.size():
		if shot_clock > 5.2:
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
