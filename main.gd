extends Node3D
# THE LAST SHOW - first-person carnival horror. The whole world is built in code.
const SPAWN := Vector3(-4.0, 0.1, 52.0)
const KNIFE_AT := Vector3(5.0, 1.04, 47.0)
const GATE_Z := -61.0
const HEART_AT := [Vector3(47.5, 1.25, 28.0), Vector3(39.5, 1.25, -2.0), Vector3(-28.0, 1.7, -4.0), Vector3(-5.0, 1.75, -47.0), Vector3(-42.5, 1.35, 36.0)]
const KNEEL_AT := [Vector3(-52.0, 0.0, -46.0), Vector3(50.0, 0.0, -50.0), Vector3(-52.0, 0.0, 8.0), Vector3(52.0, 0.0, 48.0), Vector3(2.0, 0.0, 8.0), Vector3(-20.0, 0.0, 53.0)]
const PATROL := [Vector3(0.0, 0.0, 38.0), Vector3(-22.0, 0.0, 28.0), Vector3(20.0, 0.0, 36.0), Vector3(-46.0, 0.0, 22.0), Vector3(46.0, 0.0, 4.0), Vector3(24.0, 0.0, -26.0), Vector3(-14.0, 0.0, -14.0), Vector3(2.0, 0.0, -6.0), Vector3(-46.0, 0.0, -22.0), Vector3(46.0, 0.0, -34.0), Vector3(12.0, 0.0, -54.0), Vector3(-26.0, 0.0, -52.0), Vector3(-12.0, 0.0, 22.0)]
const JACKS := [Vector3(-9.0, 0.0, 33.0), Vector3(12.0, 0.0, 12.0), Vector3(-18.0, 0.0, -30.0)]
const LAMPS := [Vector3(-5.0, 0.0, 46.0), Vector3(5.0, 0.0, 30.0), Vector3(-5.0, 0.0, 16.0), Vector3(6.0, 0.0, -6.0), Vector3(-6.0, 0.0, -18.0), Vector3(-5.0, 0.0, -26.0), Vector3(26.0, 0.0, 22.0), Vector3(-34.0, 0.0, 28.0), Vector3(20.0, 0.0, -24.0), Vector3(-45.0, 0.0, -5.0), Vector3(46.0, 0.0, 8.0)]
const STALLS := [Vector3(-18.0, 0.0, 40.0), Vector3(14.0, 0.0, 38.0), Vector3(-30.0, 0.0, 18.0), Vector3(24.0, 0.0, 12.0), Vector3(-12.0, 0.0, -22.0), Vector3(22.0, 0.0, -34.0), Vector3(-38.0, 0.0, -30.0)]
const POST_SHADER := """
shader_type canvas_item;
uniform sampler2D scr : hint_screen_texture, filter_linear_mipmap;
uniform float fear = 0.0;
uniform float flash = 0.0;
uniform vec3 flash_col = vec3(1.0, 0.0, 0.0);
uniform float glitch = 0.0;
uniform float tm = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - vec2(0.5);
	float d = dot(c, c);
	uv.x += glitch * (hash(vec2(floor(uv.y * 36.0), floor(tm * 18.0))) - 0.5) * 0.09;
	vec2 off = c * (0.012 + fear * 0.02 + glitch * 0.05);
	vec3 col;
	col.r = texture(scr, uv + off).r;
	col.g = texture(scr, uv).g;
	col.b = texture(scr, uv - off).b;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(lum) * vec3(1.0, 0.92, 0.9), 0.2 + fear * 0.35);
	col *= 1.0 - smoothstep(0.1, 0.6, d) * (0.8 + fear * 0.5);
	col += (hash(SCREEN_UV * 900.0 + tm) - 0.5) * 0.06;
	col = mix(col, flash_col, clamp(flash, 0.0, 1.0));
	COLOR = vec4(col, 1.0);
}
"""
var player = null
var clown = null
var ui = null
var post: ShaderMaterial
var env: Environment
var world: Node3D
var nav: NavigationRegion3D
var mats := {}
var hearts: Array = []
var lamps: Array = []
var jacks: Array = []
var avoid: Array = []
var patrol_pts: Array = []
var wheel: Node3D
var wheel_cabs: Array = []
var carousel: Node3D
var gate_l: Node3D
var gate_r: Node3D
var gate_lock: Node3D
var gate_light: OmniLight3D
var knife_node: Node3D
var cine: Camera3D
var hb: AudioStreamPlayer
var state := "loading"
var busy := false
var busy_scare := false
var paused := false
var prompt := ""
var target = null
var objective := ""
var msg := ""
var msg_t := 0.0
var kill_t := 0.0
var end_t := 0.0
var destroyed := 0
var has_knife := false
var has_key := false
var final_stage := false
var gate_open := false
var lamps_on := true
var black_hold := false
var scare_t := 24.0
var amb_t := 12.0
var back_t := 0.0
var lock_msg_t := 0.0
var respawn_t := -1.0
var fear := 0.0
var flash_a := 0.0
var flash_c := Color(1, 0, 0)
var glitch := 0.0
var bars := 0.0
var t := 0.0

# ---------------------------------------------------------------- setup
func _ready() -> void:
	randomize()
	var pl := CanvasLayer.new()
	pl.layer = 1
	add_child(pl)
	var cr := ColorRect.new()
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = POST_SHADER
	post = ShaderMaterial.new()
	post.shader = sh
	cr.material = post
	pl.add_child(cr)
	var ul := CanvasLayer.new()
	ul.layer = 3
	add_child(ul)
	ui = (load("res://ui.gd") as GDScript).new()
	ui.g = self
	ul.add_child(ui)
	await get_tree().process_frame
	await get_tree().process_frame
	build_all()
	await get_tree().physics_frame
	await get_tree().physics_frame
	state = "menu"

func mk(col: Color, rough: float = 0.9, tex: String = "", tri: bool = true, scl: float = 0.25, em: Color = Color.BLACK, ee: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	if tex != "":
		m.albedo_texture = load("res://%s.png" % tex)
		if tri:
			m.uv1_triplanar = true
			m.uv1_world_triplanar = true
			m.uv1_scale = Vector3(scl, scl, scl)
	if ee > 0.0:
		m.emission_enabled = true
		m.emission = em
		m.emission_energy_multiplier = ee
	return m

func make_mats() -> void:
	mats["dirt"] = mk(Color(0.9, 0.9, 0.9), 1.0, "dirt", false)
	mats["dirt"].uv1_scale = Vector3(3.5, 3.5, 1.0)
	mats["path"] = mk(Color(0.55, 0.5, 0.48), 1.0, "dirt", false)
	mats["path"].uv1_scale = Vector3(2.0, 12.0, 1.0)
	mats["wood"] = mk(Color(0.85, 0.8, 0.75), 0.9, "planks", true, 0.25)
	mats["metal"] = mk(Color(0.9, 0.9, 0.9), 0.5, "metal", true, 0.3)
	mats["paint"] = mk(Color(0.95, 0.95, 0.95), 0.85, "paint", true, 0.2)
	mats["tent"] = mk(Color(0.95, 0.95, 0.95), 0.9, "tent", true, 0.12)
	mats["tent"].cull_mode = BaseMaterial3D.CULL_DISABLED
	mats["tent_uv"] = mk(Color(0.95, 0.95, 0.95), 0.9, "tent", false)
	mats["tent_uv"].uv1_scale = Vector3(5.0, 1.0, 1.0)
	mats["tent_uv"].cull_mode = BaseMaterial3D.CULL_DISABLED
	mats["bark"] = mk(Color(0.12, 0.09, 0.07), 1.0)
	mats["dark"] = mk(Color(0.03, 0.03, 0.04), 0.9)
	mats["steel"] = mk(Color(0.8, 0.82, 0.86), 0.25, "", false, 0.25, Color(0.7, 0.75, 0.8), 0.5)
	mats["steel"].metallic = 0.9
	mats["red"] = mk(Color(0.65, 0.05, 0.07), 0.5)
	mats["white"] = mk(Color(0.88, 0.86, 0.8), 0.6)
	mats["gold"] = mk(Color(1.0, 0.8, 0.2), 0.3, "", false, 0.25, Color(1.0, 0.7, 0.1), 2.5)
	mats["bulb"] = mk(Color(1.0, 0.85, 0.5), 0.4, "", false, 0.25, Color(1.0, 0.75, 0.35), 1.5)
	mats["poster"] = mk(Color(0.9, 0.9, 0.9), 0.8, "poster", false, 0.25, Color(0.9, 0.9, 0.9), 0.0)
	mats["poster"].emission_enabled = true
	mats["poster"].emission_texture = load("res://poster.png")
	mats["poster"].emission_energy_multiplier = 0.55
	mats["poster"].cull_mode = BaseMaterial3D.CULL_DISABLED

func make_env() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.02, 0.035)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.2, 0.24, 0.36)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.07, 0.09, 0.13)
	env.fog_density = 0.04
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 0.85
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.45, 0.55, 0.9)
	moon.light_energy = 0.35
	moon.rotation_degrees = Vector3(-55.0, 30.0, 0.0)
	moon.shadow_enabled = false
	add_child(moon)

func build_all() -> void:
	make_env()
	make_mats()
	world = Node3D.new()
	add_child(world)
	var map := get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, 0.5)
	NavigationServer3D.map_set_cell_height(map, 0.5)
	nav = NavigationRegion3D.new()
	var nm := NavigationMesh.new()
	nm.cell_size = 0.5
	nm.cell_height = 0.5
	nm.agent_radius = 0.8
	nm.agent_height = 2.4
	nm.agent_max_climb = 0.5
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav.navigation_mesh = nm
	add_child(nav)
	patrol_pts = PATROL.duplicate()
	setup_avoid()
	build_ground()
	build_fence()
	build_gate()
	build_ferris()
	build_carousel()
	build_tent()
	build_funhouse()
	build_small_huts()
	for i in STALLS.size():
		stall(STALLS[i], [0.2, -0.3, 1.4, -1.2, 0.4, -0.8, 0.9][i], [Color(0.5, 0.2, 0.2), Color(0.2, 0.3, 0.5), Color(0.5, 0.45, 0.2), Color(0.3, 0.5, 0.3), Color(0.5, 0.3, 0.5), Color(0.2, 0.4, 0.45), Color(0.5, 0.35, 0.25)][i])
	for p in LAMPS:
		lamp(p, randf() < 0.4)
	scatter(26, 2.0, crate)
	scatter(14, 2.0, barrel)
	scatter(26, 3.0, tree)
	for p in JACKS:
		build_jack(p)
	build_signs()
	build_hearts()
	build_knife()
	nav.bake_navigation_mesh(false)
	player = (load("res://player.gd") as GDScript).new()
	player.g = self
	player.ui = ui
	add_child(player)
	player.global_position = SPAWN
	clown = (load("res://clown.gd") as GDScript).new()
	clown.g = self
	clown.player = player
	add_child(clown)
	clown.deactivate()
	amb = Sfx.loop2d("ambience", -4.0)
	hb = Sfx.loop2d("heart", -60.0)
	objective = "Find the knife"

# ---------------------------------------------------------------- builders
func box(par: Node, size: Vector3, pos: Vector3, m: Material, rot: float = 0.0, solid: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = rot
	par.add_child(mi)
	if solid:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		sb.add_child(cs)
		mi.add_child(sb)
	return mi

func pillar(par: Node, r: float, h: float, pos: Vector3, m: Material, solid: bool = true, rb: float = -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r if rb < 0.0 else rb
	cm.height = h
	cm.radial_segments = 12
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	par.add_child(mi)
	if solid:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = maxf(r, cm.bottom_radius)
		sh.height = h
		cs.shape = sh
		sb.add_child(cs)
		mi.add_child(sb)
	return mi

func ball(par: Node, r: float, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 14
	sm.rings = 7
	mi.mesh = sm
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	par.add_child(mi)
	return mi

func lbl(text: String, pos: Vector3, rot_y: float, size: int, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = Sfx.font
	l.font_size = size
	l.pixel_size = 0.01
	l.modulate = col
	l.outline_size = 12
	l.outline_modulate = Color(0, 0, 0)
	l.double_sided = true
	l.shaded = false
	l.position = pos
	l.rotation.y = rot_y
	world.add_child(l)

func omni(par: Node, pos: Vector3, col: Color, energy: float, rng: float, flicker: bool = false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.3
	l.position = pos
	par.add_child(l)
	if flicker:
		lamps.append({"light": l, "mat": null, "base": energy, "faulty": true, "ph": randf() * 10.0})
	return l

func setup_avoid() -> void:
	avoid.append([SPAWN, 6.0])
	avoid.append([KNIFE_AT, 4.0])
	avoid.append([Vector3(0.0, 0.0, -56.0), 7.0])
	for p in HEART_AT:
		avoid.append([p, 4.5])
	for p in KNEEL_AT:
		avoid.append([p, 6.0])
	for p in PATROL:
		avoid.append([p, 4.0])
	for p in JACKS:
		avoid.append([p, 3.5])
	for p in LAMPS:
		avoid.append([p, 2.0])
	for p in STALLS:
		avoid.append([p, 4.5])
	avoid.append([Vector3(40.0, 0.0, 30.0), 17.0])
	avoid.append([Vector3(34.0, 0.0, -14.0), 12.0])
	avoid.append([Vector3(-28.0, 0.0, -4.0), 10.0])
	avoid.append([Vector3(-5.0, 0.0, -40.0), 16.0])
	avoid.append([Vector3(-40.0, 0.0, 36.0), 7.0])
	avoid.append([Vector3(38.0, 0.0, -2.0), 6.0])

func is_free(p: Vector3, r: float) -> bool:
	if absf(p.x) > 57.0 or absf(p.z) > 57.0:
		return false
	for a in avoid:
		var c: Vector3 = a[0]
		if Vector2(p.x, p.z).distance_to(Vector2(c.x, c.z)) < float(a[1]) + r:
			return false
	return true

func scatter(count: int, r: float, fn: Callable) -> void:
	var made := 0
	var tries := 0
	while made < count and tries < 600:
		tries += 1
		var p := Vector3(randf_range(-56.0, 56.0), 0.0, randf_range(-56.0, 56.0))
		if is_free(p, r):
			fn.call(p)
			avoid.append([p, r])
			made += 1

func crate(p: Vector3) -> void:
	var s := randf_range(0.9, 1.5)
	box(nav, Vector3(s, s, s), p + Vector3(0.0, s * 0.5, 0.0), mats["wood"], randf() * TAU)

func barrel(p: Vector3) -> void:
	pillar(nav, 0.45, 1.0, p + Vector3(0.0, 0.5, 0.0), mats["metal"])

func tree(p: Vector3) -> void:
	var h := randf_range(4.0, 7.0)
	pillar(nav, 0.18, h, p + Vector3(0.0, h * 0.5, 0.0), mats["bark"], true, 0.38)
	for i in 4:
		var b := pillar(world, 0.05, randf_range(1.6, 2.6), p + Vector3(0.0, h * randf_range(0.5, 0.95), 0.0), mats["bark"], false)
		b.rotation = Vector3(0.0, randf() * TAU, randf_range(0.6, 1.2))

func build_ground() -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(150.0, 1.0, 150.0)
	cs.shape = bs
	sb.add_child(cs)
	sb.position = Vector3(0.0, -0.5, 0.0)
	nav.add_child(sb)
	var pm := PlaneMesh.new()
	pm.size = Vector2(13.0, 13.0)
	for ix in 10:
		for iz in 10:
			var mi := MeshInstance3D.new()
			mi.mesh = pm
			mi.material_override = mats["dirt"]
			mi.position = Vector3(-58.5 + ix * 13.0, 0.0, -58.5 + iz * 13.0)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			world.add_child(mi)
	var path := PlaneMesh.new()
	path.size = Vector2(8.0, 116.0)
	var pi := MeshInstance3D.new()
	pi.mesh = path
	pi.material_override = mats["path"]
	pi.position = Vector3(0.0, 0.02, -2.0)
	pi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(pi)

func build_fence() -> void:
	var h := 4.6
	box(nav, Vector3(128.0, h, 0.5), Vector3(0.0, h * 0.5, 62.0), mats["wood"])
	box(nav, Vector3(0.5, h, 128.0), Vector3(-62.0, h * 0.5, 0.0), mats["wood"])
	box(nav, Vector3(0.5, h, 128.0), Vector3(62.0, h * 0.5, 0.0), mats["wood"])
	box(nav, Vector3(58.0, h, 0.5), Vector3(-33.0, h * 0.5, -62.0), mats["wood"])
	box(nav, Vector3(58.0, h, 0.5), Vector3(33.0, h * 0.5, -62.0), mats["wood"])
	var pst := [[Vector3(-61.7, 2.8, 20.0), 1.5708], [Vector3(61.7, 2.8, -20.0), -1.5708], [Vector3(-20.0, 2.8, -61.7), 0.0], [Vector3(30.0, 2.8, 61.7), 3.1416], [Vector3(-61.7, 2.8, -30.0), 1.5708]]
	for e in pst:
		var qm := QuadMesh.new()
		qm.size = Vector2(4.2, 4.2)
		var mi := MeshInstance3D.new()
		mi.mesh = qm
		mi.material_override = mats["poster"]
		mi.position = e[0]
		mi.rotation.y = e[1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(mi)

func build_gate() -> void:
	box(nav, Vector3(1.2, 7.0, 1.2), Vector3(-4.6, 3.5, GATE_Z - 0.4), mats["wood"])
	box(nav, Vector3(1.2, 7.0, 1.2), Vector3(4.6, 3.5, GATE_Z - 0.4), mats["wood"])
	box(world, Vector3(10.4, 1.2, 1.2), Vector3(0.0, 6.6, GATE_Z - 0.4), mats["wood"], 0.0, false)
	lbl("EXIT", Vector3(0.0, 6.6, GATE_Z + 0.3), 0.0, 120, Color(0.8, 0.1, 0.1))
	gate_l = Node3D.new()
	gate_l.position = Vector3(-4.0, 0.0, GATE_Z)
	world.add_child(gate_l)
	box(gate_l, Vector3(4.0, 4.2, 0.3), Vector3(2.0, 2.1, 0.0), mats["metal"])
	gate_r = Node3D.new()
	gate_r.position = Vector3(4.0, 0.0, GATE_Z)
	world.add_child(gate_r)
	box(gate_r, Vector3(4.0, 4.2, 0.3), Vector3(-2.0, 2.1, 0.0), mats["metal"])
	gate_lock = Node3D.new()
	gate_lock.position = Vector3(0.0, 2.0, GATE_Z + 0.3)
	world.add_child(gate_lock)
	box(gate_lock, Vector3(3.0, 0.18, 0.18), Vector3.ZERO, mats["metal"], 0.0, false)
	box(gate_lock, Vector3(0.45, 0.55, 0.25), Vector3(0.0, -0.3, 0.0), mats["gold"], 0.0, false)
	gate_light = omni(world, Vector3(0.0, 2.8, GATE_Z + 3.0), Color(0.9, 0.1, 0.1), 1.6, 9.0)

func build_ferris() -> void:
	var c := Vector3(34.0, 0.0, -14.0)
	var root := Node3D.new()
	root.position = c
	world.add_child(root)
	wheel = Node3D.new()
	wheel.position = Vector3(0.0, 15.5, 0.0)
	root.add_child(wheel)
	for zz in [-1.1, 1.1]:
		var tm := TorusMesh.new()
		tm.inner_radius = 13.6
		tm.outer_radius = 14.0
		tm.rings = 48
		tm.ring_segments = 8
		var rim := MeshInstance3D.new()
		rim.mesh = tm
		rim.material_override = mats["metal"]
		rim.rotation_degrees.x = 90.0
		rim.position.z = zz
		wheel.add_child(rim)
	for i in 8:
		var sp := box(wheel, Vector3(0.18, 27.6, 0.18), Vector3.ZERO, mats["metal"], 0.0, false)
		sp.rotation.z = i * PI / 8.0
	ball(wheel, 1.0, Vector3.ZERO, mats["metal"])
	for i in 10:
		var a := i * TAU / 10.0
		var piv := Node3D.new()
		piv.position = Vector3(cos(a) * 14.0, sin(a) * 14.0, 0.0)
		wheel.add_child(piv)
		box(piv, Vector3(2.2, 1.7, 2.6), Vector3(0.0, -1.4, 0.0), mk(Color.from_hsv(randf(), 0.5, 0.45), 0.8), 0.0, false)
		box(piv, Vector3(2.5, 0.2, 2.9), Vector3(0.0, -0.45, 0.0), mats["dark"], 0.0, false)
		wheel_cabs.append(piv)
	for i in 20:
		var a2 := i * TAU / 20.0
		ball(wheel, 0.2, Vector3(cos(a2) * 14.1, sin(a2) * 14.1, 1.3), mats["bulb"])
	for sx in [-1.0, 1.0]:
		for sz in [-2.2, 2.2]:
			var leg := box(root, Vector3(0.5, 17.0, 0.5), Vector3(sx * 3.0, 7.75, sz), mats["metal"], 0.0, false)
			leg.rotation.z = sx * 0.37
			box(nav, Vector3(1.2, 1.0, 1.2), Vector3(c.x + sx * 6.0, 0.5, c.z + sz), mats["metal"])

func build_carousel() -> void:
	var c := Vector3(-28.0, 0.0, -4.0)
	carousel = Node3D.new()
	carousel.position = c
	world.add_child(carousel)
	var plat := pillar(carousel, 7.2, 0.12, Vector3(0.0, 0.06, 0.0), mats["wood"], false)
	plat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pillar(carousel, 0.35, 5.0, Vector3(0.0, 2.5, 0.0), mats["gold"], false)
	for i in 8:
		var a := i * TAU / 8.0
		var p := Vector3(cos(a) * 4.8, 0.0, sin(a) * 4.8)
		pillar(carousel, 0.05, 4.0, p + Vector3(0.0, 2.2, 0.0), mats["gold"], false)
		var hm := mk(Color.from_hsv(randf(), 0.25, 0.55), 0.7)
		var body := box(carousel, Vector3(1.5, 0.7, 0.5), p + Vector3(0.0, 1.5, 0.0), hm, -a, false)
		ball(carousel, 0.3, p + Vector3(cos(a + PI * 0.5) * 0.8, 1.9, -sin(a + PI * 0.5) * 0.8), hm)
		body.rotation.z = 0.05
	var cone := CylinderMesh.new()
	cone.top_radius = 0.1
	cone.bottom_radius = 7.8
	cone.height = 2.6
	var cm := MeshInstance3D.new()
	cm.mesh = cone
	cm.material_override = mats["tent_uv"]
	cm.position = Vector3(0.0, 6.0, 0.0)
	carousel.add_child(cm)
	pillar(carousel, 7.8, 0.7, Vector3(0.0, 4.5, 0.0), mats["tent_uv"], false)
	omni(world, c + Vector3(0.0, 4.0, 0.0), Color(1.0, 0.5, 0.3), 1.4, 11.0, true)

func build_tent() -> void:
	var c := Vector3(-5.0, 0.0, -40.0)
	var n := 22
	var r := 13.0
	for i in n:
		var a := i * TAU / n
		if i == 0:
			continue
		box(nav, Vector3(2.0 * r * sin(PI / n) + 0.15, 6.0, 0.5), c + Vector3(r * sin(a), 3.0, r * cos(a)), mats["tent"], a)
	var roof := CylinderMesh.new()
	roof.top_radius = 0.3
	roof.bottom_radius = 14.5
	roof.height = 7.0
	var rm := MeshInstance3D.new()
	rm.mesh = roof
	rm.material_override = mats["tent_uv"]
	rm.position = c + Vector3(0.0, 9.5, 0.0)
	world.add_child(rm)
	box(nav, Vector3(9.0, 1.1, 5.0), c + Vector3(0.0, 0.55, -8.0), mats["wood"])
	for row in 2:
		for k in 5:
			box(nav, Vector3(3.0, 0.5, 0.7), c + Vector3(-6.0 + k * 3.0, 0.25, 1.0 + row * 3.0), mats["wood"])
	omni(world, c + Vector3(0.0, 4.5, 0.0), Color(1.0, 0.25, 0.2), 1.4, 17.0, true)
	var sp := SpotLight3D.new()
	sp.position = c + Vector3(0.0, 6.0, -1.0)
	sp.rotation_degrees = Vector3(-72.0, 0.0, 0.0)
	sp.spot_range = 14.0
	sp.spot_angle = 30.0
	sp.light_energy = 3.0
	sp.light_color = Color(1.0, 0.85, 0.6)
	world.add_child(sp)

func building(c: Vector3, w: float, d: float, h: float, door: String, m: Material, gap: float = 3.4) -> void:
	var th := 0.4
	for side in ["n", "s", "w", "e"]:
		var horiz: bool = (side == "n" or side == "s")
		var span := w if horiz else d
		var pos := Vector3(0.0, h * 0.5, 0.0)
		if side == "n":
			pos += Vector3(0.0, 0.0, -d * 0.5)
		elif side == "s":
			pos += Vector3(0.0, 0.0, d * 0.5)
		elif side == "w":
			pos += Vector3(-w * 0.5, 0.0, 0.0)
		else:
			pos += Vector3(w * 0.5, 0.0, 0.0)
		pos += c
		if side == door:
			var seg := (span - gap) * 0.5
			var off := (gap + seg) * 0.5
			for sgn in [-1.0, 1.0]:
				if horiz:
					box(nav, Vector3(seg, h, th), pos + Vector3(sgn * off, 0.0, 0.0), m)
				else:
					box(nav, Vector3(th, h, seg), pos + Vector3(0.0, 0.0, sgn * off), m)
			if horiz:
				box(world, Vector3(gap, h - 3.0, th), pos + Vector3(0.0, 1.5, 0.0), m, 0.0, false)
			else:
				box(world, Vector3(th, h - 3.0, gap), pos + Vector3(0.0, 1.5, 0.0), m, 0.0, false)
		elif horiz:
			box(nav, Vector3(span, h, th), pos, m)
		else:
			box(nav, Vector3(th, h, span), pos, m)
	box(world, Vector3(w + 0.8, 0.4, d + 0.8), c + Vector3(0.0, h + 0.2, 0.0), mats["wood"], 0.0, false)

func build_funhouse() -> void:
	var c := Vector3(40.0, 0.0, 30.0)
	building(c, 20.0, 16.0, 8.0, "w", mats["paint"])
	box(nav, Vector3(0.5, 5.0, 12.0), Vector3(35.0, 2.5, 28.0), mats["paint"])
	box(nav, Vector3(0.5, 5.0, 12.0), Vector3(40.0, 2.5, 32.0), mats["paint"])
	box(nav, Vector3(0.5, 5.0, 12.0), Vector3(45.0, 2.5, 28.0), mats["paint"])
	var qm := QuadMesh.new()
	qm.size = Vector2(4.6, 4.6)
	var q := MeshInstance3D.new()
	q.mesh = qm
	q.material_override = mats["poster"]
	q.position = Vector3(29.7, 5.45, 30.0)
	q.rotation.y = -PI * 0.5
	world.add_child(q)
	lbl("FUNHOUSE", Vector3(29.6, 3.4, 30.0), -PI * 0.5, 80, Color(0.9, 0.7, 0.1))
	omni(world, Vector3(36.0, 3.5, 30.0), Color(0.6, 0.2, 1.0), 2.0, 11.0)
	omni(world, Vector3(46.0, 3.0, 27.0), Color(1.0, 0.1, 0.1), 2.0, 9.0, true)

func build_small_huts() -> void:
	building(Vector3(-40.0, 0.0, 36.0), 8.0, 7.0, 3.6, "e", mats["paint"])
	box(nav, Vector3(1.2, 0.9, 1.2), Vector3(-42.5, 0.45, 36.0), mats["wood"])
	lbl("FORTUNE", Vector3(-35.7, 3.0, 36.0), PI * 0.5, 70, Color(0.4, 0.6, 1.0))
	omni(world, Vector3(-41.0, 2.5, 36.0), Color(0.3, 0.5, 1.0), 1.6, 8.0, true)
	building(Vector3(38.0, 0.0, -2.0), 6.0, 6.0, 3.4, "w", mats["wood"])
	pillar(nav, 0.5, 0.9, Vector3(39.5, 0.45, -2.0), mats["metal"])
	omni(world, Vector3(38.5, 2.5, -2.0), Color(1.0, 0.3, 0.2), 1.2, 8.0, true)

func stall(p: Vector3, yaw: float, tint: Color) -> void:
	var s := Node3D.new()
	s.position = p
	s.rotation.y = yaw
	nav.add_child(s)
	var m := mk(tint, 0.9, "planks", true, 0.25)
	box(s, Vector3(4.6, 3.0, 0.2), Vector3(0.0, 1.5, -1.0), m)
	box(s, Vector3(0.2, 3.0, 2.2), Vector3(-2.2, 1.5, 0.0), m)
	box(s, Vector3(0.2, 3.0, 2.2), Vector3(2.2, 1.5, 0.0), m)
	box(s, Vector3(4.6, 1.0, 0.6), Vector3(0.0, 0.5, 1.0), m)
	box(s, Vector3(5.2, 0.15, 3.2), Vector3(0.0, 3.1, 0.2), mats["tent"], 0.0, false)

func lamp(p: Vector3, faulty: bool) -> void:
	pillar(nav, 0.12, 4.8, p + Vector3(0.0, 2.4, 0.0), mats["metal"])
	var bm := mk(Color(1.0, 0.85, 0.5), 0.4, "", false, 0.25, Color(1.0, 0.75, 0.35), 1.5)
	ball(world, 0.28, p + Vector3(0.0, 4.9, 0.0), bm)
	var l := omni(world, p + Vector3(0.0, 4.7, 0.0), Color(1.0, 0.72, 0.42), 1.7, 15.0)
	l.omni_attenuation = 1.4
	lamps.append({"light": l, "mat": bm, "base": 1.7, "faulty": faulty, "ph": randf() * 10.0})

func build_jack(p: Vector3) -> void:
	var n := Node3D.new()
	n.position = p
	n.rotation.y = randf() * TAU
	world.add_child(n)
	var cm := mk(Color(0.7, 0.1, 0.12), 0.6)
	var ym := mk(Color(0.85, 0.7, 0.15), 0.6)
	box(n, Vector3(0.8, 0.7, 0.8), Vector3(0.0, 0.35, 0.0), cm, 0.0, false)
	box(nav, Vector3(0.8, 0.7, 0.8), p + Vector3(0.0, 0.35, 0.0), cm).visible = false
	var lid := Node3D.new()
	lid.position = Vector3(0.0, 0.7, -0.4)
	n.add_child(lid)
	box(lid, Vector3(0.84, 0.08, 0.84), Vector3(0.0, 0.04, 0.4), ym, 0.0, false)
	var head := Node3D.new()
	head.position = Vector3(0.0, 0.1, 0.0)
	n.add_child(head)
	pillar(head, 0.04, 0.6, Vector3(0.0, -0.3, 0.0), mats["metal"], false)
	ball(head, 0.26, Vector3(0.0, 0.2, 0.0), mats["white"])
	ball(head, 0.06, Vector3(0.0, 0.18, 0.24), mats["red"])
	ball(head, 0.14, Vector3(-0.24, 0.26, 0.0), mats["red"])
	ball(head, 0.14, Vector3(0.24, 0.26, 0.0), mats["red"])
	ball(head, 0.035, Vector3(-0.09, 0.28, 0.23), mats["gold"])
	ball(head, 0.035, Vector3(0.09, 0.28, 0.23), mats["gold"])
	jacks.append({"pos": p, "lid": lid, "head": head, "st": 0, "snd": null})

func build_signs() -> void:
	box(nav, Vector3(0.6, 6.0, 0.6), Vector3(-6.5, 3.0, 40.0), mats["wood"])
	box(nav, Vector3(0.6, 6.0, 0.6), Vector3(6.5, 3.0, 40.0), mats["wood"])
	box(world, Vector3(14.0, 2.2, 0.4), Vector3(0.0, 6.2, 40.0), mats["wood"], 0.0, false)
	lbl("THE LAST SHOW", Vector3(0.0, 6.5, 40.3), 0.0, 130, Color(0.85, 0.08, 0.08))
	lbl("NO LAUGHING", Vector3(0.0, 5.5, 40.3), 0.0, 70, Color(0.8, 0.75, 0.6))

func build_hearts() -> void:
	var hm := mk(Color(0.5, 0.02, 0.04), 0.25, "", false, 0.25, Color(1.0, 0.04, 0.06), 1.4)
	for i in HEART_AT.size():
		var hp: Vector3 = HEART_AT[i]
		var n := Node3D.new()
		n.position = hp
		world.add_child(n)
		var body := Node3D.new()
		n.add_child(body)
		ball(body, 0.2, Vector3(-0.12, 0.08, 0.0), hm)
		ball(body, 0.2, Vector3(0.12, 0.08, 0.0), hm)
		var cone := CylinderMesh.new()
		cone.top_radius = 0.3
		cone.bottom_radius = 0.0
		cone.height = 0.5
		cone.radial_segments = 12
		var ci := MeshInstance3D.new()
		ci.mesh = cone
		ci.material_override = hm
		ci.position = Vector3(0.0, -0.16, 0.0)
		body.add_child(ci)
		var ao := pillar(body, 0.05, 0.28, Vector3(0.05, 0.34, 0.0), hm, false)
		ao.rotation.z = 0.3
		var l := omni(n, Vector3(0.0, 0.1, 0.0), Color(1.0, 0.05, 0.08), 2.5, 7.0)
		var s := Sfx.loop3d("heart", n, 4.0, 4.0)
		s.max_distance = 45.0
		hearts.append({"node": n, "body": body, "pos": hp, "alive": true, "light": l, "snd": s})

func build_knife() -> void:
	box(nav, Vector3(1.1, 1.0, 1.1), Vector3(KNIFE_AT.x, 0.5, KNIFE_AT.z), mats["wood"])
	knife_node = Node3D.new()
	knife_node.position = KNIFE_AT
	knife_node.rotation.y = 0.6
	world.add_child(knife_node)
	box(knife_node, Vector3(0.05, 0.012, 0.36), Vector3(0.0, 0.0, -0.1), mats["steel"], 0.0, false)
	box(knife_node, Vector3(0.05, 0.04, 0.16), Vector3(0.0, 0.0, 0.18), mats["dark"], 0.0, false)
	omni(knife_node, Vector3(0.0, 0.7, 0.0), Color(0.9, 0.95, 1.0), 1.4, 6.0)
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color(0.85, 0.9, 1.0, 0.16)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var beacon := pillar(knife_node, 0.07, 7.0, Vector3(0.0, 3.5, 0.0), bm, false)
	beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# ---------------------------------------------------------------- frame loop
var last_alert := -10.0
var amb: AudioStreamPlayer
var laughed := false

func _process(delta: float) -> void:
	t += delta
	if state == "loading":
		return
	wheel.rotation.z += delta * 0.08
	for cb in wheel_cabs:
		cb.rotation.z = -wheel.rotation.z
	carousel.rotation.y += delta * 0.12
	lamps_update(delta)
	for h in hearts:
		if h.alive:
			var sp: AudioStreamPlayer3D = h.snd
			var ph := fmod(sp.get_playback_position(), 0.9)
			var k := exp(-ph * 12.0) * 0.28
			if ph > 0.27:
				k += exp(-(ph - 0.27) * 14.0) * 0.18
			h.body.scale = Vector3.ONE * (1.0 + k)
			h.light.light_energy = 2.2 + k * 6.0
			var hp: Vector3 = h.pos
			h.node.position = Vector3(hp.x, hp.y + sin(t * 1.5) * 0.05, hp.z)
	if black_hold:
		flash_a = 1.0
		flash_c = Color.BLACK
	else:
		flash_a = maxf(0.0, flash_a - delta * 2.2)
	glitch = maxf(0.0, glitch - delta * 2.5)
	post.set_shader_parameter("fear", fear)
	post.set_shader_parameter("flash", flash_a)
	post.set_shader_parameter("flash_col", Vector3(flash_c.r, flash_c.g, flash_c.b))
	post.set_shader_parameter("glitch", glitch)
	post.set_shader_parameter("tm", fmod(t, 100.0))
	msg_t -= delta
	kill_t -= delta
	bars = move_toward(bars, 1.0 if busy else 0.0, delta * 1.6)
	if state == "menu":
		player.yaw += delta * 0.07
		player.pitch = 0.05
		return
	if state == "end":
		end_t += delta
		if end_t > 5.0 and not laughed:
			laughed = true
			Sfx.play("laugh", 0.0, 0.6)
		return
	if state != "play":
		return
	update_fear(delta)
	update_prompt()
	update_jacks()
	director(delta)
	amb_t -= delta
	if amb_t < 0.0:
		amb_t = randf_range(9.0, 20.0)
		var a := randf() * TAU
		var p: Vector3 = player.global_position + Vector3(sin(a), 0.0, cos(a)) * randf_range(18.0, 34.0)
		if randf() < 0.5:
			Sfx.play3d("laugh", p, -8.0, randf_range(0.6, 1.4))
		else:
			Sfx.play3d("pop", p, -4.0, randf_range(0.6, 1.0))
	if respawn_t > 0.0:
		respawn_t -= delta
		if respawn_t <= 0.0 and not final_stage and has_knife:
			var far: Vector3 = PATROL[0]
			for q in PATROL:
				if q.distance_to(player.global_position) > far.distance_to(player.global_position):
					far = q
			clown.activate(far, "patrol")
	lock_msg_t -= delta
	if not has_key and lock_msg_t <= 0.0 and Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(0.0, GATE_Z)) < 7.0:
		lock_msg_t = 12.0
		say("The gate is chained shut.", 3.0)
	if gate_open and player.global_position.z < GATE_Z - 3.0:
		ending()

func lamps_update(delta: float) -> void:
	for l in lamps:
		var e: float = l.base
		if not lamps_on:
			e = 0.0
		elif l.faulty:
			l.ph += delta * (6.0 + randf() * 10.0)
			if sin(l.ph * 3.1) + sin(l.ph * 7.3) < -0.7:
				e *= 0.15
			else:
				e *= 0.9 + randf() * 0.1
		l.light.light_energy = e
		if l.mat != null:
			l.mat.emission_energy_multiplier = e * 0.9

func update_fear(delta: float) -> void:
	var target_f := 0.0
	if clown.state in ["chase", "search", "patrol", "stun"]:
		var d: float = clown.global_position.distance_to(player.global_position)
		target_f = clampf(1.0 - d / 24.0, 0.0, 1.0)
		if clown.state == "chase":
			target_f = maxf(target_f, 0.35)
	fear = lerpf(fear, target_f, minf(1.0, delta * 2.0))
	player.fear = fear
	hb.volume_db = linear_to_db(maxf(fear, 0.0005)) + 4.0
	hb.pitch_scale = 0.85 + fear * 0.8

func say(text: String, secs: float = 3.5) -> void:
	msg = text
	msg_t = secs + 1.0

func consider(p: Vector3, r: float, dotmin: float, label: String, tg) -> void:
	if prompt != "":
		return
	var d: Vector3 = p - player.cam.global_position
	if d.length() < r and d.normalized().dot(-player.cam.global_transform.basis.z) > dotmin:
		prompt = label
		target = tg

func update_prompt() -> void:
	prompt = ""
	target = null
	if busy:
		return
	if not has_knife:
		consider(knife_node.global_position + Vector3(0.0, 0.1, 0.0), 3.4, 0.4, "TAKE", "knife")
	else:
		for h in hearts:
			if h.alive:
				consider(h.pos, 3.5, 0.55, "STAB", h)
	if final_stage and not has_key and clown.state == "cry":
		consider(clown.global_position + Vector3(0.0, 1.0, 0.0), 3.6, 0.45, "KILL", "clown")
	if has_key and not gate_open:
		consider(Vector3(0.0, 1.5, GATE_Z + 0.5), 5.5, 0.2, "OPEN", "gate")

func interact() -> void:
	if state != "play" or busy or prompt == "":
		return
	var tg = target
	if tg is String:
		if tg == "knife":
			take_knife()
		elif tg == "clown":
			execute_clown()
		elif tg == "gate":
			open_gate()
	elif tg is Dictionary:
		kill_heart(tg)

func update_jacks() -> void:
	for j in jacks:
		var d: float = player.global_position.distance_to(j.pos)
		if j.st == 0 and d < 9.0:
			j.st = 1
			j.snd = Sfx.loop3d("musicbox", j.head, -6.0, 5.0)
		elif j.st == 1 and d < 2.4:
			j.st = 2
			if j.snd != null:
				j.snd.stop()
			Sfx.play("spring", 2.0)
			Sfx.play("sting", 1.0)
			jolt(0.8)
			var lt := create_tween()
			lt.tween_property(j.lid, "rotation_degrees:x", -110.0, 0.08)
			var ht := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			ht.tween_property(j.head, "position:y", 1.1, 0.14)

# ---------------------------------------------------------------- helpers
func wait(sec: float) -> void:
	await get_tree().create_timer(sec, false).timeout

func jolt(k: float, c: Color = Color(1.0, 0.05, 0.05)) -> void:
	flash_a = clampf(0.65 * k, 0.0, 1.0)
	flash_c = c
	glitch = clampf(0.8 * k, 0.0, 1.0)
	player.jolt(k)
	Sfx.buzz(int(120.0 * k))

func player_fwd() -> Vector3:
	var f: Vector3 = -player.global_transform.basis.z
	f.y = 0.0
	return f.normalized()

func find_spot(center: Vector3, dist: float, dir: Vector3, cone: float) -> Vector3:
	var space := get_world_3d().direct_space_state
	for k in 14:
		var a := atan2(dir.x, dir.z) + randf_range(-cone, cone)
		var p := center + Vector3(sin(a), 0.0, cos(a)) * dist
		if absf(p.x) > 58.0 or absf(p.z) > 58.0:
			continue
		var q := PhysicsRayQueryParameters3D.create(center + Vector3(0.0, 1.4, 0.0), p + Vector3(0.0, 1.4, 0.0), 1)
		q.exclude = [player.get_rid()]
		if space.intersect_ray(q).is_empty():
			return p
	return center + dir * 3.0

func ghost_at(p: Vector3):
	var gh = (load("res://clown.gd") as GDScript).new()
	gh.ghost = true
	world.add_child(gh)
	gh.global_position = p
	return gh

func flicker_lamps(sec: float) -> void:
	var left := sec
	while left > 0.0:
		lamps_on = randf() > 0.45
		var dt := randf_range(0.05, 0.2)
		await wait(dt)
		left -= dt
	lamps_on = true

func blackout(sec: float) -> void:
	lamps_on = false
	player.flash_on = false
	player.flash.visible = false
	create_tween().tween_property(env, "ambient_light_energy", 0.12, 0.4)
	await wait(sec)
	lamps_on = true
	player.flash_on = true
	player.flash.visible = true
	Sfx.play("click", -2.0)
	create_tween().tween_property(env, "ambient_light_energy", 0.5, 0.3)

func particles(pos: Vector3, col: Color, amount: int, vmin: float, vmax: float, grav: Vector3, size: float, life: float) -> void:
	var p := CPUParticles3D.new()
	var sm := SphereMesh.new()
	sm.radius = size
	sm.height = size * 2.0
	sm.radial_segments = 6
	sm.rings = 3
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.vertex_color_use_as_albedo = true
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.material = pm
	p.mesh = sm
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.gravity = grav
	var gr := Gradient.new()
	gr.colors = PackedColorArray([col, Color(col.r, col.g, col.b, 0.0)])
	gr.offsets = PackedFloat32Array([0.0, 1.0])
	p.color_ramp = gr
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(life + 0.6).timeout.connect(p.queue_free)

func ring(pos: Vector3, col: Color, size: float, dur: float) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.0
	tm.rings = 32
	tm.ring_segments = 6
	mi.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * 0.2
	var tw := create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * size, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, dur)
	tw.chain().tween_callback(mi.queue_free)

func impact(pos: Vector3, k: float) -> void:
	Sfx.play("stab", 4.0, randf_range(0.9, 1.05))
	jolt(0.9 * k, Color(1.0, 0.1, 0.1))
	particles(pos, Color(0.65, 0.0, 0.02), int(40.0 * k), 2.0, 6.0 * k, Vector3(0.0, -9.0, 0.0), 0.05, 0.9)
	ring(pos, Color(1.0, 0.2, 0.1, 0.9), 3.0 * k, 0.6)

func cine_shake(k: float) -> void:
	if cine == null:
		return
	var tw := create_tween()
	for i in 6:
		tw.tween_property(cine, "h_offset", randf_range(-1.0, 1.0) * 0.3 * k * (1.0 - i / 6.0), 0.04)
	tw.tween_property(cine, "h_offset", 0.0, 0.05)

# ---------------------------------------------------------------- story beats
func take_knife() -> void:
	has_knife = true
	player.has_knife = true
	player.vm.visible = true
	knife_node.visible = false
	Sfx.play("shing", 2.0)
	Sfx.buzz(40)
	objective = "Destroy the clown's 5 hearts. Listen for the heartbeats."
	say("He keeps his hearts hidden around the carnival...", 5.0)
	knife_scare()

func knife_scare() -> void:
	busy_scare = true
	await wait(3.0)
	if state != "play":
		busy_scare = false
		return
	Sfx.play("riser", -2.0)
	blackout(3.4)
	Sfx.play3d("laugh", player.global_position - player_fwd() * 7.0, -4.0, 0.6)
	await wait(3.5)
	if state != "play" or busy:
		busy_scare = false
		return
	var pos := find_spot(player.global_position, 7.0, player_fwd(), 0.35)
	clown.activate(pos, "chase")
	clown.face_dir(player.global_position - pos)
	Sfx.play("sting", 4.0)
	jolt(1.2)
	busy_scare = false

func clown_alert() -> void:
	if t - last_alert < 6.0:
		return
	last_alert = t
	Sfx.play3d("laugh", clown.global_position, 3.0, randf_range(0.7, 0.9))
	jolt(0.4)

func player_caught() -> void:
	if state != "play" or busy or final_stage:
		return
	state = "dead"
	busy = true
	clown.state = "caught"
	player.locked = true
	var fwd := player_fwd()
	clown.global_position = player.global_position + fwd * 1.1
	clown.face_dir(-fwd)
	clown.eye_on(3.0)
	player.look_at_point(clown.global_position + Vector3(0.0, 2.0, 0.0), 0.1)
	player.fov_override = 100.0
	Sfx.play("sting", 8.0)
	Sfx.play("scream", 6.0)
	jolt(1.6)
	Sfx.buzz(400)
	await wait(1.7)
	black_hold = true
	await wait(0.4)
	state = "dead_wait"

func respawn() -> void:
	black_hold = false
	flash_a = 1.0
	flash_c = Color.BLACK
	player.global_position = SPAWN
	player.velocity = Vector3.ZERO
	player.yaw = 0.0
	player.pitch = 0.0
	player.fov_override = -1.0
	player.locked = false
	player.stamina = 1.0
	player.flash_on = true
	player.flash.visible = true
	clown.eye_on(0.25)
	clown.deactivate()
	lamps_on = true
	busy = false
	busy_scare = false
	state = "play"
	respawn_t = 7.0
	scare_t = 15.0
	say("Run. Find the hearts.", 3.0)

func kill_heart(h: Dictionary) -> void:
	busy = true
	h.alive = false
	player.locked = true
	player.vm_busy = true
	clown.hold(true)
	var pos: Vector3 = h.pos
	var dirv: Vector3 = pos - player.global_position
	dirv.y = 0.0
	dirv = dirv.normalized()
	var stand := Vector3(pos.x, player.global_position.y, pos.z) - dirv * 1.5
	player.look_at_point(pos, 0.5)
	create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).tween_property(player, "global_position", stand, 0.5)
	await wait(0.55)
	var vm: Node3D = player.vm
	var w := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	w.tween_property(vm, "position", Vector3(0.1, 0.05, -0.4), 0.45)
	w.tween_property(vm, "rotation_degrees", Vector3(70.0, 0.0, 0.0), 0.45)
	Sfx.play("riser", -6.0)
	await wait(0.7)
	var s1 := create_tween().set_parallel(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	s1.tween_property(vm, "position", Vector3(0.0, -0.12, -1.0), 0.16)
	s1.tween_property(vm, "rotation_degrees", Vector3(-35.0, 0.0, 0.0), 0.16)
	await wait(0.17)
	impact(pos, 1.0)
	await wait(0.4)
	var s2a := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	s2a.tween_property(vm, "position", Vector3(0.1, 0.0, -0.45), 0.25)
	s2a.tween_property(vm, "rotation_degrees", Vector3(65.0, 0.0, 20.0), 0.25)
	await wait(0.3)
	var s2 := create_tween().set_parallel(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	s2.tween_property(vm, "position", Vector3(0.0, -0.14, -1.05), 0.14)
	s2.tween_property(vm, "rotation_degrees", Vector3(-40.0, 0.0, -25.0), 0.14)
	await wait(0.15)
	impact(pos, 1.8)
	Sfx.play("boom", 3.0)
	Sfx.play("scream", -2.0, 0.7)
	h.snd.stop()
	h.light.light_energy = 9.0
	particles(pos, Color(1.6, 0.6, 0.15), 40, 3.0, 9.0, Vector3(0.0, 2.5, 0.0), 0.05, 1.4)
	particles(pos, Color(0.7, 0.0, 0.02), 50, 2.0, 7.0, Vector3(0.0, -9.0, 0.0), 0.06, 1.0)
	for i in 3:
		ring(pos, Color(1.0, 0.25, 0.1, 0.9), 7.0 + i * 3.0, 0.9)
		await wait(0.16)
	var shrink := create_tween().set_parallel(true)
	shrink.tween_property(h.node, "scale", Vector3(0.01, 0.01, 0.01), 0.5)
	shrink.tween_property(h.light, "light_energy", 0.0, 0.9)
	await wait(0.9)
	h.node.queue_free()
	var back := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	back.tween_property(vm, "position", player.vm_base, 0.5)
	back.tween_property(vm, "rotation_degrees", Vector3(6.0, -14.0, 0.0), 0.5)
	await wait(0.6)
	destroyed += 1
	player.locked = false
	player.vm_busy = false
	busy = false
	clown.hold(false)
	if destroyed >= 5:
		final_sequence()
	else:
		objective = "Hearts destroyed: %d / 5" % destroyed
		clown_rage()

func clown_rage() -> void:
	busy_scare = true
	Sfx.play("scream", 0.0, 0.8)
	flicker_lamps(2.0)
	await wait(1.7)
	if state != "play" or busy:
		busy_scare = false
		return
	var pos := find_spot(player.global_position, 12.0, player_fwd(), 0.7)
	clown.bonus = destroyed * 0.35
	clown.activate(pos, "chase")
	clown.stun(1.0)
	Sfx.play("sting", 2.0)
	jolt(0.9)
	busy_scare = false

func final_sequence() -> void:
	busy_scare = true
	Sfx.play("scream", 4.0, 0.7)
	jolt(1.0)
	flicker_lamps(3.0)
	await wait(1.6)
	clown.deactivate()
	var best: Vector3 = KNEEL_AT[0]
	for p in KNEEL_AT:
		if p.distance_to(player.global_position) > best.distance_to(player.global_position):
			best = p
	await wait(1.4)
	clown.activate(best, "cry")
	final_stage = true
	kill_t = 5.0
	Sfx.play("boom", -4.0)
	glitch = 0.6
	objective = "Follow the crying. Find the clown."
	busy_scare = false

func shot(pos: Vector3, tgt: Vector3, fov: float) -> void:
	cine.global_position = pos
	cine.look_at(tgt, Vector3.UP)
	cine.fov = fov

func _orbit(v: float, center: Vector3, radius: float, a0: float) -> void:
	if cine == null:
		return
	var a := a0 + v * 1.4
	cine.global_position = center + Vector3(sin(a) * radius, 1.4 + v * 0.7, cos(a) * radius)
	cine.look_at(center + Vector3(0.0, 1.2, 0.0), Vector3.UP)

func make_cine_knife() -> Node3D:
	var k := Node3D.new()
	add_child(k)
	box(k, Vector3(0.05, 0.012, 0.36), Vector3(0.0, 0.0, -0.1), mats["steel"], 0.0, false)
	box(k, Vector3(0.05, 0.04, 0.16), Vector3(0.0, 0.0, 0.18), mats["dark"], 0.0, false)
	omni(k, Vector3(0.0, 0.2, 0.0), Color(1.0, 0.95, 0.85), 1.5, 4.0)
	k.scale = Vector3.ONE * 2.2
	k.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	return k

func make_key() -> Node3D:
	var k := Node3D.new()
	add_child(k)
	var tm := TorusMesh.new()
	tm.inner_radius = 0.05
	tm.outer_radius = 0.11
	var ri := MeshInstance3D.new()
	ri.mesh = tm
	ri.material_override = mats["gold"]
	ri.position = Vector3(0.0, 0.22, 0.0)
	ri.rotation_degrees.x = 90.0
	k.add_child(ri)
	pillar(k, 0.025, 0.4, Vector3.ZERO, mats["gold"], false)
	box(k, Vector3(0.1, 0.05, 0.03), Vector3(0.06, -0.15, 0.0), mats["gold"], 0.0, false)
	box(k, Vector3(0.07, 0.05, 0.03), Vector3(0.045, -0.07, 0.0), mats["gold"], 0.0, false)
	omni(k, Vector3.ZERO, Color(1.0, 0.8, 0.2), 2.5, 5.0)
	k.scale = Vector3.ONE * 1.6
	return k

func execute_clown() -> void:
	busy = true
	player.locked = true
	player.vm.visible = false
	kill_t = 0.0
	objective = ""
	var K: Vector3 = clown.global_position
	var f: Vector3 = player.global_position - K
	f.y = 0.0
	f = f.normalized()
	var r := f.cross(Vector3.UP)
	clown.face_dir(f)
	cine = Camera3D.new()
	add_child(cine)
	cine.make_current()
	shot(K + r * 2.2 + Vector3(0.0, 1.1, 0.0) + f * 4.4, K + Vector3(0.0, 0.8, 0.0), 55.0)
	var d1 := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	d1.tween_property(cine, "global_position", K + r * 1.4 + Vector3(0.0, 1.0, 0.0) + f * 3.1, 2.5)
	await wait(2.4)
	shot(K + r * 0.3 + Vector3(0.0, 1.35, 0.0) + f * 1.6, K + Vector3(0.0, 1.4, 0.0) + f * 0.2, 36.0)
	clown.silence_cry()
	clown.lift_head()
	clown.eye_on(3.0)
	Sfx.play("riser", 0.0)
	var d2 := create_tween().set_trans(Tween.TRANS_SINE)
	d2.tween_property(cine, "global_position", K + r * 0.1 + Vector3(0.0, 1.38, 0.0) + f * 1.0, 2.2)
	await wait(2.3)
	var ck := make_cine_knife()
	shot(K - r * 0.4 + Vector3(0.0, 0.7, 0.0) + f * 2.4, K + Vector3(0.0, 2.0, 0.0), 45.0)
	ck.global_position = K + r * 0.5 + Vector3(0.0, 0.9, 0.0) + f * 1.0
	var d3 := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	d3.tween_property(ck, "global_position", K + r * 0.1 + Vector3(0.0, 3.0, 0.0) + f * 0.3, 1.2)
	await wait(1.5)
	shot(K + r * 1.8 + Vector3(0.0, 0.9, 0.0) + f * 1.0, K + Vector3(0.0, 1.2, 0.0), 48.0)
	var chest := K + Vector3(0.0, 1.15, 0.0) + f * 0.25
	ck.global_position = chest + Vector3(0.0, 1.9, 0.0)
	var d4 := create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	d4.tween_property(ck, "global_position", chest + Vector3(0.0, 0.55, 0.0), 0.16)
	await wait(0.17)
	Sfx.play("stab", 6.0, 0.8)
	Sfx.play("boom", 5.0)
	Sfx.play("scream", 2.0, 0.75)
	jolt(1.6, Color(1.0, 1.0, 1.0))
	cine_shake(1.6)
	particles(chest, Color(0.7, 0.0, 0.02), 80, 2.0, 8.0, Vector3(0.0, -9.0, 0.0), 0.06, 1.1)
	ring(chest, Color(1.0, 0.9, 0.7, 0.9), 8.0, 0.8)
	await wait(0.5)
	var orb := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	orb.tween_method(_orbit.bind(K, 3.6, 0.6), 0.0, 1.0, 3.4)
	for i in 3:
		ring(chest, Color(1.0, 0.35, 0.1, 0.9), 7.0 + i * 3.0, 1.1)
		particles(chest, Color(1.6, 0.7, 0.2), 30, 3.0, 8.0, Vector3(0.0, 3.0, 0.0), 0.05, 1.6)
		await wait(0.22)
	clown.dissolve()
	particles(chest, Color(0.25, 0.25, 0.28), 60, 1.0, 5.0, Vector3(0.0, 2.0, 0.0), 0.08, 2.0)
	ck.queue_free()
	await wait(1.0)
	var key := make_key()
	key.global_position = chest
	var kt := create_tween().set_parallel(true)
	kt.tween_property(key, "global_position", chest + Vector3(0.0, 0.9, 0.0), 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	kt.tween_property(key, "rotation:y", TAU * 2.0, 1.4)
	Sfx.play("keys", 0.0)
	await wait(1.8)
	create_tween().tween_property(key, "global_position", cine.global_position, 0.5).set_ease(Tween.EASE_IN)
	await wait(0.5)
	key.queue_free()
	cine.queue_free()
	cine = null
	player.cam.make_current()
	player.vm.visible = true
	clown.deactivate()
	has_key = true
	objective = "Escape through the main gate"
	say("GATE KEY OBTAINED", 4.0)
	flicker_lamps(1.5)
	player.locked = false
	busy = false

func open_gate() -> void:
	gate_open = true
	Sfx.play("keys", 0.0)
	await wait(0.9)
	Sfx.play("gate", 3.0)
	gate_lock.visible = false
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	tw.tween_property(gate_l, "rotation_degrees:y", 100.0, 3.8)
	tw.tween_property(gate_r, "rotation_degrees:y", -100.0, 3.8)
	gate_light.light_color = Color(0.2, 1.0, 0.3)
	objective = "RUN! Get out!"
	jolt(0.5)
	Sfx.play3d("laugh", Vector3(0.0, 1.5, GATE_Z + 30.0), 0.0, 0.7)

func ending() -> void:
	if state != "play":
		return
	state = "end"
	end_t = 0.0
	player.locked = true
	flash_c = Color.WHITE
	flash_a = 1.0

# ---------------------------------------------------------------- scares
func director(delta: float) -> void:
	if busy or busy_scare:
		return
	scare_t -= delta
	if scare_t > 0.0:
		return
	if clown.state == "chase":
		scare_t = 8.0
		return
	scare_t = randf_range(18.0, 34.0)
	match randi() % 6:
		0:
			scare_front()
		1:
			scare_behind()
		2:
			scare_apparition()
		3:
			scare_dash()
		4:
			scare_flicker()
		_:
			scare_apparition()

func scare_front() -> void:
	busy_scare = true
	Sfx.play3d("laugh", player.global_position - player_fwd() * 5.0, -6.0, 0.7)
	await wait(1.1)
	if state != "play" or busy:
		busy_scare = false
		return
	var fwd := player_fwd()
	var gh = ghost_at(find_spot(player.global_position, 8.0, fwd, 0.15))
	gh.face_dir(player.global_position - gh.global_position)
	gh.run_anim = true
	Sfx.play("sting", 3.0)
	jolt(1.0)
	create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN).tween_property(gh, "global_position", player.global_position + fwd * 1.3, 0.22)
	await wait(0.5)
	gh.queue_free()
	busy_scare = false

func scare_behind() -> void:
	busy_scare = true
	Sfx.play3d("laugh", player.global_position - player_fwd() * 6.0, 0.0, 0.8)
	await wait(1.0)
	if state != "play" or busy:
		busy_scare = false
		return
	var back := -player_fwd()
	var gh = ghost_at(player.global_position + back * 2.0)
	gh.face_dir(-back)
	Sfx.play("sting", 3.0)
	jolt(1.1)
	Sfx.play3d("laugh", gh.global_position, 3.0, 1.2)
	await wait(0.7)
	gh.queue_free()
	busy_scare = false

func scare_apparition() -> void:
	busy_scare = true
	var p := find_spot(player.global_position, randf_range(17.0, 23.0), player_fwd(), 0.6)
	if p.distance_to(player.global_position) < 10.0:
		busy_scare = false
		return
	var gh = ghost_at(p)
	var seen := 0.0
	var life := 0.0
	while is_instance_valid(gh) and state == "play" and not busy:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		life += dt
		gh.face_dir(player.global_position - gh.global_position)
		var to: Vector3 = (gh.global_position - player.cam.global_position).normalized()
		if to.dot(-player.cam.global_transform.basis.z) > 0.92:
			seen += dt
		if seen > 1.3 or life > 16.0 or gh.global_position.distance_to(player.global_position) < 10.0:
			break
	if is_instance_valid(gh):
		Sfx.play3d("laugh", gh.global_position, 0.0, 1.1)
		flicker_lamps(0.8)
		gh.queue_free()
	busy_scare = false

func scare_dash() -> void:
	busy_scare = true
	var fwd := player_fwd()
	var side := fwd.cross(Vector3.UP)
	var c: Vector3 = player.global_position + fwd * 13.0
	var a := c - side * 15.0
	var b := c + side * 15.0
	var gh = ghost_at(a)
	gh.run_anim = true
	gh.face_dir(b - a)
	Sfx.play3d("laugh", a, 0.0, 1.0)
	create_tween().tween_property(gh, "global_position", b, 1.5)
	await wait(1.55)
	gh.queue_free()
	busy_scare = false

func scare_flicker() -> void:
	busy_scare = true
	Sfx.play3d("laugh", player.global_position + player_fwd() * 10.0, -4.0, 0.6)
	await flicker_lamps(2.2)
	busy_scare = false

# ---------------------------------------------------------------- flow
func start_game() -> void:
	state = "play"
	player.locked = false
	player.yaw = 0.0
	player.pitch = 0.0
	player.global_position = SPAWN
	flash_c = Color.BLACK
	flash_a = 1.0
	Sfx.play("boom", -8.0)
	say("The Last Show is open tonight...", 4.5)
	scare_t = 24.0

func set_pause(on: bool) -> void:
	paused = on
	get_tree().paused = on

func tap() -> void:
	if paused:
		set_pause(false)
		return
	if state == "menu":
		start_game()
	elif state == "dead_wait":
		respawn()
	elif state == "end" and end_t > 8.0:
		amb.queue_free()
		hb.queue_free()
		get_tree().paused = false
		get_tree().reload_current_scene()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if state == "play" and not paused:
			set_pause(true)
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if state == "menu":
			get_tree().quit()
		elif state == "play":
			set_pause(not paused)
