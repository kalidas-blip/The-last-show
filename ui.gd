extends Node2D
# Touch controls and all 2D drawing: menus, HUD, prompts, red kill text, cinematic bars.
var g = null
var f: Font
var sz := Vector2(1280.0, 720.0)
var stick_id := -1
var look_id := -1
var sprint_id := -1
var origin := Vector2.ZERO
var spos := Vector2.ZERO
var move := Vector2.ZERO
var sprint := false
var look_acc := Vector2.ZERO
var t := 0.0

func _ready() -> void:
	f = Sfx.font
	process_mode = Node.PROCESS_MODE_ALWAYS

func take_look() -> Vector2:
	var v := look_acc
	look_acc = Vector2.ZERO
	return v

func b_sprint() -> Vector2:
	return Vector2(sz.x - 120.0, sz.y - 120.0)

func b_flash() -> Vector2:
	return Vector2(sz.x - 280.0, sz.y - 80.0)

func b_act() -> Vector2:
	return Vector2(sz.x - 150.0, sz.y - 290.0)

func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		var te := e as InputEventScreenTouch
		if te.pressed:
			down(te.index, te.position)
		else:
			up(te.index)
	elif e is InputEventScreenDrag:
		var de := e as InputEventScreenDrag
		moved(de.index, de.position, de.relative)

func down(i: int, p: Vector2) -> void:
	if g.paused or g.state != "play":
		g.tap()
		return
	if g.busy:
		return
	if g.prompt != "" and p.distance_to(b_act()) < 95.0:
		g.interact()
		return
	if p.distance_to(b_sprint()) < 85.0:
		sprint_id = i
		sprint = true
		return
	if p.distance_to(b_flash()) < 62.0:
		g.player.toggle_flash()
		return
	if p.x < sz.x * 0.42 and stick_id < 0:
		stick_id = i
		origin = p
		spos = p
		move = Vector2.ZERO
	elif look_id < 0:
		look_id = i

func up(i: int) -> void:
	if i == stick_id:
		stick_id = -1
		move = Vector2.ZERO
	if i == look_id:
		look_id = -1
	if i == sprint_id:
		sprint_id = -1
		sprint = false

func moved(i: int, p: Vector2, rel: Vector2) -> void:
	if i == stick_id:
		spos = p
		move = ((p - origin) / 85.0).limit_length(1.0)
	elif i == look_id:
		look_acc += rel

func _process(delta: float) -> void:
	sz = get_viewport_rect().size
	t += delta
	queue_redraw()

func txt(s: String, p: Vector2, size: int, col: Color = Color.WHITE, al: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER, w: float = -1.0) -> void:
	var ww := sz.x if w < 0.0 else w
	draw_string_outline(f, p, s, al, ww, size, 10, Color(0, 0, 0, col.a))
	draw_string(f, p, s, al, ww, size, col)

func heart(c: Vector2, s: float, col: Color) -> void:
	draw_circle(c + Vector2(-s * 0.5, -s * 0.2), s * 0.55, col)
	draw_circle(c + Vector2(s * 0.5, -s * 0.2), s * 0.55, col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 1.02, 0.0), c + Vector2(s * 1.02, 0.0), c + Vector2(0.0, s * 1.2)]), col)

func _draw() -> void:
	if g == null:
		return
	var st: String = g.state
	if st == "loading":
		draw_rect(Rect2(Vector2.ZERO, sz), Color.BLACK)
		txt("LOADING...", Vector2(0, sz.y * 0.5), 44, Color(0.6, 0.08, 0.08))
		return
	if st == "menu":
		draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, 0.5))
		var j := Vector2(sin(t * 37.0), cos(t * 41.0)) * 2.0
		txt("THE LAST SHOW", Vector2(0, sz.y * 0.4) + j, 110, Color(0.78, 0.05, 0.06))
		txt("An abandoned carnival. One clown. Five hearts.", Vector2(0, sz.y * 0.4 + 60.0), 30, Color(0.85, 0.8, 0.75))
		if int(t * 1.6) % 2 == 0:
			txt("TAP TO ENTER", Vector2(0, sz.y * 0.72), 54)
		txt("Headphones recommended. Contains jumpscares and gore.", Vector2(0, sz.y - 40.0), 24, Color(0.7, 0.7, 0.7))
		return
	if st == "dead_wait":
		draw_rect(Rect2(Vector2.ZERO, sz), Color.BLACK)
		txt("YOU DIED", Vector2(0, sz.y * 0.48), 120, Color(0.8, 0.05, 0.05))
		if int(t * 1.6) % 2 == 0:
			txt("TAP TO TRY AGAIN", Vector2(0, sz.y * 0.68), 46)
		return
	if st == "end":
		draw_rect(Rect2(Vector2.ZERO, sz), Color.WHITE if g.end_t < 1.2 else Color.BLACK)
		if g.end_t > 1.2:
			txt("YOU ESCAPED THE LAST SHOW", Vector2(0, sz.y * 0.42), 70, Color(0.9, 0.9, 0.9))
			if g.end_t > 5.0:
				txt("...but the laughing never stops.", Vector2(0, sz.y * 0.56), 40, Color(0.75, 0.05, 0.05))
			if g.end_t > 8.0 and int(t * 1.6) % 2 == 0:
				txt("TAP TO PLAY AGAIN", Vector2(0, sz.y * 0.8), 40)
		return
	# ---- HUD (play) ----
	if g.objective != "":
		txt(g.objective, Vector2(24, 44), 28, Color(1, 1, 1, 0.92), HORIZONTAL_ALIGNMENT_LEFT, sz.x)
	if g.has_knife:
		var n := 0
		for h in g.hearts:
			var alive: bool = h.alive
			var c := Color(0.85, 0.05, 0.08) if alive else Color(0.2, 0.2, 0.2, 0.7)
			var pulse := 1.0 + (0.12 * sin(t * 6.0 + n) if alive else 0.0)
			heart(Vector2(sz.x - 190.0 + n * 40.0, 40.0), 11.0 * pulse, c)
			n += 1
	var stm: float = g.player.stamina
	if stm < 0.99:
		draw_rect(Rect2(24, sz.y - 30, 200, 8), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(24, sz.y - 30, 200.0 * stm, 8), Color(0.9, 0.9, 0.6, 0.8))
	if g.msg_t > 0.0:
		txt(g.msg, Vector2(0, sz.y * 0.8), 30, Color(1, 1, 1, clampf(g.msg_t, 0.0, 1.0)))
	if g.kill_t > 0.0:
		var j2 := Vector2(sin(t * 53.0), cos(t * 47.0)) * 3.0
		var pz := 1.0 + 0.04 * sin(t * 10.0)
		var a := clampf(g.kill_t, 0.0, 1.0)
		txt("KILL THE CLOWN", Vector2(0, sz.y * 0.43) + j2 + Vector2(0, 5), int(110.0 * pz), Color(0.35, 0.0, 0.0, a))
		txt("KILL THE CLOWN", Vector2(0, sz.y * 0.43) + j2, int(110.0 * pz), Color(1.0, 0.04, 0.04, a))
	if not g.busy:
		draw_circle(sz * 0.5, 2.5, Color(1, 1, 1, 0.35))
		if stick_id >= 0:
			draw_circle(origin, 85.0, Color(1, 1, 1, 0.08))
			draw_arc(origin, 85.0, 0.0, TAU, 40, Color(1, 1, 1, 0.3), 2.0)
			draw_circle(origin + (spos - origin).limit_length(85.0), 34.0, Color(1, 1, 1, 0.3))
		else:
			draw_arc(Vector2(sz.x * 0.14, sz.y * 0.72), 70.0, 0.0, TAU, 40, Color(1, 1, 1, 0.12), 2.0)
		var sc := b_sprint()
		draw_circle(sc, 62.0, Color(1, 1, 1, 0.22 if sprint else 0.1))
		draw_arc(sc, 62.0, 0.0, TAU, 32, Color(1, 1, 1, 0.35), 2.0)
		txt("RUN", sc + Vector2(-sz.x * 0.5, 9), 24, Color(1, 1, 1, 0.8))
		var fc := b_flash()
		draw_circle(fc, 44.0, Color(1, 1, 1, 0.22 if g.player.flash_on else 0.08))
		draw_arc(fc, 44.0, 0.0, TAU, 32, Color(1, 1, 1, 0.35), 2.0)
		txt("LIGHT", fc + Vector2(-sz.x * 0.5, 8), 20, Color(1, 1, 1, 0.8))
		if g.prompt != "":
			var ac := b_act()
			var r := 74.0 + sin(t * 8.0) * 3.0
			draw_circle(ac, r, Color(0.8, 0.05, 0.05, 0.55))
			draw_arc(ac, r, 0.0, TAU, 32, Color(1, 0.3, 0.3, 0.9), 3.0)
			txt(g.prompt, ac + Vector2(-sz.x * 0.5, 9), 26)
	var bh: float = sz.y * 0.12 * g.bars
	if bh > 0.5:
		draw_rect(Rect2(0, 0, sz.x, bh), Color.BLACK)
		draw_rect(Rect2(0, sz.y - bh, sz.x, bh), Color.BLACK)
	if g.paused:
		draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, 0.75))
		txt("PAUSED", Vector2(0, sz.y * 0.45), 90)
		txt("TAP TO RESUME", Vector2(0, sz.y * 0.6), 40)
