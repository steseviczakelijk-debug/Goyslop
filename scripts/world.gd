extends Node3D
## Everything you see in 3D: the bridge, scenery and one sprite per unit. It only
## reads the simulation; it never changes it.

const B = preload("res://scripts/balance.gd")
const Sim = preload("res://scripts/sim.gd")

const FLOOR_PERIOD := 2.5
const GRASS_PERIOD := 6.0
const WALL_LENGTH := 240.0
const WALL_WIDTH := 0.55
const WALL_HEIGHT := 0.7
const WALL_TOP_PERIOD := WALL_WIDTH * 3.0    # the capstone picture is 1:3
const WALL_SIDE_PERIOD := WALL_HEIGHT * 4.0  # the stone strip is 4:1
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
var armored_mm: MultiMesh
var bullet_mm: MultiMesh
var trail_mm: MultiMesh
var soldier_mm: MultiMesh
var shadow_mm: MultiMesh
var enemy_shadow_mm: MultiMesh
var wall_mats: Array = []  # [material, texture shift per metre, along u]
var blob_mat: StandardMaterial3D
var floor_mat: StandardMaterial3D
var grass_mat: StandardMaterial3D
var water_mat: StandardMaterial3D
var river: MeshInstance3D
var castle: MeshInstance3D
var scenery: Array = []  # [MultiMesh, PackedVector2Array of (x, z0)]
var squad_badge: MeshInstance3D
var squad_label: Label3D

# Effects
var cam: Camera3D
var cam_home := Vector3.ZERO
var shake := 0.0
var cheering := false
var puffs: Particles
var fallen: Particles   # orcs knocked off their feet
var fallen_archers: Particles
var fallen_armored: Particles
var sparks: Particles
var confetti: Particles
var coins_fx: Particles
var floaters: Array = []      # pooled Label3D for "+12" / "-3"
var slot_recoil := PackedFloat32Array()
var slot_pop := PackedFloat32Array()
var slot_x := PackedFloat32Array()   # each archer trails the squad a little
var count_before := 0
var count_pulse := 0.0
var shown_before := 0
var lost_pending := 0
var lost_timer := 0.0
var boss_mat: ShaderMaterial
var boss_meshes: Array[QuadMesh] = []   # walking, mace raised, mace down
var boss_pose_shown := 0
var boss_quarter := 4
var boss_hurt := 0.0
var boss_warning: MeshInstance3D          # red patch where the mace will land
var boss_sprite: MeshInstance3D
var boss_bar: MeshInstance3D
var boss_step := 0.0
var gate_pulse := {}          # gate id -> remaining pulse time
var last_time := 0.0
## Screen positions where a coin should start flying to the counter; main
## hands these to the interface and clears the list.
var coin_flights: Array[Vector2] = []
## True for one frame when the boss lands a step; main reads it for sound.
var stomped := false


## A pool of camera-facing particles drawn with one MultiMesh. Each particle
## can spin and show one picture out of the texture's grid.
class Particles:
	var mm: MultiMesh
	var pos := PackedVector3Array()
	var vel := PackedVector3Array()
	var life := PackedFloat32Array()
	var span := PackedFloat32Array()
	var size := PackedFloat32Array()
	var col := PackedColorArray()
	var cell := PackedFloat32Array()
	var angle := PackedFloat32Array()
	var spin := PackedFloat32Array()
	var gravity := 0.0
	var bounces := false   # land on the ground instead of falling through
	var shrinks := false   # fade out by getting smaller as well
	var count := 0
	var cap := 0

	func _init(multimesh: MultiMesh, capacity: int) -> void:
		mm = multimesh
		cap = capacity
		for a in [pos, vel, life, span, size, col, cell, angle, spin]:
			a.resize(cap)

	func emit(p: Vector3, v: Vector3, seconds: float, s: float, c := Color.WHITE, picture := 0.0, turn := 0.0) -> void:
		if count >= cap:
			return
		pos[count] = p
		vel[count] = v
		life[count] = seconds
		span[count] = seconds
		size[count] = s
		col[count] = c
		cell[count] = picture
		angle[count] = randf_range(-PI, PI) if turn != 0.0 else 0.0
		spin[count] = turn
		count += 1

	func update(dt: float) -> void:
		var i := 0
		while i < count:
			life[i] -= dt
			if life[i] <= 0.0:
				count -= 1
				pos[i] = pos[count]
				vel[i] = vel[count]
				life[i] = life[count]
				span[i] = span[count]
				size[i] = size[count]
				col[i] = col[count]
				cell[i] = cell[count]
				angle[i] = angle[count]
				spin[i] = spin[count]
				continue
			var v := vel[i]
			v.y -= gravity * dt
			vel[i] = v
			var p := pos[i] + v * dt
			if bounces and p.y < 0.05:
				p.y = 0.05
				vel[i] = Vector3(v.x * 0.5, -v.y * 0.4, v.z * 0.5)
			pos[i] = p
			angle[i] += spin[i] * dt
			var k := life[i] / span[i]
			var s := size[i] * (0.5 + 0.5 * k) if shrinks else size[i]
			mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(s, s, s)), p))
			var c := col[i]
			c.a *= minf(1.0, k * 2.5)
			mm.set_instance_color(i, c)
			mm.set_instance_custom_data(i, Color(cell[i], angle[i], 0, 0))
			i += 1
		mm.visible_instance_count = count


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


## Like _sprite_mesh, but with the unit shader so it can flash, lean and switch
## pose. `poses` is how many pictures sit side by side in the texture.
func _unit_mesh(path: String, height: float, poses := 1) -> QuadMesh:
	var tex: Texture2D = load(path)
	var m := ShaderMaterial.new()
	m.shader = preload("res://scripts/unit.gdshader")
	m.set_shader_parameter("tex", tex)
	m.set_shader_parameter("poses", float(poses))
	var quad := QuadMesh.new()
	quad.size = Vector2(height * tex.get_width() / poses / tex.get_height(), height)
	quad.center_offset = Vector3(0, height * 0.5, 0)
	quad.material = m
	return quad


func _particles(path: String, capacity: int, grid := Vector2.ONE) -> Particles:
	var m := ShaderMaterial.new()
	m.shader = preload("res://scripts/particle.gdshader")
	m.set_shader_parameter("tex", load(path))
	m.set_shader_parameter("grid", grid)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = m
	return Particles.new(_multimesh(quad, capacity, true, true), capacity)


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


func _multimesh(mesh: Mesh, count: int, custom := false, colors := false) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = custom
	mm.use_colors = colors
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

	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = 48.0
	cam.far = 450.0
	add_child(cam)
	cam.position = Vector3(0, 8.6, 8.2)
	cam.rotation_degrees.x = -30.0
	cam_home = cam.position

	# Sky backdrop rides with the camera; its painted hills sit on the horizon.
	var sky := QuadMesh.new()
	sky.size = Vector2(190, 285)
	sky.material = _unshaded(load("res://assets/sky.png"))
	_instance(sky, Vector3(0, 190.0 * tan(deg_to_rad(30.0)) + 0.37 * 285.0, -190), cam)

	# Ground layers: grass, a river that passes under the bridge, the bridge deck.
	var grass := _ground("res://assets/grass.png", Vector2(600, 600), -0.08, Vector2(100, 100))
	grass.position.z = -200
	grass_mat = grass.mesh.material
	grass_mat.albedo_color = Color(0.88, 0.93, 0.88)  # a touch calmer, so units stand out
	river = _ground("res://assets/water.png", Vector2(600, 14), -0.05, Vector2(42, 1))
	water_mat = river.mesh.material
	var deck := _ground("res://assets/bridge_floor.png", Vector2(B.ROAD_HALF * 2, 240), 0.0, Vector2(2, 240.0 / FLOOR_PERIOD))
	deck.position.z = -100
	floor_mat = deck.mesh.material

	# A low stone wall along both edges, built from real faces so it recedes
	# correctly: capstones on top, stone blocks on the side facing the road.
	var top_mat := _unshaded(load("res://assets/wall_top.png"))
	top_mat.uv1_scale = Vector3(1, WALL_LENGTH / WALL_TOP_PERIOD, 1)
	wall_mats.append([top_mat, -1.0 / WALL_TOP_PERIOD, false])
	for side in [-1.0, 1.0]:
		var top := PlaneMesh.new()
		top.size = Vector2(WALL_WIDTH, WALL_LENGTH)
		top.material = top_mat
		_instance(top, Vector3(side * (B.ROAD_HALF + WALL_WIDTH * 0.5), WALL_HEIGHT, -100))
		var face_mat := _unshaded(load("res://assets/wall_side.png"))
		face_mat.albedo_color = Color(0.82, 0.8, 0.8)
		face_mat.uv1_scale = Vector3(WALL_LENGTH / WALL_SIDE_PERIOD, 1, 1)
		# The face is turned to look at the road, so its texture runs the other
		# way along the bridge on the left than on the right.
		wall_mats.append([face_mat, side / WALL_SIDE_PERIOD, true])
		var face := QuadMesh.new()
		face.size = Vector2(WALL_LENGTH, WALL_HEIGHT)
		face.material = face_mat
		var inst := _instance(face, Vector3(side * B.ROAD_HALF, WALL_HEIGHT * 0.5, -100))
		inst.rotation.y = -side * PI * 0.5

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
	enemy_mm = _multimesh(_unit_mesh("res://assets/orc.png", 1.25, 2), B.MAX_ENEMIES, true)
	armored_mm = _multimesh(_unit_mesh("res://assets/armored_orc.png", 1.65, 4), B.MAX_ENEMIES, true)
	soldier_mm = _multimesh(_unit_mesh("res://assets/archer.png", 1.45, 4), B.MAX_SHOWN, true)
	slot_recoil.resize(B.MAX_SHOWN)
	slot_pop.resize(B.MAX_SHOWN)
	slot_x.resize(B.MAX_SHOWN)
	# A faint streak behind each arrow makes its flight readable.
	var streak := Gradient.new()
	streak.set_color(0, Color(1, 1, 1, 0.55))
	streak.set_color(1, Color(1, 1, 1, 0))
	var streak_tex := GradientTexture2D.new()
	streak_tex.gradient = streak
	streak_tex.fill_from = Vector2(0.5, 0.0)
	streak_tex.fill_to = Vector2(0.5, 1.0)
	streak_tex.width = 8
	streak_tex.height = 64
	var trail_mat := _unshaded(streak_tex)
	trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	trail_mat.billboard_keep_scale = true
	trail_mat.no_depth_test = true
	var trail := QuadMesh.new()
	trail.size = Vector2(0.1, 1.6)
	trail.center_offset = Vector3(0, -0.4, 0)
	trail.material = trail_mat
	trail_mm = _multimesh(trail, B.MAX_BULLETS)
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
	# The three troll pictures are drawn at different zoom levels; these heights
	# keep his body the same size in all of them.
	var troll := _unit_mesh("res://assets/troll.png", 5.6, 3)
	var smash := _unit_mesh("res://assets/troll_smash.png", 5.35)
	boss_meshes = [troll, _unit_mesh("res://assets/troll_windup.png", 6.5), smash]
	boss_mat = troll.material
	boss_sprite = _instance(troll, Vector3.ZERO, boss_node)

	var glow_mat := _unshaded(load("res://assets/warning_ring.png"))
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var patch := PlaneMesh.new()
	patch.size = Vector2(B.BOSS_SMASH_HALF * 3.0, B.BOSS_SMASH_HALF * 3.0)
	patch.material = glow_mat
	boss_warning = _instance(patch, Vector3(0, 0.06, B.BOSS_REACH), boss_node)
	boss_warning.visible = false
	var bar_back := _bar_mesh(Color(0.08, 0.1, 0.2), 3.3, 0.42)
	_instance(bar_back, Vector3(0, 5.2, 0), boss_node)
	boss_bar = _instance(_bar_mesh(Color(0.95, 0.2, 0.15), 3.1, 0.26), Vector3(0, 5.2, 0.02), boss_node)
	boss_label = _label3d(54)
	boss_label.position = Vector3(0, 5.2, 0.04)
	boss_node.add_child(boss_label)
	boss_node.visible = false
	add_child(boss_node)

	# Effects: smoke puffs, impact sparks, confetti, coins and floating numbers.
	fallen = _particles("res://assets/orc_fall.png", 120)
	fallen.gravity = 16.0
	fallen.shrinks = true
	fallen_armored = _particles("res://assets/armored_orc_fall.png", 40)
	fallen_armored.gravity = 16.0
	fallen_armored.shrinks = true
	fallen_archers = _particles("res://assets/archer_fall.png", 40)
	fallen_archers.gravity = 16.0
	fallen_archers.shrinks = true
	puffs = _particles("res://assets/puff.png", 300)
	puffs.shrinks = true
	sparks = _particles("res://assets/spark.png", 80)
	sparks.shrinks = true
	confetti = _particles("res://assets/confetti.png", 160, Vector2(3, 2))
	confetti.gravity = 3.0
	coins_fx = _particles("res://assets/coin.png", 80)
	coins_fx.gravity = 22.0
	coins_fx.bounces = true
	for i in 6:
		var l := _label3d(96)
		l.visible = false
		l.render_priority = 3
		add_child(l)
		floaters.append({"label": l, "life": 0.0})


func _bar_mesh(color: Color, width: float, height: float) -> QuadMesh:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.no_depth_test = true
	var quad := QuadMesh.new()
	quad.size = Vector2(width, height)
	quad.material = m
	return quad


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
	l.font = preload("res://assets/fonts/LilitaOne-Regular.ttf")
	return l


func render(sim: Sim, time: float) -> void:
	var dt := clampf(time - last_time, 0.0, 0.05)
	last_time = time
	var t := Transform3D.IDENTITY
	enemy_shadow_mm.visible_instance_count = sim.e_count
	var plain := 0
	var armored := 0
	for i in sim.e_count:
		var seed := sim.e_seed[i]
		var phase := time * (9.0 + seed * 3.0) + seed * 40.0
		var squash := 1.0 + sin(phase * 2.0) * 0.05
		if sim.e_armored[i] == 1:
			# Poses: 0 and 1 run, 2 axe raised, 3 axe coming down.
			var pose := 1.0 if sin(phase) > 0.0 else 0.0
			var hop := absf(sin(phase)) * 0.12
			var lean := sin(phase) * 0.05
			if sim.e_attack[i] > 0.0:
				pose = 3.0 if sim.e_attack[i] < B.ARMORED_STRIKE else 2.0
				hop = 0.0
				lean = 0.0
				squash = 1.0
			t.basis = Basis.from_scale(Vector3(2.0 - squash, squash, 1.0))
			t.origin = Vector3(sim.e_x[i], hop, sim.e_z[i])
			armored_mm.set_instance_transform(armored, t)
			armored_mm.set_instance_custom_data(armored, Color(sim.e_flash[i], lean, pose, 0))
			armored += 1
		else:
			var big := 0.88 + seed * 0.28
			t.basis = Basis.from_scale(Vector3((2.0 - squash) * big, squash * big, 1.0))
			t.origin = Vector3(sim.e_x[i], absf(sin(phase)) * 0.12, sim.e_z[i])
			enemy_mm.set_instance_transform(plain, t)
			enemy_mm.set_instance_custom_data(plain, Color(sim.e_flash[i], sin(phase) * 0.06, 1.0 if sin(phase) > 0.0 else 0.0, 0))
			plain += 1
		t.basis = Basis.IDENTITY
		t.origin.y = 0.03
		enemy_shadow_mm.set_instance_transform(i, t)
	enemy_mm.visible_instance_count = plain
	armored_mm.visible_instance_count = armored

	trail_mm.visible_instance_count = sim.b_count
	for i in sim.b_count:
		# Arrows rise and fall along a shallow arc over their full range.
		var flown := 1.0 - sim.b_left[i] / B.BULLET_RANGE
		t.origin = Vector3(sim.b_x[i], sin(flown * PI) * 0.7, sim.b_z[i])
		bullet_mm.set_instance_transform(i, t)
		trail_mm.set_instance_transform(i, t)

	var shown := mini(sim.soldiers, B.MAX_SHOWN)
	soldier_mm.visible_instance_count = shown
	shadow_mm.visible_instance_count = shown
	for i in range(shown_before, shown):
		slot_pop[i] = 1.0
		slot_x[i] = sim.squad_x + sim.formation[i].x
	shown_before = shown
	for i in shown:
		var f := sim.formation[i]
		var recoil := slot_recoil[i]
		var pop := slot_pop[i]
		slot_recoil[i] = maxf(0.0, recoil - dt * 6.0)
		slot_pop[i] = maxf(0.0, pop - dt * 4.0)
		var grow := 1.0 - pop + sin(pop * PI) * 0.45
		var hop := absf(sin(time * 7.0 + i * 1.3)) * (0.5 if cheering else 0.05)
		t.basis = Basis.from_scale(Vector3(grow * (1.0 + recoil * 0.12), grow * (1.0 - recoil * 0.14), 1.0))
		# Archers further from the centre follow later, so the crowd flows.
		var follow := 1.0 - exp(-dt * (24.0 - 14.0 * i / B.MAX_SHOWN))
		slot_x[i] = lerpf(slot_x[i], sim.squad_x + f.x, follow)
		t.origin = Vector3(clampf(slot_x[i], -B.ROAD_HALF + 0.3, B.ROAD_HALF - 0.3), hop, f.y + recoil * 0.12)
		soldier_mm.set_instance_transform(i, t)
		# Poses: 0 aiming, 1 just released, 2 other foot forward, 3 cheering.
		var stride := sin(time * 7.0 + i * 1.3)
		var pose := 3.0 if cheering else (1.0 if recoil > 0.25 else (2.0 if stride > 0.0 else 0.0))
		soldier_mm.set_instance_custom_data(i, Color(pop * 0.8, stride * 0.04, pose, 0))
		t.basis = Basis.IDENTITY
		t.origin.y = 0.03
		shadow_mm.set_instance_transform(i, t)
	var count_text := str(sim.soldiers)
	squad_label.text = count_text
	squad_label.pixel_size = 0.009 * minf(1.0, 2.6 / count_text.length())
	squad_label.position = Vector3(sim.squad_x, 2.3, -sim.squad_r - 0.3)
	if sim.soldiers != count_before:
		count_before = sim.soldiers
		count_pulse = 1.0
	count_pulse = maxf(0.0, count_pulse - dt * 5.0)
	var bump := 1.0 + count_pulse * 0.3
	squad_label.scale = Vector3(bump, bump, bump)
	squad_badge.scale = squad_label.scale
	squad_badge.position = squad_label.position

	# Scrolling ground: slide the textures instead of moving geometry.
	floor_mat.uv1_offset.y = -fposmod(sim.distance / FLOOR_PERIOD, 1.0)
	grass_mat.uv1_offset.y = -fposmod(sim.distance / GRASS_PERIOD, 1.0)
	water_mat.uv1_offset.x = fposmod(time * 0.03, 1.0)
	river.position.z = fposmod(sim.distance + 70.0, RIVER_PERIOD) - 170.0

	for w in wall_mats:
		var shift := fposmod(sim.distance * w[1], 1.0)
		if w[2]:
			w[0].uv1_offset.x = shift
		else:
			w[0].uv1_offset.y = shift

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
		var frac := clampf(sim.boss_hp / sim.boss_max, 0.0, 1.0)
		boss_bar.scale.x = maxf(frac, 0.001)
		boss_bar.position.x = -(1.0 - frac) * 1.55
		var quarter := int(ceilf(frac * 4.0))
		if quarter < boss_quarter:
			boss_hurt = 0.45
		boss_quarter = quarter
		boss_hurt = maxf(0.0, boss_hurt - dt)
		if sim.boss_pose != boss_pose_shown:
			boss_pose_shown = sim.boss_pose
			boss_sprite.mesh = boss_meshes[boss_pose_shown]
			boss_mat = boss_sprite.mesh.material
		boss_mat.set_shader_parameter("flash", sim.boss_flash * 0.35)
		boss_warning.visible = sim.boss_pose == 1
		if sim.boss_pose == 0:
			# The troll stomps: every footfall shakes the ground once it is close.
			var step := sin(time * 3.2)
			boss_sprite.position = Vector3(0, absf(step) * 0.3, 0)
			boss_mat.set_shader_parameter("tilt", step * 0.03)
			# Poses: 0 and 1 are his two steps, 2 is the flinch shown briefly each
			# time he loses another quarter of his health.
			boss_mat.set_shader_parameter("pose", 2.0 if boss_hurt > 0.0 else (1.0 if step > 0.0 else 0.0))
			if step * boss_step < 0.0 and sim.boss_z > -40.0:
				add_shake(0.12)
				stomped = true
			boss_step = step
		elif sim.boss_pose == 1:
			# Mace raised: he stretches and trembles while the warning patch grows.
			var charge := 1.0 - sim.boss_timer / B.BOSS_WINDUP
			boss_sprite.position = Vector3(0, charge * 0.25, 0)
			boss_mat.set_shader_parameter("tilt", sin(time * 40.0) * 0.015 * charge)
			var grow := 0.35 + 0.65 * charge
			boss_warning.scale = Vector3(grow, 1, grow)
		else:
			# Mace on the ground: the picture is anchored at the mace head, which
			# lies in front of his feet.
			boss_sprite.position = Vector3(0, 0, 2.3)
			boss_mat.set_shader_parameter("tilt", 0.0)
	_sync_gates(sim, dt)
	_update_effects(dt)


## Reacts to what the simulation reported this tick.
func apply_fx(sim: Sim) -> void:
	var kills := 0
	for e in sim.fx:
		match e[0]:
			"shot":
				slot_recoil[e[1]] = 1.0
			"kill":
				kills += 1
				if kills <= 10:
					var at := Vector3(e[1], 0.6, e[2])
					# The orc is thrown backward, tumbling, and leaves a puff behind.
					var pool := fallen_armored if e[3] else fallen
					pool.emit(at + Vector3(0, 0.2, 0), Vector3(randf_range(-2.0, 2.0), randf_range(4.5, 6.5), randf_range(-7.0, -4.0)), 0.5, 2.1 if e[3] else 1.7, Color.WHITE, 0.0, randf_range(-7.0, 7.0))
					puffs.emit(at, Vector3(randf_range(-1.0, 1.0), randf_range(0.5, 1.5), 0.0), 0.4, 0.75, Color(0.8, 1.0, 0.65, 0.95), 0.0, randf_range(-2.0, 2.0))
					if kills <= 4:
						sparks.emit(at, Vector3.ZERO, 0.12, 0.8, Color.WHITE, 0.0, 6.0)
					if kills <= 3:
						coins_fx.emit(at, Vector3(randf_range(-1.5, 1.5), randf_range(5.0, 8.0), randf_range(-0.5, 1.5)), 0.7, 0.45)
						if kills == 1:
							coin_flights.append(cam.unproject_position(at))
			"lost":
				lost_pending += e[3]
				add_shake(0.06)
				# A few of the lost archers are thrown back toward the camera.
				for k in mini(e[3], 3):
					fallen_archers.emit(Vector3(e[1] + randf_range(-0.6, 0.6), 0.3, e[2] + 0.4), Vector3(randf_range(-3.0, 3.0), randf_range(5.0, 7.0), randf_range(2.0, 4.0)), 0.55, 1.6, Color.WHITE, 0.0, randf_range(-6.0, 6.0))
				for k in 4:
					puffs.emit(Vector3(e[1], 0.7, e[2]), Vector3(randf_range(-2.0, 2.0), randf_range(1.0, 3.0), randf_range(-1.0, 1.0)), 0.45, 0.8, Color(1.0, 0.4, 0.35, 0.95), 0.0, randf_range(-2.0, 2.0))
			"gate":
				var good: bool = e[3]
				var tint := Color(0.4, 0.75, 1.0) if good else Color(1.0, 0.3, 0.25)
				for k in 14:
					sparks.emit(Vector3(e[1] + randf_range(-1.6, 1.6), randf_range(0.8, 2.6), -0.3), Vector3(randf_range(-2.0, 2.0), randf_range(1.0, 4.0), randf_range(-1.0, 1.0)), 0.45, 0.55, tint.lerp(Color.WHITE, 0.4), 0.0, randf_range(-5.0, 5.0))
				_float_text("%+d" % e[2], Vector3(sim.squad_x, 3.2, -sim.squad_r - 0.3), Color(0.6, 0.9, 1.0) if good else Color(1.0, 0.4, 0.35))
				if not good:
					add_shake(0.15)
			"grow":
				gate_pulse[e[1]] = 1.0
			"chop":
				sparks.emit(Vector3(e[1], 0.5, e[2] + 0.6), Vector3.ZERO, 0.15, 1.6, Color.WHITE, 0.0, 5.0)
				add_shake(0.12)
			"boss_hit":
				sparks.emit(Vector3(sim.boss_x + randf_range(-1.0, 1.0), randf_range(1.0, 3.5), sim.boss_z + 0.5), Vector3.ZERO, 0.14, 1.1, Color.WHITE, 0.0, 6.0)
			"smash":
				add_shake(0.5)
				var ground := Vector3(e[1], 0.3, e[2])
				for k in 16:
					var dir := Vector3(cos(k * 0.39), 0.0, sin(k * 0.39))
					puffs.emit(ground + dir * 0.8, dir * randf_range(3.0, 5.0) + Vector3(0, randf_range(0.5, 2.0), 0), 0.55, 1.3, Color(0.85, 0.8, 0.7, 0.95), 0.0, randf_range(-2.0, 2.0))
				sparks.emit(ground + Vector3(0, 0.6, 0.3), Vector3.ZERO, 0.2, 3.0, Color.WHITE, 0.0, 4.0)
			"boss_dead":
				add_shake(0.6)
				for k in 36:
					puffs.emit(Vector3(e[1] + randf_range(-1.5, 1.5), randf_range(0.5, 5.0), e[2]), Vector3(randf_range(-4.0, 4.0), randf_range(1.0, 6.0), randf_range(-2.0, 2.0)), randf_range(0.5, 1.0), 1.2, Color(0.7, 0.95, 0.85, 0.95), 0.0, randf_range(-2.0, 2.0))
				for k in 10:
					coin_flights.append(cam.unproject_position(Vector3(e[1] + randf_range(-2.0, 2.0), randf_range(1.0, 4.0), e[2])))
				for k in 30:
					coins_fx.emit(Vector3(e[1], 2.5, e[2]), Vector3(randf_range(-4.0, 4.0), randf_range(6.0, 12.0), randf_range(0.0, 6.0)), 1.4, 0.6)


func add_shake(amount: float) -> void:
	shake = minf(0.6, shake + amount)


## Celebration when a level is won; cleared again by end_celebration().
func celebrate(sim: Sim) -> void:
	cheering = true
	for k in 150:
		confetti.emit(Vector3(randf_range(-5.0, 5.0), randf_range(7.0, 13.0), randf_range(-7.0, 2.0)), Vector3(randf_range(-1.2, 1.2), randf_range(-3.0, -1.0), randf_range(-0.5, 0.5)), randf_range(1.8, 3.2), randf_range(0.3, 0.5), Color.WHITE, float(k % 6), randf_range(-6.0, 6.0))


func end_celebration() -> void:
	cheering = false
	boss_pose_shown = 0
	boss_quarter = 4
	boss_hurt = 0.0
	boss_sprite.mesh = boss_meshes[0]
	boss_mat = boss_meshes[0].material
	boss_warning.visible = false
	shown_before = 0
	stomped = false


func _float_text(text: String, at: Vector3, color: Color) -> void:
	for f in floaters:
		if f.life <= 0.0:
			f.life = 1.0
			f.label.text = text
			f.label.modulate = color
			f.label.position = at
			f.label.visible = true
			return


func _update_effects(dt: float) -> void:
	fallen.update(dt)
	fallen_archers.update(dt)
	fallen_armored.update(dt)
	puffs.update(dt)
	sparks.update(dt)
	confetti.update(dt)
	coins_fx.update(dt)
	for f in floaters:
		if f.life > 0.0:
			f.life -= dt * 1.1
			var l: Label3D = f.label
			l.position.y += dt * 1.6
			l.modulate.a = clampf(f.life * 2.0, 0.0, 1.0)
			l.outline_modulate.a = l.modulate.a
			var s := 1.0 + maxf(0.0, f.life - 0.8) * 2.5
			l.scale = Vector3(s, s, s)
			l.visible = f.life > 0.0
	# Losses come in bursts, so show them as one number a few times a second.
	lost_timer -= dt
	if lost_pending > 0 and lost_timer <= 0.0:
		_float_text("-%d" % lost_pending, squad_label.position + Vector3(randf_range(-0.8, 0.8), 0.9, 0), Color(1.0, 0.4, 0.35))
		lost_pending = 0
		lost_timer = 0.35
	shake = maxf(0.0, shake - dt * 1.8)
	cam.position = cam_home + Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake * shake * 1.5


func _sync_gates(sim: Sim, dt: float) -> void:
	var alive := {}
	for g in sim.gates:
		alive[g.id] = true
		if not gate_views.has(g.id):
			gate_views[g.id] = _make_gate(g)
		var v: Dictionary = gate_views[g.id]
		v.node.position.z = g.z
		var pulse: float = gate_pulse.get(g.id, 0.0)
		if pulse > 0.0:
			gate_pulse[g.id] = pulse - dt * 6.0
		var bump := 1.0 + maxf(pulse, 0.0) * 0.35
		v.label.scale = Vector3(bump, bump, bump)
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
			gate_pulse.erase(id)


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
