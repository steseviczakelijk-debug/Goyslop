extends CanvasLayer
## The 2D interface on top of the game: level banner, progress, coins, the
## start/win/lose overlay and a performance readout for test builds.

signal stress_requested
signal menu_toggled(open: bool)
signal settings_changed(music: float, sfx: float, vibrate: bool)
signal restart_requested
signal coin_landed

const INK := Color(0.05, 0.1, 0.3)
const WinScreen = preload("res://scripts/win_screen.gd")

var level_label: Label
var coin_label: Label
var coin_icon: TextureRect
var coin_layer: Control
var coins_flying := 0
var progress_fill: NinePatchRect
var progress_width := 0.0
var overlay: Control
var msg_label: Label
var title_banner: TextureRect
var result_button: TextureRect
var win_screen: WinScreen
var sub_label: Label
var button_label: Label
var perf_button: Button
var menu: Control
var music_slider: HSlider
var sfx_slider: HSlider
var vibrate_label: Label
var menu_button: TextureButton
var menu_buttons := {}  # caption -> button, for the touch self-check
var vibrate_on := true
var perf_timer := 0.0
var perf_on := false  # the readout stays hidden until its corner is tapped


func _hud_label(parent: Control, size: int, color := Color.WHITE, outline := true) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline:
		l.add_theme_constant_override("outline_size", size / 5)
		l.add_theme_color_override("font_outline_color", INK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## A HUD image centred horizontally, `width` wide, with its top at `top`.
func _hud_image(parent: Control, path: String, width: float, top: float) -> TextureRect:
	var tex: Texture2D = load(path)
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	var h := width * tex.get_height() / tex.get_width()
	t.anchor_left = 0.5
	t.anchor_right = 0.5
	t.offset_left = -width * 0.5
	t.offset_right = width * 0.5
	t.offset_top = top
	t.offset_bottom = top + h
	return t


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var banner := _hud_image(root, "res://assets/ui_level_banner.png", 520, 56)
	level_label = _hud_label(banner, 44, Color(0.36, 0.2, 0.08), false)
	level_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bar := _hud_image(root, "res://assets/ui_progress_bar.png", 400, 176)
	var bar_h := bar.offset_bottom - bar.offset_top
	progress_width = 400 * 0.93
	# The rounded ends stay intact while the middle stretches with progress.
	progress_fill = NinePatchRect.new()
	progress_fill.texture = load("res://assets/ui_progress_fill.png")
	progress_fill.patch_margin_left = 24
	progress_fill.patch_margin_right = 24
	progress_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(progress_fill)
	progress_fill.position = Vector2(400 * 0.035, bar_h * 0.22)
	progress_fill.size = Vector2(0, bar_h * 0.56)
	var icon := _hud_image(bar, "res://assets/ui_castle_icon.png", 62, bar_h * 0.5 - 34)
	icon.offset_left = 200 - 40
	icon.offset_right = 200 + 22

	coin_layer = Control.new()
	coin_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	coin_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(coin_layer)
	var coin := _hud_image(root, "res://assets/coin.png", 46, 250)
	coin_icon = coin
	coin.anchor_left = 0.0
	coin.anchor_right = 0.0
	coin.offset_left = 28
	coin.offset_right = 74
	coin_label = _hud_label(root, 36)
	coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	coin_label.position = Vector2(84, 248)
	coin_label.size = Vector2(300, 50)

	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)
	# The title sits on a ribbon when there is one for it (see show_overlay).
	title_banner = _hud_image(overlay, "res://assets/ui_title_victory.png", 700, 0)
	title_banner.anchor_top = 0.5
	title_banner.anchor_bottom = 0.5
	var ribbon_h := title_banner.offset_bottom
	title_banner.offset_top = -270 - ribbon_h * 0.49
	title_banner.offset_bottom = -270 + ribbon_h * 0.51
	msg_label = _hud_label(overlay, 100)
	msg_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	msg_label.offset_bottom = -520
	win_screen = WinScreen.new()
	overlay.add_child(win_screen)
	win_screen.finished.connect(func(_multiplier): result_button.visible = true)
	var button := _hud_image(overlay, "res://assets/ui_button.png", 400, 0)
	result_button = button
	button.anchor_top = 0.5
	button.anchor_bottom = 0.5
	button.offset_top = -110
	button.offset_bottom = -110 + 400.0 * 196.0 / 768.0
	button_label = _hud_label(button, 46)
	button_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sub_label = _hud_label(overlay, 34)
	sub_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sub_label.offset_top = 110

	menu_button = TextureButton.new()
	menu_button.texture_normal = load("res://assets/ui_badge.png")
	menu_button.ignore_texture_size = true
	menu_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	menu_button.pressed.connect(open_menu)
	root.add_child(menu_button)
	menu_button.anchor_left = 1.0
	menu_button.anchor_right = 1.0
	menu_button.offset_left = -104
	menu_button.offset_right = -20
	menu_button.offset_top = 164
	menu_button.offset_bottom = 248
	var bars := TextureRect.new()
	bars.texture = load("res://assets/ui_pause.png")
	bars.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bars.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_button.add_child(bars)
	bars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 24)
	if OS.is_debug_build():
		perf_button = Button.new()
		perf_button.flat = true
		perf_button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		perf_button.add_theme_font_size_override("font_size", 22)
		perf_button.add_theme_constant_override("outline_size", 6)
		perf_button.add_theme_color_override("font_outline_color", INK)
		perf_button.pressed.connect(func():
			if perf_on:
				stress_requested.emit()
			perf_on = true)
		root.add_child(perf_button)
		perf_button.anchor_left = 1.0
		perf_button.anchor_right = 1.0
		perf_button.offset_left = -260
		perf_button.offset_right = -16
		perf_button.offset_top = 262
		perf_button.offset_bottom = 356
	_build_menu(root)


func show_overlay(title: String, button: String, sub: String) -> void:
	overlay.visible = true
	msg_label.text = title
	var ribbon := "res://assets/ui_title_%s.png" % title.to_lower()
	title_banner.visible = title != "" and ResourceLoader.exists(ribbon)
	if title_banner.visible:
		title_banner.texture = load(ribbon)
	msg_label.add_theme_font_size_override("font_size", 70 if title_banner.visible else 100)
	button_label.text = button
	sub_label.text = sub
	win_screen.stop()
	result_button.visible = true
	_move_result_button(-110)


func _move_result_button(top: float) -> void:
	result_button.offset_top = top
	result_button.offset_bottom = top + 400.0 * 196.0 / 768.0


## The win screen: the title, then stars, coins and the wheel; the button to
## continue only appears once the reward has been handed out.
func show_win(stars: int, earned: int, seed_value: int) -> void:
	show_overlay("VICTORY", "NEXT LEVEL", "")
	result_button.visible = false
	_move_result_button(360)
	win_screen.start(stars, earned, seed_value)


func hide_overlay() -> void:
	overlay.visible = false


func set_level(level: int) -> void:
	level_label.text = "LEVEL %d" % level


func set_progress(fraction: float) -> void:
	progress_fill.size.x = progress_width * fraction
	progress_fill.visible = progress_fill.size.x >= 20.0


func set_coins(coins: int) -> void:
	coin_label.text = str(coins)


## Shows frames per second and unit counts; tapping it starts the stress level.
func update_perf(dt: float, enemies: int, arrows: int) -> void:
	if perf_button == null or not perf_on:
		return
	perf_timer -= dt
	if perf_timer <= 0.0:
		perf_timer = 0.5
		perf_button.text = "%d fps\n%d orcs  %d arrows\ntap: stress test" % [Engine.get_frames_per_second(), enemies, arrows]


func _build_menu(root: Control) -> void:
	menu = ColorRect.new()
	menu.color = Color(0.02, 0.05, 0.15, 0.6)
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.visible = false
	root.add_child(menu)

	var panel := MarginContainer.new()
	menu.add_child(panel)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -310
	panel.offset_right = 310
	panel.offset_top = -450
	panel.offset_bottom = 450
	for side in ["left", "right", "bottom"]:
		panel.add_theme_constant_override("margin_" + side, 62)
	panel.add_theme_constant_override("margin_top", 150)
	var frame := TextureRect.new()
	frame.texture = load("res://assets/ui_menu_panel.png")
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(frame)
	frame.anchor_left = 0.5
	frame.anchor_right = 0.5
	frame.anchor_top = 0.5
	frame.anchor_bottom = 0.5
	frame.offset_left = -310
	frame.offset_right = 310
	frame.offset_top = -450
	frame.offset_bottom = 450
	menu.move_child(frame, 0)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	panel.add_child(rows)
	var title := _hud_label(rows, 56)
	title.text = "MENU"

	music_slider = _menu_slider(rows, "Music")
	sfx_slider = _menu_slider(rows, "Sound")

	vibrate_label = _menu_button(rows, "", func():
		vibrate_on = not vibrate_on
		_show_vibrate()
		_emit_settings())

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(spacer)
	_menu_button(rows, "RESUME", close_menu)
	_menu_button(rows, "RESTART LEVEL", func():
		close_menu()
		restart_requested.emit())


func _menu_slider(rows: Control, text: String) -> HSlider:
	var label := _hud_label(rows, 38)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.text = text
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(0, 64)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.02, 0.05, 0.18)
	track.set_corner_radius_all(9)
	track.content_margin_top = 9
	track.content_margin_bottom = 9
	slider.add_theme_stylebox_override("slider", track)
	var filled := track.duplicate()
	filled.bg_color = Color(0.25, 0.8, 1.0)
	slider.add_theme_stylebox_override("grabber_area", filled)
	slider.add_theme_stylebox_override("grabber_area_highlight", filled)
	var knob_image: Image = load("res://assets/coin.png").get_image()
	knob_image.resize(60, 62, Image.INTERPOLATE_LANCZOS)
	var knob := ImageTexture.create_from_image(knob_image)
	slider.add_theme_icon_override("grabber", knob)
	slider.add_theme_icon_override("grabber_highlight", knob)
	slider.value_changed.connect(func(_v): _emit_settings())
	rows.add_child(slider)
	return slider


func _menu_button(rows: Control, text: String, action: Callable) -> Label:
	var b := TextureButton.new()
	b.texture_normal = load("res://assets/ui_button.png")
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.custom_minimum_size = Vector2(0, 92)
	b.pressed.connect(action)
	rows.add_child(b)
	var l := _hud_label(b, 38)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.text = text
	menu_buttons[text] = b
	return l


func _show_vibrate() -> void:
	vibrate_label.text = "VIBRATION: ON" if vibrate_on else "VIBRATION: OFF"


func _emit_settings() -> void:
	settings_changed.emit(music_slider.value, sfx_slider.value, vibrate_on)


## Fills the menu with the saved settings without triggering a save.
func load_settings(music: float, sfx: float, vibrate: bool) -> void:
	music_slider.set_value_no_signal(music)
	sfx_slider.set_value_no_signal(sfx)
	vibrate_on = vibrate
	_show_vibrate()


func open_menu() -> void:
	if not menu.visible:
		menu.visible = true
		menu_toggled.emit(true)


func close_menu() -> void:
	if menu.visible:
		menu.visible = false
		menu_toggled.emit(false)


## Sends a coin from a point on screen to the coin counter, which bumps when
## it lands. Limited in number so a big fight stays readable.
func fly_coin(from: Vector2) -> void:
	if coins_flying >= 8:
		return
	coins_flying += 1
	var coin := TextureRect.new()
	coin.texture = coin_icon.texture
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin.size = Vector2(32, 34)
	coin.position = from - coin.size * 0.5
	coin_layer.add_child(coin)
	var target := coin_icon.get_global_rect().get_center() - coin.size * 0.5
	var hop := coin.position + Vector2(randf_range(-50, 50), randf_range(-90, -40))
	var tween := create_tween()
	tween.tween_property(coin, "position", hop, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(coin, "position", target, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		coin.queue_free()
		coins_flying -= 1
		coin_landed.emit()
		coin_icon.pivot_offset = coin_icon.size * 0.5
		coin_icon.scale = Vector2(1.35, 1.35)
		create_tween().tween_property(coin_icon, "scale", Vector2.ONE, 0.15))
