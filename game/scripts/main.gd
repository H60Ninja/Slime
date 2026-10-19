extends Node2D
## Root scene: table background, the slime, the make-slime ritual, the icon UI, sounds.

const SETTINGS := "user://settings.cfg"
const SlimeScript := preload("res://scripts/slime.gd")
const UIScript := preload("res://scripts/ui.gd")
const PourScript := preload("res://scripts/pour.gd")
const MixingScript := preload("res://scripts/mixing.gd")
const JarsScript := preload("res://scripts/jars.gd")
const PickerScript := preload("res://scripts/picker.gd")
const ScentsScript := preload("res://scripts/scents.gd")
const HandScript := preload("res://scripts/hand.gd")
const StoreScript := preload("res://scripts/store.gd")
const GateScript := preload("res://scripts/gate.gd")

# Premium ("Slime Shop", one-time unlock). Hidden entirely until billing exists.
const PREMIUM_THEMES := {
	"candy":  {"color": Color("ff8fcf"), "style": "shiny", "sparkle": true, "drops": [Color("7fd3ff"), Color("ffe44d"), Color("f4f4ff")], "beads": 12, "stars": 0, "scent": "bubblegum"},
	"ocean":  {"color": Color("4fb8ff"), "style": "clear", "sparkle": false, "drops": [Color("3fe0b8"), Color("f4f4ff")], "beads": 0, "stars": 8, "scent": "mint"},
	"dino":   {"color": Color("6fe36a"), "style": "crunchy", "sparkle": false, "drops": [Color("2c2c5e")], "beads": 10, "stars": 0, "scent": ""},
	"sunset": {"color": Color("ff9b2f"), "style": "butter", "sparkle": false, "drops": [Color("ff5fb8"), Color("9d6bff")], "beads": 0, "stars": 0, "scent": "strawberry"},
}

const THEMES := {
	"icecream": {"color": Color("ff9ad5"), "style": "cloud", "sparkle": false, "drops": [Color("fff2bf"), Color("9fd8ff")], "beads": 14, "stars": 0, "scent": "strawberry"},
	"unicorn":  {"color": Color("ffb6de"), "style": "holo", "sparkle": true, "drops": [Color("c58bff"), Color("7fd3ff")], "beads": 0, "stars": 10, "scent": "bubblegum"},
	"galaxy":   {"color": Color("2c2c5e"), "style": "glow", "sparkle": true, "drops": [Color("9d6bff"), Color("4fb8ff")], "beads": 0, "stars": 12, "scent": ""},
	"rainbow":  {"color": Color("ff4d4d"), "style": "magic", "sparkle": false, "drops": [Color("ffe44d"), Color("4fb8ff"), Color("6fe36a")], "beads": 0, "stars": 0, "scent": ""},
	"lemonade": {"color": Color("ffe44d"), "style": "clear", "sparkle": false, "drops": [Color("f4f4ff")], "beads": 8, "stars": 0, "scent": "lemon"},
	"mint":     {"color": Color("3fe0b8"), "style": "crunchy", "sparkle": false, "drops": [Color("f4f4ff")], "beads": 0, "stars": 0, "scent": "mint"},
}

var slime: Node2D
var ui: CanvasLayer
var mixing: Node2D = null
var _play_area := Rect2()
var _squish: Array[AudioStreamPlayer] = []
var _pops: Array[AudioStreamPlayer] = []
var _slurps: Array[AudioStreamPlayer] = []
var _squelches: Array[AudioStreamPlayer] = []
var _stretches: Array[AudioStreamPlayer] = []
var _sprinkle: AudioStreamPlayer
var _crackles: Array[AudioStreamPlayer] = []
var _kind_voices := {}   # style -> Array[AudioStreamPlayer] (finger-lands sound per kind)
const KIND_PITCH := {"shiny": 0.0, "clear": 0.22, "metal": 0.05, "cloud": -0.18, "crunchy": 0.0, "butter": -0.25, "fluffy": -0.15, "glow": -0.05, "holo": 0.12, "magic": 0.08}
var _poofs: Array[AudioStreamPlayer] = []
var _click: AudioStreamPlayer
var _bubble: Array[AudioStreamPlayer] = []
var _wet: AudioStreamPlayer
var _slice_wets: Array[AudioStreamPlayer] = []
var _slice_crunch: AudioStreamPlayer
var _jar: AudioStreamPlayer
var jars: CanvasLayer
var _knife := false
var _knife_pts := {}   # touch index -> last px
var _knife_trail: KnifeTrail
var _wet_target_db := -60.0
var _bg: TextureRect
var _bg_dark: ColorRect
var themes: CanvasLayer
var scents_picker: CanvasLayer
var scents: Node2D
var _hint: Node2D
var _hint_t := 0.0
var store: Node
var gate: CanvasLayer
var sprinkles_picker: CanvasLayer
var stamps_picker: CanvasLayer
var _roller := false
var _roller_pts := {}
var _roller_remembered := false
var _knife_remembered := false
var _fps_timer := 0.0
var _snapping := false


func _ready() -> void:
	_build_background()

	slime = SlimeScript.new()
	slime.name = "Slime"
	add_child(slime)

	ui = UIScript.new()
	ui.name = "UI"
	add_child(ui)

	ui.color_picked.connect(_on_color)
	ui.style_picked.connect(func(s: String): slime.style = s; slime.wobble(0.6); _play(_touch_sound()); _save())
	ui.sparkle_toggled.connect(func(on: bool): slime.sparkle = on; _play(_pops.pick_random()); _save())
	ui.reset_pressed.connect(_on_new)
	ui.bowl_pressed.connect(func(): if not mixing: _start_mixing())
	ui.themes_pressed.connect(func(): if not mixing: themes.open(); _play(_click))
	ui.scents_pressed.connect(func(): if not mixing: scents_picker.open(scents.scent); _play(_click))
	ui.sprinkles_pressed.connect(func(): if not mixing: sprinkles_picker.open(); _play(_click))
	ui.stamps_pressed.connect(func(): if not mixing: stamps_picker.open(); _play(_click))
	ui.glue_pressed.connect(_on_glue)
	ui.roller_toggled.connect(_on_roller)
	ui.undo_pressed.connect(_on_undo)
	ui.snapshot_pressed.connect(_snapshot)
	ui.knife_toggled.connect(_on_knife)
	ui.jars_pressed.connect(func(): if not mixing: jars.open(); _play(_jar))
	slime.kneading.connect(_on_kneading)
	slime.style_changed.connect(_on_style_changed)
	slime.touch_at.connect(func(px: Vector2): scents.puff(px, 3); _hide_hint())
	slime.knead_at.connect(func(px: Vector2): scents.puff(px, 1))
	slime.sliced.connect(func(): _play(_slice_crunch if slime.style == "crunchy" else _slice_wets.pick_random()))
	slime.touched.connect(func(inside: bool): if inside: _play(_touch_sound()))
	slime.released.connect(func(inside: bool): if inside: _play(_pops.pick_random()); slime.wobble(0.3); _refresh_undo())
	slime.stretched.connect(func(): _play(_crackles.pick_random() if slime.style == "crunchy" else _stretches.pick_random()))
	slime.held.connect(func(): _play(_poofs.pick_random() if slime.style == "fluffy" else _squelches.pick_random()))
	slime.bubbles.popped.connect(func(): _play(_bubble.pick_random()))

	_setup_audio_bus()
	for k in 5:
		_squish.append(_player("res://assets/sfx/squish%d.wav" % k, -1.0))
	for k in 4:
		_pops.append(_player("res://assets/sfx/pop%d.wav" % k, -5.0))
	for k in 2:
		_slurps.append(_player("res://assets/sfx/slurp%d.wav" % k))
	for k in 3:
		_squelches.append(_player("res://assets/sfx/squelch%d.wav" % k, -2.0))
	for k in 3:
		_stretches.append(_player("res://assets/sfx/stretch%d.wav" % k, -3.0))
	for k in 3:
		_crackles.append(_player("res://assets/sfx/crackle%d.wav" % k, -3.0))
	for k in 2:
		_poofs.append(_player("res://assets/sfx/poof%d.wav" % k, -2.0))
	for fam in ["jelly", "metal", "cloud", "butter", "glow", "holo", "magic"]:
		var arr: Array[AudioStreamPlayer] = []
		for k in 3:
			arr.append(_player("res://assets/sfx/%s%d.wav" % [fam, k], -1.5))
		_kind_voices[fam] = arr
	_sprinkle = _player("res://assets/sfx/sprinkle.wav", -3.0)
	_click = _player("res://assets/sfx/click.wav", -6.0)
	for k in 4:
		_bubble.append(_player("res://assets/sfx/bubble%d.wav" % k, -7.0))
	for k in 2:
		_slice_wets.append(_player("res://assets/sfx/slice_wet%d.wav" % k, -2.0))
	_slice_crunch = _player("res://assets/sfx/slice_crunch.wav", -2.0)
	_jar = _player("res://assets/sfx/jar.wav", -6.0)
	_wet = _player("res://assets/sfx/wet_loop.wav", -60.0)
	var ws := _wet.stream as AudioStreamWAV
	if ws:
		ws.loop_mode = AudioStreamWAV.LOOP_FORWARD
		ws.loop_begin = 0
		ws.loop_end = ws.data.size() / (4 if ws.stereo else 2)
	_wet.play()

	jars = JarsScript.new()
	jars.name = "Jars"
	add_child(jars)
	jars.setup(func(): return slime.get_state(), _thumb_image)
	jars.jar_saved.connect(func(_i: int): _play(_jar))
	jars.jar_loaded.connect(func(_i: int, st: Dictionary): slime.set_state(st); ui.set_state(slime.color, slime.style, slime.sparkle); _play(_slurps.pick_random()); _save())

	scents = ScentsScript.new()
	scents.name = "Scents"
	scents.z_index = 8
	add_child(scents)

	themes = PickerScript.new()
	themes.name = "Themes"
	add_child(themes)
	themes.setup([], 4)
	themes.picked.connect(_apply_theme)

	scents_picker = PickerScript.new()
	scents_picker.name = "ScentsPicker"
	add_child(scents_picker)
	var sitems := [{"id": "", "draw": _draw_scent_tile.bind("")}]
	for k in ScentsScript.KINDS:
		sitems.append({"id": k, "draw": _draw_scent_tile.bind(k)})
	scents_picker.setup(sitems, 4)
	scents_picker.picked.connect(func(id: String): scents.scent = id; ui.set_scent(id); _play(_sprinkle); _save())

	store = StoreScript.new()
	store.name = "Store"
	add_child(store)
	store.changed.connect(_rebuild_pickers)
	gate = GateScript.new()
	gate.name = "Gate"
	add_child(gate)
	gate.confirmed.connect(func(): store.purchase())

	sprinkles_picker = PickerScript.new()
	sprinkles_picker.name = "Sprinkles"
	add_child(sprinkles_picker)
	sprinkles_picker.setup([], 4)
	sprinkles_picker.picked.connect(_on_sprinkle)
	sprinkles_picker.locked_picked.connect(func(_id: String): gate.open())

	stamps_picker = PickerScript.new()
	stamps_picker.name = "Stamps"
	add_child(stamps_picker)
	stamps_picker.setup([], 4)
	stamps_picker.picked.connect(func(shape: String): slime.remember(); slime.stamp(shape); _play(_squelches.pick_random()); _refresh_undo())
	stamps_picker.locked_picked.connect(func(_id: String): gate.open())
	themes.locked_picked.connect(func(_id: String): gate.open())
	_rebuild_pickers()

	_hint = HandScript.new()
	_hint.z_index = 20
	_hint.visible = false
	add_child(_hint)

	_knife_trail = KnifeTrail.new()
	_knife_trail.z_index = 10
	add_child(_knife_trail)

	get_tree().root.size_changed.connect(_layout)
	_layout()
	var first_run := not _load()
	if first_run:
		_start_mixing()
	_refresh_undo()


## Each kind on the left column has its own landing voice.
func _touch_sound() -> AudioStreamPlayer:
	match slime.style:
		"crunchy":
			return _crackles.pick_random()
		"fluffy":
			return _poofs.pick_random()
		"clear":
			return _kind_voices["jelly"].pick_random()
		"metal", "cloud", "butter", "glow", "holo", "magic":
			return _kind_voices[slime.style].pick_random()
	return _squish.pick_random()


## Kinds also colour the shared sounds (squelch, stretch, pop) by pitch.
func _kind_pitch() -> float:
	return KIND_PITCH.get(slime.style, 0.0)


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
	_bg = bg
	_bg_dark = ColorRect.new()
	_bg_dark.color = Color("141628")
	_bg_dark.modulate.a = 0.0
	_bg_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_bg_dark)
	_bg_dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Landscape uses a 1920x1200 canvas, portrait 1200x1920; the UI anchors do the rest.
func _layout() -> void:
	var win := get_window().size
	var portrait: bool = win.y > win.x
	var want := Vector2i(1200, 1920) if portrait else Vector2i(1920, 1200)
	if get_tree().root.content_scale_size != want:
		get_tree().root.content_scale_size = want
	var vp := Vector2(want)
	var side := 24.0 + 88.0 + 30.0
	var bottom := 270.0 if portrait else 150.0
	_play_area = Rect2(side, 60, vp.x - side * 2.0, vp.y - 60 - bottom)
	slime.play_area = _play_area
	ui.set_portrait(portrait)
	if mixing:
		mixing.set_area(_play_area)


## A "Slime" bus: light compression keeps the sticky clicks present, a very short, mostly
## dry room gives the close-mic feel ASMR recordings have.
func _setup_audio_bus() -> void:
	if AudioServer.get_bus_index("Slime") != -1:
		return
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, "Slime")
	AudioServer.set_bus_send(idx, "Master")
	var comp := AudioEffectCompressor.new()
	comp.threshold = -14.0
	comp.ratio = 3.0
	comp.attack_us = 8.0
	comp.release_ms = 90.0
	comp.gain = 2.0
	AudioServer.add_bus_effect(idx, comp)
	var rev := AudioEffectReverb.new()
	rev.room_size = 0.12
	rev.damping = 0.7
	rev.wet = 0.08
	rev.dry = 1.0
	rev.predelay_msec = 6.0
	AudioServer.add_bus_effect(idx, rev)


func _player(path: String, db := 0.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = db
	p.bus = "Slime"
	add_child(p)
	return p


func _play(p: AudioStreamPlayer) -> void:
	p.pitch_scale = randf_range(0.9, 1.12) + (_kind_pitch() if slime else 0.0)
	p.play()


# ---------------------------------------------------------------- make-slime ritual

func _start_mixing() -> void:
	if mixing:
		return
	mixing = MixingScript.new()
	mixing.name = "Mixing"
	mixing.set_area(_play_area)
	mixing.poured.connect(func(): _play(_slurps.pick_random()))
	mixing.stirring.connect(func(): _play(_squish.pick_random()))
	mixing.color_chosen.connect(_on_mix_color)
	mixing.skipped.connect(func(): if mixing: mixing.queue_free(); _on_mixed(slime.color); _play(_pops.pick_random()))
	mixing.done.connect(_on_mixed)
	add_child(mixing)
	ui.set_ritual_mode(true)
	_hide_hint()
	slime.visible = false
	slime.set_process_unhandled_input(false)
	slime.set_physics_process(false)
	_wet_target_db = -60.0
	if _knife:
		_knife = false
		ui.set_knife(false)
	if _roller:
		_roller = false
		ui.set_roller(false)


func _on_mix_color(col: Color, from: Vector2) -> void:
	var pour := PourScript.new()
	pour.color = col
	pour.start = from
	pour.target = mixing.bowl_center
	pour.position = from
	pour.landed.connect(func(c: Color, _at: Vector2): if mixing: mixing.add_color(c); slime.color = c; _play(_slurps.pick_random()))
	add_child(pour)
	_play(_pops.pick_random())


func _on_mixed(col: Color) -> void:
	mixing = null
	ui.set_ritual_mode(false)
	slime.color = col
	slime.reset()
	slime.visible = true
	slime.set_process_unhandled_input(not (_knife or _roller))
	slime.set_physics_process(true)
	_play(_slurps.pick_random())
	_save()
	_show_hint()
	_refresh_undo()


## First touch hint: a hand presses the lump, then smears it.
func _show_hint() -> void:
	var c: Vector2 = slime.drop_target()
	_hint.drag(c + Vector2(-120, -40), c + Vector2(140, 60))
	_hint_t = 7.0


func _hide_hint() -> void:
	_hint_t = 0.0
	_hint.hide_hand()


## + gives a fresh lump straight away; the bowl button runs the ritual.
func _on_new() -> void:
	if mixing:
		return
	slime.remember()
	slime.reset()
	scents.puff(slime.drop_target(), 4)
	_play(_slurps.pick_random())
	_refresh_undo()


func _on_color(c: Color, from: Vector2) -> void:
	var pour := PourScript.new()
	pour.color = c
	pour.start = from
	pour.target = slime.drop_target()
	pour.position = from
	pour.landed.connect(func(col: Color, _at: Vector2): slime.drop(col); scents.puff(slime.drop_target(), 3); _play(_slurps.pick_random()); _save())
	add_child(pour)
	_play(_pops.pick_random())


## Pickers show free items always, premium items only when owned or purchasable.
func _rebuild_pickers() -> void:
	var titems := []
	for id in THEMES:
		titems.append({"id": id, "draw": _draw_theme_tile.bind(id)})
	if store.show_premium():
		for id in PREMIUM_THEMES:
			titems.append({"id": id, "draw": _draw_theme_tile.bind(id), "locked": not store.is_unlocked()})
	themes.set_items(titems)
	var sitems := [
		{"id": "beads", "draw": _draw_sprinkle_tile.bind("beads")},
		{"id": "stars", "draw": _draw_sprinkle_tile.bind("stars")},
	]
	if store.show_premium():
		sitems.append({"id": "rainbow", "draw": _draw_sprinkle_tile.bind("rainbow"), "locked": not store.is_unlocked()})
	sprinkles_picker.set_items(sitems)
	var stitems := [
		{"id": "star", "draw": _draw_stamp_tile.bind("star")},
		{"id": "heart", "draw": _draw_stamp_tile.bind("heart")},
		{"id": "circle", "draw": _draw_stamp_tile.bind("circle")},
		{"id": "flower", "draw": _draw_stamp_tile.bind("flower")},
	]
	stamps_picker.set_items(stitems)


func _theme_data(id: String) -> Dictionary:
	return THEMES[id] if THEMES.has(id) else PREMIUM_THEMES[id]


func _on_sprinkle(id: String) -> void:
	slime.remember()
	match id:
		"beads":
			slime.addins.sprinkle(0, 10)
		"stars":
			slime.addins.sprinkle(1, 10)
		"rainbow":
			slime.addins.sprinkle(0, 8)
			slime.addins.sprinkle(1, 6)
	_play(_sprinkle)
	_refresh_undo()


func _on_glue() -> void:
	if mixing:
		return
	slime.remember()
	var from := Vector2(slime.drop_target().x, _play_area.position.y - 60)
	var pour := PourScript.new()
	pour.color = Color("f2f2f6")
	pour.start = from
	pour.target = slime.drop_target()
	pour.position = from
	pour.landed.connect(func(_c: Color, _at: Vector2):
		if slime.add_glue():
			scents.puff(slime.drop_target(), 3)
			_play(_slurps.pick_random())
		else:
			_play(_pops.pick_random())
		_refresh_undo())
	add_child(pour)


func _on_undo() -> void:
	if mixing:
		return
	if slime.undo():
		_play(_squish.pick_random())
	_refresh_undo()


func _refresh_undo() -> void:
	ui.set_undo_enabled(slime.can_undo())


func _draw_sprinkle_tile(c: CanvasItem, r: Rect2, id: String) -> void:
	var centre := r.get_center()
	match id:
		"beads":
			for q: Vector2 in [Vector2(-40, 20), Vector2(30, 28), Vector2(0, -30), Vector2(-20, -5), Vector2(38, -22)]:
				c.draw_circle(centre + q, 22, Color.from_hsv(fmod(q.x * 0.01 + 0.5, 1.0), 0.45, 1.0))
				c.draw_circle(centre + q + Vector2(-7, -7), 7, Color(1, 1, 1, 0.7))
		"stars":
			for q: Vector2 in [Vector2(-34, 22), Vector2(34, -26), Vector2(6, 10)]:
				var pts := PackedVector2Array()
				for i in 10:
					var rr := 30.0 if i % 2 == 0 else 13.0
					var a := -PI / 2 + TAU * i / 10
					pts.append(centre + q + Vector2(cos(a), sin(a)) * rr)
				c.draw_colored_polygon(pts, [Color("ffd84d"), Color("ff9ad5"), Color("7fe3ff")][int(q.x) % 3])
		"rainbow":
			for i in 7:
				var a := -PI / 2 + TAU * i / 7.0
				c.draw_circle(centre + Vector2(cos(a), sin(a)) * 48, 18, Color.from_hsv(i / 7.0, 0.7, 1.0))
			var pts := PackedVector2Array()
			for i in 10:
				var rr := 26.0 if i % 2 == 0 else 11.0
				var a := -PI / 2 + TAU * i / 10
				pts.append(centre + Vector2(cos(a), sin(a)) * rr)
			c.draw_colored_polygon(pts, Color.WHITE)


func _draw_stamp_tile(c: CanvasItem, r: Rect2, shape: String) -> void:
	var centre := r.get_center()
	var pts := PackedVector2Array()
	match shape:
		"star":
			for i in 10:
				var rr := 70.0 if i % 2 == 0 else 32.0
				var a := -PI / 2 + TAU * i / 10
				pts.append(centre + Vector2(cos(a), sin(a)) * rr)
		"heart":
			for i in 40:
				var t := TAU * i / 40.0
				var x := 16.0 * pow(sin(t), 3.0)
				var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
				pts.append(centre + Vector2(x, y) * 4.2 + Vector2(0, 6))
		"circle":
			for i in 32:
				var a := TAU * i / 32.0
				pts.append(centre + Vector2(cos(a), sin(a)) * 62)
		"flower":
			for i in 60:
				var a := TAU * i / 60.0
				var rr := 70.0 * (0.62 + 0.38 * absf(cos(2.5 * a)))
				pts.append(centre + Vector2(cos(a), sin(a)) * rr)
	pts.append(pts[0])
	c.draw_polyline(pts, {"star": Color("8a8fa8"), "heart": Color("ff7aa8"), "circle": Color("4fb8ff"), "flower": Color("ff9b2f")}[shape], 12.0, true)


func _apply_theme(id: String) -> void:
	var t: Dictionary = _theme_data(id)
	slime.remember()
	slime.color = t["color"]
	slime.style = t["style"]
	slime.sparkle = t["sparkle"]
	slime.reset()
	var drops: Array = t["drops"]
	for i in drops.size():
		var a := TAU * i / drops.size() + 0.7
		slime.drop(drops[i], Vector2(cos(a), sin(a)) * 7.0)
	slime.color = t["color"]
	if t["beads"] > 0:
		slime.addins.sprinkle(0, t["beads"])
	if t["stars"] > 0:
		slime.addins.sprinkle(1, t["stars"])
	scents.scent = t["scent"]
	ui.set_scent(scents.scent)
	ui.set_state(slime.color, slime.style, slime.sparkle)
	scents.puff(slime.drop_target(), 5)
	_play(_slurps.pick_random())
	_save()


func _draw_theme_tile(c: CanvasItem, r: Rect2, id: String) -> void:
	var t: Dictionary = _theme_data(id)
	var centre := r.get_center()
	var rad := r.size.x * 0.34
	var base: Color = t["color"]
	c.draw_circle(centre + Vector2(6, 10), rad, Color(0, 0, 0, 0.12))
	c.draw_circle(centre, rad, base)
	var drops: Array = t["drops"]
	for i in drops.size():
		var a := TAU * i / drops.size() + 0.7
		c.draw_circle(centre + Vector2(cos(a), sin(a)) * rad * 0.45, rad * 0.3, drops[i])
	c.draw_circle(centre + Vector2(-rad * 0.4, -rad * 0.45), rad * 0.22, Color(1, 1, 1, 0.75))
	if t["sparkle"]:
		for q: Vector2 in [Vector2(0.6, -0.7), Vector2(-0.8, 0.2), Vector2(0.4, 0.75)]:
			var p: Vector2 = centre + q * rad
			c.draw_line(p + Vector2(-9, 0), p + Vector2(9, 0), Color.WHITE, 3.0, true)
			c.draw_line(p + Vector2(0, -9), p + Vector2(0, 9), Color.WHITE, 3.0, true)
	if t["beads"] > 0:
		for q: Vector2 in [Vector2(0.3, 0.3), Vector2(-0.5, 0.5), Vector2(0.1, -0.3)]:
			c.draw_circle(centre + q * rad, 6, Color("ffffff"))
	if t["stars"] > 0:
		for q: Vector2 in [Vector2(0.5, 0.5), Vector2(-0.6, -0.3)]:
			var p: Vector2 = centre + q * rad
			var pts := PackedVector2Array()
			for i in 10:
				var rr := 10.0 if i % 2 == 0 else 4.5
				var ang := -PI / 2 + TAU * i / 10
				pts.append(p + Vector2(cos(ang), sin(ang)) * rr)
			c.draw_colored_polygon(pts, Color("ffd84d"))
	if t["scent"] != "":
		c.draw_set_transform(r.position + Vector2(r.size.x - 34, 34), 0.0, Vector2(0.9, 0.9))
		ScentsScript.draw_icon(c, t["scent"], 1.0)
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_scent_tile(c: CanvasItem, r: Rect2, kind: String) -> void:
	c.draw_set_transform(r.get_center(), 0.0, Vector2(2.6, 2.6))
	ScentsScript.draw_icon(c, kind, 1.0)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Android back: close whatever is open, never quit by accident
		if jars.visible:
			jars.close()
		elif themes.visible:
			themes.close()
		elif scents_picker.visible:
			scents_picker.close()
		elif sprinkles_picker.visible:
			sprinkles_picker.close()
		elif stamps_picker.visible:
			stamps_picker.close()
		elif gate.visible:
			gate.close()
		elif _roller:
			_roller = false
			ui.set_roller(false)
			_on_roller(false)
		elif _knife:
			_knife = false
			ui.set_knife(false)
			_on_knife(false)


# ---------------------------------------------------------------- snapshot

func _snapshot() -> void:
	if _snapping or mixing:
		return
	_snapping = true
	_play(_click)
	ui.visible = false
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	ui.visible = true
	var saved := _save_image(img)
	_flash_and_polaroid(img, saved)
	_snapping = false


func _save_image(img: Image) -> bool:
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var name := "slime-%s.png" % stamp
	if _save_to_gallery(img, name):
		return true
	var pics := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if pics != "":
		var dir := pics.path_join("Slime")
		if DirAccess.make_dir_recursive_absolute(dir) == OK and img.save_png(dir.path_join(name)) == OK:
			return true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://snapshots"))
	return img.save_png("user://snapshots/" + name) == OK


## Android 10+: insert the PNG into MediaStore (Pictures/Slime) so it shows in the
## tablet's gallery with no storage permission. Uses Godot's JavaClassWrapper.
func _save_to_gallery(img: Image, name: String) -> bool:
	if OS.get_name() != "Android":
		return false
	var rt = Engine.get_singleton("AndroidRuntime")
	if rt == null:
		return false
	var activity = rt.getActivity()
	if activity == null:
		return false
	var resolver = activity.getContentResolver()
	var ContentValues = JavaClassWrapper.wrap("android.content.ContentValues")
	var values = ContentValues.ContentValues()
	values.put("_display_name", name)
	values.put("mime_type", "image/png")
	values.put("relative_path", "Pictures/Slime")
	var Media = JavaClassWrapper.wrap("android.provider.MediaStore$Images$Media")
	var collection = Media.getContentUri("external")
	var uri = resolver.insert(collection, values)
	if JavaClassWrapper.get_exception() != null or uri == null:
		push_warning("MediaStore insert failed")
		return false
	var out = resolver.openOutputStream(uri)
	if JavaClassWrapper.get_exception() != null or out == null:
		return false
	out.write(img.save_png_to_buffer())
	out.flush()
	out.close()
	if JavaClassWrapper.get_exception() != null:
		push_warning("MediaStore write failed")
		return false
	return true


func _flash_and_polaroid(img: Image, _saved: bool) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.85)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flash)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := TextureRect.new()
	card.texture = ImageTexture.create_from_image(img)
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_SCALE
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := Vector2(get_tree().root.content_scale_size)
	card.size = vp * 0.5
	card.pivot_offset = card.size * 0.5
	card.position = vp * 0.25
	layer.add_child(card)
	var frame := ReferenceRect.new()
	frame.editor_only = false
	frame.border_color = Color.WHITE
	frame.border_width = 14.0
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(flash, "color:a", 0.0, 0.35)
	tw.tween_property(card, "scale", Vector2(0.18, 0.18), 0.9).set_delay(0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(card, "position", Vector2(vp.x * 0.5 - card.size.x * 0.5, vp.y - card.size.y * 0.5 - 40), 0.9).set_delay(0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(card, "modulate:a", 0.0, 0.4).set_delay(1.6)
	tw.chain().tween_callback(layer.queue_free)


# ---------------------------------------------------------------- knife & sound

func _on_knife(on: bool) -> void:
	_knife = on
	if on:
		_roller = false
	slime.set_process_unhandled_input(not (_knife or _roller))
	_knife_pts.clear()
	_play(_click)


func _on_roller(on: bool) -> void:
	_roller = on
	if on:
		_knife = false
	slime.set_process_unhandled_input(not (_knife or _roller))
	_knife_pts.clear()
	_play(_click)


func _unhandled_input(event: InputEvent) -> void:
	if not (_knife or _roller) or mixing:
		return
	if event is InputEventScreenTouch:
		var p := make_canvas_position_local(event.position)
		if event.pressed:
			if _knife_pts.is_empty():
				slime.remember()
			_knife_pts[event.index] = p
			_knife_trail.roller = _roller
			_knife_trail.begin(p)
		else:
			_knife_pts.erase(event.index)
			_knife_trail.end()
			_refresh_undo()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and _knife_pts.has(event.index):
		var p := make_canvas_position_local(event.position)
		var prev: Vector2 = _knife_pts[event.index]
		if p.distance_to(prev) > 6.0:
			if _roller:
				if slime.roll(prev, p) and randf() < 0.12:
					_play(_squelches.pick_random())
			else:
				slime.slice(prev, p)
			_knife_pts[event.index] = p
			_knife_trail.add(p)
		get_viewport().set_input_as_handled()


## Glow-in-the-dark slime turns the lights off.
func _on_style_changed(st: String) -> void:
	if _bg_dark == null:
		return
	var tw := create_tween()
	tw.tween_property(_bg_dark, "modulate:a", 1.0 if st == "glow" else 0.0, 0.6)


## Wet loop follows how fast the kids are kneading.
func _on_kneading(speed: float) -> void:
	var k := clampf(speed / 1.4, 0.0, 1.0)
	_wet_target_db = lerpf(-60.0, -8.0, sqrt(k))
	_wet.pitch_scale = 0.8 + 0.6 * k + _kind_pitch() * 1.2


func _thumb_image() -> Image:
	ui.visible = false
	jars.visible = false
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	ui.visible = true
	jars.visible = true
	var vp := Vector2(get_tree().root.content_scale_size)
	var r := Rect2i(Vector2i(_play_area.position), Vector2i(_play_area.size))
	img = img.get_region(r)
	img.resize(260, 325, Image.INTERPOLATE_BILINEAR)
	return img


class KnifeTrail extends Node2D:
	var roller := false
	var _pts := PackedVector2Array()
	var _fade := 0.0
	func begin(p: Vector2) -> void:
		_pts = PackedVector2Array([p])
		_fade = 1.0
	func add(p: Vector2) -> void:
		_pts.append(p)
		if _pts.size() > 24:
			_pts.remove_at(0)
		queue_redraw()
	func end() -> void:
		_pts = PackedVector2Array()
		queue_redraw()
	func _process(delta: float) -> void:
		if _pts.size() > 1:
			_fade = maxf(0.0, _fade - delta * 0.5)
			queue_redraw()
	func _draw() -> void:
		if _pts.size() < 2:
			return
		var tip := _pts[_pts.size() - 1]
		var dir := (tip - _pts[_pts.size() - 2]).normalized()
		var n := Vector2(-dir.y, dir.x)
		if roller:
			draw_set_transform(tip, dir.angle(), Vector2.ONE)
			draw_rect(Rect2(Vector2(-18, -70), Vector2(36, 140)), Color("d9a46a"))
			draw_rect(Rect2(Vector2(-10, -96), Vector2(20, 26)), Color("8a6a4a"))
			draw_rect(Rect2(Vector2(-10, 70), Vector2(20, 26)), Color("8a6a4a"))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_polyline(_pts, Color(1, 1, 1, 0.75), 6.0, true)
			draw_colored_polygon(PackedVector2Array([tip + dir * 70, tip + n * 14 - dir * 10, tip - n * 14 - dir * 10]), Color("e6ebf3"))


# ---------------------------------------------------------------- settings

func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("slime", "color", slime.color)
	cf.set_value("slime", "sparkle", slime.sparkle)
	cf.set_value("slime", "style", slime.style)
	cf.set_value("slime", "scent", scents.scent)
	cf.save(SETTINGS)


## Returns false on a fresh install (no settings yet).
func _load() -> bool:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS) != OK:
		return false
	slime.color = cf.get_value("slime", "color", slime.color)
	slime.sparkle = cf.get_value("slime", "sparkle", false)
	slime.style = cf.get_value("slime", "style", "shiny")
	slime.reset()
	scents.scent = cf.get_value("slime", "scent", "")
	ui.set_scent(scents.scent)
	ui.set_state(slime.color, slime.style, slime.sparkle)
	return true


func _process(delta: float) -> void:
	if _hint_t > 0.0:
		_hint_t -= delta
		if _hint_t <= 0.0:
			_hint.hide_hand()
	if _wet:
		_wet.volume_db = lerpf(_wet.volume_db, _wet_target_db, minf(1.0, delta * 8.0))
	if OS.is_debug_build():
		_fps_timer += delta
		if _fps_timer > 3.0:
			_fps_timer = 0.0
			print("fps %d" % Engine.get_frames_per_second())
