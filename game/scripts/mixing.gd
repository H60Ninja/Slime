extends Node2D
## The "make slime" opening, guided for non-readers: a hand shows what to tap, the
## colour bottles sit right under the bowl, step icons across the top fill in, and a big
## go button in the corner skips straight to a lump.

signal poured
signal stirring
signal color_chosen(col: Color, from: Vector2)
signal skipped
signal done(col: Color)

enum Step { GLUE, COLOR, ACTIVATOR, STIR, LIFT }
const COLORS: Array[Color] = [Color("6fe36a"), Color("4fb8ff"), Color("9d6bff"), Color("ff5fb8"), Color("ff4d4d"), Color("ffe44d")]
const HandScript := preload("res://scripts/hand.gd")

var step := Step.GLUE
var bowl_center := Vector2(960, 640)
var bowl_r := 300.0
var fill := 0.0
var liquid := Color("f2f2f6")
var gloss := 0.0
var stir := 0.0
var swirl := 0.0
var _pour_t := -1.0
var _pour_col := Color.WHITE
var _t := 0.0
var _lift_t := 0.0
var _stir_cd := 0.0
var _last_drag := {}
var _area := Rect2()
var _hand: Node2D
var _touched_this_step := false
var _color_wait := false


func _ready() -> void:
	_hand = HandScript.new()
	_hand.z_index = 20
	add_child(_hand)
	_cue()


func set_area(r: Rect2) -> void:
	_area = r
	bowl_center = r.get_center() + Vector2(0, 30)
	bowl_r = minf(r.size.x, r.size.y) * 0.24
	_cue()


func _glue_rect() -> Rect2:
	return Rect2(bowl_center + Vector2(-bowl_r * 2.1, -bowl_r * 1.15), Vector2(150, 230))


func _act_rect() -> Rect2:
	return Rect2(bowl_center + Vector2(bowl_r * 2.1 - 150, -bowl_r * 1.15), Vector2(150, 230))


func _color_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var n := COLORS.size()
	var w := 96.0
	var gap := 22.0
	var x0 := bowl_center.x - (n * w + (n - 1) * gap) * 0.5
	var y := bowl_center.y + bowl_r * 1.18
	for i in n:
		out.append(Rect2(x0 + i * (w + gap), y, w, 130))
	return out


func skip_rect() -> Rect2:
	return Rect2(_area.end - Vector2(150, 150), Vector2(130, 130))


func _step_icon_centers() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var y := _area.position.y + 70
	for i in 4:
		out.append(Vector2(bowl_center.x + (i - 1.5) * 150.0, y))
	return out


## Point the hand at whatever the kid should do now.
func _cue() -> void:
	if _hand == null:
		return
	match step:
		Step.GLUE:
			_hand.tap_at(_glue_rect().get_center() + Vector2(0, 20))
		Step.COLOR:
			_hand.tap_at(_color_rects()[3].get_center())
		Step.ACTIVATOR:
			_hand.tap_at(_act_rect().get_center() + Vector2(0, 20))
		Step.STIR:
			_hand.circle(bowl_center, bowl_r * 0.5)
		_:
			_hand.hide_hand()


func _process(delta: float) -> void:
	_t += delta
	_stir_cd = maxf(0.0, _stir_cd - delta)
	if _pour_t >= 0.0:
		_pour_t += delta
		if step == Step.GLUE:
			fill = lerpf(fill, 0.55, delta * 2.0)
		elif step == Step.ACTIVATOR:
			gloss = lerpf(gloss, 1.0, delta * 2.0)
			fill = lerpf(fill, 0.62, delta * 2.0)
		if _pour_t > 1.3:
			_pour_t = -1.0
			if step == Step.GLUE:
				step = Step.COLOR
			elif step == Step.ACTIVATOR:
				step = Step.STIR
			_cue()
	swirl = maxf(0.0, swirl - delta * 1.5)
	if step == Step.LIFT:
		_lift_t += delta
		if _lift_t > 0.7:
			done.emit(liquid)
			queue_free()
			return
	queue_redraw()


## Called by main when the colour drop lands in the bowl.
func add_color(col: Color) -> void:
	if step != Step.COLOR:
		return
	liquid = col.lerp(Color.WHITE, 0.15)
	fill = minf(0.6, fill + 0.05)
	step = Step.ACTIVATOR
	_color_wait = false
	_cue()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		var p := make_canvas_position_local(event.position)
		if skip_rect().grow(16).has_point(p):
			skipped.emit()
			return
		match step:
			Step.GLUE:
				if _glue_rect().grow(40).has_point(p) and _pour_t < 0.0:
					_pour_t = 0.0
					_pour_col = Color("f2f2f6")
					_hand.hide_hand()
					poured.emit()
			Step.COLOR:
				if not _color_wait:
					var rs := _color_rects()
					for i in rs.size():
						if rs[i].grow(16).has_point(p):
							_color_wait = true
							_hand.hide_hand()
							color_chosen.emit(COLORS[i], rs[i].get_center())
			Step.ACTIVATOR:
				if _act_rect().grow(40).has_point(p) and _pour_t < 0.0:
					_pour_t = 0.0
					_pour_col = Color("9fd8ff")
					_hand.hide_hand()
					poured.emit()
		_last_drag[event.index] = p
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and not event.pressed:
		_last_drag.erase(event.index)
	elif event is InputEventScreenDrag and step == Step.STIR:
		var p := make_canvas_position_local(event.position)
		if p.distance_to(bowl_center) < bowl_r * 1.15 and _last_drag.has(event.index):
			var d: float = p.distance_to(_last_drag[event.index])
			stir = minf(1.0, stir + d / 2200.0)
			swirl = minf(1.0, swirl + d * 0.01)
			if stir > 0.05:
				_hand.hide_hand()
			if _stir_cd <= 0.0 and d > 4.0:
				_stir_cd = 0.35
				stirring.emit()
			if stir >= 1.0:
				step = Step.LIFT
				_lift_t = 0.0
				_cue()
		_last_drag[event.index] = p
		get_viewport().set_input_as_handled()


func _bottle(r: Rect2, body: Color, label: Color, tilt: float, dim: float) -> void:
	draw_set_transform(r.get_center(), tilt, Vector2.ONE)
	var hw := r.size.x * 0.5
	var hh := r.size.y * 0.5
	var b := body.lerp(Color("d8d4cc"), dim)
	var l := label.lerp(Color("c8c4bc"), dim)
	draw_rect(Rect2(Vector2(-hw, -hh + 50), Vector2(r.size.x, r.size.y - 50)), b)
	draw_rect(Rect2(Vector2(-hw * 0.45, -hh), Vector2(hw * 0.9, 56)), b.darkened(0.25))
	draw_rect(Rect2(Vector2(-hw + 14, -hh + 95), Vector2(r.size.x - 28, 70)), l)
	draw_circle(Vector2(0, -hh + 130), 16, Color(1, 1, 1, 0.9 - 0.5 * dim))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw() -> void:
	# step icons across the top: glue, drop, activator, swirl
	var centers := _step_icon_centers()
	for i in 4:
		var c := centers[i]
		var done_step := i < int(step) or step == Step.LIFT
		var active := i == int(step)
		draw_circle(c, 44, Color.WHITE if active or done_step else Color(1, 1, 1, 0.55))
		if active:
			draw_arc(c, 44, 0.0, TAU, 40, Color("4fb8ff"), 6.0, true)
		if done_step:
			draw_line(c + Vector2(-16, 2), c + Vector2(-5, 13), Color("6fe36a"), 8.0, true)
			draw_line(c + Vector2(-5, 13), c + Vector2(18, -12), Color("6fe36a"), 8.0, true)
		else:
			match i:
				0:
					draw_rect(Rect2(c + Vector2(-13, -8), Vector2(26, 28)), Color("ff9b2f"))
					draw_rect(Rect2(c + Vector2(-6, -20), Vector2(12, 12)), Color("8a8fa8"))
				1:
					var pts := PackedVector2Array()
					for k in 18:
						var a := TAU * k / 18.0
						pts.append(c + Vector2(cos(a) * 14, sin(a) * 14 + 6))
					pts.append(c + Vector2(0, -22))
					draw_colored_polygon(Geometry2D.convex_hull(pts), Color("ff5fb8"))
				2:
					draw_rect(Rect2(c + Vector2(-13, -8), Vector2(26, 28)), Color("4fb8ff"))
					draw_rect(Rect2(c + Vector2(-6, -20), Vector2(12, 12)), Color("8a8fa8"))
				3:
					draw_arc(c, 16, 0.4, 5.6, 20, Color("9d6bff"), 7.0, true)
		if i < 3:
			draw_line(c + Vector2(50, 0), c + Vector2(100, 0), Color(1, 1, 1, 0.7), 6.0, true)

	# bowl
	draw_circle(bowl_center + Vector2(10, 18), bowl_r * 1.05, Color(0, 0, 0, 0.12))
	draw_circle(bowl_center, bowl_r * 1.05, Color("e9e2d6"))
	draw_circle(bowl_center, bowl_r * 0.97, Color("fbf7f1"))
	draw_arc(bowl_center, bowl_r * 1.01, 0.0, TAU, 64, Color("d9d0c2"), 6.0, true)
	if fill > 0.01:
		var lr := bowl_r * 0.94 * clampf(fill / 0.6, 0.3, 1.0)
		draw_circle(bowl_center + Vector2(0, 10), lr, liquid.darkened(0.08))
		draw_circle(bowl_center, lr * 0.97, liquid)
		if swirl > 0.0 or step >= Step.STIR:
			for i in 3:
				var a0 := _t * (2.0 + swirl * 6.0) + i * TAU / 3.0
				draw_arc(bowl_center, lr * (0.35 + 0.2 * i), a0, a0 + 2.2, 24, liquid.darkened(0.18), 10.0, true)
		if gloss > 0.0:
			draw_circle(bowl_center + Vector2(-lr * 0.35, -lr * 0.4), lr * 0.18, Color(1, 1, 1, 0.6 * gloss))

	# bottles: only the one that matters is bright
	var gt := -0.9 if (_pour_t >= 0.0 and step == Step.GLUE) else 0.0
	var at := 0.9 if (_pour_t >= 0.0 and step == Step.ACTIVATOR) else 0.0
	_bottle(_glue_rect(), Color("fafafa"), Color("ff9b2f"), gt, 0.0 if step == Step.GLUE else 0.6)
	_bottle(_act_rect(), Color("c9ebff"), Color("4fb8ff"), at, 0.0 if step == Step.ACTIVATOR else 0.6)
	if _pour_t >= 0.0:
		var from: Vector2 = (_glue_rect().get_center() + Vector2(60, -60)) if step == Step.GLUE else (_act_rect().get_center() + Vector2(-60, -60))
		var to := bowl_center + Vector2(0, -bowl_r * 0.3)
		var k := clampf(_pour_t / 0.3, 0.0, 1.0)
		draw_line(from, from.lerp(to, k), _pour_col, 18.0, true)
		if k >= 1.0:
			draw_circle(to, 22.0 + 6.0 * sin(_t * 20.0), _pour_col)

	# colour bottles under the bowl (only during the colour step)
	if step == Step.COLOR:
		var rs := _color_rects()
		for i in rs.size():
			var r := rs[i]
			var c := COLORS[i]
			draw_rect(Rect2(r.position + Vector2(0, 34), Vector2(r.size.x, r.size.y - 34)), c)
			draw_rect(Rect2(r.position + Vector2(r.size.x * 0.3, 0), Vector2(r.size.x * 0.4, 40)), Color("5a6478"))
			draw_rect(Rect2(r.position + Vector2(10, 60), Vector2(r.size.x - 20, 44)), Color(1, 1, 1, 0.85))
			draw_circle(r.position + Vector2(r.size.x * 0.5, 82), 12, c)

	# stir hint ring
	if step == Step.STIR:
		draw_arc(bowl_center, bowl_r * 1.12, -PI / 2, -PI / 2 + TAU * stir, 64, Color("6fe36a"), 12.0, true)
	if step == Step.LIFT:
		var k := _lift_t / 0.7
		draw_circle(bowl_center, bowl_r * 0.94 * (1.0 + k * 0.4), liquid)

	# skip / go button: a lump with an arrow
	var sr := skip_rect()
	var sc := sr.get_center()
	draw_circle(sc + Vector2(0, 5), 65, Color(0, 0, 0, 0.15))
	draw_circle(sc, 65, Color.WHITE)
	draw_circle(sc + Vector2(-14, 4), 26, Color("6fe36a"))
	draw_circle(sc + Vector2(-22, -4), 7, Color(1, 1, 1, 0.8))
	draw_line(sc + Vector2(18, 4), sc + Vector2(44, 4), Color("4fb8ff"), 10.0, true)
	draw_colored_polygon(PackedVector2Array([sc + Vector2(40, -12), sc + Vector2(56, 4), sc + Vector2(40, 20)]), Color("4fb8ff"))
