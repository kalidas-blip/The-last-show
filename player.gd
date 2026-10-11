extends CharacterBody3D
# First-person controller: touch look, floating joystick, sprint, flashlight, knife viewmodel.
var g = null
var ui = null
var head: Node3D
var cam: Camera3D
var flash: SpotLight3D
var vm: Node3D
var vm_base := Vector3(0.3, -0.27, -0.55)
var vm_busy := false
var yaw := 0.0
var pitch := 0.0
var stamina := 1.0
var tired := false
var rest_t := 0.0
var sprinting := false
var locked := true
var noise := 0.0
var step_d := 0.0
var bob_t := 0.0
var shake_amt := 0.0
var fov_kick := 0.0
var fov_override := -1.0
var flash_on := true
var flick_t := 0.0
var fear := 0.0
var has_knife := false

func _ready() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.75
	cs.shape = cap
	cs.position.y = 0.875
	add_child(cs)
	head = Node3D.new()
	head.position.y = 1.6
	add_child(head)
	cam = Camera3D.new()
	cam.near = 0.05
	cam.far = 150.0
	cam.fov = 75.0
	head.add_child(cam)
	cam.make_current()
	flash = SpotLight3D.new()
	flash.spot_range = 34.0
	flash.spot_angle = 32.0
	flash.spot_attenuation = 0.8
	flash.light_energy = 5.5
	flash.light_color = Color(1.0, 0.95, 0.82)
	flash.shadow_enabled = true
	flash.position = Vector3(0.1, -0.1, -0.1)
	cam.add_child(flash)
	vm = Node3D.new()
	vm.position = vm_base
	vm.rotation_degrees = Vector3(6.0, -14.0, 0.0)
	vm.visible = false
	cam.add_child(vm)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.82, 0.84, 0.88)
	steel.metallic = 0.9
	steel.roughness = 0.25
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.05, 0.03, 0.03)
	var parts := [[Vector3(0.012, 0.045, 0.32), Vector3(0.0, 0.0, -0.2), steel], [Vector3(0.04, 0.045, 0.13), Vector3(0.0, 0.0, 0.03), dark], [Vector3(0.035, 0.07, 0.02), Vector3(0.0, 0.0, -0.035), dark]]
	for p in parts:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = p[0]
		mi.mesh = bm
		mi.material_override = p[2]
		mi.position = p[1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		vm.add_child(mi)

func toggle_flash() -> void:
	flash_on = not flash_on
	flash.visible = flash_on
	Sfx.play("click", -4.0)

func jolt(k: float) -> void:
	shake_amt = maxf(shake_amt, 1.4 * k)
	fov_kick = 16.0 * k

func look_at_point(p: Vector3, dur: float) -> void:
	var d := p - head.global_position
	var yt := atan2(-d.x, -d.z)
	var pt := clampf(atan2(d.y, Vector2(d.x, d.z).length()), -1.4, 1.4)
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(_look_step.bind(yaw, yt, pitch, pt), 0.0, 1.0, dur)

func _look_step(v: float, y0: float, yt: float, p0: float, pt: float) -> void:
	yaw = lerp_angle(y0, yt, v)
	pitch = lerpf(p0, pt, v)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	else:
		velocity.y = -0.5
	var mv := Vector2.ZERO
	if not locked and ui != null:
		mv = ui.move
		var lk: Vector2 = ui.take_look()
		yaw -= lk.x * 0.0045
		pitch = clampf(pitch - lk.y * 0.0045, -1.45, 1.45)
	rotation.y = yaw
	head.rotation.x = pitch
	noise = 0.0
	var spd := 3.3
	var amt := mv.length()
	if locked:
		velocity.x = 0.0
		velocity.z = 0.0
		sprinting = false
	else:
		var want: bool = ui != null and ui.sprint and amt > 0.15 and not tired
		if want and stamina > 0.0:
			sprinting = true
			stamina -= delta * 0.2
			rest_t = 0.0
			spd = 6.0
			if stamina <= 0.0:
				stamina = 0.0
				tired = true
		else:
			sprinting = false
			rest_t += delta
			if rest_t > 1.0:
				stamina = minf(1.0, stamina + delta * 0.14)
			if tired and stamina > 0.3:
				tired = false
		var dir := transform.basis * Vector3(mv.x, 0.0, mv.y)
		dir = dir.limit_length(1.0)
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
		if amt > 0.15:
			noise = 18.0 if sprinting else 6.0
			if is_on_floor():
				step_d += spd * amt * delta
				if step_d > (2.3 if sprinting else 1.7):
					step_d = 0.0
					Sfx.play("step", -9.0 if sprinting else -15.0, randf_range(0.85, 1.15))
	move_and_slide()
	bob_t += delta * spd * 1.7
	head.position.y = 1.6 + sin(bob_t) * 0.035 * minf(amt, 1.0)
	shake_amt = maxf(0.0, shake_amt - delta * 1.8)
	cam.position = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * shake_amt * 0.05
	cam.rotation.z = sin(bob_t * 0.5) * 0.012 * minf(amt, 1.0) + sin(Time.get_ticks_msec() * 0.01) * 0.004 * fear
	fov_kick = lerpf(fov_kick, 0.0, minf(1.0, delta * 6.0))
	var target := 75.0 - fear * 5.0 + fov_kick
	if fov_override > 0.0:
		target = fov_override
	cam.fov = lerpf(cam.fov, target, minf(1.0, delta * (18.0 if fov_override > 0.0 else 10.0)))
	if flash_on:
		flick_t -= delta
		if flick_t > 0.0:
			flash.visible = false
		else:
			flash.visible = true
			if randf() < fear * 0.012:
				flick_t = randf_range(0.05, 0.25)
	if has_knife and not vm_busy:
		vm.position = vm_base + Vector3(sin(bob_t * 0.5) * 0.01, sin(bob_t) * 0.012, 0.0) * minf(amt, 1.0)
