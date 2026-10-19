extends CanvasLayer
## Generic icon-only picker overlay: a grid of round-cornered tiles, each drawn by a
## callable. Tap a tile to pick it, tap outside or the X to close.

signal picked(id: String)
signal closed

var _items: Array = []   # {id, draw: Callable(canvas: CanvasItem, rect: Rect2)}
var _selected := ""
var _shade: ColorRect
var _board: Board
var _cols := 4


func setup(items: Array, cols := 4) -> void:
	_items = items
	_cols = cols
	layer = 6
	visible = false
	_shade = ColorRect.new()
	_shade.color = Color(0.1, 0.1, 0.15, 0.55)
	add_child(_shade)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.gui_input.connect(_on_input)
	_board = Board.new()
	_board.picker = self
	add_child(_board)


func open(selected := "") -> void:
	_selected = selected
	visible = true
	_board.queue_redraw()


func close() -> void:
	visible = false
	closed.emit()


func rects() -> Array[Rect2]:
	var vp := Vector2(get_tree().root.content_scale_size)
	var portrait := vp.y > vp.x
	var cols := mini(_cols, 3) if portrait else _cols
	var n := _items.size()
	var rows := int(ceil(float(n) / cols))
	var gap := 28.0
	var tw := minf(260.0, (vp.x - 160.0 - (cols - 1) * gap) / cols)
	var th := tw
	var total_w := cols * tw + (cols - 1) * gap
	var total_h := rows * th + (rows - 1) * gap
	var x0 := (vp.x - total_w) * 0.5
	var y0 := (vp.y - total_h) * 0.5
	var out: Array[Rect2] = []
	for i in n:
		out.append(Rect2(x0 + (i % cols) * (tw + gap), y0 + (i / cols) * (th + gap), tw, th))
	return out


func close_rect() -> Rect2:
	var vp := Vector2(get_tree().root.content_scale_size)
	return Rect2(vp.x - 24 - 88, 24, 88, 88)


func _on_input(ev: InputEvent) -> void:
	if (ev is InputEventScreenTouch or ev is InputEventMouseButton) and ev.pressed:
		var pos: Vector2 = ev.position
		if close_rect().grow(12).has_point(pos):
			close()
			return
		var rs := rects()
		for i in rs.size():
			if rs[i].grow(8).has_point(pos):
				_selected = _items[i]["id"]
				picked.emit(_selected)
				close()
				return
		close()


class Board extends Node2D:
	var picker: CanvasLayer

	func _draw() -> void:
		var rs: Array[Rect2] = picker.rects()
		for i in rs.size():
			var r: Rect2 = rs[i]
			var sel: bool = picker._items[i]["id"] == picker._selected
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color.WHITE
			sb.set_corner_radius_all(36)
			sb.shadow_color = Color(0, 0, 0, 0.25)
			sb.shadow_size = 10
			sb.shadow_offset = Vector2(0, 6)
			if sel:
				sb.border_color = Color("4fb8ff")
				sb.set_border_width_all(8)
			draw_style_box(sb, r)
			picker._items[i]["draw"].call(self, r.grow(-18))
		# close X
		var c: Rect2 = picker.close_rect()
		var sbx := StyleBoxFlat.new()
		sbx.bg_color = Color.WHITE
		sbx.set_corner_radius_all(44)
		draw_style_box(sbx, c)
		var cc: Vector2 = c.get_center()
		draw_line(cc + Vector2(-20, -20), cc + Vector2(20, 20), Color("5a6478"), 9.0, true)
		draw_line(cc + Vector2(-20, 20), cc + Vector2(20, -20), Color("5a6478"), 9.0, true)
