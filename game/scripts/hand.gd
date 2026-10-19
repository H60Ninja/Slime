extends Node2D
## A cartoon pointing hand that shows kids what to do: tap here, drag there, stir round.

enum Mode { HIDDEN, TAP, DRAG, CIRCLE }

var mode := Mode.HIDDEN
var a := Vector2.ZERO
var b := Vector2.ZERO
var radius := 120.0
var _t := 0.0


func tap_at(p: Vector2) -> void:
	mode = Mode.TAP
	a = p
	_t = 0.0
	visible = true


func drag(from: Vector2, to: Vector2) -> void:
	mode = Mode.DRAG
	a = from
	b = to
	_t = 0.0
	visible = true


func circle(center: Vector2, r: float) -> void:
	mode = Mode.CIRCLE
	a = center
	radius = r
	_t = 0.0
	visible = true


func hide_hand() -> void:
	mode = Mode.HIDDEN
	visible = false


func _process(delta: float) -> void:
	if mode == Mode.HIDDEN:
		return
	_t += delta
	queue_redraw()


func _draw() -> void:
	var p := a
	var press := 0.0
	match mode:
		Mode.TAP:
			var k := fmod(_t, 1.1) / 1.1
			press = 1.0 - absf(k * 2.0 - 1.0)   # down then up
			press = smoothstep(0.0, 1.0, press)
			p = a + Vector2(0, 18) * press
			if k < 0.5:
				draw_arc(a, 40.0 + 60.0 * (1.0 - press), 0.0, TAU, 40, Color(1, 1, 1, 0.8 * (1.0 - press)), 8.0, true)
		Mode.DRAG:
			var k := fmod(_t, 1.6) / 1.6
			var e := smoothstep(0.0, 1.0, clampf((k - 0.15) / 0.6, 0.0, 1.0))
			p = a.lerp(b, e)
			press = 1.0 if k > 0.1 and k < 0.8 else 0.0
			if k > 0.15 and k < 0.8:
				draw_line(a, p, Color(1, 1, 1, 0.6), 12.0, true)
		Mode.CIRCLE:
			var ang := _t * 2.4
			p = a + Vector2(cos(ang), sin(ang)) * radius
			press = 1.0
			draw_arc(a, radius, ang - 2.2, ang, 24, Color(1, 1, 1, 0.5), 12.0, true)
	_draw_hand(p, press)


func _draw_hand(p: Vector2, press: float) -> void:
	var skin := Color("ffd9b3")
	var line := Color("5a3c2e")
	var s := 1.0 - 0.08 * press
	draw_set_transform(p, 0.0, Vector2(s, s))
	# shadow
	draw_circle(Vector2(6, 46), 34, Color(0, 0, 0, 0.12))
	# fingertip at origin; finger goes down-right into the palm
	var finger := PackedVector2Array([Vector2(-14, 0), Vector2(14, 0), Vector2(18, 44), Vector2(-18, 44)])
	draw_colored_polygon(finger, skin)
	draw_circle(Vector2(0, 0), 14, skin)
	draw_arc(Vector2(0, 0), 14, PI, TAU, 16, line, 4.0, true)
	draw_line(Vector2(-14, 0), Vector2(-18, 44), line, 4.0, true)
	draw_line(Vector2(14, 0), Vector2(18, 44), line, 4.0, true)
	# palm + curled fingers
	draw_circle(Vector2(8, 70), 36, skin)
	draw_arc(Vector2(8, 70), 36, -0.2, PI + 0.6, 24, line, 4.0, true)
	for i in 3:
		var c := Vector2(30 + i * 10, 48 + i * 14)
		draw_circle(c, 11, skin)
		draw_arc(c, 11, -1.4, 1.2, 12, line, 4.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
