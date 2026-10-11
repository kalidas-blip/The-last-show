extends CharacterBody3D
# The clown: procedural model, hunting AI (sight + hearing + nav), and cinematic poses.
var g = null
var player = null
var ghost := false
var state := "dormant"
var held_state := ""
var visual: Node3D
var rig := {}
var agent: NavigationAgent3D
var music: AudioStreamPlayer3D
var cry_snd: AudioStreamPlayer3D
var eye: OmniLight3D
var speed := 3.5
var bonus := 0.0
var walk_t := 0.0
var tt := 0.0
var last_known := Vector3.ZERO
var patrol_target := Vector3.ZERO
var lost_t := 0.0
var wait_t := 0.0
var lunge_t := 0.0
var lunge_cd := 6.0
var stun_t := 0.0
var step_t := 0.0
var stuck_t := 0.0
var last_pos := Vector3.ZERO
var nudge_t := 0.0
var nudge_dir := Vector3.ZERO
var run_anim := false

func mat(c: Color, r: float = 0.7, em: Color = Color.BLACK, ee: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = r
	if ee > 0.0:
		m.emission_enabled = true
		m.emission = em
		m.emission_energy_multiplier = ee
	return m

func part(par: Node3D, mesh: Mesh, m: Material, pos: Vector3, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	par.add_child(mi)
	return mi

func sph(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 14
	s.rings = 7
	return s

func cyl(rt: float, rb: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = 10
	c.rings = 1
	return c

func bx(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b

func build() -> void:
	visual = Node3D.new()
	add_child(visual)
	var skin := mat(Color(0.9, 0.88, 0.8), 0.55)
	var red := mat(Color(0.72, 0.04, 0.06), 0.5)
	var suit := mat(Color(0.28, 0.1, 0.34), 0.8)
	var suit2 := mat(Color(0.8, 0.65, 0.12), 0.8)
	var white := mat(Color(0.82, 0.8, 0.74), 0.8)
	var dark := mat(Color(0.02, 0.0, 0.02), 1.0)
	var glow := mat(Color(0.9, 1.0, 0.3), 0.3, Color(0.8, 1.0, 0.2), 3.0)
	var torso := Node3D.new()
	torso.position = Vector3(0.0, 1.1, 0.0)
	visual.add_child(torso)
	rig["torso"] = torso
	part(torso, cyl(0.3, 0.42, 0.95), suit, Vector3(0.0, 0.48, 0.0))
	part(torso, sph(0.45), suit, Vector3(0.0, 0.35, 0.05), Vector3(1.0, 0.9, 0.85))
	for i in 3:
		part(torso, sph(0.06), red, Vector3(0.0, 0.25 + i * 0.22, 0.43 - i * 0.05))
	var ruff := TorusMesh.new()
	ruff.inner_radius = 0.16
	ruff.outer_radius = 0.44
	part(torso, ruff, white, Vector3(0.0, 0.98, 0.0), Vector3(1.0, 0.6, 1.0))
	var head := Node3D.new()
	head.position = Vector3(0.0, 1.0, 0.05)
	torso.add_child(head)
	rig["head"] = head
	part(head, sph(0.3), skin, Vector3.ZERO, Vector3(1.0, 1.18, 1.0))
	part(head, sph(0.2), red, Vector3(-0.36, 0.1, -0.02))
	part(head, sph(0.2), red, Vector3(0.36, 0.1, -0.02))
	part(head, sph(0.16), red, Vector3(0.0, 0.38, -0.05))
	for s in [-1.0, 1.0]:
		part(head, sph(0.085), dark, Vector3(s * 0.12, 0.08, 0.255), Vector3(1.0, 1.4, 0.5))
		part(head, sph(0.03), glow, Vector3(s * 0.12, 0.08, 0.292))
		var brow := part(head, bx(0.16, 0.025, 0.03), dark, Vector3(s * 0.12, 0.2, 0.27))
		brow.rotation.z = s * 0.4
	part(head, sph(0.075), mat(Color(0.8, 0.05, 0.05), 0.4, Color(0.6, 0.0, 0.0), 0.5), Vector3(0.0, -0.02, 0.31))
	for i in range(-3, 4):
		var x := i * 0.05
		var y := -0.2 + 0.008 * i * i
		var zz := 0.3 * sqrt(maxf(0.05, 1.0 - pow(x / 0.3, 2.0) - pow(y / 0.354, 2.0))) + 0.005
		part(head, bx(0.05, 0.09, 0.015), dark, Vector3(x, y - 0.045, zz - 0.004))
		part(head, bx(0.03, 0.045, 0.012), white, Vector3(x, y - 0.02, zz + 0.004))
		part(head, bx(0.056, 0.03, 0.02), red, Vector3(x, y, zz + 0.006))
		part(head, bx(0.056, 0.026, 0.02), red, Vector3(x, y - 0.1, zz + 0.004))
	eye = OmniLight3D.new()
	eye.position = Vector3(0.0, 0.05, 0.45)
	eye.light_color = Color(0.7, 1.0, 0.2)
	eye.omni_range = 4.0
	eye.light_energy = 0.25
	head.add_child(eye)
	for s in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(s * 0.2, 1.1, 0.0)
		visual.add_child(hip)
		part(hip, cyl(0.15, 0.13, 0.55), suit2, Vector3(0.0, -0.275, 0.0))
		var knee := Node3D.new()
		knee.position = Vector3(0.0, -0.55, 0.0)
		hip.add_child(knee)
		part(knee, cyl(0.13, 0.1, 0.55), suit2, Vector3(0.0, -0.275, 0.0))
		part(knee, bx(0.3, 0.17, 0.75), red, Vector3(0.0, -0.58, 0.18))
		rig["hipL" if s < 0.0 else "hipR"] = hip
		rig["kneeL" if s < 0.0 else "kneeR"] = knee
		var sh := Node3D.new()
		sh.position = Vector3(s * 0.52, 0.85, 0.0)
		torso.add_child(sh)
		part(sh, cyl(0.1, 0.08, 1.15), suit, Vector3(0.0, -0.575, 0.0))
		part(sh, sph(0.16), white, Vector3(0.0, -1.2, 0.0))
		for f in [-1.0, 0.0, 1.0]:
			var fg := part(sh, bx(0.03, 0.22, 0.03), white, Vector3(f * 0.06, -1.38, 0.0))
			fg.rotation.z = f * 0.2
		sh.rotation.z = s * 0.1
		rig["shL" if s < 0.0 else "shR"] = sh

func _ready() -> void:
	build()
	if ghost:
		return
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 2.3
	cs.shape = cap
	cs.position.y = 1.15
	add_child(cs)
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 1.2
	agent.target_desired_distance = 1.5
	agent.radius = 0.7
	agent.height = 2.2
	add_child(agent)
	music = Sfx.loop3d("musicbox", self, -2.0, 9.0)
	music.max_distance = 70.0
	music.stop()

func face_dir(d: Vector3) -> void:
	visual.rotation.y = atan2(d.x, d.z)

func eye_on(e: float) -> void:
	eye.light_energy = e

func activate(pos: Vector3, st: String = "chase") -> void:
	global_position = pos
	velocity = Vector3.ZERO
	state = st
	held_state = ""
	lost_t = 0.0
	lunge_cd = randf_range(5.0, 9.0)
	last_known = player.global_position
	face_dir(player.global_position - pos)
	visible = true
	if st == "cry":
		set_cry()
	else:
		music.play()

func deactivate() -> void:
	state = "dormant"
	held_state = ""
	visible = false
	velocity = Vector3.ZERO
	global_position = Vector3(0.0, -100.0, 0.0)
	if music != null:
		music.stop()
	if cry_snd != null:
		cry_snd.queue_free()
		cry_snd = null

func hold(on: bool) -> void:
	if on:
		if state == "dormant" or state == "cry":
			return
		held_state = state
		state = "frozen"
		music.stream_paused = true
	elif held_state != "":
		state = held_state
		held_state = ""
		music.stream_paused = false

func stun(sec: float) -> void:
	state = "stun"
	stun_t = sec
	Sfx.play3d("scream", global_position, 2.0, 0.85)

func set_cry() -> void:
	state = "cry"
	music.stop()
	kneel(true, 0.1)
	cry_snd = Sfx.loop3d("sob", self, 10.0, 12.0)
	cry_snd.max_distance = 150.0

func silence_cry() -> void:
	if cry_snd != null:
		cry_snd.queue_free()
		cry_snd = null

func kneel(on: bool, dur: float = 1.2) -> void:
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_SINE)
	tw.tween_property(visual, "position:y", -0.55 if on else 0.0, dur)
	for k in ["hipL", "hipR"]:
		tw.tween_property(rig[k], "rotation:x", 0.0, dur)
	for k in ["kneeL", "kneeR"]:
		tw.tween_property(rig[k], "rotation:x", 1.5 if on else 0.0, dur)
	tw.tween_property(rig["torso"], "rotation:x", 0.45 if on else 0.0, dur)
	tw.tween_property(rig["head"], "rotation:x", 0.9 if on else 0.0, dur)
	for k in ["shL", "shR"]:
		tw.tween_property(rig[k], "rotation:x", -0.35 if on else 0.0, dur)

func lift_head() -> void:
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	tw.tween_property(rig["head"], "rotation:x", -0.15, 1.3)
	tw.tween_property(rig["torso"], "rotation:x", 0.1, 1.3)

func dissolve() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(visual, "scale", Vector3(0.02, 0.02, 0.02), 1.6).set_ease(Tween.EASE_IN)
	tw.tween_property(visual, "position:y", visual.position.y + 0.6, 1.6)

func pick_patrol() -> void:
	var pts: Array = g.patrol_pts
	var best: Vector3 = pts[randi() % pts.size()]
	if randf() < 0.55:
		for i in 3:
			var c: Vector3 = pts[randi() % pts.size()]
			if c.distance_to(player.global_position) < best.distance_to(player.global_position):
				best = c
	patrol_target = best

func can_see(dist: float) -> bool:
	var rng: float = 30.0 if player.flash_on else 11.0
	if player.sprinting:
		rng += 6.0
	if dist > rng:
		return false
	var to: Vector3 = player.global_position - global_position
	to.y = 0.0
	var fwd := Vector3(sin(visual.rotation.y), 0.0, cos(visual.rotation.y))
	if dist > 4.0 and fwd.dot(to.normalized()) < 0.2:
		return false
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0.0, 1.9, 0.0), player.global_position + Vector3(0.0, 1.4, 0.0), 1)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or hit.get("collider") == player

func move_to(target: Vector3, spd: float, delta: float) -> void:
	agent.target_position = target
	var dir := agent.get_next_path_position() - global_position
	dir.y = 0.0
	if agent.is_navigation_finished() or dir.length() < 0.05:
		dir = target - global_position
		dir.y = 0.0
	if nudge_t > 0.0:
		nudge_t -= delta
		dir = nudge_dir
	if dir.length() > 0.05:
		dir = dir.normalized()
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(dir.x, dir.z), minf(1.0, delta * 8.0))
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	stuck_t += delta
	if stuck_t > 0.7:
		stuck_t = 0.0
		if global_position.distance_to(last_pos) < 0.3 and spd > 0.0:
			nudge_t = 0.5
			nudge_dir = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
		last_pos = global_position
	step_t += spd * delta
	if step_t > 2.6:
		step_t = 0.0
		Sfx.play3d("step", global_position, 3.0, 0.55, 5.0)

func _physics_process(delta: float) -> void:
	if ghost or state == "dormant":
		animate(delta)
		return
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	else:
		velocity.y = -0.5
	if state == "cry" or state == "frozen" or state == "caught":
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		animate(delta)
		return
	var ppos: Vector3 = player.global_position
	var dist := global_position.distance_to(ppos)
	var sees := can_see(dist)
	var hears: bool = dist < player.noise
	if state == "stun":
		stun_t -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		if stun_t <= 0.0:
			state = "chase"
	elif sees or hears:
		if state != "chase":
			state = "chase"
			g.clown_alert()
		last_known = ppos
		lost_t = 0.0
	elif state == "chase":
		lost_t += delta
		if lost_t > 5.0:
			state = "search"
			wait_t = 0.0
	if state == "chase":
		var spd := speed + bonus
		lunge_cd -= delta
		if lunge_t > 0.0:
			lunge_t -= delta
			spd *= 1.28
		elif lunge_cd <= 0.0 and sees and dist < 14.0 and dist > 5.0:
			lunge_t = 1.0
			lunge_cd = randf_range(7.0, 12.0)
			Sfx.play3d("laugh", global_position, 3.0, 1.25)
		move_to(ppos if sees else last_known, spd, delta)
		if dist < 1.3:
			g.player_caught()
	elif state == "search":
		if global_position.distance_to(last_known) < 2.0:
			velocity.x = 0.0
			velocity.z = 0.0
			wait_t += delta
			visual.rotation.y += delta * 1.4
			if wait_t > 2.5:
				state = "patrol"
				pick_patrol()
		else:
			move_to(last_known, 2.6, delta)
	elif state == "patrol":
		if global_position.distance_to(patrol_target) < 2.5 or patrol_target == Vector3.ZERO:
			pick_patrol()
		move_to(patrol_target, 2.4, delta)
	move_and_slide()
	animate(delta)

func tx(n: Node3D, v: float, k: float) -> void:
	n.rotation.x = lerpf(n.rotation.x, v, k)

func animate(delta: float) -> void:
	tt += delta
	if state == "cry":
		visual.rotation.z = sin(tt * 24.0) * 0.014
		return
	var k := minf(1.0, delta * 10.0)
	var hl: Node3D = rig["hipL"]
	var hr: Node3D = rig["hipR"]
	var kl: Node3D = rig["kneeL"]
	var kr: Node3D = rig["kneeR"]
	var sl: Node3D = rig["shL"]
	var sr: Node3D = rig["shR"]
	var torso: Node3D = rig["torso"]
	var head: Node3D = rig["head"]
	visual.rotation.z = 0.0
	if state == "stun":
		tx(sl, -2.8, k)
		tx(sr, -2.8, k)
		tx(torso, -0.35, k)
		tx(head, -0.7, k)
		visual.rotation.z = sin(tt * 45.0) * 0.05
		return
	if state == "caught":
		tx(sl, -1.6, k)
		tx(sr, -1.6, k)
		tx(torso, 0.3, k)
		tx(head, 0.1, k)
		visual.rotation.z = sin(tt * 38.0) * 0.04
		return
	var sp := Vector2(velocity.x, velocity.z).length()
	var aggressive := state == "chase" or run_anim
	if sp > 0.4 or run_anim:
		walk_t += delta * (5.0 + (3.5 if aggressive else 0.0))
		var sw := sin(walk_t)
		hl.rotation.x = sw * 0.7
		hr.rotation.x = -sw * 0.7
		kl.rotation.x = maxf(0.0, sin(walk_t + 1.6))
		kr.rotation.x = maxf(0.0, sin(walk_t + 1.6 + PI))
		tx(torso, 0.36 if aggressive else 0.18, k)
		if aggressive:
			tx(sl, -1.1 + sin(tt * 12.0) * 0.12, k)
			tx(sr, -1.1 - sin(tt * 12.0) * 0.12, k)
		else:
			tx(sl, -sw * 0.5, k)
			tx(sr, sw * 0.5, k)
	else:
		for n in [hl, hr, kl, kr]:
			tx(n, 0.0, k)
		tx(torso, 0.05, k)
		tx(sl, sin(tt * 1.2) * 0.06, k)
		tx(sr, -sin(tt * 1.2) * 0.06, k)
	head.rotation.z = sin(tt * 0.9) * 0.12
	tx(head, 0.08 + sin(tt * 0.5) * 0.05, k)
