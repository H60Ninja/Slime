extends Node2D
## The "make slime" ritual: pour glue, pick a colour, pour activator, stir, done.
## Everything is drawn in code; the only text-free hints are pulsing rings.

signal need_color(on: bool)   ## ask the UI to pulse the palette
signal poured                 ## a bottle was poured (sound hook)
signal stirring               ## stir sound hook (rate limited)
signal done(col: Color)

enum Step { GLUE, COLOR, ACTIVATOR, STIR, LIFT }

var step := Step.GLUE
var bowl_center := Vector2(960, 640)
var bowl_r := 300.0
var fill := 0.0
var liquid := Color("f2f2f6")
var gloss := 0.0
var stir := 0.0
var swirl := 0.0
var _pour_t := -1.0       # >= 0 while a bottle is pouring
var _pour_col := Color.WHITE
var _t := 0.0
var _lift_t := 0.0
var _stir_cd := 0.0
var _last_drag := {}      # index -> last pos
var _area := Rect2()


func set_area(r: Rect2) -> void:
	_area = r
	bowl_center = r.get_center() + Vector2(0, 40)
	bowl_r = minf(r.size.x, r.size.y) * 0.27


func _glue_rect() -> Rect2:
	return Rect2(bowl_center + Vector2(-bowl_r * 1.9, -bowl_r * 1.25), Vector2(150, 230))


func _act_rect() -> Rect2:
	return Rect2(bowl_center + Vector2(bowl_r * 1.9 - 150, -bowl_r * 1.25), Vector2(150, 230))


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
				need_color.emit(true)
			elif step == Step.ACTIVATOR:
				step = Step.STIR
	swirl = maxf(0.0, swirl - delta * 1.5)
	if step == Step.LIFT:
		_lift_t += delta
		if _lift_t > 0.7:
			done.emit(liquid)
			queue_free()
			return
	queue_redraw()


## Called by main when a palette colour is poured in (after the drop lands).
func add_color(col: Color) -> void:
	if step != Step.COLOR:
		return
	liquid = col.lerp(Color.WHITE, 0.15)
	fill = minf(0.6, fill + 0.05)
	step = Step.ACTIVATOR
	need_color.emit(false)


func is_waiting_for_color() -> bool:
	return step == Step.COLOR


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		var p := make_canvas_position_local(event.position)
		if step == Step.GLUE and _glue_rect().grow(30).has_point(p) and _pour_t < 0.0:
			_pour_t = 0.0
			_pour_col = Color("f2f2f6")
			poured.emit()
		elif step == Step.ACTIVATOR and _act_rect().grow(30).has_point(p) and _pour_t < 0.0:
			_pour_t = 0.0
			_pour_col = Color("9fd8ff")
			poured.emit()
		_last_drag[event.index] = p
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and not event.pressed:
		_last_drag.erase(event.index)
	elif event is InputEventScreenDrag and step == Step.STIR:
		var p := make_canvas_position_local(event.position)
		if p.distance_to(bowl_center) < bowl_r * 1.1 and _last_drag.has(event.index):
			var d: float = p.distance_to(_last_drag[event.index])
			stir = minf(1.0, stir + d / 2600.0)
			swirl = minf(1.0, swirl + d * 0.01)
			if _stir_cd <= 0.0 and d > 4.0:
				_stir_cd = 0.35
				stirring.emit()
			if stir >= 1.0:
				step = Step.LIFT
				_lift_t = 0.0
		_last_drag[event.index] = p
		get_viewport().set_input_as_handled()


func _pulse(center: Vector2, r: float) -> void:
	var k := fmod(_t, 1.2) / 1.2
	draw_arc(center, r + 30.0 * k, 0.0, TAU, 48, Color(1, 1, 1, 0.9 * (1.0 - k)), 8.0 * (1.0 - k) + 1.0, true)


func _bottle(r: Rect2, body: Color, label: Color, tilt: float) -> void:
	draw_set_transform(r.get_center(), tilt, Vector2.ONE)
	var hw := r.size.x * 0.5
	var hh := r.size.y * 0.5
	draw_rect(Rect2(Vector2(-hw, -hh + 50), Vector2(r.size.x, r.size.y - 50)), body)
	draw_rect(Rect2(Vector2(-hw * 0.45, -hh), Vector2(hw * 0.9, 56)), body.darkened(0.25))
	draw_rect(Rect2(Vector2(-hw + 14, -hh + 95), Vector2(r.size.x - 28, 70)), label)
	draw_circle(Vector2(0, -hh + 130), 16, Color(1, 1, 1, 0.9))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw() -> void:
	# bowl shadow + rim
	draw_circle(bowl_center + Vector2(10, 18), bowl_r * 1.05, Color(0, 0, 0, 0.12))
	draw_circle(bowl_center, bowl_r * 1.05, Color("e9e2d6"))
	draw_circle(bowl_center, bowl_r * 0.97, Color("fbf7f1"))
	draw_arc(bowl_center, bowl_r * 1.01, 0.0, TAU, 64, Color("d9d0c2"), 6.0, true)
	# liquid
	if fill > 0.01:
		var lr := bowl_r * 0.94 * clampf(fill / 0.6, 0.3, 1.0)
		var lc := liquid.darkened(0.08)
		draw_circle(bowl_center + Vector2(0, 10), lr, lc)
		draw_circle(bowl_center, lr * 0.97, liquid)
		if swirl > 0.0 or step >= Step.STIR:
			for i in 3:
				var a0 := _t * (2.0 + swirl * 6.0) + i * TAU / 3.0
				draw_arc(bowl_center, lr * (0.35 + 0.2 * i), a0, a0 + 2.2, 24, liquid.darkened(0.18), 10.0, true)
		if gloss > 0.0:
			draw_circle(bowl_center + Vector2(-lr * 0.35, -lr * 0.4), lr * 0.18, Color(1, 1, 1, 0.6 * gloss))
	# bottles
	var gt := -0.9 if (_pour_t >= 0.0 and step == Step.GLUE) else 0.0
	var at := 0.9 if (_pour_t >= 0.0 and step == Step.ACTIVATOR) else 0.0
	_bottle(_glue_rect(), Color("fafafa"), Color("ff9b2f"), gt)
	_bottle(_act_rect(), Color("c9ebff"), Color("4fb8ff"), at)
	# pour stream
	if _pour_t >= 0.0:
		var from: Vector2 = (_glue_rect().get_center() + Vector2(60, -60)) if step == Step.GLUE else (_act_rect().get_center() + Vector2(-60, -60))
		var to := bowl_center + Vector2(0, -bowl_r * 0.3)
		var k := clampf(_pour_t / 0.3, 0.0, 1.0)
		var mid := from.lerp(to, k)
		draw_line(from, mid, _pour_col, 18.0, true)
		if k >= 1.0:
			draw_circle(to, 22.0 + 6.0 * sin(_t * 20.0), _pour_col)
	# hints
	match step:
		Step.GLUE:
			_pulse(_glue_rect().get_center(), 130.0)
		Step.ACTIVATOR:
			_pulse(_act_rect().get_center(), 130.0)
		Step.STIR:
			# circular arrow in the bowl + progress ring
			var a0 := _t * 2.0
			draw_arc(bowl_center, bowl_r * 0.55, a0, a0 + 4.5, 32, Color(1, 1, 1, 0.75), 12.0, true)
			var tip := bowl_center + Vector2(cos(a0 + 4.5), sin(a0 + 4.5)) * bowl_r * 0.55
			var dir := Vector2(-sin(a0 + 4.5), cos(a0 + 4.5))
			draw_colored_polygon(PackedVector2Array([tip + dir * 28, tip + dir.rotated(PI / 2) * 22, tip - dir.rotated(PI / 2) * 22]), Color(1, 1, 1, 0.75))
			draw_arc(bowl_center, bowl_r * 1.12, -PI / 2, -PI / 2 + TAU * stir, 64, Color("6fe36a"), 10.0, true)
		Step.LIFT:
			var k := _lift_t / 0.7
			draw_circle(bowl_center, bowl_r * 0.94 * (1.0 + k * 0.4), liquid)
