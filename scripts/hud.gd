extends CanvasLayer
## The 2D interface on top of the game: level banner, progress, coins, the
## start/win/lose overlay and a performance readout for test builds.

signal stress_requested

const INK := Color(0.05, 0.1, 0.3)

var level_label: Label
var coin_label: Label
var progress_fill: Panel
var progress_width := 0.0
var overlay: Control
var msg_label: Label
var sub_label: Label
var button_label: Label
var perf_button: Button
var perf_timer := 0.0


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
	progress_fill = Panel.new()
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.25, 0.8, 1.0)
	fill_style.set_corner_radius_all(int(bar_h * 0.3))
	progress_fill.add_theme_stylebox_override("panel", fill_style)
	progress_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(progress_fill)
	progress_fill.position = Vector2(400 * 0.035, bar_h * 0.22)
	progress_fill.size = Vector2(0, bar_h * 0.56)
	var icon := _hud_image(bar, "res://assets/ui_castle_icon.png", 62, bar_h * 0.5 - 34)
	icon.offset_left = 200 - 40
	icon.offset_right = 200 + 22

	var coin := _hud_image(root, "res://assets/coin.png", 46, 250)
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
	msg_label = _hud_label(overlay, 100)
	msg_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	msg_label.offset_bottom = -420
	var button := _hud_image(overlay, "res://assets/ui_button.png", 400, 0)
	button.anchor_top = 0.5
	button.anchor_bottom = 0.5
	button.offset_top = -110
	button.offset_bottom = -110 + 400.0 * 196.0 / 768.0
	button_label = _hud_label(button, 46)
	button_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sub_label = _hud_label(overlay, 34)
	sub_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sub_label.offset_top = 110

	if OS.is_debug_build():
		perf_button = Button.new()
		perf_button.flat = true
		perf_button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		perf_button.add_theme_font_size_override("font_size", 22)
		perf_button.add_theme_constant_override("outline_size", 6)
		perf_button.add_theme_color_override("font_outline_color", INK)
		perf_button.pressed.connect(func(): stress_requested.emit())
		root.add_child(perf_button)
		perf_button.anchor_left = 1.0
		perf_button.anchor_right = 1.0
		perf_button.offset_left = -260
		perf_button.offset_right = -16
		perf_button.offset_top = 236
		perf_button.offset_bottom = 330


func show_overlay(title: String, button: String, sub: String) -> void:
	overlay.visible = true
	msg_label.text = title
	button_label.text = button
	sub_label.text = sub


func hide_overlay() -> void:
	overlay.visible = false


func set_level(level: int) -> void:
	level_label.text = "LEVEL %d" % level


func set_progress(fraction: float) -> void:
	progress_fill.size.x = progress_width * fraction


func set_coins(coins: int) -> void:
	coin_label.text = str(coins)


## Shows frames per second and unit counts; tapping it starts the stress level.
func update_perf(dt: float, enemies: int, arrows: int) -> void:
	if perf_button == null:
		return
	perf_timer -= dt
	if perf_timer <= 0.0:
		perf_timer = 0.5
		perf_button.text = "%d fps\n%d orcs  %d arrows\ntap: stress test" % [Engine.get_frames_per_second(), enemies, arrows]
