extends Node2D
class_name Slime
## A lump of slime on a table, simulated as a thickness field on a coarse grid.
## Fingers press (crater + rim), smear (carry slime along the stroke), pile up and
## spread. Shapes persist and slump back only slowly. Total slime is conserved, so it
## can never be lost. Rendering is a shader that lights the surface from its slopes.

signal touched(inside: bool)
signal released(inside: bool)

const GW := 80
const GH := 52

@export var play_area := Rect2(70, 70, 1630, 1060):
	set(v):
		play_area = v
		_layout()
@export var mound_radius := 330.0      ## px, starting lump
@export var finger_px := 58.0          ## finger radius in px
@export var press_rate := 0.045        ## fraction of thickness pushed out per tick while pressing
@export var smear_strength := 0.9      ## how much of the finger motion the slime follows
@export var slump := 0.0012            ## diffusion per tick (lower = holds shapes longer)
@export var h_cap := 2.6               ## max thickness (peaks)

var color: Color = Color("6fe36a"):
	set(v):
		color = v
		if _mat:
			_mat.set_shader_parameter("color", v)
var sparkle := false:
	set(v):
		sparkle = v
		if _mat:
			_mat.set_shader_parameter("sparkle", 1.0 if v else 0.0)

var _h := PackedFloat32Array()
var _tmp := PackedFloat32Array()
var _mass0 := 0.0
var _cell := Vector2(27, 27)
var _fingers := {}  # index -> {pos: Vector2(grid), prev: Vector2(grid), ticks: int}
var _tick := 0
var _time := 0.0
var _wobble := 0.0

var _rect: ColorRect
var _mat: ShaderMaterial
var _img: Image
var _tex: ImageTexture


func _ready() -> void:
	_h.resize(GW * GH)
	_tmp.resize(GW * GH)
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
	_mat.set_shader_parameter("color", color)
	_mat.set_shader_parameter("sparkle", 1.0 if sparkle else 0.0)
	_rect.material = _mat
	add_child(_rect)
	_img = Image.create_empty(GW, GH, false, Image.FORMAT_RF)
	_tex = ImageTexture.create_from_image(_img)
	_mat.set_shader_parameter("height_tex", _tex)
	_layout()
	reset()


func _layout() -> void:
	if _rect == null:
		return
	_rect.position = play_area.position
	_rect.size = play_area.size
	_cell = Vector2(play_area.size.x / GW, play_area.size.y / GH)
	_mat.set_shader_parameter("cell_px", _cell)


## Fresh round mound in the middle of the table.
func reset() -> void:
	var c := Vector2(GW * 0.5, GH * 0.5)
	var rx := mound_radius / _cell.x
	var ry := mound_radius / _cell.y
	for y in GH:
		for x in GW:
			var dx := (x + 0.5 - c.x) / rx
			var dy := (y + 0.5 - c.y) / ry
			var d2 := dx * dx + dy * dy
			_h[y * GW + x] = pow(1.0 - d2, 0.55) * 0.95 if d2 < 1.0 else 0.0
	_mass0 = _sum(_h)
	_fingers.clear()
	_wobble = 1.0


func wobble(strength := 1.0) -> void:
	_wobble = strength


# ---------------------------------------------------------------- input

func _to_grid(canvas_pos: Vector2) -> Vector2:
	var p := make_canvas_position_local(canvas_pos) - play_area.position
	return Vector2(p.x / _cell.x, p.y / _cell.y)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var g := _to_grid(event.position)
		if event.pressed:
			var inside := _sample(g.x - 0.5, g.y - 0.5) > 0.05
			_fingers[event.index] = {"pos": g, "prev": g, "ticks": 0}
			touched.emit(inside)
		elif _fingers.has(event.index):
			var inside := _sample(g.x - 0.5, g.y - 0.5) > 0.05
			_fingers.erase(event.index)
			released.emit(inside)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and _fingers.has(event.index):
		_fingers[event.index]["pos"] = _to_grid(event.position)
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- simulation

func _physics_process(_delta: float) -> void:
	_tick += 1
	var rf := finger_px / _cell.x
	for f in _fingers.values():
		var pos: Vector2 = f["pos"]
		var v: Vector2 = pos - f["prev"]
		f["prev"] = pos
		f["ticks"] += 1
		var speed := v.length()
		if speed > 0.03:
			_smear(pos, v, rf * 1.9)
		# press: full strength when still, weaker while sweeping
		var k := press_rate * (1.0 - 0.55 * clampf(speed / 1.5, 0.0, 1.0))
		_press(pos, rf, k)
	if _tick % 3 == 0:
		_relax(slump * 3.0)
	if _tick % 4 == 0:
		var m := _sum(_h)
		if m > 0.0001:
			var s := _mass0 / m
			if absf(s - 1.0) > 0.0005:
				for i in GW * GH:
					_h[i] *= s


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


## Carry slime along the finger's motion (semi-Lagrangian smudge inside radius r).
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
			_tmp[row + x] = _h[row + x]
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
			_h[y * GW + x] = minf(h_cap, _sample_tmp(x - vs.x * w, y - vs.y * w))


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
			_h[i] = maxf(0.0, c + d * lap)


func _sample_tmp(fx: float, fy: float) -> float:
	fx = clampf(fx, 0.0, GW - 1.001)
	fy = clampf(fy, 0.0, GH - 1.001)
	var x := int(fx)
	var y := int(fy)
	var tx := fx - x
	var ty := fy - y
	var i := y * GW + x
	var a := _tmp[i] + (_tmp[i + 1] - _tmp[i]) * tx
	var b := _tmp[i + GW] + (_tmp[i + GW + 1] - _tmp[i + GW]) * tx
	return a + (b - a) * ty


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
	_mat.set_shader_parameter("time", _time)
	_mat.set_shader_parameter("wobble", _wobble)
