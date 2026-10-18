extends Node2D
## Air bubbles that rise out of the slime under a pressing finger, grow, and pop.

signal popped

const MAX := 18

var slime: Node2D
var _b: Array = []       # {p, r, rmax, t, life}
var _bursts: Array = []  # {p, r, t}


func spawn(px: Vector2) -> void:
	if _b.size() >= MAX:
		return
	var p := px + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 40.0
	var g: Vector2 = slime.to_grid_px(p)
	if slime.sample_height(g.x - 0.5, g.y - 0.5) < 0.12:
		return
	_b.append({"p": p, "r": 5.0, "rmax": randf_range(16.0, 34.0), "t": 0.0, "life": randf_range(0.7, 1.4)})


## Pop any bubble within `radius` px of `px` (a finger sweeping through).
func pop_near(px: Vector2, radius: float) -> void:
	for i in range(_b.size() - 1, -1, -1):
		if _b[i]["p"].distance_to(px) < radius + _b[i]["r"]:
			_pop(i)


func clear() -> void:
	_b.clear()
	_bursts.clear()
	queue_redraw()


func _pop(i: int) -> void:
	var b: Dictionary = _b[i]
	_bursts.append({"p": b["p"], "r": b["r"], "t": 0.0})
	_b.remove_at(i)
	popped.emit()


func _process(delta: float) -> void:
	for i in range(_b.size() - 1, -1, -1):
		var b: Dictionary = _b[i]
		b["t"] += delta
		var k: float = clampf(b["t"] / b["life"], 0.0, 1.0)
		b["r"] = lerpf(5.0, b["rmax"], 1.0 - (1.0 - k) * (1.0 - k))
		b["p"] += Vector2(sin(b["t"] * 7.0) * 0.3, -delta * 6.0)
		if b["t"] >= b["life"]:
			_pop(i)
	for i in range(_bursts.size() - 1, -1, -1):
		_bursts[i]["t"] += delta
		if _bursts[i]["t"] > 0.28:
			_bursts.remove_at(i)
	if not _b.is_empty() or not _bursts.is_empty():
		queue_redraw()


func _draw() -> void:
	for b in _b:
		var p: Vector2 = b["p"]
		var r: float = b["r"]
		draw_circle(p, r, Color(1, 1, 1, 0.10))
		draw_arc(p, r, 0.0, TAU, 28, Color(1, 1, 1, 0.55), 2.5, true)
		draw_arc(p, r * 0.82, 0.0, TAU, 28, Color(0, 0, 0, 0.08), 2.0, true)
		draw_circle(p + Vector2(-r * 0.4, -r * 0.4), r * 0.22, Color(1, 1, 1, 0.75))
	for s in _bursts:
		var k: float = s["t"] / 0.28
		var r: float = s["r"] * (1.0 + k * 0.9)
		draw_arc(s["p"], r, 0.0, TAU, 28, Color(1, 1, 1, 0.6 * (1.0 - k)), 3.0 * (1.0 - k) + 0.5, true)
		for j in 6:
			var a := TAU * j / 6.0 + k
			var q: Vector2 = s["p"] + Vector2(cos(a), sin(a)) * r * (1.0 + k * 0.6)
			draw_circle(q, 2.5 * (1.0 - k) + 0.5, Color(1, 1, 1, 0.7 * (1.0 - k)))
