extends CanvasLayer
class_name SlimeUI
## Icon-only controls: a column of colour dots on the right, and two round
## buttons bottom-left (sparkle toggle, new slime). No text anywhere.

signal color_picked(c: Color)
signal sparkle_toggled(on: bool)
signal reset_pressed

const PALETTE: Array[Color] = [
	Color("6fe36a"),  # lime
	Color("3fe0b8"),  # mint
	Color("4fb8ff"),  # sky
	Color("9d6bff"),  # purple
	Color("ff5fb8"),  # pink
	Color("ff4d4d"),  # red
	Color("ff9b2f"),  # orange
	Color("ffe44d"),  # yellow
	Color("f4f4ff"),  # cloud
	Color("2c2c5e"),  # galaxy
]
const DOT := 88.0

var _buttons: Array[Button] = []
var _selected := 0
var _sparkle := false


func _ready() -> void:
	var col := VBoxContainer.new()
	col.name = "Palette"
	col.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	col.offset_right = -24
	col.offset_left = -24 - DOT
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(col)
	for i in PALETTE.size():
		var b := _round_button(PALETTE[i])
		b.pressed.connect(_on_color.bind(i))
		col.add_child(b)
		_buttons.append(b)
	_refresh_selection()

	var row := HBoxContainer.new()
	row.name = "Tools"
	row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	row.offset_left = 24
	row.offset_bottom = -24
	row.offset_top = -24 - DOT
	row.add_theme_constant_override("separation", 18)
	add_child(row)

	var spark := _round_button(Color("ffffff"), Color("ffd84d"))
	spark.add_child(_icon(IconKind.STAR))
	spark.pressed.connect(_on_sparkle)
	row.add_child(spark)

	var fresh := _round_button(Color("ffffff"), Color("4fb8ff"))
	fresh.add_child(_icon(IconKind.PLUS))
	fresh.pressed.connect(func(): reset_pressed.emit())
	row.add_child(fresh)


func _round_button(fill: Color, border := Color(1, 1, 1, 0.9)) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(DOT, DOT)
	b.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, _dot_style(fill, border, 0))
	b.add_theme_stylebox_override("pressed", _dot_style(fill.darkened(0.15), border, 0))
	return b


func _dot_style(fill: Color, border: Color, border_w: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.set_corner_radius_all(int(DOT))
	s.border_color = border
	s.set_border_width_all(border_w)
	s.anti_aliasing = true
	s.shadow_color = Color(0, 0, 0, 0.18)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 4)
	return s


func _refresh_selection() -> void:
	for i in _buttons.size():
		var w := 8 if i == _selected else 0
		_buttons[i].add_theme_stylebox_override("normal", _dot_style(PALETTE[i], Color.WHITE, w))
		_buttons[i].add_theme_stylebox_override("hover", _dot_style(PALETTE[i], Color.WHITE, w))


func _on_color(i: int) -> void:
	_selected = i
	_refresh_selection()
	color_picked.emit(PALETTE[i])


func _on_sparkle() -> void:
	_sparkle = not _sparkle
	sparkle_toggled.emit(_sparkle)


enum IconKind { STAR, PLUS }

func _icon(kind: IconKind) -> Control:
	var c := IconControl.new()
	c.kind = kind
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


class IconControl extends Control:
	var kind: int = 0
	func _draw() -> void:
		var c := size * 0.5
		var col := Color("ffd84d") if kind == 0 else Color("4fb8ff")
		if kind == 0:
			var pts := PackedVector2Array()
			for i in 10:
				var r := 26.0 if i % 2 == 0 else 11.0
				var a := -PI / 2 + TAU * i / 10
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			draw_colored_polygon(pts, col)
		else:
			draw_line(c + Vector2(-24, 0), c + Vector2(24, 0), col, 10.0, true)
			draw_line(c + Vector2(0, -24), c + Vector2(0, 24), col, 10.0, true)
