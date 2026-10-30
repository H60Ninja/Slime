extends Node2D
class_name Slime
## A lump of slime on a table, simulated as a thickness field on a coarse grid with a
## colour per cell. Fingers press (crater + rim), smear (carry slime and colour along
## the stroke), pile up and spread. Shapes persist and slump only slowly. Total slime
## is conserved, so it can never be lost. A shader lights the surface from its slopes.

signal touched(inside: bool)
signal released(inside: bool)
signal stretched          ## a fast drag through slime (sound hook)
signal held               ## finger held still on slime for a moment (sound hook)
signal style_changed(style: String)
signal kneading(speed: float)   ## every physics tick: fastest finger speed on slime (0 when idle)
signal sliced
signal touch_at(px: Vector2)     ## finger down on slime (local px)
signal knead_at(px: Vector2)     ## throttled: a finger moving on slime (local px)

var GW := 80
var GH := 52
const UNIFORMS := ["spec_k", "spec_pow", "alpha_k", "clear_k", "metal", "matte", "crunch", "fluff", "thick_px", "glow", "holo"]
const STYLES := {
	"shiny":   {"spec_k": 0.5,  "spec_pow": 70.0, "alpha_k": 1.0,  "clear_k": 0.0, "metal": 0.0, "matte": 0.0,  "crunch": 0.0, "fluff": 0.0, "thick_px": 230.0},
	"clear":   {"spec_k": 0.8,  "spec_pow": 90.0, "alpha_k": 0.68, "clear_k": 1.0, "metal": 0.0, "matte": 0.0,  "crunch": 0.0, "fluff": 0.0, "thick_px": 230.0},
	"metal":   {"spec_k": 1.1,  "spec_pow": 36.0, "alpha_k": 1.0,  "clear_k": 0.0, "metal": 1.0, "matte": 0.0,  "crunch": 0.0, "fluff": 0.0, "thick_px": 230.0},
	"cloud":   {"spec_k": 0.12, "spec_pow": 16.0, "alpha_k": 1.0,  "clear_k": 0.0, "metal": 0.0, "matte": 1.0,  "crunch": 0.0, "fluff": 0.0, "thick_px": 230.0},
	"crunchy": {"spec_k": 0.45, "spec_pow": 50.0, "alpha_k": 1.0,  "clear_k": 0.0, "metal": 0.0, "matte": 0.1,  "crunch": 1.0, "fluff": 0.0, "thick_px": 230.0,
				"smear": 0.8, "slump": 0.7, "press": 0.8},
	"butter":  {"spec_k": 0.15, "spec_pow": 12.0, "alpha_k": 1.0,  "clear_k": 0.0, "metal": 0.0, "matte": 0.75, "crunch": 0.0, "fluff": 0.0, "thick_px": 200.0,
				"smear": 1.15, "slump": 3.0, "press": 1.3},
	"fluffy":  {"spec_k": 0.2,  "spec_pow": 20.0, "alpha_k": 1.0,  "clear_k": 0.0, "metal": 0.0, "matte": 0.55, "crunch": 0.0, "fluff": 1.0, "thick_px": 330.0,
				"smear": 0.8, "slump": 0.6, "press": 1.4},
	"glow":    {"spec_k": 0.6,  "spec_pow": 60.0, "alpha_k": 1.0,  "clear_k": 0.0, "metal": 0.0, "matte": 0.0,  "crunch": 0.0, "fluff": 0.0, "thick_px": 230.0, "glow": 1.0, "holo": 0.0},
	"holo":    {"spec_k": 1.0,  "spec_pow": 40.0, "alpha_k": 1.0,  "clear_k": 0.0, "metal": 0.6, "matte": 0.0,  "crunch": 0.0, "fluff": 0.0, "thick_px": 230.0, "glow": 0.0, "holo": 1.0},
	"magic":   {"spec_k": 0.5,  "spec_pow": 70.0, "alpha_k": 1.0,  "clear_k": 0.0, "metal": 0.0, "matte": 0.0,  "crunch": 0.0, "fluff": 0.0, "thick_px": 230.0, "glow": 0.0, "holo": 0.0,
				"hue_drift": 1.0},
}

@export var play_area := Rect2(70, 70, 1630, 1060):
	set(v):
		play_area = v
		_layout()
@export var mound_radius := 330.0      ## px, starting lump
@export var finger_px := 58.0          ## finger radius in px
@export var press_rate := 0.045        ## fraction of thickness pushed out per tick while pressing
@export var smear_strength := 0.9      ## how much of the finger motion the slime follows
@export var slump := 0.0012            ## diffusion per tick (lower = holds shapes longer)
@export var mix_rate := 0.03           ## colour blending per relax step (kneading mixes colours)
@export var h_cap := 2.6               ## max thickness (peaks)
@export var drop_px := 140.0           ## radius of a colour drop
@export var max_growth := 2.4          ## the lump can grow to this many times its starting amount
@export var stamp_px := 170.0          ## radius of a cookie-cutter stamp

var color: Color = Color("6fe36a")     ## selected colour (used by drops and new lumps)
var sparkle := false:
	set(v):
		sparkle = v
		if _mat:
			_mat.set_shader_parameter("sparkle", 1.0 if v else 0.0)
var style := "shiny":
	set(v):
		if not STYLES.has(v):
			return
		style = v
		_smear_mult = STYLES[v].get("smear", 1.0)
		_slump_mult = STYLES[v].get("slump", 1.0)
		_press_mult = STYLES[v].get("press", 1.0)
		_hue_drift = STYLES[v].get("hue_drift", 0.0)
		if _hue_drift == 0.0:
			_hue = 0.0
		if _mat:
			for k in UNIFORMS:
				_mat.set_shader_parameter(k, STYLES[v].get(k, 0.0))
			_mat.set_shader_parameter("hue_shift", _hue)
		style_changed.emit(v)

var addins: Node2D
var bubbles: Node2D

var _h := PackedFloat32Array()
var _tmp := PackedFloat32Array()
var _c := PackedFloat32Array()     # per cell: Kubelka-Munk K/S for r,g,b (paint-like mixing)
var _ctmp := PackedFloat32Array()
var _mass0 := 0.0
var _mass_base := 0.0   # amount in a fresh lump; growth cap is relative to this
var _undo: Array = []
var _cell := Vector2(20, 20)
var _fingers := {}  # index -> {pos, prev, ticks, still, moved}
var _tick := 0
var _time := 0.0
var _wobble := 0.0
var _stretch_cd := 0.0
var _smear_mult := 1.0
var _slump_mult := 1.0
var _press_mult := 1.0
var _hue_drift := 0.0
var _hue := 0.0
var _knead_speed := 0.0

var _rect: ColorRect
var _mat: ShaderMaterial
var _img: Image
var _tex: ImageTexture
var _cimg: Image
var _ctex: ImageTexture


func _ready() -> void:
	_h.resize(GW * GH)
	_tmp.resize(GW * GH)
	_c.resize(GW * GH * 3)
	_ctmp.resize(GW * GH * 3)
	_rect = ColorRect.new()
	_rect.name = "Surface"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/slime.gdshader")
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.06
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	var ntex := NoiseTexture2D.new()
	ntex.noise = noise
	ntex.width = 256
	ntex.height = 256
	ntex.seamless = true
	ntex.invert = true
	_mat.set_shader_parameter("noise_tex", ntex)
	_mat.set_shader_parameter("grid", Vector2(GW, GH))
	_mat.set_shader_parameter("sparkle", 1.0 if sparkle else 0.0)
	_rect.material = _mat
	add_child(_rect)
	_img = Image.create_empty(GW, GH, false, Image.FORMAT_RF)
	_tex = ImageTexture.create_from_image(_img)
	_cimg = Image.create_empty(GW, GH, false, Image.FORMAT_RGBF)
	_ctex = ImageTexture.create_from_image(_cimg)
	_mat.set_shader_parameter("height_tex", _tex)
	_mat.set_shader_parameter("color_tex", _ctex)
	addins = load("res://scripts/addins.gd").new()
	addins.name = "Addins"
	addins.slime = self
	add_child(addins)
	bubbles = load("res://scripts/bubbles.gd").new()
	bubbles.name = "Bubbles"
	bubbles.slime = self
	add_child(bubbles)
	style = style
	_layout()
	reset()


func _layout() -> void:
	if _rect == null:
		return
	var want_w := 80 if play_area.size.x >= play_area.size.y else 52
	var want_h := 52 if play_area.size.x >= play_area.size.y else 80
	if want_w != GW:
		_transpose_grid(want_w, want_h)
	_rect.position = play_area.position
	_rect.size = play_area.size
	_cell = Vector2(play_area.size.x / GW, play_area.size.y / GH)
	_mat.set_shader_parameter("cell_px", _cell)
	_mat.set_shader_parameter("grid", Vector2(GW, GH))


## Rotate the tablet: swap grid axes, carrying the slime over (transposed).
func _transpose_grid(w: int, h: int) -> void:
	var oh := PackedFloat32Array()
	var oc := PackedFloat32Array()
	oh.resize(w * h)
	oc.resize(w * h * 3)
	if _h.size() == GW * GH and _h.size() > 0:
		for y in h:
			for x in w:
				var i := y * w + x
				var j := x * GW + y   # old (x=y, y=x)
				oh[i] = _h[j]
				oc[i * 3] = _c[j * 3]
				oc[i * 3 + 1] = _c[j * 3 + 1]
				oc[i * 3 + 2] = _c[j * 3 + 2]
	GW = w
	GH = h
	_h = oh
	_c = oc
	_tmp.resize(w * h)
	_ctmp.resize(w * h * 3)
	_img = Image.create_empty(GW, GH, false, Image.FORMAT_RF)
	_tex = ImageTexture.create_from_image(_img)
	_cimg = Image.create_empty(GW, GH, false, Image.FORMAT_RGBF)
	_ctex = ImageTexture.create_from_image(_cimg)
	_mat.set_shader_parameter("height_tex", _tex)
	_mat.set_shader_parameter("color_tex", _ctex)
	if addins:
		addins.transpose()
	if bubbles:
		bubbles.clear()


func cell_size() -> Vector2:
	return _cell


## Local pixel position -> grid coordinates.
func to_grid_px(p: Vector2) -> Vector2:
	var q := p - play_area.position
	return Vector2(q.x / _cell.x, q.y / _cell.y)


## Grid coordinates -> local pixel position.
func to_px(g: Vector2) -> Vector2:
	return play_area.position + Vector2(g.x * _cell.x, g.y * _cell.y)


## Where a poured drop should land (local px).
func drop_target() -> Vector2:
	return to_px(_centroid())


## Fresh round mound of the selected colour in the middle of the table.
func reset() -> void:
	var c := Vector2(GW * 0.5, GH * 0.5)
	var rx := mound_radius / _cell.x
	var ry := mound_radius / _cell.y
	for y in GH:
		for x in GW:
			var dx := (x + 0.5 - c.x) / rx
			var dy := (y + 0.5 - c.y) / ry
			var d2 := dx * dx + dy * dy
			var d := sqrt(d2)
			# cosine dome: rounded top, zero slope at the foot (no shelf, no scalloped edge)
			_h[y * GW + x] = 0.95 * pow(0.5 + 0.5 * cos(PI * d), 0.55) if d < 1.0 else 0.0
	var ks := to_ks(color)
	for i in GW * GH:
		_c[i * 3] = ks.x
		_c[i * 3 + 1] = ks.y
		_c[i * 3 + 2] = ks.z
	_mass0 = _sum(_h)
	_mass_base = _mass0
	_fingers.clear()
	_wobble = 1.0
	if addins:
		addins.clear()
	if bubbles:
		bubbles.clear()


## Pour more slime (glue) onto the lump: a mound lands at the centroid and the whole
## lump gets bigger. Capped at max_growth times a fresh lump. Returns false when full.
func add_glue(amount := 0.18) -> bool:
	if _mass0 >= _mass_base * max_growth - 0.001:
		_wobble = 0.5
		return false
	var c := _centroid()
	# footprint radius from the area that currently has slime, then a little beyond it
	var cells := 0
	for v in _h:
		if v > 0.05:
			cells += 1
	var r := maxf(drop_px / _cell.x, sqrt(cells / PI) * 1.12)
	var r2 := r * r
	var want := _mass_base * amount
	var x0 := maxi(0, int(c.x - r))
	var x1 := mini(GW - 1, int(c.x + r) + 1)
	var y0 := maxi(0, int(c.y - r))
	var y1 := mini(GH - 1, int(c.y + r) + 1)
	var wsum := 0.0
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx := x + 0.5 - c.x
			var dy := y + 0.5 - c.y
			var d2 := dx * dx + dy * dy
			if d2 < r2:
				var w := pow(1.0 - d2 / r2, 0.7)
				wsum += w
	if wsum <= 0.0:
		return false
	var per := want / wsum
	var ks := to_ks(color)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx := x + 0.5 - c.x
			var dy := y + 0.5 - c.y
			var d2 := dx * dx + dy * dy
			if d2 < r2:
				var w := pow(1.0 - d2 / r2, 0.7)
				var i := y * GW + x
				var add := per * w
				var old := _h[i]
				_h[i] = minf(h_cap, old + add)
				# new glue carries the current colour; blend by how much it adds
				var blend := add / maxf(0.001, old + add) * 0.8
				_c[i * 3] = lerpf(_c[i * 3], ks.x, blend)
				_c[i * 3 + 1] = lerpf(_c[i * 3 + 1], ks.y, blend)
				_c[i * 3 + 2] = lerpf(_c[i * 3 + 2], ks.z, blend)
	_mass0 = minf(_sum(_h), _mass_base * max_growth)
	_wobble = 0.9
	return true


func growth() -> float:
	return _mass0 / maxf(0.001, _mass_base)


## Pour a drop of the selected colour onto the lump (adds a little slime too).
func drop(col: Color, offset := Vector2.ZERO) -> void:
	color = col
	var ks := to_ks(col)
	var c := _centroid() + offset
	var r := drop_px / _cell.x
	var r2 := r * r
	var x0 := maxi(0, int(c.x - r))
	var x1 := mini(GW - 1, int(c.x + r) + 1)
	var y0 := maxi(0, int(c.y - r))
	var y1 := mini(GH - 1, int(c.y + r) + 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx := x + 0.5 - c.x
			var dy := y + 0.5 - c.y
			var d2 := dx * dx + dy * dy
			if d2 < r2:
				var w := 1.0 - d2 / r2
				var i := y * GW + x
				var blend := minf(1.0, w * 2.4)
				_c[i * 3] = lerpf(_c[i * 3], ks.x, blend)
				_c[i * 3 + 1] = lerpf(_c[i * 3 + 1], ks.y, blend)
				_c[i * 3 + 2] = lerpf(_c[i * 3 + 2], ks.z, blend)
				_h[i] = minf(h_cap, _h[i] + 0.45 * w * w)
	_mass0 = _sum(_h)
	_wobble = 0.8


## Press a cookie-cutter shape ("star" or "heart") into the lump: the inside is pushed
## down and the displaced slime piles into a rim just outside the outline.
func stamp(shape: String) -> void:
	var poly := _shape_polygon(shape, stamp_px / _cell.x)
	var c := _centroid()
	var r := stamp_px / _cell.x
	var x0 := maxi(0, int(c.x - r * 1.6))
	var x1 := mini(GW - 1, int(c.x + r * 1.6) + 1)
	var y0 := maxi(0, int(c.y - r * 1.6))
	var y1 := mini(GH - 1, int(c.y + r * 1.6) + 1)
	var removed := 0.0
	var rim: Array = []   # [index, weight]
	var rim_w := 0.0
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var q := Vector2(x + 0.5, y + 0.5) - c
			var i := y * GW + x
			var dist := _poly_distance(q, poly)
			if Geometry2D.is_point_in_polygon(q, poly):
				if _h[i] > 0.02:
					var k := 0.55 if dist > 0.8 else 0.55 * dist / 0.8
					var take := _h[i] * k
					_h[i] -= take
					removed += take
			elif dist < 2.2:
				var t := 1.0 - absf(dist - 1.0) / 1.2
				if t > 0.0 and _h[i] > 0.01:
					rim.append([i, t * t])
					rim_w += t * t
	if removed > 0.0 and rim_w > 0.0:
		var per := removed / rim_w
		for e in rim:
			_h[e[0]] = minf(h_cap, _h[e[0]] + per * e[1])
	_wobble = 0.5


## Knife: cut along a line (local px). Slime under the blade is pushed to either side,
## leaving a groove that slowly heals. Returns true if any slime was cut.
func slice(a_px: Vector2, b_px: Vector2) -> bool:
	var a := to_grid_px(a_px)
	var b := to_grid_px(b_px)
	var half_w := 1.3                    # groove half-width in cells
	var reach := 3.2                     # how far the displaced slime piles up
	var x0 := maxi(0, int(minf(a.x, b.x) - reach) - 1)
	var x1 := mini(GW - 1, int(maxf(a.x, b.x) + reach) + 1)
	var y0 := maxi(0, int(minf(a.y, b.y) - reach) - 1)
	var y1 := mini(GH - 1, int(maxf(a.y, b.y) + reach) + 1)
	var removed := 0.0
	var rim: Array = []
	var rim_w := 0.0
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var q := Vector2(x + 0.5, y + 0.5)
			var cp := Geometry2D.get_closest_point_to_segment(q, a, b)
			var d := q.distance_to(cp)
			var i := y * GW + x
			if d < half_w:
				var k := 0.85 * (1.0 - (d / half_w) * (d / half_w) * 0.5)
				var take := _h[i] * k
				_h[i] -= take
				removed += take
			elif d < reach and _h[i] > 0.01:
				var t := 1.0 - absf(d - (half_w + 0.8)) / (reach - half_w)
				if t > 0.0:
					rim.append([i, t * t])
					rim_w += t * t
	if removed < 0.05:
		return false
	if rim_w > 0.0:
		var per := removed / rim_w
		for e in rim:
			_h[e[0]] = minf(h_cap, _h[e[0]] + per * e[1])
	sliced.emit()
	return true


## Undo: remember the lump before a gesture or tool, restore on request (8 deep).
func remember() -> void:
	_undo.append({"h": _h.duplicate(), "c": _c.duplicate(), "mass": _mass0, "addins": addins.get_state()})
	if _undo.size() > 8:
		_undo.pop_front()


func can_undo() -> bool:
	return not _undo.is_empty()


func undo() -> bool:
	if _undo.is_empty():
		return false
	var u: Dictionary = _undo.pop_back()
	if u["h"].size() != _h.size():
		return false
	_h = u["h"]
	_c = u["c"]
	_mass0 = u["mass"]
	addins.set_state(u["addins"])
	bubbles.clear()
	_wobble = 0.6
	return true


## Rolling pin: flatten a wide strip along the stroke; the squeezed-out slime piles up
## on both sides. Returns true if anything moved.
func roll(a_px: Vector2, b_px: Vector2) -> bool:
	var a := to_grid_px(a_px)
	var b := to_grid_px(b_px)
	var half_w := 3.2
	var reach := 6.0
	var flat := 0.30
	var x0 := maxi(0, int(minf(a.x, b.x) - reach) - 1)
	var x1 := mini(GW - 1, int(maxf(a.x, b.x) + reach) + 1)
	var y0 := maxi(0, int(minf(a.y, b.y) - reach) - 1)
	var y1 := mini(GH - 1, int(maxf(a.y, b.y) + reach) + 1)
	var removed := 0.0
	var rim: Array = []
	var rim_w := 0.0
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var q := Vector2(x + 0.5, y + 0.5)
			var cp := Geometry2D.get_closest_point_to_segment(q, a, b)
			var d := q.distance_to(cp)
			var i := y * GW + x
			if d < half_w:
				if _h[i] > flat:
					var take := (_h[i] - flat) * 0.6
					_h[i] -= take
					removed += take
			elif d < reach and _h[i] > 0.01:
				var t := 1.0 - absf(d - (half_w + 1.2)) / (reach - half_w)
				if t > 0.0:
					rim.append([i, t * t])
					rim_w += t * t
	if removed < 0.03:
		return false
	if rim_w > 0.0:
		var per := removed / rim_w
		for e in rim:
			_h[e[0]] = minf(h_cap, _h[e[0]] + per * e[1])
	# a rolling pin leaves a smooth strip: blur inside it
	for y in range(maxi(1, y0), mini(GH - 2, y1) + 1):
		for x in range(maxi(1, x0), mini(GW - 2, x1) + 1):
			var q := Vector2(x + 0.5, y + 0.5)
			if q.distance_to(Geometry2D.get_closest_point_to_segment(q, a, b)) < half_w:
				var i := y * GW + x
				var m := (_h[i - 1] + _h[i + 1] + _h[i - GW] + _h[i + GW]) * 0.25
				_h[i] = lerpf(_h[i], m, 0.6)
	return true


## Snapshot of the whole slime for the jar shelf.
func get_state() -> Dictionary:
	return {"gw": GW, "gh": GH, "h": _h.duplicate(), "c": _c.duplicate(), "color": color,
			"style": style, "sparkle": sparkle, "hue": _hue, "addins": addins.get_state()}


func set_state(d: Dictionary) -> void:
	if d.get("gw", 0) != GW or d.get("gh", 0) != GH:
		reset()   # saved in the other orientation: start fresh in this one
		return
	_h = d["h"].duplicate()
	_c = d["c"].duplicate()
	_mass0 = _sum(_h)
	color = d.get("color", color)
	style = d.get("style", "shiny")
	sparkle = d.get("sparkle", false)
	_hue = d.get("hue", 0.0)
	if _mat:
		_mat.set_shader_parameter("hue_shift", _hue)
	addins.set_state(d.get("addins", []))
	bubbles.clear()
	_wobble = 0.6


func _shape_polygon(shape: String, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if shape == "heart":
		for i in 40:
			var t := TAU * i / 40.0
			var x := 16.0 * pow(sin(t), 3.0)
			var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
			pts.append(Vector2(x, y) / 16.0 * r)
	elif shape == "circle":
		for i in 32:
			var a := TAU * i / 32.0
			pts.append(Vector2(cos(a), sin(a)) * r * 0.85)
	elif shape == "flower":
		for i in 60:
			var a := TAU * i / 60.0
			var rr := r * (0.62 + 0.38 * absf(cos(2.5 * a)))
			pts.append(Vector2(cos(a), sin(a)) * rr)
	elif shape == "moon":
		# Crescent: outer circle (radius r) minus an inner circle (0.85 r) shifted right.
		var a0 := deg_to_rad(58.0)
		for i in 33:
			var a := a0 + (TAU - 2.0 * a0) * i / 32.0
			pts.append(Vector2(cos(a), sin(a)) * r)
		var b0 := deg_to_rad(88.0)
		for i in 25:
			var b := (TAU - b0) - (TAU - 2.0 * b0) * i / 24.0
			pts.append(Vector2(0.5 * r, 0.0) + Vector2(cos(b), sin(b)) * 0.85 * r)
	elif shape == "fish":
		# Ellipse body facing right, open at the back, with a forked tail.
		var span := PI - 0.7
		for i in 41:
			var a := -span + 2.0 * span * i / 40.0
			pts.append(Vector2(0.15 * r + 0.6 * r * cos(a), 0.42 * r * sin(a)))
		pts.append(Vector2(-0.95 * r, 0.5 * r))
		pts.append(Vector2(-0.68 * r, 0.0))
		pts.append(Vector2(-0.95 * r, -0.5 * r))
	else:
		for i in 10:
			var rr := r if i % 2 == 0 else r * 0.45
			var a := -PI / 2.0 + TAU * i / 10.0
			pts.append(Vector2(cos(a), sin(a)) * rr)
	return pts


static func _poly_distance(q: Vector2, poly: PackedVector2Array) -> float:
	var best := 1e9
	var n := poly.size()
	for i in n:
		var d := q.distance_to(Geometry2D.get_closest_point_to_segment(q, poly[i], poly[(i + 1) % n]))
		if d < best:
			best = d
	return best


func wobble(strength := 1.0) -> void:
	_wobble = strength


## Grid cells with at least `min_h` slime (for sprinkling add-ins).
func slime_cells(min_h: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for y in range(0, GH, 2):
		for x in range(0, GW, 2):
			if _h[y * GW + x] > min_h:
				out.append(Vector2(x, y))
	return out


func sample_height(fx: float, fy: float) -> float:
	return _sample(fx, fy)


## Displayed slime colour at a grid position (bilinear in K/S space, like the shader).
func sample_color(fx: float, fy: float) -> Color:
	fx = clampf(fx, 0.0, GW - 1.001)
	fy = clampf(fy, 0.0, GH - 1.001)
	var x := int(fx)
	var y := int(fy)
	var tx := fx - x
	var ty := fy - y
	var i0 := (y * GW + x) * 3
	var i1 := i0 + 3
	var i2 := i0 + GW * 3
	var i3 := i2 + 3
	var out := Vector3.ZERO
	for ch in 3:
		var a := _c[i0 + ch] + (_c[i1 + ch] - _c[i0 + ch]) * tx
		var b := _c[i2 + ch] + (_c[i3 + ch] - _c[i2 + ch]) * tx
		out[ch] = a + (b - a) * ty
	return from_ks(out)


## Kubelka-Munk: reflectance -> K/S. Mixing K/S linearly behaves like mixing paint
## (yellow + blue = green, red + yellow = orange) instead of averaging light.
static func to_ks(c: Color) -> Vector3:
	var v := Vector3.ZERO
	for ch in 3:
		var r := clampf(c[ch], 0.02, 0.985)
		v[ch] = (1.0 - r) * (1.0 - r) / (2.0 * r)
	return v


static func from_ks(v: Vector3) -> Color:
	var c := Color(0, 0, 0, 1)
	for ch in 3:
		var k := maxf(v[ch], 0.0)
		c[ch] = 1.0 + k - sqrt(k * k + 2.0 * k)
	return c


func _centroid() -> Vector2:
	var sx := 0.0
	var sy := 0.0
	var m := 0.0
	for y in GH:
		for x in GW:
			var v := _h[y * GW + x]
			sx += v * (x + 0.5)
			sy += v * (y + 0.5)
			m += v
	if m < 0.001:
		return Vector2(GW * 0.5, GH * 0.5)
	return Vector2(sx / m, sy / m)


# ---------------------------------------------------------------- input

func _to_grid(canvas_pos: Vector2) -> Vector2:
	var p := make_canvas_position_local(canvas_pos) - play_area.position
	return Vector2(p.x / _cell.x, p.y / _cell.y)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var g := _to_grid(event.position)
		if event.pressed:
			var inside := _sample(g.x - 0.5, g.y - 0.5) > 0.05
			if _fingers.is_empty():
				remember()
			_fingers[event.index] = {"pos": g, "prev": g, "still": 0, "held": false, "inside": inside}
			touched.emit(inside)
			if inside:
				touch_at.emit(to_px(g))
		elif _fingers.has(event.index):
			var inside := _sample(g.x - 0.5, g.y - 0.5) > 0.05
			_fingers.erase(event.index)
			_pinch_prev = -1.0
			released.emit(inside)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and _fingers.has(event.index):
		_fingers[event.index]["pos"] = _to_grid(event.position)
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- simulation

func _physics_process(delta: float) -> void:
	_tick += 1
	_stretch_cd = maxf(0.0, _stretch_cd - delta)
	var rf := finger_px / _cell.x
	var top_speed := 0.0
	for f in _fingers.values():
		var pos: Vector2 = f["pos"]
		var v: Vector2 = pos - f["prev"]
		f["prev"] = pos
		var speed := v.length()
		var on_slime := _sample(pos.x - 0.5, pos.y - 0.5) > 0.05
		if on_slime:
			top_speed = maxf(top_speed, speed)
			if speed > 0.25 and _tick % 8 == 0:
				knead_at.emit(to_px(pos))
		if speed > 0.03:
			_smear(pos, v * _smear_mult, rf * 1.9)
			addins.advect(pos, v * smear_strength, rf * 1.9)
			bubbles.pop_near(to_px(pos), finger_px * 1.1)
			if on_slime and speed > 0.5 and _tick % 10 == 0:
				bubbles.spawn(to_px(pos - v.normalized() * rf * 1.5))
			f["still"] = 0
			if speed > 0.9 and on_slime and _stretch_cd <= 0.0:
				_stretch_cd = 0.4
				stretched.emit()
		else:
			f["still"] += 1
			if f["still"] == 20 and on_slime and not f["held"]:
				f["held"] = true
				held.emit()
			if on_slime and f["still"] >= 8 and f["still"] % 10 == 0:
				bubbles.spawn(to_px(pos) + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * finger_px * 1.6)
		var k := press_rate * _press_mult * (1.0 - 0.55 * clampf(speed / 1.5, 0.0, 1.0))
		_press(pos, rf, k)
		addins.push_out(pos, rf)
	if _fingers.size() == 2:
		_pinch(rf)
	_knead_speed = lerpf(_knead_speed, top_speed, 0.25)
	kneading.emit(_knead_speed)
	if _hue_drift > 0.0 and top_speed > 0.05:
		_hue = fmod(_hue + top_speed * 0.012 * _hue_drift, TAU)
		_mat.set_shader_parameter("hue_shift", _hue)
	if _tick % 3 == 0:
		_relax(slump * 3.0 * _slump_mult)
	if _tick % 6 == 0:
		_mix(mix_rate)
	if _tick % 4 == 0:
		var m := _sum(_h)
		if m > 0.0001:
			var s := _mass0 / m
			if absf(s - 1.0) > 0.0005:
				for i in GW * GH:
					_h[i] *= s


## Two fingers closing on each other squeeze the slime between them up into a ridge.
var _pinch_prev := -1.0
func _pinch(rf: float) -> void:
	var fs := _fingers.values()
	var a: Vector2 = fs[0]["pos"]
	var b: Vector2 = fs[1]["pos"]
	var d := a.distance_to(b)
	if _pinch_prev < 0.0:
		_pinch_prev = d
		return
	var closing := _pinch_prev - d
	_pinch_prev = d
	if closing < 0.08 or d < rf * 1.5 or d > rf * 9.0:
		return
	var amount := minf(0.06, closing * 0.05)
	var mid := (a + b) * 0.5
	var moved := 0.0
	for f in [a, b]:
		moved += _take(f, rf * 1.1, amount)
	_deposit(mid, rf * 0.9 + d * 0.08, moved)


func _take(c: Vector2, r: float, k: float) -> float:
	var r2 := r * r
	var got := 0.0
	for y in range(maxi(0, int(c.y - r)), mini(GH - 1, int(c.y + r) + 1) + 1):
		for x in range(maxi(0, int(c.x - r)), mini(GW - 1, int(c.x + r) + 1) + 1):
			var dx := x + 0.5 - c.x
			var dy := y + 0.5 - c.y
			var d2 := dx * dx + dy * dy
			if d2 < r2:
				var i := y * GW + x
				var t := _h[i] * k * (1.0 - d2 / r2)
				_h[i] -= t
				got += t
	return got


func _deposit(c: Vector2, r: float, amount: float) -> void:
	var r2 := r * r
	var wsum := 0.0
	for y in range(maxi(0, int(c.y - r)), mini(GH - 1, int(c.y + r) + 1) + 1):
		for x in range(maxi(0, int(c.x - r)), mini(GW - 1, int(c.x + r) + 1) + 1):
			var dx := x + 0.5 - c.x
			var dy := y + 0.5 - c.y
			var d2 := dx * dx + dy * dy
			if d2 < r2:
				var w := 1.0 - d2 / r2
				wsum += w * w
	if wsum <= 0.0:
		return
	for y in range(maxi(0, int(c.y - r)), mini(GH - 1, int(c.y + r) + 1) + 1):
		for x in range(maxi(0, int(c.x - r)), mini(GW - 1, int(c.x + r) + 1) + 1):
			var dx := x + 0.5 - c.x
			var dy := y + 0.5 - c.y
			var d2 := dx * dx + dy * dy
			if d2 < r2:
				var w := 1.0 - d2 / r2
				var i := y * GW + x
				_h[i] = minf(h_cap, _h[i] + amount * w * w / wsum)


## Push slime down under the finger and out to a rim around it (mass conserving).
func _press(c: Vector2, r: float, k: float) -> void:
	var x0 := maxi(0, int(c.x - r * 2.3))
	var x1 := mini(GW - 1, int(c.x + r * 2.3) + 1)
	var y0 := maxi(0, int(c.y - r * 2.3))
	var y1 := mini(GH - 1, int(c.y + r * 2.3) + 1)
	var removed := 0.0
	var rim_w := 0.0
	var r2 := r * r
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx := x + 0.5 - c.x
			var dy := y + 0.5 - c.y
			var d2 := dx * dx + dy * dy
			if d2 < r2:
				var w := 1.0 - d2 / r2
				w = w * w
				var i := y * GW + x
				var take := _h[i] * k * w
				_h[i] -= take
				removed += take
			else:
				var d := sqrt(d2) / r
				if d < 2.3:
					var t := 1.0 - absf(d - 1.45) / 0.85
					if t > 0.0:
						rim_w += t * t
	if removed <= 0.0 or rim_w <= 0.0:
		return
	var per := removed / rim_w
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx := x + 0.5 - c.x
			var dy := y + 0.5 - c.y
			var d := sqrt(dx * dx + dy * dy) / r
			if d >= 1.0 and d < 2.3:
				var t := 1.0 - absf(d - 1.45) / 0.85
				if t > 0.0:
					var i := y * GW + x
					_h[i] = minf(h_cap, _h[i] + per * t * t)


## Carry slime and its colour along the finger's motion (semi-Lagrangian smudge).
func _smear(c: Vector2, v: Vector2, r: float) -> void:
	var x0 := maxi(0, int(c.x - r))
	var x1 := mini(GW - 1, int(c.x + r) + 1)
	var y0 := maxi(0, int(c.y - r))
	var y1 := mini(GH - 1, int(c.y + r) + 1)
	var mx0 := maxi(0, x0 - 3)
	var mx1 := mini(GW - 1, x1 + 3)
	var my0 := maxi(0, y0 - 3)
	var my1 := mini(GH - 1, y1 + 3)
	for y in range(my0, my1 + 1):
		var row := y * GW
		for x in range(mx0, mx1 + 1):
			var i := row + x
			_tmp[i] = _h[i]
			_ctmp[i * 3] = _c[i * 3]
			_ctmp[i * 3 + 1] = _c[i * 3 + 1]
			_ctmp[i * 3 + 2] = _c[i * 3 + 2]
	var r2 := r * r
	var vs := v * smear_strength
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx := x + 0.5 - c.x
			var dy := y + 0.5 - c.y
			var d2 := dx * dx + dy * dy
			if d2 >= r2:
				continue
			var w := 1.0 - d2 / r2
			w = w * w * (3.0 - 2.0 * w)
			var sx := clampf(x - vs.x * w, 0.0, GW - 1.001)
			var sy := clampf(y - vs.y * w, 0.0, GH - 1.001)
			var ix := int(sx)
			var iy := int(sy)
			var tx := sx - ix
			var ty := sy - iy
			var i0 := iy * GW + ix
			var i1 := i0 + 1
			var i2 := i0 + GW
			var i3 := i2 + 1
			var w0 := (1.0 - tx) * (1.0 - ty)
			var w1 := tx * (1.0 - ty)
			var w2 := (1.0 - tx) * ty
			var w3 := tx * ty
			var i := y * GW + x
			_h[i] = minf(h_cap, _tmp[i0] * w0 + _tmp[i1] * w1 + _tmp[i2] * w2 + _tmp[i3] * w3)
			# colour: weight by thickness so thin/empty cells don't bleed their stale colour
			var hw0 := w0 * (_tmp[i0] + 0.02)
			var hw1 := w1 * (_tmp[i1] + 0.02)
			var hw2 := w2 * (_tmp[i2] + 0.02)
			var hw3 := w3 * (_tmp[i3] + 0.02)
			var hs := hw0 + hw1 + hw2 + hw3
			for ch in 3:
				_c[i * 3 + ch] = (_ctmp[i0 * 3 + ch] * hw0 + _ctmp[i1 * 3 + ch] * hw1 + _ctmp[i2 * 3 + ch] * hw2 + _ctmp[i3 * 3 + ch] * hw3) / hs


## Slow flow: sharp shapes soften over time.
func _relax(d: float) -> void:
	var n := GW * GH
	for i in n:
		_tmp[i] = _h[i]
	for y in range(1, GH - 1):
		var row := y * GW
		for x in range(1, GW - 1):
			var i := row + x
			var c := _tmp[i]
			var lap := _tmp[i - 1] + _tmp[i + 1] + _tmp[i - GW] + _tmp[i + GW] - 4.0 * c
			# thick slime slumps faster than a thin smear (gravity has more to pull on)
			_h[i] = maxf(0.0, c + d * (0.35 + 0.65 * minf(1.0, c)) * lap)


## Colours blend into their neighbours where there is slime (kneading mixes them).
func _mix(d: float) -> void:
	var n := GW * GH * 3
	for i in n:
		_ctmp[i] = _c[i]
	for y in range(1, GH - 1):
		var row := y * GW
		for x in range(1, GW - 1):
			var i := row + x
			if _h[i] < 0.03:
				continue
			var b := i * 3
			for ch in 3:
				var c := _ctmp[b + ch]
				var lap := _ctmp[b - 3 + ch] + _ctmp[b + 3 + ch] + _ctmp[b - GW * 3 + ch] + _ctmp[b + GW * 3 + ch] - 4.0 * c
				_c[b + ch] = c + d * lap


func _sample(fx: float, fy: float) -> float:
	fx = clampf(fx, 0.0, GW - 1.001)
	fy = clampf(fy, 0.0, GH - 1.001)
	var x := int(fx)
	var y := int(fy)
	var tx := fx - x
	var ty := fy - y
	var i := y * GW + x
	var a := _h[i] + (_h[i + 1] - _h[i]) * tx
	var b := _h[i + GW] + (_h[i + GW + 1] - _h[i + GW]) * tx
	return a + (b - a) * ty


static func _sum(a: PackedFloat32Array) -> float:
	var s := 0.0
	for v in a:
		s += v
	return s


# ---------------------------------------------------------------- rendering

func _process(delta: float) -> void:
	_time += delta
	_wobble = maxf(0.0, _wobble - delta * 1.6)
	_img.set_data(GW, GH, false, Image.FORMAT_RF, _h.to_byte_array())
	_tex.update(_img)
	_cimg.set_data(GW, GH, false, Image.FORMAT_RGBF, _c.to_byte_array())
	_ctex.update(_cimg)
	_mat.set_shader_parameter("time", _time)
	_mat.set_shader_parameter("wobble", _wobble)
