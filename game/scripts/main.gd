extends Node2D
## Root scene: table background, the slime, the icon UI, sounds.

const SETTINGS := "user://settings.cfg"
const SlimeScript := preload("res://scripts/slime.gd")
const UIScript := preload("res://scripts/ui.gd")

var slime: Node2D
var ui: CanvasLayer
var _squish: Array[AudioStreamPlayer] = []
var _pop: AudioStreamPlayer
var _slurp: AudioStreamPlayer
var _fps_timer := 0.0


func _ready() -> void:
	_build_background()

	slime = SlimeScript.new()
	slime.name = "Slime"
	add_child(slime)

	ui = UIScript.new()
	ui.name = "UI"
	add_child(ui)

	ui.color_picked.connect(_on_color)
	ui.sparkle_toggled.connect(func(on: bool): slime.sparkle = on; _save())
	ui.reset_pressed.connect(func(): slime.reset(); _play(_slurp))
	slime.touched.connect(func(inside: bool): if inside: _play(_squish.pick_random()))
	slime.released.connect(func(inside: bool): if inside: _play(_pop))

	for k in 3:
		_squish.append(_player("res://assets/sfx/squish%d.wav" % k))
	_pop = _player("res://assets/sfx/pop.wav", -6.0)
	_slurp = _player("res://assets/sfx/slurp.wav")

	_load()
	get_tree().root.size_changed.connect(_layout)
	_layout()


func _build_background() -> void:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color("fbf6ee"), Color("e4dccd")])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.45)
	t.fill_to = Vector2(0.5, 1.1)
	t.width = 64
	t.height = 64
	var layer := CanvasLayer.new()
	layer.name = "BackgroundLayer"
	layer.layer = -1
	add_child(layer)
	var bg := TextureRect.new()
	bg.name = "Background"
	bg.texture = t
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _layout() -> void:
	var vp := get_viewport_rect().size
	# Leave room for the palette column on the right and a margin everywhere.
	slime.play_area = Rect2(70, 70, vp.x - 70 - 150, vp.y - 140)


func _player(path: String, db := 0.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = db
	add_child(p)
	return p


func _play(p: AudioStreamPlayer) -> void:
	p.pitch_scale = randf_range(0.85, 1.2)
	p.play()


func _on_color(c: Color) -> void:
	slime.color = c
	slime.wobble(1.0)
	_play(_squish.pick_random())
	_save()


func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("slime", "color", slime.color)
	cf.set_value("slime", "sparkle", slime.sparkle)
	cf.save(SETTINGS)


func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS) != OK:
		return
	slime.color = cf.get_value("slime", "color", slime.color)
	slime.sparkle = cf.get_value("slime", "sparkle", false)
	ui.select_color(slime.color)
	ui.set_sparkle(slime.sparkle)


func _process(delta: float) -> void:
	if OS.is_debug_build():
		_fps_timer += delta
		if _fps_timer > 3.0:
			_fps_timer = 0.0
			print("fps %d" % Engine.get_frames_per_second())
