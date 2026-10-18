extends CanvasLayer
## Shelf of six jars. Tap an empty jar to put the current slime in it, tap a full jar
## to take that slime out, hold a full jar to replace it with the current slime.

signal jar_saved(index: int)
signal jar_loaded(index: int, state: Dictionary)
signal closed

const COUNT := 6
const DIR := "user://jars"
const HOLD := 0.7

var _thumbs: Array = []      # Texture2D or null
var _shade: ColorRect
var _board: ShelfBoard
var _hold_idx := -1
var _hold_t := 0.0
var _get_state: Callable
var _get_thumb: Callable


func setup(get_state: Callable, get_thumb: Callable) -> void:
	_get_state = get_state
	_get_thumb = get_thumb
	layer = 6
	visible = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	_thumbs.resize(COUNT)
	for i in COUNT:
		_thumbs[i] = _load_thumb(i)
	_shade = ColorRect.new()
	_shade.color = Color(0.1, 0.1, 0.15, 0.55)
	add_child(_shade)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.gui_input.connect(_on_shade_input)
	_board = ShelfBoard.new()
	_board.shelf = self
	add_child(_board)


func open() -> void:
	visible = true
	_hold_idx = -1
	_board.queue_redraw()


func close() -> void:
	visible = false
	closed.emit()


func layout_rects() -> Array[Rect2]:
	var vp := Vector2(get_tree().root.content_scale_size)
	var portrait := vp.y > vp.x
	var cols := 3 if portrait else 6
	var rows := 2 if portrait else 1
	var jw := minf(260.0, (vp.x - 120.0 - (cols - 1) * 30.0) / cols)
	var jh := jw * 1.25
	var total_w := cols * jw + (cols - 1) * 30.0
	var total_h := rows * jh + (rows - 1) * 40.0
	var x0 := (vp.x - total_w) * 0.5
	var y0 := (vp.y - total_h) * 0.5
	var out: Array[Rect2] = []
	for i in COUNT:
		var cx := i % cols
		var cy := i / cols
		out.append(Rect2(x0 + cx * (jw + 30.0), y0 + cy * (jh + 40.0), jw, jh))
	return out


func _on_shade_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch or ev is InputEventMouseButton:
		var pressed: bool = ev.pressed
		var pos: Vector2 = ev.position
		var rects := layout_rects()
		var hit := -1
		for i in COUNT:
			if rects[i].grow(10).has_point(pos):
				hit = i
		if pressed:
			if hit < 0:
				close()
				return
			_hold_idx = hit
			_hold_t = 0.0
		else:
			if _hold_idx >= 0 and _hold_t < HOLD:
				_tap(_hold_idx)
			_hold_idx = -1
			_board.hold_frac = 0.0
			_board.queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	if _hold_idx >= 0:
		_hold_t += delta
		_board.hold_idx = _hold_idx
		_board.hold_frac = clampf(_hold_t / HOLD, 0.0, 1.0)
		_board.queue_redraw()
		if _hold_t >= HOLD and _thumbs[_hold_idx] != null:
			_save(_hold_idx)
			_hold_idx = -1
			_board.hold_frac = 0.0
		elif _hold_t >= HOLD:
			_save(_hold_idx)
			_hold_idx = -1
			_board.hold_frac = 0.0


func _tap(i: int) -> void:
	if _thumbs[i] == null:
		_save(i)
	else:
		var st := _load_state(i)
		if st.is_empty():
			return
		jar_loaded.emit(i, st)
		close()


func _save(i: int) -> void:
	var st: Dictionary = _get_state.call()
	var f := FileAccess.open("%s/jar%d.var" % [DIR, i], FileAccess.WRITE)
	if f:
		f.store_var(st, false)
		f.close()
	var img: Image = await _get_thumb.call()
	if img:
		img.save_png("%s/jar%d.png" % [DIR, i])
		_thumbs[i] = ImageTexture.create_from_image(img)
	jar_saved.emit(i)
	_board.queue_redraw()


func _load_state(i: int) -> Dictionary:
	var f := FileAccess.open("%s/jar%d.var" % [DIR, i], FileAccess.READ)
	if f == null:
		return {}
	var v = f.get_var(false)
	f.close()
	return v if v is Dictionary else {}


func _load_thumb(i: int) -> Texture2D:
	var path := "%s/jar%d.png" % [DIR, i]
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	return ImageTexture.create_from_image(img) if img else null


func thumb(i: int) -> Texture2D:
	return _thumbs[i]


class ShelfBoard extends Node2D:
	var shelf: CanvasLayer
	var hold_idx := -1
	var hold_frac := 0.0

	func _draw() -> void:
		var rects: Array[Rect2] = shelf.layout_rects()
		for i in rects.size():
			var r: Rect2 = rects[i]
			# shelf plank
			draw_rect(Rect2(r.position + Vector2(-16, r.size.y - 6), Vector2(r.size.x + 32, 22)), Color("c9b89a"))
			# glass jar
			var body := Rect2(r.position + Vector2(0, r.size.y * 0.16), Vector2(r.size.x, r.size.y * 0.84))
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.92, 0.96, 1.0, 0.85)
			style.set_corner_radius_all(28)
			style.border_color = Color(1, 1, 1, 0.9)
			style.set_border_width_all(4)
			draw_style_box(style, body)
			# lid
			draw_rect(Rect2(r.position + Vector2(r.size.x * 0.15, 0), Vector2(r.size.x * 0.7, r.size.y * 0.18)), Color("8e99ad"))
			draw_rect(Rect2(r.position + Vector2(r.size.x * 0.15, r.size.y * 0.04), Vector2(r.size.x * 0.7, r.size.y * 0.04)), Color("b8c2d4"))
			var t: Texture2D = shelf.thumb(i)
			if t:
				var inner := body.grow(-14)
				var ts := t.get_size()
				var scale := maxf(inner.size.x / ts.x, inner.size.y / ts.y)
				var dst := Rect2(inner.position + (inner.size - ts * scale) * 0.5, ts * scale)
				# clip to the jar with a simple inset rect
				draw_texture_rect_region(t, inner, Rect2((ts - inner.size / scale) * 0.5, inner.size / scale))
				draw_rect(inner, Color(1, 1, 1, 0.12))
			else:
				# empty: faint plus
				var c := body.get_center()
				draw_line(c + Vector2(-26, 0), c + Vector2(26, 0), Color(0.5, 0.6, 0.75, 0.5), 8.0, true)
				draw_line(c + Vector2(0, -26), c + Vector2(0, 26), Color(0.5, 0.6, 0.75, 0.5), 8.0, true)
			# glass highlight
			draw_rect(Rect2(body.position + Vector2(14, 20), Vector2(10, body.size.y * 0.5)), Color(1, 1, 1, 0.45))
			if i == hold_idx and hold_frac > 0.0:
				draw_arc(body.get_center(), r.size.x * 0.42, -PI / 2, -PI / 2 + TAU * hold_frac, 48, Color("ff6b6b"), 10.0, true)
