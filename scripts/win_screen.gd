extends Control
## The reward sequence after a win: stars for how much of the perfect army
## survived, coins counting up, then a wheel that multiplies them. The wheel is
## honest: every segment is equally likely, so what you see is what you get.
##
## Stars, wheel and pointer are drawn in code for now; replace with art later.

signal sfx(sound: String, pitch: float)
signal finished(multiplier: int)

enum Phase { IDLE, INTRO, WAIT_SPIN, SPINNING, BONUS, DONE }

const SEGMENTS := [1, 2, 1, 3, 2, 1, 4, 5]
const COLORS := {1: Color(0.16, 0.36, 0.86), 2: Color(0.2, 0.62, 0.3), 3: Color(0.93, 0.6, 0.1), 4: Color(0.84, 0.22, 0.2), 5: Color(0.6, 0.25, 0.8)}
const GOLD := Color(1.0, 0.8, 0.15)
const INK := Color(0.05, 0.1, 0.3)

var phase := Phase.IDLE
var earned := 0
var shown := -1
var stars: Array[StarIcon] = []
var coin_row: Control
var count_label: Label
var wheel: Wheel
var pointer: Pointer
var prompt: Label
var mult_label: Label
var sequence: Tween
var last_segment := 0
var rng := RandomNumberGenerator.new()


class StarIcon extends Control:
	var filled := false

	func _draw() -> void:
		var points := PackedVector2Array()
		var c := size * 0.5
		for i in 10:
			var r := size.x * (0.5 if i % 2 == 0 else 0.22)
			var a := -PI * 0.5 + i * PI / 5.0
			points.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(points, Color(1.0, 0.8, 0.15) if filled else Color(0.08, 0.14, 0.35, 0.85))
		points.append(points[0])
		draw_polyline(points, Color(0.5, 0.3, 0.0) if filled else Color(1.0, 0.8, 0.15), 4.0, true)


class Wheel extends Control:
	var segments: Array = []
	var colors := {}

	func _draw() -> void:
		var c := size * 0.5
		var r := size.x * 0.5
		var step := TAU / segments.size()
		var font := get_theme_default_font()
		for i in segments.size():
			var a0 := -PI * 0.5 + i * step
			var points := PackedVector2Array([c])
			for k in 13:
				var a := a0 + step * k / 12.0
				points.append(c + Vector2(cos(a), sin(a)) * (r - 8.0))
			draw_colored_polygon(points, colors[segments[i]])
			var mid := a0 + step * 0.5
			draw_set_transform(c + Vector2(cos(mid), sin(mid)) * r * 0.64, mid + PI * 0.5)
			var text := "x%d" % segments[i]
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
			draw_string_outline(font, Vector2(-w * 0.5, 14), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, 8, Color(0.05, 0.1, 0.3))
			draw_string(font, Vector2(-w * 0.5, 14), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color.WHITE)
			draw_set_transform(Vector2.ZERO, 0.0)
		draw_arc(c, r - 5.0, 0.0, TAU, 64, Color(1.0, 0.8, 0.15), 10.0, true)
		draw_circle(c, 18.0, Color(1.0, 0.8, 0.15))
		draw_circle(c, 9.0, Color(0.5, 0.3, 0.0))


class Pointer extends Control:
	func _draw() -> void:
		var w := size.x
		var points := PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w * 0.5, size.y)])
		draw_colored_polygon(points, Color(0.95, 0.2, 0.15))
		points.append(points[0])
		draw_polyline(points, Color(0.05, 0.1, 0.3), 4.0, true)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	for i in 3:
		var star := StarIcon.new()
		_place(star, Vector2((i - 1) * 104.0, -62.0 - (16.0 if i == 1 else 0.0)), Vector2(92, 92))
		stars.append(star)

	coin_row = Control.new()
	_place(coin_row, Vector2(0, 34), Vector2(360, 60))
	var coin := TextureRect.new()
	coin.texture = load("res://assets/coin.png")
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.position = Vector2(70, 2)
	coin.size = Vector2(56, 56)
	coin_row.add_child(coin)
	count_label = _label(54, coin_row)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	count_label.position = Vector2(138, -4)
	count_label.size = Vector2(240, 64)

	wheel = Wheel.new()
	wheel.segments = SEGMENTS
	wheel.colors = COLORS
	_place(wheel, Vector2(0, 222), Vector2(290, 290))
	pointer = Pointer.new()
	_place(pointer, Vector2(0, 72), Vector2(40, 44))

	prompt = _label(40, self)
	_place(prompt, Vector2(0, 408), Vector2(600, 56))
	prompt.text = "TAP TO SPIN"
	mult_label = _label(150, self)
	_place(mult_label, Vector2(0, 222), Vector2(400, 180))
	mult_label.add_theme_color_override("font_color", GOLD)


## Puts `node` at `center`, measured from the middle of the screen.
func _place(node: Control, center: Vector2, node_size: Vector2) -> void:
	if node.get_parent() == null:
		add_child(node)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.set_anchors_preset(Control.PRESET_CENTER)
	node.offset_left = center.x - node_size.x * 0.5
	node.offset_right = center.x + node_size.x * 0.5
	node.offset_top = center.y - node_size.y * 0.5
	node.offset_bottom = center.y + node_size.y * 0.5
	node.pivot_offset = node_size * 0.5


func _label(font_size: int, parent: Control) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_constant_override("outline_size", font_size / 5)
	l.add_theme_color_override("font_outline_color", INK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func busy() -> bool:
	return phase != Phase.IDLE and phase != Phase.DONE


func stop() -> void:
	if sequence != null:
		sequence.kill()
	phase = Phase.IDLE
	visible = false


func start(star_count: int, coins: int, seed_value: int) -> void:
	stop()
	rng.seed = seed_value
	visible = true
	phase = Phase.INTRO
	earned = coins
	shown = -1
	_set_count(0)
	wheel.rotation = 0.0
	last_segment = 0
	for node in [wheel, pointer, prompt, mult_label]:
		node.scale = Vector2.ZERO
	for i in 3:
		stars[i].filled = i < star_count
		stars[i].scale = Vector2.ZERO
		stars[i].queue_redraw()
	coin_row.scale = Vector2.ZERO

	sequence = create_tween()
	for i in 3:
		sequence.tween_callback(_star_sound.bind(i, star_count))
		sequence.tween_property(stars[i], "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	sequence.tween_property(coin_row, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	sequence.tween_method(_set_count, 0, earned, 1.1)
	sequence.tween_property(wheel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	sequence.parallel().tween_property(pointer, "scale", Vector2.ONE, 0.3)
	sequence.tween_callback(func(): phase = Phase.WAIT_SPIN)
	sequence.tween_property(prompt, "scale", Vector2.ONE, 0.2)


func _star_sound(i: int, star_count: int) -> void:
	if i < star_count:
		sfx.emit("gate_good", 0.9 + i * 0.2)


func _set_count(value: int) -> void:
	if value == shown:
		return
	# The tone climbs as the number does.
	if shown >= 0 and value > shown:
		sfx.emit("coin", 0.8 + 1.0 * value / maxf(earned * 5.0, 1.0) + 0.6 * value / maxf(earned, 1.0) * 0.5)
	shown = value
	count_label.text = "+%d" % value


## A tap during the sequence: spins the wheel once it is waiting.
func tap() -> void:
	if phase != Phase.WAIT_SPIN:
		return
	phase = Phase.SPINNING
	var landed := rng.randi() % SEGMENTS.size()
	var step := TAU / SEGMENTS.size()
	var target := -(landed + rng.randf_range(0.2, 0.8)) * step - TAU * 5.0
	sequence = create_tween()
	sequence.tween_property(prompt, "scale", Vector2.ZERO, 0.15)
	sequence.parallel().tween_property(wheel, "rotation", target, 3.4).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	sequence.tween_callback(_landed.bind(SEGMENTS[landed]))


func _landed(multiplier: int) -> void:
	phase = Phase.BONUS
	mult_label.text = "x%d" % multiplier
	sfx.emit("gate_good", 0.8 + multiplier * 0.15)
	sequence = create_tween()
	sequence.tween_property(mult_label, "scale", Vector2(1.25, 1.25), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	sequence.tween_property(mult_label, "scale", Vector2.ONE, 0.12)
	if multiplier > 1:
		sequence.tween_method(_set_count, earned, earned * multiplier, 0.9)
	sequence.tween_interval(0.35)
	sequence.tween_callback(func():
		phase = Phase.DONE
		finished.emit(multiplier))


func _process(_dt: float) -> void:
	if phase == Phase.SPINNING:
		var segment := int(floor(-wheel.rotation / (TAU / SEGMENTS.size())))
		if segment != last_segment:
			last_segment = segment
			sfx.emit("click", 1.0)
			pointer.rotation = -0.25
		pointer.rotation = lerpf(pointer.rotation, 0.0, 0.25)
