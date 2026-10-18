extends Node2D
## A drop of colour that falls from the palette dot onto the lump, then splashes.

signal landed(col: Color, at: Vector2)

const FALL := 0.5
const SPLASH := 0.35

var color := Color.WHITE
var start := Vector2.ZERO
var target := Vector2.ZERO
var _t := 0.0
var _landed := false


func _process(delta: float) -> void:
	_t += delta
	if not _landed and _t >= FALL:
		_landed = true
		_t = 0.0
		position = target
		landed.emit(color, target)
	elif _landed and _t >= SPLASH:
		queue_free()
		return
	if not _landed:
		var k := _t / FALL
		var e := k * k   # accelerating fall
		position = start.lerp(target, e) + Vector2(0, -sin(k * PI) * 140.0)
	queue_redraw()


func _draw() -> void:
	if not _landed:
		var k := _t / FALL
		var r := lerpf(22.0, 46.0, k)
		var stretch := 1.0 + 0.5 * sin(k * PI)
		# tail
		var tail := PackedVector2Array([Vector2(-r * 0.5, 0), Vector2(0, -r * 1.6 * stretch), Vector2(r * 0.5, 0)])
		draw_colored_polygon(tail, color)
		draw_circle(Vector2.ZERO, r, color)
		draw_circle(Vector2(-r * 0.35, -r * 0.3), r * 0.3, Color(1, 1, 1, 0.6))
		draw_circle(Vector2(0, r * 0.15), r * 0.9, Color(0, 0, 0, 0.0))
	else:
		var k := _t / SPLASH
		var a := 1.0 - k
		draw_arc(Vector2.ZERO, 60.0 + 110.0 * k, 0.0, TAU, 40, Color(color.r, color.g, color.b, 0.95 * a), 16.0 * a + 1.0, true)
		draw_arc(Vector2.ZERO, 30.0 + 60.0 * k, 0.0, TAU, 40, Color(1, 1, 1, 0.8 * a), 8.0 * a + 1.0, true)
		for j in 8:
			var ang := TAU * j / 8.0 + 0.3
			var q := Vector2(cos(ang), sin(ang)) * (50.0 + 120.0 * k)
			draw_circle(q + Vector2(0, -40.0 * sin(k * PI)), 7.0 * a + 1.0, Color(color.r, color.g, color.b, a))
