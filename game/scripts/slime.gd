extends Node2D
class_name Slime
## A 2D soft-body blob (position-based dynamics on a ring of points) that kids
## can poke, smear, pinch and stretch with any number of fingers.
##
## Simulation runs at the physics tick (60 Hz) with SUBSTEPS sub-steps so it
## behaves identically on a 60 Hz Fire tablet and a 120 Hz Google tablet.

signal touched(inside: bool)
signal released(inside: bool)

const N := 64
const SUBSTEPS := 4
const ITERS := 3

@export var radius := 250.0
@export var damping := 0.975          ## velocity kept per sub-step
@export var heal := 0.010             ## pull toward the rest circle per sub-step (shape memory)
@export var area_k := 0.55            ## how hard the blob keeps its area (bulges when squeezed)
@export var edge_k := 0.85
@export var bend_k := 0.35
@export var finger_radius := 48.0     ## size of a finger that pushes the edge from outside
@export var smear_radius := 240.0     ## reach of a finger dragging from inside
@export var play_area := Rect2(80, 80, 1660, 1040)  ## points are clamped inside this (canvas coords)

var color: Color = Color("6fe36a"):
	set(v):
		color = v
		_apply_colors()
var sparkle := false:
	set(v):
		sparkle = v
		if is_node_ready():
			_glitter.visible = v

var _p := PackedVector2Array()
var _pp := PackedVector2Array()
var _rest := PackedVector2Array()
var _rest_area := 0.0
var _l1 := 0.0
var _l2 := 0.0
var _fingers := {}  # touch index -> {pos, prev, inside, dent}
var _time := 0.0

var _shadow: Polygon2D
var _body: Polygon2D
var _inner: Polygon2D
var _highlight: Polygon2D
var _spec: Polygon2D
var _dents: Node2D
var _glitter: Sprite2D
var _dent_tex: GradientTexture2D


func _ready() -> void:
	_build_nodes()
	reset()


func _build_nodes() -> void:
	_shadow = Polygon2D.new()
	_shadow.name = "Shadow"
	_shadow.position = Vector2(10, 16)
	add_child(_shadow)

	_body = Polygon2D.new()
	_body.name = "Body"
	_body.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	add_child(_body)

	_inner = Polygon2D.new()
	_inner.name = "Inner"
	_body.add_child(_inner)

	_highlight = Polygon2D.new()
	_highlight.name = "Highlight"
	_highlight.position = Vector2(-26, -34)
	_body.add_child(_highlight)

	_spec = Polygon2D.new()
	_spec.name = "Specular"
	_body.add_child(_spec)

	_dents = Node2D.new()
	_dents.name = "Dents"
	_body.add_child(_dents)

	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0.32), Color(0, 0, 0, 0.10), Color(0, 0, 0, 0)])
	_dent_tex = GradientTexture2D.new()
	_dent_tex.gradient = g
	_dent_tex.fill = GradientTexture2D.FILL_RADIAL
	_dent_tex.fill_from = Vector2(0.5, 0.5)
	_dent_tex.fill_to = Vector2(0.5, 0.0)
	_dent_tex.width = 128
	_dent_tex.height = 128

	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.08
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.08, 0.14, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0), Color(1, 1, 1, 0)])
	var ntex := NoiseTexture2D.new()
	ntex.noise = noise
	ntex.color_ramp = ramp
	ntex.width = 256
	ntex.height = 256
	ntex.seamless = true
	_glitter = Sprite2D.new()
	_glitter.name = "Glitter"
	_glitter.texture = ntex
	_glitter.region_enabled = true
	_glitter.region_rect = Rect2(0, 0, 1024, 1024)
	_glitter.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glitter.material = mat
	_glitter.modulate = Color(1, 1, 1, 0.8)
	_glitter.visible = sparkle
	_body.add_child(_glitter)

	_apply_colors()


func _apply_colors() -> void:
	if _body == null:
		return
	_shadow.color = Color(0, 0, 0, 0.18)
	_body.color = color.darkened(0.22)
	_inner.color = color
	_highlight.color = Color(1, 1, 1, 0.22)
	_spec.color = Color(1, 1, 1, 0.55)


## Put a fresh round blob in the middle of the play area, with a little wobble.
func reset() -> void:
	_p.resize(N)
	_pp.resize(N)
	_rest.resize(N)
	var c := play_area.get_center()
	for i in N:
		var a := TAU * i / N
		var r := Vector2(cos(a), sin(a)) * radius
		_rest[i] = r
		_p[i] = c + r * 1.12
		_pp[i] = c + r * 1.0
	_l1 = _rest[0].distance_to(_rest[1])
	_l2 = _rest[0].distance_to(_rest[2])
	_rest_area = _area(_rest)
	for d in _dents.get_children():
		d.queue_free()
	_fingers.clear()


func wobble(strength := 0.08) -> void:
	var c := _centroid(_p)
	for i in N:
		_pp[i] = c + (_pp[i] - c) * (1.0 - strength)


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var pos: Vector2 = make_canvas_position_local(event.position)
		if event.pressed:
			var inside := Geometry2D.is_point_in_polygon(pos, _p)
			var f := {"pos": pos, "prev": pos, "inside": inside, "dent": null, "trail": pos}
			if inside:
				f["dent"] = _spawn_dent(pos)
			_fingers[event.index] = f
			touched.emit(inside)
		else:
			if _fingers.has(event.index):
				var f: Dictionary = _fingers[event.index]
				if f["dent"] != null:
					_fade_dent(f["dent"])
				_fingers.erase(event.index)
				released.emit(f["inside"])
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if _fingers.has(event.index):
			var f: Dictionary = _fingers[event.index]
			var pos: Vector2 = make_canvas_position_local(event.position)
			f["pos"] = pos
			if f["dent"] != null:
				f["dent"].position = pos
				if pos.distance_to(f["trail"]) > 34.0:
					f["trail"] = pos
					_fade_dent(_spawn_dent(pos), 0.9)
			get_viewport().set_input_as_handled()


func _spawn_dent(pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _dent_tex
	s.position = pos
	s.scale = Vector2.ONE * (finger_radius * 2.6 / 128.0)
	_dents.add_child(s)
	return s


func _fade_dent(s: Sprite2D, seconds := 1.6) -> void:
	var t := create_tween()
	t.tween_property(s, "modulate:a", 0.0, seconds).set_ease(Tween.EASE_IN)
	t.tween_callback(s.queue_free)


# ---------------------------------------------------------------- simulation

func _physics_process(_delta: float) -> void:
	for f in _fingers.values():
		f["step"] = (f["pos"] - f["prev"]) / SUBSTEPS
	for _s in SUBSTEPS:
		_integrate()
		for f in _fingers.values():
			_apply_finger(f)
		for _k in ITERS:
			_solve_edges()
			_solve_area()
			_solve_shape()
			_solve_bounds()
			for f in _fingers.values():
				if not f["inside"]:
					_apply_finger(f)
	for f in _fingers.values():
		f["prev"] = f["pos"]


func _integrate() -> void:
	for i in N:
		var v := (_p[i] - _pp[i]) * damping
		_pp[i] = _p[i]
		_p[i] += v


func _apply_finger(f: Dictionary) -> void:
	var fp: Vector2 = f["prev"] + f["step"] * SUBSTEPS if false else f["pos"]
	if f["inside"]:
		var step: Vector2 = f["step"]
		if step == Vector2.ZERO:
			return
		for i in N:
			var d := _p[i].distance_to(fp)
			if d < smear_radius:
				var w := 1.0 - d / smear_radius
				w = w * w * (3.0 - 2.0 * w)
				_p[i] += step * w
				_pp[i] += step * w * 0.55
	else:
		for i in N:
			var d := _p[i] - fp
			var l := d.length()
			if l < finger_radius and l > 0.001:
				_p[i] = fp + d / l * finger_radius


func _solve_edges() -> void:
	for i in N:
		_distance(i, (i + 1) % N, _l1, edge_k)
	for i in N:
		_distance(i, (i + 2) % N, _l2, bend_k)


func _distance(a: int, b: int, rest_len: float, k: float) -> void:
	var d := _p[b] - _p[a]
	var l := d.length()
	if l < 0.0001:
		return
	var corr := d / l * (l - rest_len) * 0.5 * k
	_p[a] += corr
	_p[b] -= corr


func _solve_area() -> void:
	var c := _area(_p) - _rest_area
	var grads := PackedVector2Array()
	grads.resize(N)
	var denom := 0.0
	for i in N:
		var nxt := _p[(i + 1) % N]
		var prv := _p[(i - 1 + N) % N]
		var g := Vector2(nxt.y - prv.y, prv.x - nxt.x) * 0.5
		grads[i] = g
		denom += g.length_squared()
	if denom < 0.0001:
		return
	var lam := -c / denom * area_k
	for i in N:
		_p[i] += grads[i] * lam


func _solve_shape() -> void:
	var c := _centroid(_p)
	for i in N:
		_p[i] += (c + _rest[i] - _p[i]) * heal


func _solve_bounds() -> void:
	var r := play_area
	for i in N:
		_p[i].x = clampf(_p[i].x, r.position.x, r.end.x)
		_p[i].y = clampf(_p[i].y, r.position.y, r.end.y)


static func _area(pts: PackedVector2Array) -> float:
	var a := 0.0
	var n := pts.size()
	for i in n:
		var j := (i + 1) % n
		a += pts[i].x * pts[j].y - pts[j].x * pts[i].y
	return absf(a) * 0.5


static func _centroid(pts: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for q in pts:
		c += q
	return c / pts.size()


# ---------------------------------------------------------------- rendering

func _process(delta: float) -> void:
	_time += delta
	var outline := _chaikin(_chaikin(_p))
	_shadow.polygon = outline
	_body.polygon = outline
	_set_multi(_inner, Geometry2D.offset_polygon(outline, -22.0, Geometry2D.JOIN_ROUND))
	_set_multi(_highlight, Geometry2D.offset_polygon(outline, -70.0, Geometry2D.JOIN_ROUND))
	var c := _centroid(_p)
	var bb := _bounds(outline)
	var spec_c := Vector2(lerpf(bb.position.x, bb.end.x, 0.32), lerpf(bb.position.y, bb.end.y, 0.28))
	_spec.polygon = _ellipse(spec_c, Vector2(bb.size.x * 0.11, bb.size.y * 0.06), -0.5)
	if sparkle:
		_glitter.position = c
		_glitter.region_rect.position = Vector2(sin(_time * 0.7) * 40.0, cos(_time * 0.9) * 40.0)
		_glitter.modulate.a = 0.55 + 0.35 * sin(_time * 3.0)


static func _chaikin(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	out.resize(n * 2)
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		out[i * 2] = a * 0.75 + b * 0.25
		out[i * 2 + 1] = a * 0.25 + b * 0.75
	return out


static func _set_multi(poly: Polygon2D, parts: Array) -> void:
	if parts.is_empty():
		poly.polygon = PackedVector2Array()
		poly.polygons = []
		return
	var verts := PackedVector2Array()
	var idx := []
	for part in parts:
		var base := verts.size()
		verts.append_array(part)
		var ids := PackedInt32Array()
		ids.resize(part.size())
		for k in part.size():
			ids[k] = base + k
		idx.append(ids)
	poly.polygon = verts
	poly.polygons = idx


static func _ellipse(center: Vector2, r: Vector2, rot: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24
		out.append(center + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot))
	return out


static func _bounds(pts: PackedVector2Array) -> Rect2:
	var r := Rect2(pts[0], Vector2.ZERO)
	for q in pts:
		r = r.expand(q)
	return r
