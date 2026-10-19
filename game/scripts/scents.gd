extends Node2D
## Scented slime: little fruit/candy puffs drift up from wherever the kids touch.

const KINDS := ["strawberry", "lemon", "blueberry", "mint", "chocolate", "bubblegum"]

var scent := ""   # "" = unscented
var _p: Array = []   # {pos, vel, t, life, rot, size}


func puff(px: Vector2, n := 2) -> void:
	if scent == "":
		return
	for _k in n:
		if _p.size() > 40:
			_p.pop_front()
		_p.append({"pos": px + Vector2(randf_range(-30, 30), randf_range(-10, 10)),
				   "vel": Vector2(randf_range(-25, 25), randf_range(-95, -60)),
				   "t": 0.0, "life": randf_range(1.2, 1.9), "rot": randf_range(-0.5, 0.5),
				   "size": randf_range(0.8, 1.2)})


func _process(delta: float) -> void:
	for i in range(_p.size() - 1, -1, -1):
		var q: Dictionary = _p[i]
		q["t"] += delta
		q["pos"] += q["vel"] * delta
		q["vel"].x += sin(q["t"] * 5.0) * 40.0 * delta
		if q["t"] >= q["life"]:
			_p.remove_at(i)
	if not _p.is_empty():
		queue_redraw()


## Draws one scent icon of ~24px radius at the origin of the current transform.
static func draw_icon(c: CanvasItem, kind: String, s := 1.0) -> void:
	match kind:
		"strawberry":
			var pts := PackedVector2Array()
			for i in 20:
				var a := TAU * i / 20.0
				var r := 22.0 * s * (1.0 - 0.25 * maxf(0.0, sin(a)))
				pts.append(Vector2(cos(a) * r * 0.9, sin(a) * r + 4 * s))
			c.draw_colored_polygon(pts, Color("ff4d6d"))
			for q in [Vector2(-8, 2), Vector2(6, -2), Vector2(-2, 12), Vector2(9, 10)]:
				c.draw_circle(q * s, 2.2 * s, Color("ffe8a3"))
			c.draw_colored_polygon(PackedVector2Array([Vector2(-14, -14) * s, Vector2(0, -22) * s, Vector2(14, -14) * s, Vector2(0, -8) * s]), Color("5fd36a"))
		"lemon":
			var pts := PackedVector2Array()
			for i in 20:
				var a := TAU * i / 20.0
				pts.append(Vector2(cos(a) * 24.0, sin(a) * 16.0) * s)
			pts.append(Vector2(29, 0) * s)
			c.draw_colored_polygon(Geometry2D.convex_hull(pts), Color("ffe44d"))
			c.draw_circle(Vector2(-8, -5) * s, 4.0 * s, Color(1, 1, 1, 0.7))
		"blueberry":
			c.draw_circle(Vector2.ZERO, 20.0 * s, Color("4a5fd6"))
			c.draw_circle(Vector2(0, -6) * s, 6.0 * s, Color("2c3a8c"))
			c.draw_circle(Vector2(-7, -8) * s, 4.0 * s, Color(1, 1, 1, 0.6))
		"mint":
			var leaf := PackedVector2Array([Vector2(0, -24), Vector2(16, -8), Vector2(10, 18), Vector2(0, 24), Vector2(-10, 18), Vector2(-16, -8)])
			for i in leaf.size():
				leaf[i] *= s
			c.draw_colored_polygon(leaf, Color("5fd3a0"))
			c.draw_line(Vector2(0, -20) * s, Vector2(0, 20) * s, Color("2e8f6a"), 3.0 * s, true)
		"chocolate":
			c.draw_rect(Rect2(Vector2(-22, -16) * s, Vector2(44, 32) * s), Color("7a4a2a"))
			c.draw_rect(Rect2(Vector2(-18, -12) * s, Vector2(16, 10) * s), Color("9a6a46"))
			c.draw_rect(Rect2(Vector2(2, -12) * s, Vector2(16, 10) * s), Color("9a6a46"))
			c.draw_rect(Rect2(Vector2(-18, 2) * s, Vector2(16, 10) * s), Color("9a6a46"))
			c.draw_rect(Rect2(Vector2(2, 2) * s, Vector2(16, 10) * s), Color("9a6a46"))
		"bubblegum":
			c.draw_circle(Vector2.ZERO, 22.0 * s, Color("ff8fcf"))
			c.draw_arc(Vector2.ZERO, 14.0 * s, 0.0, 4.2, 20, Color("ffffff"), 5.0 * s, true)
			c.draw_circle(Vector2(-8, -8) * s, 5.0 * s, Color(1, 1, 1, 0.8))
		_:
			# none: a crossed-out nose-ish wave
			c.draw_arc(Vector2(-10, 0), 10.0 * s, PI, TAU, 12, Color("8a8fa8"), 5.0 * s, true)
			c.draw_arc(Vector2(10, 0), 10.0 * s, 0.0, PI, 12, Color("8a8fa8"), 5.0 * s, true)
			c.draw_line(Vector2(-22, 22) * s, Vector2(22, -22) * s, Color("ff6b6b"), 6.0 * s, true)


func _draw() -> void:
	for q in _p:
		var k: float = q["t"] / q["life"]
		var shrink: float = 1.0 - smoothstep(0.65, 1.0, k)   # pops away at the end of its life
		draw_set_transform(q["pos"], q["rot"] + sin(q["t"] * 4.0) * 0.2, Vector2.ONE * (0.6 * q["size"] * (0.8 + 0.3 * k) * shrink))
		draw_circle(Vector2.ZERO, 30.0, Color(1, 1, 1, 0.3))
		draw_icon(self, scent, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
