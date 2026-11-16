extends Control
## Everything around the levels: the start screen (logo, upgrades button,
## tutorial hand), the upgrades panel and the daily reward. It only shows
## state and reports taps; the game decides what a tap does.

signal blocking_changed(blocked: bool)
signal buy_requested(index: int)
signal claim_requested

const B = preload("res://scripts/balance.gd")
const INK := Color(0.05, 0.1, 0.3)
const GOLD := Color(1.0, 0.82, 0.2)

var start: Control
var dot: TextureRect
var streak_row: Control
var streak_label: Label
var hand: TextureRect
var hand_label: Label
var clock := 0.0

var up_panel: Control
var up_coins: Label
var cards: Array = []       # per upgrade: {button, level, text, price}
var daily_panel: Control
var tiles: Array = []       # per day: {tile, check}
var buttons := {}           # name -> button, for the touch self-check


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_start()
	_build_upgrades()
	_build_daily()


# ---------------------------------------------------------------- helpers

func _pic(path: String, parent: Control) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	return t


func _label(font_size: int, parent: Control, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", maxi(4, font_size / 5))
	l.add_theme_color_override("font_outline_color", INK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _button(path: String, parent: Control, action: Callable) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = load(path)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.pressed.connect(action)
	parent.add_child(b)
	return b


## Puts `node` at `center`, measured from the middle of its parent.
func _center(node: Control, center: Vector2, node_size: Vector2) -> void:
	node.set_anchors_preset(Control.PRESET_CENTER)
	node.offset_left = center.x - node_size.x * 0.5
	node.offset_right = center.x + node_size.x * 0.5
	node.offset_top = center.y - node_size.y * 0.5
	node.offset_bottom = center.y + node_size.y * 0.5
	node.pivot_offset = node_size * 0.5


## Puts `node` inside its parent at a pixel position.
func _box(node: Control, pos: Vector2, node_size: Vector2) -> void:
	node.position = pos
	node.size = node_size


func _dim() -> ColorRect:
	var d := ColorRect.new()
	d.color = Color(0.02, 0.05, 0.15, 0.65)
	d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	d.visible = false
	add_child(d)
	return d


# ---------------------------------------------------------------- start screen

func _build_start() -> void:
	start = Control.new()
	start.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	start.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start.visible = false
	add_child(start)
	_center(_pic("res://assets/ui_logo.png", start), Vector2(0, -275), Vector2(540, 270))
	var up := _button("res://assets/ui_button.png", start, open_upgrades)
	_center(up, Vector2(0, 50), Vector2(300, 77))
	buttons["upgrades"] = up
	var text := _label(34, up)
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text.text = "UPGRADES"
	dot = _pic("res://assets/ui_dot.png", up)
	_box(dot, Vector2(262, -18), Vector2(52, 52))
	streak_row = Control.new()
	streak_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start.add_child(streak_row)
	_box(streak_row, Vector2(22, 306), Vector2(360, 60))
	_box(_pic("res://assets/ui_flame.png", streak_row), Vector2(4, 0), Vector2(48, 58))
	streak_label = _label(30, streak_row, Color(1.0, 0.75, 0.3))
	streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_box(streak_label, Vector2(62, 8), Vector2(300, 44))
	hand_label = _label(34, start)
	_center(hand_label, Vector2(0, 200), Vector2(600, 50))
	hand_label.text = "DRAG TO MOVE"
	hand = _pic("res://assets/ui_hand.png", start)
	_center(hand, Vector2(0, 290), Vector2(110, 110))


func show_start(can_buy: bool, teach: bool, streak := 0) -> void:
	start.visible = true
	streak_row.visible = streak >= 2
	streak_label.text = "%d WINS IN A ROW" % streak
	dot.visible = can_buy
	hand.visible = teach
	hand_label.visible = teach


func hide_start() -> void:
	start.visible = false


func _process(dt: float) -> void:
	clock += dt
	if start.visible:
		if hand.visible:
			var x := sin(clock * 2.4) * 150.0
			hand.offset_left = x - 55.0
			hand.offset_right = x + 55.0
		if dot.visible:
			var s := 1.0 + sin(clock * 6.0) * 0.12
			dot.pivot_offset = dot.size * 0.5
			dot.scale = Vector2(s, s)


# ---------------------------------------------------------------- upgrades

func _build_upgrades() -> void:
	up_panel = _dim()
	_center(_pic("res://assets/ui_menu_panel.png", up_panel), Vector2.ZERO, Vector2(640, 980))
	var title := _label(54, up_panel)
	_center(title, Vector2(0, -322), Vector2(500, 60))
	title.text = "UPGRADES"
	var coin := _pic("res://assets/coin.png", up_panel)
	_center(coin, Vector2(-70, -268), Vector2(44, 44))
	up_coins = _label(38, up_panel, GOLD)
	up_coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_center(up_coins, Vector2(70, -268), Vector2(220, 50))
	for i in B.UPGRADES.size():
		var def: Dictionary = B.UPGRADES[i]
		var card := _button("res://assets/ui_card.png", up_panel, func(): buy_requested.emit(i))
		_center(card, Vector2(0, -160 + i * 148), Vector2(480, 138))
		buttons["card%d" % i] = card
		var icon := _pic(def.icon, card)
		_box(icon, Vector2(38, 30), Vector2(88, 80))
		var name_label := _label(30, card)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_box(name_label, Vector2(148, 16), Vector2(220, 36))
		name_label.text = def.name
		var level := _label(24, card, Color(0.7, 0.85, 1.0))
		level.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_box(level, Vector2(330, 18), Vector2(120, 32))
		var text := _label(22, card)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_box(text, Vector2(148, 52), Vector2(310, 30))
		var price_coin := _pic("res://assets/coin.png", card)
		_box(price_coin, Vector2(148, 88), Vector2(34, 34))
		var price := _label(30, card, GOLD)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_box(price, Vector2(190, 84), Vector2(260, 40))
		cards.append({"button": card, "level": level, "text": text, "price": price, "coin": price_coin})
	var close := _button("res://assets/ui_button.png", up_panel, close_upgrades)
	_center(close, Vector2(0, 408), Vector2(260, 66))
	buttons["close"] = close
	var close_text := _label(32, close)
	close_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	close_text.text = "CLOSE"


## `levels` holds how many levels of each upgrade are owned.
func refresh_upgrades(coins: int, levels: Array) -> void:
	up_coins.text = str(coins)
	for i in cards.size():
		var def: Dictionary = B.UPGRADES[i]
		var owned: int = levels[i]
		var c: Dictionary = cards[i]
		c.level.text = "Lv %d" % owned
		var next := mini(owned + 1, B.UPGRADE_MAX_LEVEL)
		var amount: float = def.step * next
		c.text.text = def.text % (int(1 + amount) if i == 0 else int(round(amount * 100.0)))
		var maxed := owned >= B.UPGRADE_MAX_LEVEL
		var price := B.upgrade_price(i, owned)
		c.price.text = "MAX" if maxed else str(price)
		c.coin.visible = not maxed
		var affordable := not maxed and coins >= price
		c.price.add_theme_color_override("font_color", GOLD if affordable or maxed else Color(1.0, 0.45, 0.4))
		c.button.modulate = Color.WHITE if affordable else Color(0.72, 0.72, 0.78)


## A short bump on the card that was just bought.
func pop_card(index: int) -> void:
	var card: TextureButton = cards[index].button
	card.scale = Vector2(1.08, 1.08)
	create_tween().tween_property(card, "scale", Vector2.ONE, 0.18)


func open_upgrades() -> void:
	up_panel.visible = true
	blocking_changed.emit(true)


func close_upgrades() -> void:
	up_panel.visible = false
	blocking_changed.emit(daily_panel.visible)


# ---------------------------------------------------------------- daily reward

func _build_daily() -> void:
	daily_panel = _dim()
	_center(_pic("res://assets/ui_daily_panel.png", daily_panel), Vector2.ZERO, Vector2(660, 660))
	var title := _label(46, daily_panel)
	_center(title, Vector2(0, -205), Vector2(560, 56))
	title.text = "DAILY REWARD"
	for i in B.DAILY_REWARDS.size():
		var row := 0 if i < 4 else 1
		var x := (i - 1.5) * 132.0 if row == 0 else (i - 5) * 132.0
		var tile := _pic("res://assets/ui_tile.png", daily_panel)
		_center(tile, Vector2(x, -78 + row * 142), Vector2(124, 124))
		var day := _label(20, tile)
		_box(day, Vector2(0, 14), Vector2(124, 26))
		day.text = "DAY %d" % (i + 1)
		var coin := _pic("res://assets/coin.png", tile)
		_box(coin, Vector2(42, 40), Vector2(40, 40))
		var amount := _label(26, tile, GOLD)
		_box(amount, Vector2(0, 80), Vector2(124, 32))
		amount.text = str(B.DAILY_REWARDS[i])
		var check := _pic("res://assets/ui_check.png", tile)
		_box(check, Vector2(22, 22), Vector2(80, 80))
		tiles.append({"tile": tile, "check": check})
	var claim := _button("res://assets/ui_button.png", daily_panel, func(): claim_requested.emit())
	_center(claim, Vector2(0, 222), Vector2(300, 77))
	buttons["claim"] = claim
	var text := _label(36, claim)
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text.text = "CLAIM"


## Shows the calendar with `today` (0-6) as the reward about to be claimed.
func show_daily(today: int) -> void:
	for i in tiles.size():
		tiles[i].check.visible = i < today
		tiles[i].tile.modulate = Color.WHITE if i <= today else Color(0.6, 0.6, 0.68)
		tiles[i].tile.scale = Vector2(1.1, 1.1) if i == today else Vector2.ONE
	daily_panel.visible = true
	blocking_changed.emit(true)


func hide_daily() -> void:
	daily_panel.visible = false
	blocking_changed.emit(up_panel.visible)
