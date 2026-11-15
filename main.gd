extends Node3D
## Medieval lane shooter: drag to move your knights along the castle bridge,
## archery is automatic. Gates change squad size, orc hordes eat soldiers and
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
const SCENERY_ROWS := 44
const BUCKETS := 22
const BUCKET_W := 0.5
const SAVE_PATH := "user://save.cfg"

var state := State.MENU
var level := 1
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
var seam_mm: MultiMesh
var merlon_mm: MultiMesh
var squad_label: Label3D
var formation := PackedVector2Array()

var level_label: Label
var progress: ProgressBar
var msg_label: Label
var sub_label: Label

var autoplay := false
var auto_levels := 1
var shot_path := ""
var shot_time := 6.0


class Gate:
	var node: Node3D
	var label: Label3D
	var mat: StandardMaterial3D
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
		var good := op == "mul" or value > 0
		label.text = ("x%d" % value) if op == "mul" else ("%+d" % value)
		mat.albedo_color = Color(0.15, 0.5, 1.0, 0.6) if good else Color(1.0, 0.2, 0.2, 0.6)


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
		var r := 0.27 * sqrt(float(i))
		var a := i * 2.39996
		formation.append(Vector2(cos(a) * r, sin(a) * r))
	_build_world()
	_build_hud()
	_reset_level()
	if autoplay:
		_start()


# ---------------------------------------------------------------- setup

func _mat(c: Color, emissive := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emissive:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _multimesh(mesh: Mesh, count: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	mm.visible_instance_count = 0
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.custom_aabb = AABB(Vector3(-30, -5, -120), Vector3(60, 30, 160))
	add_child(inst)
	return mm


func _box(size: Vector3, pos: Vector3, c: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _mat(c)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	add_child(mi)
	return mi


func _capsule(radius: float, height: float, c: Color) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 3
	mesh.material = _mat(c)
	return mesh


func _merge(parts: Array) -> ArrayMesh:
	# parts: [PrimitiveMesh, offset, color] -> one mesh with a surface per part
	var am := ArrayMesh.new()
	for p in parts:
		var arrays: Array = p[0].get_mesh_arrays()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in verts.size():
			verts[i] += p[1]
		arrays[Mesh.ARRAY_VERTEX] = verts
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		am.surface_set_material(am.get_surface_count() - 1, _mat(p[2]))
	return am


func _sphere(radius: float, hemisphere := false) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius if hemisphere else radius * 2.0
	m.is_hemisphere = hemisphere
	m.radial_segments = 10
	m.rings = 5
	return m


func _cone(radius: float, height: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 8
	return m


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.36, 0.66, 0.9)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.35
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)

	var cam := Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = 42.0
	cam.far = 200.0
	add_child(cam)
	cam.look_at_from_position(Vector3(0, 15, 9), Vector3(0, 0, -6))

	var stone := Color(0.62, 0.6, 0.55)
	var wall := Color(0.46, 0.45, 0.44)
	_box(Vector3(ROAD_HALF * 2, 1, 220), Vector3(0, -0.5, -80), stone)
	for side in [-1.0, 1.0]:
		_box(Vector3(0.6, 1.0, 220), Vector3(side * (ROAD_HALF + 0.3), 0.1, -80), wall)
	_box(Vector3(400, 1, 400), Vector3(0, -4, -100), Color(0.12, 0.36, 0.62))

	var seam := BoxMesh.new()
	seam.size = Vector3(ROAD_HALF * 2, 0.02, 0.07)
	seam.material = _mat(Color(0.45, 0.43, 0.4))
	seam_mm = _multimesh(seam, SCENERY_ROWS)
	seam_mm.visible_instance_count = SCENERY_ROWS
	var merlon := BoxMesh.new()
	merlon.size = Vector3(0.6, 0.5, 1.0)
	merlon.material = _mat(wall)
	merlon_mm = _multimesh(merlon, SCENERY_ROWS * 2)
	merlon_mm.visible_instance_count = SCENERY_ROWS * 2

	var skin := Color(0.95, 0.76, 0.6)
	var orc := Color(0.35, 0.6, 0.2)
	enemy_mm = _multimesh(_merge([
		[_capsule(0.27, 0.75, Color.WHITE), Vector3(0, 0.38, 0), Color(0.4, 0.25, 0.15)],
		[_sphere(0.23), Vector3(0, 0.9, 0), orc],
	]), MAX_ENEMIES)
	soldier_mm = _multimesh(_merge([
		[_capsule(0.21, 0.7, Color.WHITE), Vector3(0, 0.35, 0), Color(0.15, 0.4, 0.95)],
		[_sphere(0.16), Vector3(0, 0.8, 0), skin],
		[_sphere(0.2, true), Vector3(0, 0.82, 0), Color(0.75, 0.77, 0.8)],
	]), MAX_SHOWN)
	var bullet := BoxMesh.new()
	bullet.size = Vector3(0.07, 0.07, 1.0)
	bullet.material = _mat(Color(1.0, 0.9, 0.55), true)
	bullet_mm = _multimesh(bullet, MAX_BULLETS)

	squad_label = _label3d(72)
	add_child(squad_label)

	boss_node = Node3D.new()
	var body := MeshInstance3D.new()
	body.mesh = _merge([
		[_capsule(1.3, 3.6, Color.WHITE), Vector3(0, 1.8, 0), Color(0.3, 0.22, 0.16)],
		[_sphere(0.95), Vector3(0, 4.0, 0), Color(0.3, 0.5, 0.18)],
		[_cone(0.25, 0.9), Vector3(-0.6, 5.0, 0), Color(0.9, 0.88, 0.8)],
		[_cone(0.25, 0.9), Vector3(0.6, 5.0, 0), Color(0.9, 0.88, 0.8)],
	])
	boss_node.add_child(body)
	boss_label = _label3d(110)
	boss_label.position.y = 6.2
	boss_node.add_child(boss_label)
	boss_node.visible = false
	add_child(boss_node)


func _label3d(size: int) -> Label3D:
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = size
	l.outline_size = size / 4
	l.no_depth_test = true
	l.pixel_size = 0.009
	return l


func _hud_label(parent: Control, size: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", size / 5)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.1, 0.3))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	level_label = _hud_label(root, 44)
	level_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	level_label.offset_top = 70

	progress = ProgressBar.new()
	progress.show_percentage = false
	progress.max_value = 1.0
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(progress)
	progress.set_anchors_preset(Control.PRESET_TOP_WIDE)
	progress.offset_left = 140
	progress.offset_right = -140
	progress.offset_top = 140
	progress.offset_bottom = 164

	msg_label = _hud_label(root, 96)
	msg_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	msg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	msg_label.offset_bottom = -360
	sub_label = _hud_label(root, 40)
	sub_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sub_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub_label.offset_bottom = -140


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
	msg_label.text = "TAP TO START"
	sub_label.text = "Drag to move your knights"


func _start() -> void:
	state = State.PLAY
	msg_label.text = ""
	sub_label.text = ""


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
			boss_hp = ev.hp
			boss_max = ev.hp
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
	g.node = Node3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(x1 - x0 - 0.2, 2.6, 0.15)
	g.mat = _mat(Color(0, 0, 1, 0.6))
	mesh.material = g.mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position.y = 1.3
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.node.add_child(mi)
	g.label = _label3d(150)
	g.label.position = Vector3(0, 1.5, 0.2)
	g.node.add_child(g.label)
	g.node.position = Vector3((x0 + x1) * 0.5, 0, z)
	add_child(g.node)
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
	squad_r = 0.3 + 0.27 * sqrt(float(mini(soldiers, MAX_SHOWN)))

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
		if not remove:
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
		_finish(true)
	elif boss_z > -squad_r - BOSS_R:
		soldiers = 0


func _finish(win: bool) -> void:
	state = State.WIN if win else State.LOSE
	b_count = 0
	msg_label.text = "VICTORY" if win else "DEFEAT"
	sub_label.text = "Tap for next level" if win else "Tap to retry"
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
	for i in e_count:
		t.origin = Vector3(e_x[i], absf(sin(time * 9.0 + i)) * 0.12, e_z[i])
		enemy_mm.set_instance_transform(i, t)

	bullet_mm.visible_instance_count = b_count
	for i in b_count:
		t.origin = Vector3(b_x[i], 0.7, b_z[i])
		bullet_mm.set_instance_transform(i, t)

	var shown := mini(soldiers, MAX_SHOWN)
	soldier_mm.visible_instance_count = shown
	for i in shown:
		var f := formation[i]
		t.origin = Vector3(clampf(squad_x + f.x, -ROAD_HALF + 0.25, ROAD_HALF - 0.25), 0.0, f.y)
		soldier_mm.set_instance_transform(i, t)
	squad_label.text = str(soldiers)
	squad_label.position = Vector3(squad_x, 2.2, -squad_r * 0.5)

	var off := fmod(distance, 2.5)
	for i in SCENERY_ROWS:
		var z := 12.0 - i * 2.5 + off
		t.origin = Vector3(0, 0.01, z)
		seam_mm.set_instance_transform(i, t)
		t.origin = Vector3(-ROAD_HALF - 0.3, 0.85, z)
		merlon_mm.set_instance_transform(i * 2, t)
		t.origin.x = ROAD_HALF + 0.3
		merlon_mm.set_instance_transform(i * 2 + 1, t)

	if boss_active:
		boss_node.position = Vector3(boss_x, 0, boss_z)
		boss_label.text = str(int(ceilf(boss_hp)))
	progress.value = clampf(distance / level_length, 0.0, 1.0)


# ---------------------------------------------------------------- persistence

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "level", level)
	cfg.save(SAVE_PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		level = maxi(1, int(cfg.get_value("progress", "level", 1)))


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
