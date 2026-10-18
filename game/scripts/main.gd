extends Node2D
## Root scene: table background, the slime, the make-slime ritual, the icon UI, sounds.

const SETTINGS := "user://settings.cfg"
const SlimeScript := preload("res://scripts/slime.gd")
const UIScript := preload("res://scripts/ui.gd")
const PourScript := preload("res://scripts/pour.gd")
const MixingScript := preload("res://scripts/mixing.gd")
const JarsScript := preload("res://scripts/jars.gd")

var slime: Node2D
var ui: CanvasLayer
var mixing: Node2D = null
var _play_area := Rect2()
var _squish: Array[AudioStreamPlayer] = []
var _pop: AudioStreamPlayer
var _slurp: AudioStreamPlayer
var _squelch: AudioStreamPlayer
var _stretch: AudioStreamPlayer
var _sprinkle: AudioStreamPlayer
var _crackle: AudioStreamPlayer
var _poof: AudioStreamPlayer
var _click: AudioStreamPlayer
var _bubble: Array[AudioStreamPlayer] = []
var _wet: AudioStreamPlayer
var _slice_wet: AudioStreamPlayer
var _slice_crunch: AudioStreamPlayer
var _jar: AudioStreamPlayer
var jars: CanvasLayer
var _knife := false
var _knife_pts := {}   # touch index -> last px
var _knife_trail: KnifeTrail
var _wet_target_db := -60.0
var _bg: TextureRect
var _bg_dark: ColorRect
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
	ui.sparkle_toggled.connect(func(on: bool): slime.sparkle = on; _play(_pop); _save())
	ui.reset_pressed.connect(_on_new)
	ui.addin_pressed.connect(func(kind: int): slime.addins.sprinkle(kind, 10); _play(_sprinkle))
	ui.stamp_pressed.connect(func(shape: String): slime.stamp(shape); _play(_squelch))
	ui.snapshot_pressed.connect(_snapshot)
	ui.knife_toggled.connect(_on_knife)
	ui.jars_pressed.connect(func(): if not mixing: jars.open(); _play(_jar))
	slime.kneading.connect(_on_kneading)
	slime.style_changed.connect(_on_style_changed)
	slime.sliced.connect(func(): _play(_slice_crunch if slime.style == "crunchy" else _slice_wet))
	slime.touched.connect(func(inside: bool): if inside: _play(_touch_sound()))
	slime.released.connect(func(inside: bool): if inside: _play(_pop); slime.wobble(0.3))
	slime.stretched.connect(func(): _play(_crackle if slime.style == "crunchy" else _stretch))
	slime.held.connect(func(): _play(_poof if slime.style == "fluffy" else _squelch))
	slime.bubbles.popped.connect(func(): _play(_bubble.pick_random()))

	for k in 3:
		_squish.append(_player("res://assets/sfx/squish%d.wav" % k))
	_pop = _player("res://assets/sfx/pop.wav", -6.0)
	_slurp = _player("res://assets/sfx/slurp.wav")
	_squelch = _player("res://assets/sfx/squelch.wav", -3.0)
	_stretch = _player("res://assets/sfx/stretch.wav", -4.0)
	_sprinkle = _player("res://assets/sfx/sprinkle.wav", -2.0)
	_crackle = _player("res://assets/sfx/crackle.wav", -3.0)
	_poof = _player("res://assets/sfx/poof.wav", -3.0)
	_click = _player("res://assets/sfx/click.wav", -4.0)
	for k in 3:
		_bubble.append(_player("res://assets/sfx/bubble%d.wav" % k, -8.0))
	_slice_wet = _player("res://assets/sfx/slice_wet.wav", -2.0)
	_slice_crunch = _player("res://assets/sfx/slice_crunch.wav", -2.0)
	_jar = _player("res://assets/sfx/jar.wav", -6.0)
	_wet = _player("res://assets/sfx/wet_loop.wav", -60.0)
	var ws := _wet.stream as AudioStreamWAV
	if ws:
		ws.loop_mode = AudioStreamWAV.LOOP_FORWARD
		ws.loop_begin = 0
		ws.loop_end = ws.data.size() / 2
	_wet.play()

	jars = JarsScript.new()
	jars.name = "Jars"
	add_child(jars)
	jars.setup(func(): return slime.get_state(), _thumb_image)
	jars.jar_saved.connect(func(_i: int): _play(_jar))
	jars.jar_loaded.connect(func(_i: int, st: Dictionary): slime.set_state(st); ui.set_state(slime.color, slime.style, slime.sparkle); _play(_slurp); _save())

	_knife_trail = KnifeTrail.new()
	_knife_trail.z_index = 10
	add_child(_knife_trail)

	get_tree().root.size_changed.connect(_layout)
	_layout()
	var first_run := not _load()
	if first_run:
		_start_mixing()


func _touch_sound() -> AudioStreamPlayer:
	match slime.style:
		"crunchy":
			return _crackle
		"fluffy":
			return _poof
	return _squish.pick_random()


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
	_play_area = Rect2(side, 60, vp.x - side * 2.0, vp.y - 60 - 150)
	slime.play_area = _play_area
	if mixing:
		mixing.set_area(_play_area)


func _player(path: String, db := 0.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = db
	add_child(p)
	return p


func _play(p: AudioStreamPlayer) -> void:
	p.pitch_scale = randf_range(0.85, 1.2)
	p.play()


# ---------------------------------------------------------------- make-slime ritual

func _start_mixing() -> void:
	if mixing:
		return
	mixing = MixingScript.new()
	mixing.name = "Mixing"
	mixing.set_area(_play_area)
	mixing.need_color.connect(func(on: bool): ui.pulse_palette(on))
	mixing.poured.connect(func(): _play(_slurp))
	mixing.stirring.connect(func(): _play(_squish.pick_random()))
	mixing.done.connect(_on_mixed)
	add_child(mixing)
	slime.visible = false
	slime.set_process_unhandled_input(false)
	slime.set_physics_process(false)
	_wet_target_db = -60.0
	if _knife:
		_knife = false
		ui.set_knife(false)


func _on_mixed(col: Color) -> void:
	mixing = null
	ui.pulse_palette(false)
	slime.color = col
	slime.reset()
	slime.visible = true
	slime.set_process_unhandled_input(not _knife)
	slime.set_physics_process(true)
	_play(_slurp)
	_save()


func _on_new() -> void:
	if mixing:
		# second tap on + skips the ritual
		mixing.queue_free()
		_on_mixed(slime.color)
		return
	_start_mixing()


func _on_color(c: Color, from: Vector2) -> void:
	var pour := PourScript.new()
	pour.color = c
	pour.start = from
	pour.target = mixing.bowl_center if mixing else slime.drop_target()
	pour.position = from
	if mixing:
		pour.landed.connect(func(col: Color, _at: Vector2): if mixing: mixing.add_color(col); slime.color = col; _play(_slurp); _save())
	else:
		pour.landed.connect(func(col: Color, _at: Vector2): slime.drop(col); _play(_slurp); _save())
	add_child(pour)
	_play(_pop)


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
	slime.set_process_unhandled_input(not on)
	_knife_pts.clear()
	_play(_click)


func _unhandled_input(event: InputEvent) -> void:
	if not _knife or mixing:
		return
	if event is InputEventScreenTouch:
		var p := make_canvas_position_local(event.position)
		if event.pressed:
			_knife_pts[event.index] = p
			_knife_trail.begin(p)
		else:
			_knife_pts.erase(event.index)
			_knife_trail.end()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and _knife_pts.has(event.index):
		var p := make_canvas_position_local(event.position)
		var prev: Vector2 = _knife_pts[event.index]
		if p.distance_to(prev) > 6.0:
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
	_wet.pitch_scale = 0.8 + 0.6 * k
	if slime.style == "clear":
		_wet.pitch_scale += 0.25
	elif slime.style in ["butter", "fluffy", "cloud"]:
		_wet.pitch_scale -= 0.2


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
		draw_polyline(_pts, Color(1, 1, 1, 0.75), 6.0, true)
		var tip := _pts[_pts.size() - 1]
		var dir := (tip - _pts[_pts.size() - 2]).normalized()
		var n := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([tip + dir * 70, tip + n * 14 - dir * 10, tip - n * 14 - dir * 10]), Color("e6ebf3"))


# ---------------------------------------------------------------- settings

func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("slime", "color", slime.color)
	cf.set_value("slime", "sparkle", slime.sparkle)
	cf.set_value("slime", "style", slime.style)
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
	ui.set_state(slime.color, slime.style, slime.sparkle)
	return true


func _process(delta: float) -> void:
	if _wet:
		_wet.volume_db = lerpf(_wet.volume_db, _wet_target_db, minf(1.0, delta * 8.0))
	if OS.is_debug_build():
		_fps_timer += delta
		if _fps_timer > 3.0:
			_fps_timer = 0.0
			print("fps %d" % Engine.get_frames_per_second())
