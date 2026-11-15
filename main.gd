extends Node3D
## Medieval lane shooter: drag to move your archers along the castle bridge,
## shooting is automatic. Gates change squad size, orc hordes eat soldiers and
## a troll ends each level.

enum State { MENU, PLAY, WIN, LOSE }

const ROAD_HALF := 4.0
const SCROLL_SPEED := 7.0
const SPAWN_AHEAD := 55.0
const BULLET_SPEED := 45.0
const BULLET_RANGE := 32.0
const FIRE_INTERVAL := 0.16
const MAX_SHOOTERS := 8
const MAX_ENEMIES := 1500
const MAX_BULLETS := 160
const MAX_SHOWN := 60
const ENEMY_R := 0.38
const ENEMY_SPEED := 2.0
const ENEMY_SPACING := 0.72
const GATE_HITS_PER_POINT := 7
const BOSS_R := 1.5
const BUCKETS := 22
const BUCKET_W := 0.5
const SAVE_PATH := "user://save.cfg"

const FLOOR_PERIOD := 2.5
const GRASS_PERIOD := 6.0
const RAIL_LENGTH := 2.5
const RAIL_COUNT := 80
const RAIL_TILT := 0.55
const RIVER_PERIOD := 200.0
const SCENERY_LOOP := 200.0
const GATE_WIDTH := 3.7
const GATE_BASE := 1.0
const INK := Color(0.05, 0.1, 0.3)

var state := State.MENU
var level := 1
var coins := 0
var soldiers := 1
var squad_x := 0.0
var squad_r := 0.3
var distance := 0.0
var level_length := 1.0
var scroll := 0.0
var fire_timer := 0.0
var time := 0.0
var events: Array = []
var next_event := 0

var e_x := PackedFloat32Array()
var e_z := PackedFloat32Array()
var e_hp := PackedFloat32Array()
var e_count := 0
var buckets: Array = []

var b_x := PackedFloat32Array()
var b_z := PackedFloat32Array()
var b_dmg := PackedFloat32Array()
var b_left := PackedFloat32Array()
var b_count := 0

var gates: Array = []
var next_pair := 0
var gate_meshes := {}
var post_mesh: QuadMesh

var boss_active := false
var boss_hp := 0.0
var boss_max := 1.0
var boss_x := 0.0
var boss_z := 0.0
var boss_node: Node3D
var boss_label: Label3D

var enemy_mm: MultiMesh
var bullet_mm: MultiMesh
var soldier_mm: MultiMesh
var shadow_mm: MultiMesh
var enemy_shadow_mm: MultiMesh
var rail_mm: MultiMesh
var blob_mat: StandardMaterial3D
var floor_mat: StandardMaterial3D
var grass_mat: StandardMaterial3D
var water_mat: StandardMaterial3D
var river: MeshInstance3D
var castle: MeshInstance3D
var scenery: Array = []  # [MultiMesh, PackedVector2Array of (x, z0)]
var squad_badge: MeshInstance3D
var squad_label: Label3D
var formation := PackedVector2Array()

var level_label: Label
var coin_label: Label
var progress_fill: Panel
var progress_width := 0.0
var overlay: Control
var msg_label: Label
var sub_label: Label
var button_label: Label

var autoplay := false
var auto_levels := 1
var shot_path := ""
var shot_time := 6.0


class Gate:
	var node: Node3D
	var banner: MeshInstance3D
	var label: Label3D
	var meshes: Dictionary
	var x0: float
	var x1: float
	var z: float
	var op: String
	var value: int
	var hits := 0
	var pair: int

	func apply(n: int) -> int:
		return n * value if op == "mul" else n + value

	func refresh() -> void:
		if op == "mul":
			label.text = "x%d" % value
			banner.mesh = meshes.purple
		else:
			label.text = "%+d" % value
			banner.mesh = meshes.blue if value > 0 else meshes.red


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--autoplay":
			autoplay = true
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
		_load()
	e_x.resize(MAX_ENEMIES)
	e_z.resize(MAX_ENEMIES)
	e_hp.resize(MAX_ENEMIES)
	b_x.resize(MAX_BULLETS)
	b_z.resize(MAX_BULLETS)
	b_dmg.resize(MAX_BULLETS)
	b_left.resize(MAX_BULLETS)
	for i in BUCKETS:
		buckets.append(PackedInt32Array())
	for i in MAX_SHOWN:
		var r := 0.33 * sqrt(float(i))
		var a := i * 2.39996
		formation.append(Vector2(cos(a) * r, sin(a) * r))
	_build_world()
	_build_hud()
	_reset_level()
	if autoplay:
		_start()


# ---------------------------------------------------------------- setup

func _unshaded(tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _cutout(path: String) -> StandardMaterial3D:
	var m := _unshaded(load(path))
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	return m


## A camera-facing sprite quad standing on the ground (or `base` above it).
func _sprite_mesh(path: String, height: float, base := 0.0) -> QuadMesh:
	var m := _cutout(path)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	var tex := m.albedo_texture
	var quad := QuadMesh.new()
	quad.size = Vector2(height * tex.get_width() / tex.get_height(), height)
	quad.center_offset = Vector3(0, base + height * 0.5, 0)
	quad.material = m
	return quad


func _blob_mesh(size: float) -> PlaneMesh:
	if blob_mat == null:
		var grad := Gradient.new()
		grad.set_color(0, Color(0, 0, 0, 0.45))
		grad.set_color(1, Color(0, 0, 0, 0))
		var tex := GradientTexture2D.new()
		tex.gradient = grad
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 64
		tex.height = 64
		blob_mat = _unshaded(tex)
		blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var blob := PlaneMesh.new()
	blob.size = Vector2(size, size)
	blob.material = blob_mat
	return blob


func _instance(mesh: Mesh, pos := Vector3.ZERO, parent: Node = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _multimesh(mesh: Mesh, count: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	mm.visible_instance_count = 0
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.custom_aabb = AABB(Vector3(-60, -5, -220), Vector3(120, 40, 260))
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)
	return mm


func _ground(path: String, size: Vector2, y: float, uv: Vector2) -> MeshInstance3D:
	var mat := _unshaded(load(path))
	mat.uv1_scale = Vector3(uv.x, uv.y, 1)
	var plane := PlaneMesh.new()
	plane.size = size
	plane.material = mat
	return _instance(plane, Vector3(0, y, 0))


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.25, 0.6, 1.0)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var cam := Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = 48.0
	cam.far = 450.0
	add_child(cam)
	cam.position = Vector3(0, 8.6, 8.2)
	cam.rotation_degrees.x = -30.0

	# Sky backdrop rides with the camera; its painted hills sit on the horizon.
	var sky := QuadMesh.new()
	sky.size = Vector2(190, 285)
	sky.material = _unshaded(load("res://assets/sky.png"))
	_instance(sky, Vector3(0, 190.0 * tan(deg_to_rad(30.0)) + 0.37 * 285.0, -190), cam)

	# Ground layers: grass, a river that passes under the bridge, the bridge deck.
	var grass := _ground("res://assets/grass.png", Vector2(600, 600), -0.08, Vector2(100, 100))
	grass.position.z = -200
	grass_mat = grass.mesh.material
	river = _ground("res://assets/water.png", Vector2(600, 14), -0.05, Vector2(42, 1))
	water_mat = river.mesh.material
	var deck := _ground("res://assets/bridge_floor.png", Vector2(ROAD_HALF * 2, 240), 0.0, Vector2(2, 240.0 / FLOOR_PERIOD))
	deck.position.z = -100
	floor_mat = deck.mesh.material

	# Railings: flat sprites along the road, leaning outward so the camera sees them.
	var rail_mat := _cutout("res://assets/railing.png")
	rail_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var rail_tex := rail_mat.albedo_texture
	var rail := QuadMesh.new()
	var rail_h := RAIL_LENGTH * rail_tex.get_height() / rail_tex.get_width()
	rail.size = Vector2(RAIL_LENGTH, rail_h)
	rail.center_offset = Vector3(0, rail_h * 0.5, 0)
	rail.material = rail_mat
	rail_mm = _multimesh(rail, RAIL_COUNT * 2)
	rail_mm.visible_instance_count = RAIL_COUNT * 2

	# Roadside scenery loops forever as the level scrolls.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	_scatter("res://assets/pine.png", 5.5, 26, 7.5, 34.0, rng)
	_scatter("res://assets/bush.png", 1.4, 18, 5.8, 26.0, rng)
	_scatter("res://assets/rock.png", 1.3, 12, 5.8, 22.0, rng)
	var poles := PackedVector2Array()
	for i in int(SCENERY_LOOP / 20.0):
		poles.append(Vector2(-5.4, i * 20.0))
		poles.append(Vector2(5.4, i * 20.0))
	var pole_mm := _multimesh(_sprite_mesh("res://assets/banner_pole.png", 4.2), poles.size())
	pole_mm.visible_instance_count = poles.size()
	scenery.append([pole_mm, poles])

	castle = _instance(_sprite_mesh("res://assets/castle.png", 13.0))

	# Units are camera-facing sprites with a soft blob shadow underneath.
	enemy_shadow_mm = _multimesh(_blob_mesh(0.8), MAX_ENEMIES)
	shadow_mm = _multimesh(_blob_mesh(0.75), MAX_SHOWN)
	enemy_mm = _multimesh(_sprite_mesh("res://assets/orc.png", 1.25), MAX_ENEMIES)
	soldier_mm = _multimesh(_sprite_mesh("res://assets/archer.png", 1.35), MAX_SHOWN)
	bullet_mm = _multimesh(_sprite_mesh("res://assets/arrow.png", 1.7, 0.3), MAX_BULLETS)

	var gate_h := GATE_WIDTH * 295.0 / 512.0
	for c in ["blue", "red", "purple"]:
		gate_meshes[c] = _sprite_mesh("res://assets/gate_%s.png" % c, gate_h, GATE_BASE)
	post_mesh = _sprite_mesh("res://assets/gate_post.png", GATE_BASE + gate_h + 0.25)

	var badge := _sprite_mesh("res://assets/ui_badge.png", 1.15)
	badge.center_offset = Vector3.ZERO
	badge.material.no_depth_test = true
	badge.material.render_priority = 1
	squad_badge = _instance(badge)
	squad_label = _label3d(64)
	squad_label.render_priority = 2
	add_child(squad_label)

	boss_node = Node3D.new()
	_instance(_blob_mesh(5.0), Vector3(0, 0.04, 0), boss_node)
	_instance(_sprite_mesh("res://assets/troll.png", 5.6), Vector3.ZERO, boss_node)
	boss_label = _label3d(110)
	boss_label.position.y = 6.4
	boss_node.add_child(boss_label)
	boss_node.visible = false
	add_child(boss_node)


func _scatter(path: String, height: float, count: int, near: float, far: float, rng: RandomNumberGenerator) -> void:
	var spots := PackedVector2Array()
	for i in count:
		var side := -1.0 if i % 2 == 0 else 1.0
		spots.append(Vector2(side * rng.randf_range(near, far), rng.randf_range(0.0, SCENERY_LOOP)))
	var mm := _multimesh(_sprite_mesh(path, height), count)
	mm.visible_instance_count = count
	scenery.append([mm, spots])


func _label3d(size: int) -> Label3D:
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = size
	l.outline_size = size / 4
	l.outline_modulate = INK
	l.no_depth_test = true
	l.pixel_size = 0.009
	return l


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


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

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


func _show_overlay(title: String, button: String, sub: String) -> void:
	overlay.visible = true
	msg_label.text = title
	button_label.text = button
	sub_label.text = sub


# ---------------------------------------------------------------- level

func _gen_level(lv: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * lv + 13
	events = []
	var est := 1.0
	var s := 32.0
	var segments := mini(5 + lv, 12)
	var growth := 1.0 + lv * 0.05
	for i in segments:
		var best := {}
		if est >= 4.0 and rng.randf() < 0.25:
			best = {"op": "mul", "value": 3 if rng.randf() < 0.15 else 2}
		else:
			best = {"op": "add", "value": int(round(est * rng.randf_range(0.4, 1.0))) + rng.randi_range(1, 3)}
		var other := {}
		if rng.randf() < 0.5:
			other = {"op": "add", "value": -maxi(1, int(round(est * rng.randf_range(0.2, 0.5))))}
		else:
			other = {"op": "add", "value": rng.randi_range(1, 3)}
		var flip := rng.randf() < 0.5
		events.append({"s": s, "type": "gates", "left": other if flip else best, "right": best if flip else other})
		est = (est * best.value if best.op == "mul" else est + best.value) + 1.0
		s += 16.0

		var want := est * rng.randf_range(2.5, 4.0) * growth * (0.5 if i == 0 else 1.0)
		var hp := maxf(1.0, ceilf(want / 350.0))
		var count := clampi(int(want / hp), 3, 350)
		var x0 := -ROAD_HALF + 0.5
		var x1 := ROAD_HALF - 0.5
		if count < 24:
			if rng.randf() < 0.5:
				x1 = -0.3
			else:
				x0 = 0.3
		events.append({"s": s, "type": "wave", "count": count, "hp": hp, "x0": x0, "x1": x1})
		var per_row := int((x1 - x0) / ENEMY_SPACING) + 1
		s += 16.0 + ceilf(float(count) / per_row) * ENEMY_SPACING
		est *= 0.85
	s += 8.0
	events.append({"s": s, "type": "boss", "hp": est * 25.0 * growth})
	level_length = s


func _reset_level() -> void:
	for g in gates:
		g.node.queue_free()
	gates.clear()
	e_count = 0
	b_count = 0
	boss_active = false
	boss_node.visible = false
	soldiers = 1
	squad_x = 0.0
	distance = 0.0
	next_event = 0
	fire_timer = 0.0
	scroll = SCROLL_SPEED
	_gen_level(level)
	state = State.MENU
	level_label.text = "LEVEL %d" % level
	_show_overlay("", "PLAY", "Drag to move your archers")


func _start() -> void:
	state = State.PLAY
	overlay.visible = false


func _spawn(ev: Dictionary) -> void:
	var z: float = -(ev.s - distance)
	match ev.type:
		"gates":
			_spawn_gate(ev.left, -ROAD_HALF, 0.0, z)
			_spawn_gate(ev.right, 0.0, ROAD_HALF, z)
			next_pair += 1
		"wave":
			var per_row := int((ev.x1 - ev.x0) / ENEMY_SPACING) + 1
			for i in ev.count:
				if e_count >= MAX_ENEMIES:
					break
				e_x[e_count] = ev.x0 + (i % per_row) * ENEMY_SPACING
				e_z[e_count] = z - (i / per_row) * ENEMY_SPACING
				e_hp[e_count] = ev.hp
				e_count += 1
		"boss":
			boss_active = true
			# Never let an oversized army delete the boss instantly.
			boss_hp = maxf(ev.hp, soldiers * 30.0)
			boss_max = boss_hp
			boss_x = 0.0
			boss_z = z
			boss_node.visible = true


func _spawn_gate(def: Dictionary, x0: float, x1: float, z: float) -> void:
	var g := Gate.new()
	g.x0 = x0
	g.x1 = x1
	g.z = z
	g.op = def.op
	g.value = def.value
	g.pair = next_pair
	g.meshes = gate_meshes
	g.node = Node3D.new()
	g.node.position = Vector3((x0 + x1) * 0.5, 0, z)
	add_child(g.node)
	g.banner = _instance(gate_meshes.blue, Vector3.ZERO, g.node)
	var half := (x1 - x0) * 0.5
	_instance(post_mesh, Vector3(-half, 0, 0.05), g.node)
	if x1 >= ROAD_HALF:
		_instance(post_mesh, Vector3(half, 0, 0.05), g.node)
	g.label = _label3d(120)
	g.label.position = Vector3(0, GATE_BASE + 1.2, 0.1)
	g.node.add_child(g.label)
	g.refresh()
	gates.append(g)


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if event is InputEventScreenDrag and state == State.PLAY:
		var w := get_viewport().get_visible_rect().size.x
		squad_x += event.relative.x * (ROAD_HALF * 2.0 / w) * 1.5
		_clamp_squad()
	elif event is InputEventScreenTouch and event.pressed:
		match state:
			State.MENU:
				_start()
			State.WIN, State.LOSE:
				_reset_level()
				_start()


func _clamp_squad() -> void:
	squad_x = clampf(squad_x, -ROAD_HALF + 0.4, ROAD_HALF - 0.4)


# ---------------------------------------------------------------- simulation

func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	time += dt
	if state == State.PLAY:
		if autoplay:
			_auto_steer(dt)
		_tick(dt)
	_render()
	if shot_path != "" and time >= shot_time:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot_path)
		get_tree().quit()


func _tick(dt: float) -> void:
	distance += scroll * dt
	while next_event < events.size() and events[next_event].s - distance <= SPAWN_AHEAD:
		_spawn(events[next_event])
		next_event += 1
	squad_r = 0.3 + 0.33 * sqrt(float(mini(soldiers, MAX_SHOWN)))

	fire_timer -= dt
	if fire_timer <= 0.0:
		fire_timer += FIRE_INTERVAL
		_fire()

	_update_bullets(dt)
	_update_enemies(dt)
	_update_gates(dt)
	_update_boss(dt)

	if soldiers <= 0:
		soldiers = 0
		_finish(false)


func _fire() -> void:
	var shown := mini(soldiers, MAX_SHOWN)
	var shooters := mini(soldiers, MAX_SHOOTERS)
	var dmg := float(soldiers) / shooters
	for i in shooters:
		if b_count >= MAX_BULLETS:
			return
		var f := formation[randi() % shown]
		b_x[b_count] = clampf(squad_x + f.x, -ROAD_HALF + 0.1, ROAD_HALF - 0.1)
		b_z[b_count] = f.y - 0.5
		b_dmg[b_count] = dmg
		b_left[b_count] = BULLET_RANGE
		b_count += 1


func _update_bullets(dt: float) -> void:
	for k in BUCKETS:
		buckets[k].clear()
	for i in e_count:
		if e_z[i] > -BULLET_RANGE - 2.0:
			var k := clampi(int((e_x[i] + ROAD_HALF + 1.5) / BUCKET_W), 0, BUCKETS - 1)
			buckets[k].append(i)

	var step := BULLET_SPEED * dt
	var i := 0
	while i < b_count:
		var x := b_x[i]
		var z_old := b_z[i]
		var z_new := z_old - step
		var dmg := b_dmg[i]

		for g in gates:
			if g.op == "add" and g.z <= z_old and g.z >= z_new and x >= g.x0 and x < g.x1:
				g.hits += 1
				if g.hits % GATE_HITS_PER_POINT == 0:
					g.value += 1
					g.refresh()
				dmg = 0.0
				break

		if dmg > 0.0 and boss_active and absf(x - boss_x) < BOSS_R and boss_z <= z_old + 1.0 and boss_z >= z_new - 1.0:
			boss_hp -= dmg
			dmg = 0.0

		if dmg > 0.0:
			var kc := int((x + ROAD_HALF + 1.5) / BUCKET_W)
			for k in range(maxi(kc - 1, 0), mini(kc + 2, BUCKETS)):
				for j in buckets[k]:
					if e_hp[j] > 0.0 and absf(e_x[j] - x) < ENEMY_R and e_z[j] <= z_old + ENEMY_R and e_z[j] >= z_new - ENEMY_R:
						var d := minf(dmg, e_hp[j])
						e_hp[j] -= d
						dmg -= d
						if dmg <= 0.001:
							break
				if dmg <= 0.001:
					break

		b_left[i] -= step
		if dmg <= 0.001 or b_left[i] <= 0.0:
			b_count -= 1
			b_x[i] = b_x[b_count]
			b_z[i] = b_z[b_count]
			b_dmg[i] = b_dmg[b_count]
			b_left[i] = b_left[b_count]
		else:
			b_z[i] = z_new
			b_dmg[i] = dmg
			i += 1


func _update_enemies(dt: float) -> void:
	var dz := (scroll + ENEMY_SPEED) * dt
	var steer := 1.3 * dt
	var i := 0
	while i < e_count:
		var remove := e_hp[i] <= 0.0
		if remove:
			coins += 1
		else:
			var z := e_z[i] + dz
			var x := e_x[i]
			if z > -16.0:
				x = move_toward(x, squad_x, steer)
				e_x[i] = x
			e_z[i] = z
			if z > -squad_r - ENEMY_R and absf(x - squad_x) < squad_r + ENEMY_R:
				soldiers -= int(ceilf(e_hp[i]))
				remove = true
			elif z > 6.0:
				remove = true
		if remove:
			e_count -= 1
			e_x[i] = e_x[e_count]
			e_z[i] = e_z[e_count]
			e_hp[i] = e_hp[e_count]
		else:
			i += 1


func _update_gates(dt: float) -> void:
	var taken := -1
	for g in gates:
		g.z += scroll * dt
		g.node.position.z = g.z
		if g.z >= -0.2 and squad_x >= g.x0 and squad_x < g.x1:
			soldiers = clampi(g.apply(soldiers), 0, 999999)
			taken = g.pair
	if taken >= 0 or (not gates.is_empty() and gates[0].z > 4.0):
		var drop: int = taken if taken >= 0 else gates[0].pair
		for g in gates.filter(func(q): return q.pair == drop):
			g.node.queue_free()
			gates.erase(g)


func _update_boss(dt: float) -> void:
	if not boss_active:
		return
	if boss_z > -22.0:
		scroll = 0.0
	boss_z += (scroll + 1.8) * dt
	boss_x = move_toward(boss_x, squad_x, 1.0 * dt)
	if boss_hp <= 0.0:
		boss_active = false
		boss_node.visible = false
		coins += 50
		_finish(true)
	elif boss_z > -squad_r - BOSS_R:
		soldiers = 0


func _finish(win: bool) -> void:
	state = State.WIN if win else State.LOSE
	b_count = 0
	if win:
		_show_overlay("VICTORY", "NEXT LEVEL", "")
	else:
		_show_overlay("DEFEAT", "RETRY", "")
	if autoplay:
		print("RESULT level=%d win=%s soldiers=%d progress=%.2f" % [level, win, soldiers, distance / level_length])
	if win:
		level += 1
	if not autoplay:
		_save()
	if autoplay and shot_path == "":
		auto_levels -= 1
		if auto_levels <= 0:
			get_tree().quit()
		else:
			_reset_level()
			_start()


# ---------------------------------------------------------------- rendering

func _render() -> void:
	var t := Transform3D.IDENTITY
	enemy_mm.visible_instance_count = e_count
	enemy_shadow_mm.visible_instance_count = e_count
	for i in e_count:
		t.origin = Vector3(e_x[i], absf(sin(time * 9.0 + i)) * 0.12, e_z[i])
		enemy_mm.set_instance_transform(i, t)
		t.origin.y = 0.03
		enemy_shadow_mm.set_instance_transform(i, t)

	bullet_mm.visible_instance_count = b_count
	for i in b_count:
		t.origin = Vector3(b_x[i], 0.0, b_z[i])
		bullet_mm.set_instance_transform(i, t)

	var shown := mini(soldiers, MAX_SHOWN)
	soldier_mm.visible_instance_count = shown
	shadow_mm.visible_instance_count = shown
	for i in shown:
		var f := formation[i]
		t.origin = Vector3(clampf(squad_x + f.x, -ROAD_HALF + 0.3, ROAD_HALF - 0.3), 0.0, f.y)
		soldier_mm.set_instance_transform(i, t)
		t.origin.y = 0.03
		shadow_mm.set_instance_transform(i, t)
	var count_text := str(soldiers)
	squad_label.text = count_text
	squad_label.pixel_size = 0.009 * minf(1.0, 2.6 / count_text.length())
	squad_label.position = Vector3(squad_x, 2.3, -squad_r - 0.3)
	squad_badge.position = squad_label.position

	# Scrolling ground: slide the textures instead of moving geometry.
	floor_mat.uv1_offset.y = -fposmod(distance / FLOOR_PERIOD, 1.0)
	grass_mat.uv1_offset.y = -fposmod(distance / GRASS_PERIOD, 1.0)
	water_mat.uv1_offset.x = fposmod(time * 0.03, 1.0)
	river.position.z = fposmod(distance + 70.0, RIVER_PERIOD) - 170.0

	var off := fmod(distance, RAIL_LENGTH)
	var lean_x := sin(RAIL_TILT)
	var lean_y := cos(RAIL_TILT)
	var left := Basis(Vector3(0, 0, 1), Vector3(-lean_x, lean_y, 0), Vector3(-lean_y, -lean_x, 0))
	var right := Basis(Vector3(0, 0, 1), Vector3(lean_x, lean_y, 0), Vector3(-lean_y, lean_x, 0))
	for i in RAIL_COUNT:
		var z := 14.0 - i * RAIL_LENGTH + off
		rail_mm.set_instance_transform(i * 2, Transform3D(left, Vector3(-ROAD_HALF, 0, z)))
		rail_mm.set_instance_transform(i * 2 + 1, Transform3D(right, Vector3(ROAD_HALF, 0, z)))

	for entry in scenery:
		var mm: MultiMesh = entry[0]
		var spots: PackedVector2Array = entry[1]
		for i in spots.size():
			t.origin = Vector3(spots[i].x, 0, fposmod(spots[i].y + distance, SCENERY_LOOP) - SCENERY_LOOP + 20.0)
			mm.set_instance_transform(i, t)

	castle.position.z = -(level_length + 30.0 - distance)
	castle.visible = castle.position.z > -190.0

	if boss_active:
		boss_node.position = Vector3(boss_x, 0, boss_z)
		boss_label.text = str(int(ceilf(boss_hp)))
	progress_fill.size.x = progress_width * clampf(distance / level_length, 0.0, 1.0)
	coin_label.text = str(coins)


# ---------------------------------------------------------------- persistence

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "level", level)
	cfg.set_value("progress", "coins", coins)
	cfg.save(SAVE_PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		level = maxi(1, int(cfg.get_value("progress", "level", 1)))
		coins = maxi(0, int(cfg.get_value("progress", "coins", 0)))


# ---------------------------------------------------------------- test bot

func _auto_steer(dt: float) -> void:
	var target := squad_x
	var best_gate: Gate = null
	for g in gates:
		if g.z > -14.0 and (best_gate == null or (g.pair == best_gate.pair and g.apply(soldiers) > best_gate.apply(soldiers))):
			if best_gate == null or g.pair == best_gate.pair:
				best_gate = g
	if best_gate != null:
		target = (best_gate.x0 + best_gate.x1) * 0.5
	else:
		var near := -1
		for i in e_count:
			if e_z[i] > -BULLET_RANGE and (near < 0 or e_z[i] > e_z[near]):
				near = i
		if near >= 0:
			target = e_x[near]
		elif boss_active:
			target = boss_x
		elif not gates.is_empty():
			var g: Gate = gates[0]
			for q in gates:
				if q.pair == g.pair and q.apply(soldiers) > g.apply(soldiers):
					g = q
			target = (g.x0 + g.x1) * 0.5
	squad_x = move_toward(squad_x, target, 9.0 * dt)
	_clamp_squad()
