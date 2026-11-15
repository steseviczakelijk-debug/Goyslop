extends Node3D
## Everything you see in 3D: the bridge, scenery and one sprite per unit. It only
## reads the simulation; it never changes it.

const B = preload("res://scripts/balance.gd")
const Sim = preload("res://scripts/sim.gd")

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

var gate_meshes := {}
var gate_views := {}  # gate id -> {node, banner, label, value}
var post_mesh: QuadMesh
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


func _ready() -> void:
	_build_world()


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
	var deck := _ground("res://assets/bridge_floor.png", Vector2(B.ROAD_HALF * 2, 240), 0.0, Vector2(2, 240.0 / FLOOR_PERIOD))
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
	enemy_shadow_mm = _multimesh(_blob_mesh(0.8), B.MAX_ENEMIES)
	shadow_mm = _multimesh(_blob_mesh(0.75), B.MAX_SHOWN)
	enemy_mm = _multimesh(_sprite_mesh("res://assets/orc.png", 1.25), B.MAX_ENEMIES)
	soldier_mm = _multimesh(_sprite_mesh("res://assets/archer.png", 1.35), B.MAX_SHOWN)
	bullet_mm = _multimesh(_sprite_mesh("res://assets/arrow.png", 1.7, 0.3), B.MAX_BULLETS)

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


func render(sim: Sim, time: float) -> void:
	var t := Transform3D.IDENTITY
	enemy_mm.visible_instance_count = sim.e_count
	enemy_shadow_mm.visible_instance_count = sim.e_count
	for i in sim.e_count:
		t.origin = Vector3(sim.e_x[i], absf(sin(time * 9.0 + i)) * 0.12, sim.e_z[i])
		enemy_mm.set_instance_transform(i, t)
		t.origin.y = 0.03
		enemy_shadow_mm.set_instance_transform(i, t)

	bullet_mm.visible_instance_count = sim.b_count
	for i in sim.b_count:
		t.origin = Vector3(sim.b_x[i], 0.0, sim.b_z[i])
		bullet_mm.set_instance_transform(i, t)

	var shown := mini(sim.soldiers, B.MAX_SHOWN)
	soldier_mm.visible_instance_count = shown
	shadow_mm.visible_instance_count = shown
	for i in shown:
		var f := sim.formation[i]
		t.origin = Vector3(clampf(sim.squad_x + f.x, -B.ROAD_HALF + 0.3, B.ROAD_HALF - 0.3), 0.0, f.y)
		soldier_mm.set_instance_transform(i, t)
		t.origin.y = 0.03
		shadow_mm.set_instance_transform(i, t)
	var count_text := str(sim.soldiers)
	squad_label.text = count_text
	squad_label.pixel_size = 0.009 * minf(1.0, 2.6 / count_text.length())
	squad_label.position = Vector3(sim.squad_x, 2.3, -sim.squad_r - 0.3)
	squad_badge.position = squad_label.position

	# Scrolling ground: slide the textures instead of moving geometry.
	floor_mat.uv1_offset.y = -fposmod(sim.distance / FLOOR_PERIOD, 1.0)
	grass_mat.uv1_offset.y = -fposmod(sim.distance / GRASS_PERIOD, 1.0)
	water_mat.uv1_offset.x = fposmod(time * 0.03, 1.0)
	river.position.z = fposmod(sim.distance + 70.0, RIVER_PERIOD) - 170.0

	var off := fmod(sim.distance, RAIL_LENGTH)
	var lean_x := sin(RAIL_TILT)
	var lean_y := cos(RAIL_TILT)
	var left := Basis(Vector3(0, 0, 1), Vector3(-lean_x, lean_y, 0), Vector3(-lean_y, -lean_x, 0))
	var right := Basis(Vector3(0, 0, 1), Vector3(lean_x, lean_y, 0), Vector3(-lean_y, lean_x, 0))
	for i in RAIL_COUNT:
		var z := 14.0 - i * RAIL_LENGTH + off
		rail_mm.set_instance_transform(i * 2, Transform3D(left, Vector3(-B.ROAD_HALF, 0, z)))
		rail_mm.set_instance_transform(i * 2 + 1, Transform3D(right, Vector3(B.ROAD_HALF, 0, z)))

	for entry in scenery:
		var mm: MultiMesh = entry[0]
		var spots: PackedVector2Array = entry[1]
		for i in spots.size():
			t.origin = Vector3(spots[i].x, 0, fposmod(spots[i].y + sim.distance, SCENERY_LOOP) - SCENERY_LOOP + 20.0)
			mm.set_instance_transform(i, t)

	castle.position.z = -(sim.level_length + 30.0 - sim.distance)
	castle.visible = castle.position.z > -190.0

	boss_node.visible = sim.boss_active
	if sim.boss_active:
		boss_node.position = Vector3(sim.boss_x, 0, sim.boss_z)
		boss_label.text = str(int(ceilf(sim.boss_hp)))
	_sync_gates(sim)


func _sync_gates(sim: Sim) -> void:
	var alive := {}
	for g in sim.gates:
		alive[g.id] = true
		if not gate_views.has(g.id):
			gate_views[g.id] = _make_gate(g)
		var v: Dictionary = gate_views[g.id]
		v.node.position.z = g.z
		if v.value != g.value:
			v.value = g.value
			if g.op == "mul":
				v.label.text = "x%d" % g.value
				v.banner.mesh = gate_meshes.purple
			else:
				v.label.text = "%+d" % g.value
				v.banner.mesh = gate_meshes.blue if g.value > 0 else gate_meshes.red
	for id in gate_views.keys():
		if not alive.has(id):
			gate_views[id].node.queue_free()
			gate_views.erase(id)


func _make_gate(g: Sim.Gate) -> Dictionary:
	var node := Node3D.new()
	node.position = Vector3((g.x0 + g.x1) * 0.5, 0, g.z)
	add_child(node)
	var banner := _instance(gate_meshes.blue, Vector3.ZERO, node)
	var half: float = (g.x1 - g.x0) * 0.5
	_instance(post_mesh, Vector3(-half, 0, 0.05), node)
	if g.x1 >= B.ROAD_HALF:
		_instance(post_mesh, Vector3(half, 0, 0.05), node)
	var label := _label3d(120)
	label.position = Vector3(0, GATE_BASE + 1.2, 0.1)
	node.add_child(label)
	return {"node": node, "banner": banner, "label": label, "value": null}
