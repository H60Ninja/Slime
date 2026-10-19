extends CanvasLayer
## Parental gate before a purchase: a grown-up holds the big lock for three seconds.
## Icon-only, no reading needed. Then the shop sheet shows what the unlock contains.

signal confirmed
signal closed

const HOLD := 3.0

var _shade: ColorRect
var _board: Board
var _t := 0.0
var _holding := false


func _ready() -> void:
	layer = 7
	visible = false
	_shade = ColorRect.new()
	_shade.color = Color(0.1, 0.1, 0.15, 0.6)
	add_child(_shade)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.gui_input.connect(_on_input)
	_board = Board.new()
	_board.gate = self
	add_child(_board)


func open() -> void:
	_t = 0.0
	_holding = false
	visible = true
	_board.queue_redraw()


func close() -> void:
	visible = false
	closed.emit()


func lock_rect() -> Rect2:
	var vp := Vector2(get_tree().root.content_scale_size)
	return Rect2(vp * 0.5 - Vector2(130, 130), Vector2(260, 260))


var _hold_index := -1

func _on_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch or ev is InputEventMouseButton:
		var idx: int = ev.index if ev is InputEventScreenTouch else 0
		if ev.pressed:
			if _holding:
				return   # a second finger must not cancel the grown-up's hold
			if lock_rect().grow(20).has_point(ev.position):
				_holding = true
				_hold_index = idx
				_t = 0.0
			else:
				close()
		elif _holding and idx == _hold_index:
			_holding = false
			_t = 0.0
			_board.queue_redraw()


func _process(delta: float) -> void:
	if not visible or not _holding:
		return
	_t += delta
	_board.queue_redraw()
	if _t >= HOLD:
		_holding = false
		visible = false
		confirmed.emit()


class Board extends Node2D:
	var gate: CanvasLayer
	func _draw() -> void:
		var r: Rect2 = gate.lock_rect()
		var c := r.get_center()
		var k: float = clampf(gate._t / gate.HOLD, 0.0, 1.0)
		draw_circle(c, 150, Color(1, 1, 1, 0.95))
		# lock body + shackle
		draw_rect(Rect2(c + Vector2(-60, -10), Vector2(120, 90)), Color("5a6478"))
		draw_arc(c + Vector2(0, -20), 42, PI, TAU, 24, Color("5a6478"), 18.0, true)
		draw_circle(c + Vector2(0, 30), 14, Color.WHITE)
		# progress ring + grown-up hand hint (big hand) 
		draw_arc(c, 150, -PI / 2, -PI / 2 + TAU * k, 64, Color("4fb8ff"), 14.0, true)
		if k > 0.0:
			draw_circle(c, 150, Color(0.31, 0.72, 1.0, 0.12 * k))
		# three dots = "3 seconds"
		for i in 3:
			var on := k > (i + 1) / 3.0 - 0.001
			draw_circle(c + Vector2(-40 + i * 40, 125), 12, Color("4fb8ff") if on else Color(0.6, 0.65, 0.75, 0.6))
