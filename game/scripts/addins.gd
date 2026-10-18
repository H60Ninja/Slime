extends Node2D
## Beads and stars sprinkled onto the slime. They ride along when the slime is
## smeared and get pushed aside by a pressing finger.

enum Kind { BEAD, STAR }
const MAX := 70

var slime: Node2D   # set by Slime
var _items: Array = []  # {p: Vector2 (grid), kind: int, col: Color, rot: float, size: float}


func clear() -> void:
	_items.clear()
	queue_redraw()


## Sprinkle n items of a kind onto cells that have slime.
func sprinkle(kind: int, n: int) -> void:
	var spots: Array[Vector2] = slime.slime_cells(0.25)
	if spots.is_empty():
		return
	for _k in n:
		if _items.size() >= MAX:
			_items.pop_front()
		var c: Vector2 = spots.pick_random() + Vector2(randf(), randf())
		var col: Color
		if kind == Kind.BEAD:
			col = Color.from_hsv(randf(), 0.45, 1.0)
		else:
			col = [Color("ffd84d"), Color("ffffff"), Color("ff9ad5"), Color("7fe3ff")].pick_random()
		_items.append({"p": c, "kind": kind, "col": col, "rot": randf() * TAU, "size": randf_range(0.85, 1.15)})
	queue_redraw()


## Carry items with a smearing finger (same falloff as the slime).
func advect(c: Vector2, v: Vector2, r: float) -> void:
	var r2 := r * r
	for it in _items:
		var d2: float = it["p"].distance_squared_to(c)
		if d2 < r2:
			var w := 1.0 - d2 / r2
			w = w * w * (3.0 - 2.0 * w)
			it["p"] += v * w
			it["rot"] += v.length() * 0.3 * w
			_clamp(it)


## Push items out from under a pressing finger toward its rim.
func push_out(c: Vector2, r: float) -> void:
	for it in _items:
		var d: Vector2 = it["p"] - c
		var l := d.length()
		if l < r * 1.15:
			var dir := d / l if l > 0.001 else Vector2.RIGHT.rotated(randf() * TAU)
			it["p"] = it["p"].lerp(c + dir * r * 1.4, 0.25)
			_clamp(it)


func _clamp(it: Dictionary) -> void:
	it["p"] = Vector2(clampf(it["p"].x, 0.5, slime.GW - 1.5), clampf(it["p"].y, 0.5, slime.GH - 1.5))


func _process(_delta: float) -> void:
	if not _items.is_empty():
		queue_redraw()


func _draw() -> void:
	var cell: Vector2 = slime.cell_size()
	var origin: Vector2 = slime.play_area.position
	for it in _items:
		var gp: Vector2 = it["p"]
		var h: float = slime.sample_height(gp.x - 0.5, gp.y - 0.5)
		var px := origin + gp * cell
		var on := clampf(h / 0.08, 0.0, 1.0)         # fades when it ends up on bare table
		var sink := clampf((h - 0.15) / 0.9, 0.0, 1.0)  # how deep it sits in thick slime
		var size: float = it["size"] * (0.75 + 0.25 * on)
		var col: Color = it["col"]
		col.a = 0.55 + 0.45 * on
		var slime_col: Color = slime.sample_color(gp.x - 0.5, gp.y - 0.5)
		if it["kind"] == Kind.BEAD:
			var rr := 12.0 * size
			# dimple in the slime around a sunk bead
			draw_circle(px, rr * (1.0 + 0.35 * sink), Color(slime_col.r * 0.55, slime_col.g * 0.55, slime_col.b * 0.55, 0.35 * sink))
			draw_circle(px + Vector2(2, 3), rr, Color(0, 0, 0, 0.12 * on * (1.0 - sink)))
			draw_circle(px, rr, col)
			draw_circle(px + Vector2(-rr * 0.35, -rr * 0.35), rr * 0.36, Color(1, 1, 1, 0.65 * col.a))
			# translucent slime covering the lower part of the bead
			var cover := Color(slime_col.r, slime_col.g, slime_col.b, 0.4 * sink)
			draw_circle(px + Vector2(0, rr * 0.25), rr * 1.02, cover)
			draw_arc(px, rr * 1.02, 0.0, TAU, 24, Color(1, 1, 1, 0.25 * sink), 1.5, true)
		else:
			var pts := PackedVector2Array()
			for i in 10:
				var rad := (16.0 if i % 2 == 0 else 7.0) * size
				var a: float = it["rot"] + TAU * i / 10.0
				pts.append(px + Vector2(cos(a), sin(a)) * rad)
			draw_colored_polygon(pts, col)
			if sink > 0.0:
				draw_colored_polygon(pts, Color(slime_col.r, slime_col.g, slime_col.b, 0.4 * sink))
