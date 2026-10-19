extends CanvasLayer
class_name SlimeUI
## Icon-only controls. Right column: colours (tap = pour a drop). Left column: slime
## kinds. Bottom row: new lump, sparkle, beads, stars, star stamp, heart stamp, camera.

signal color_picked(c: Color, from: Vector2)
signal style_picked(style: String)
signal sparkle_toggled(on: bool)
signal addin_pressed(kind: int)
signal stamp_pressed(shape: String)
signal reset_pressed
signal snapshot_pressed
signal knife_toggled(on: bool)
signal jars_pressed
signal bowl_pressed
signal themes_pressed
signal scents_pressed

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
const STYLES := ["shiny", "clear", "metal", "cloud", "crunchy", "butter", "fluffy", "glow", "holo", "magic"]
const DOT := 88.0

enum Icon { PLUS, STAR, SHINY, CLEAR, METAL, CLOUD, BEADS, STARS, STAMP_STAR, STAMP_HEART, CRUNCHY, BUTTER, FLUFFY, CAMERA, GLOW, HOLO, MAGIC, KNIFE, JARS, BOWL, THEMES, SCENTS }
const STYLE_ICONS := [Icon.SHINY, Icon.CLEAR, Icon.METAL, Icon.CLOUD, Icon.CRUNCHY, Icon.BUTTER, Icon.FLUFFY, Icon.GLOW, Icon.HOLO, Icon.MAGIC]

var _buttons: Array[Button] = []
var _style_buttons: Array[Button] = []
var _selected := 0
var _style := 0
var _sparkle := false
var _spark_btn: Button
var _knife_btn: Button
var _knife := false
var _palette: VBoxContainer
var _styles_col: VBoxContainer
var _tools: HFlowContainer
var _scent_btn: Button
var _scent_kind := ""
var _pulse_target: Control = null
var _pulse_t := 0.0
var _pulse: PulseRing


func _ready() -> void:
	var col := VBoxContainer.new()
	col.name = "Palette"
	_palette = col
	add_child(col)
	col.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	col.offset_right = -24
	col.offset_left = -24 - DOT
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in PALETTE.size():
		var b := _round_button(PALETTE[i])
		b.pressed.connect(_on_color.bind(i))
		col.add_child(b)
		_buttons.append(b)

	var left := VBoxContainer.new()
	left.name = "Styles"
	_styles_col = left
	add_child(left)
	left.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	left.offset_left = 24
	left.offset_right = 24 + DOT
	left.add_theme_constant_override("separation", 10)
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in STYLES.size():
		var b := _round_button(Color.WHITE)
		b.add_child(_icon(STYLE_ICONS[i]))
		b.pressed.connect(_on_style.bind(i))
		left.add_child(b)
		_style_buttons.append(b)

	var row := HFlowContainer.new()
	row.name = "Tools"
	_tools = row
	add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	row.offset_left = 24 + DOT + 30
	row.offset_right = -(24 + DOT + 30)
	row.offset_bottom = -24
	row.offset_top = -24 - DOT * 2 - 14
	row.add_theme_constant_override("h_separation", 12)
	row.add_theme_constant_override("v_separation", 14)
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.last_wrap_alignment = FlowContainer.LAST_WRAP_ALIGNMENT_CENTER

	var fresh := _round_button(Color.WHITE)
	fresh.name = "New"
	fresh.add_child(_icon(Icon.PLUS))
	fresh.pressed.connect(func(): reset_pressed.emit())
	row.add_child(fresh)
	var bowl := _round_button(Color.WHITE)
	bowl.add_child(_icon(Icon.BOWL))
	bowl.pressed.connect(func(): bowl_pressed.emit())
	row.add_child(bowl)
	var themes := _round_button(Color.WHITE)
	themes.add_child(_icon(Icon.THEMES))
	themes.pressed.connect(func(): themes_pressed.emit())
	row.add_child(themes)

	row.add_child(_spacer())
	_spark_btn = _round_button(Color.WHITE)
	_spark_btn.add_child(_icon(Icon.STAR))
	_spark_btn.pressed.connect(_on_sparkle)
	row.add_child(_spark_btn)

	row.add_child(_spacer())
	var beads := _round_button(Color.WHITE)
	beads.add_child(_icon(Icon.BEADS))
	beads.pressed.connect(func(): addin_pressed.emit(0))
	row.add_child(beads)
	var stars := _round_button(Color.WHITE)
	stars.add_child(_icon(Icon.STARS))
	stars.pressed.connect(func(): addin_pressed.emit(1))
	row.add_child(stars)

	row.add_child(_spacer())
	var st := _round_button(Color.WHITE)
	st.add_child(_icon(Icon.STAMP_STAR))
	st.pressed.connect(func(): stamp_pressed.emit("star"))
	row.add_child(st)
	var ht := _round_button(Color.WHITE)
	ht.add_child(_icon(Icon.STAMP_HEART))
	ht.pressed.connect(func(): stamp_pressed.emit("heart"))
	row.add_child(ht)

	_knife_btn = _round_button(Color.WHITE)
	_knife_btn.add_child(_icon(Icon.KNIFE))
	_knife_btn.pressed.connect(_on_knife)
	row.add_child(_knife_btn)

	row.add_child(_spacer())
	var cam := _round_button(Color.WHITE)
	cam.add_child(_icon(Icon.CAMERA))
	cam.pressed.connect(func(): snapshot_pressed.emit())
	row.add_child(cam)
	var jars := _round_button(Color.WHITE)
	jars.add_child(_icon(Icon.JARS))
	jars.pressed.connect(func(): jars_pressed.emit())
	row.add_child(jars)
	_scent_btn = _round_button(Color.WHITE)
	_scent_btn.add_child(_icon(Icon.SCENTS))
	_scent_btn.pressed.connect(func(): scents_pressed.emit())
	row.add_child(_scent_btn)

	_pulse = PulseRing.new()
	_pulse.visible = false
	add_child(_pulse)

	_refresh_selection()


## One toolbar row in landscape, two in portrait.
func set_portrait(portrait: bool) -> void:
	_tools.offset_top = (-24 - DOT * 2 - 14) if portrait else (-24 - DOT)


## During the make-slime opening, hide everything the kid doesn't need.
func set_ritual_mode(on: bool) -> void:
	_palette.visible = not on
	_styles_col.visible = not on
	_tools.visible = not on


func set_scent(kind: String) -> void:
	_scent_kind = kind
	_refresh_selection()


## Draw an attention ring around a palette dot ("pick a colour") or hide it.
func pulse_palette(on: bool) -> void:
	_pulse_target = _buttons[_selected] if on else null
	_pulse.visible = on


func _process(delta: float) -> void:
	if _pulse_target:
		_pulse_t += delta
		_pulse.position = _pulse_target.global_position + _pulse_target.size * 0.5
		_pulse.t = _pulse_t
		_pulse.queue_redraw()


func palette_dot_position(i: int) -> Vector2:
	return _buttons[i].global_position + _buttons[i].size * 0.5


func _spacer() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(10, 1)
	return c


func _round_button(fill: Color) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(DOT, DOT)
	b.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, _dot_style(fill, Color.WHITE, 0))
	b.add_theme_stylebox_override("pressed", _dot_style(fill.darkened(0.15), Color.WHITE, 0))
	b.pivot_offset = Vector2(DOT, DOT) * 0.5
	b.button_down.connect(func():
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2(0.86, 0.86), 0.06))
	b.button_up.connect(func():
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2(1.08, 1.08), 0.08)
		tw.tween_property(b, "scale", Vector2.ONE, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK))
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


func _set_ring(b: Button, fill: Color, on: bool, ring := Color.WHITE) -> void:
	var w := 8 if on else 0
	b.add_theme_stylebox_override("normal", _dot_style(fill, ring, w))
	b.add_theme_stylebox_override("hover", _dot_style(fill, ring, w))


func _refresh_selection() -> void:
	for i in _buttons.size():
		_set_ring(_buttons[i], PALETTE[i], i == _selected)
	for i in _style_buttons.size():
		_set_ring(_style_buttons[i], Color.WHITE, i == _style, Color("4fb8ff"))
	_set_ring(_spark_btn, Color.WHITE, _sparkle, Color("ffd84d"))
	_set_ring(_knife_btn, Color.WHITE, _knife, Color("ff6b6b"))
	_set_ring(_scent_btn, Color.WHITE, _scent_kind != "", Color("ff8fcf"))


## Sync with loaded settings (no signals).
func set_state(c: Color, style: String, sparkle: bool) -> void:
	for i in PALETTE.size():
		if PALETTE[i].is_equal_approx(c):
			_selected = i
	_style = maxi(0, STYLES.find(style))
	_sparkle = sparkle
	_refresh_selection()


func _on_color(i: int) -> void:
	_selected = i
	_refresh_selection()
	color_picked.emit(PALETTE[i], palette_dot_position(i))


func _on_style(i: int) -> void:
	_style = i
	_refresh_selection()
	style_picked.emit(STYLES[i])


func set_knife(on: bool) -> void:
	_knife = on
	_refresh_selection()


func _on_knife() -> void:
	_knife = not _knife
	_refresh_selection()
	knife_toggled.emit(_knife)


func _on_sparkle() -> void:
	_sparkle = not _sparkle
	_refresh_selection()
	sparkle_toggled.emit(_sparkle)


func _icon(kind: Icon) -> Control:
	var c := IconControl.new()
	c.kind = kind
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


const ScentDraw := preload("res://scripts/scents.gd")


class PulseRing extends Node2D:
	var t := 0.0
	func _draw() -> void:
		var k := fmod(t, 1.2) / 1.2
		draw_arc(Vector2.ZERO, 52.0 + 30.0 * k, 0.0, TAU, 40, Color(1, 1, 1, 0.9 * (1.0 - k)), 7.0 * (1.0 - k) + 1.0, true)


class IconControl extends Control:
	var kind: int = 0

	func _star(c: Vector2, r_out: float, r_in: float, rot := -PI / 2) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 10:
			var r := r_out if i % 2 == 0 else r_in
			var a := rot + TAU * i / 10
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		return pts

	func _heart(c: Vector2, scale: float) -> PackedVector2Array:
		var hp := PackedVector2Array()
		for i in 40:
			var t := TAU * i / 40.0
			var x := 16.0 * pow(sin(t), 3.0)
			var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
			hp.append(c + Vector2(x, y) * scale + Vector2(0, 2))
		return hp

	func _draw() -> void:
		var c := size * 0.5
		match kind:
			0:  # PLUS
				draw_line(c + Vector2(-24, 0), c + Vector2(24, 0), Color("4fb8ff"), 10.0, true)
				draw_line(c + Vector2(0, -24), c + Vector2(0, 24), Color("4fb8ff"), 10.0, true)
			1:  # STAR (sparkle)
				draw_colored_polygon(_star(c, 26, 11), Color("ffd84d"))
			2:  # SHINY
				draw_circle(c, 24, Color("6fe36a"))
				draw_circle(c + Vector2(-8, -9), 7, Color(1, 1, 1, 0.85))
			3:  # CLEAR: water drop
				var pts := PackedVector2Array()
				for i in 24:
					var a := TAU * i / 24
					pts.append(c + Vector2(cos(a) * 18, sin(a) * 18 + 8))
				pts.append(c + Vector2(0, -28))
				draw_colored_polygon(Geometry2D.convex_hull(pts), Color("7fd3ff"))
				draw_circle(c + Vector2(-6, 8), 5, Color(1, 1, 1, 0.8))
			4:  # METAL: diamond
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -26), c + Vector2(24, 0), c + Vector2(0, 26), c + Vector2(-24, 0)]), Color("b8c0d0"))
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -26), c + Vector2(24, 0), c + Vector2(0, 0)]), Color("e8ecf4"))
			5:  # CLOUD
				var col := Color("9fb7ff")
				draw_circle(c + Vector2(-12, 6), 12, col)
				draw_circle(c + Vector2(2, -4), 15, col)
				draw_circle(c + Vector2(15, 7), 11, col)
				draw_rect(Rect2(c + Vector2(-12, 6), Vector2(27, 12)), col)
			6:  # BEADS
				draw_circle(c + Vector2(-14, 8), 10, Color("ff8fcf"))
				draw_circle(c + Vector2(12, 10), 10, Color("8fd8ff"))
				draw_circle(c + Vector2(0, -10), 10, Color("ffe36a"))
			7:  # STARS (confetti)
				draw_colored_polygon(_star(c + Vector2(-10, 6), 15, 6), Color("ff9ad5"))
				draw_colored_polygon(_star(c + Vector2(13, -8), 11, 4.5, 0.4), Color("ffd84d"))
			8:  # STAMP_STAR
				var sp := _star(c, 26, 12)
				sp.append(sp[0])
				draw_polyline(sp, Color("8a8fa8"), 6.0, true)
			9:  # STAMP_HEART
				var hp := _heart(c, 1.5)
				hp.append(hp[0])
				draw_polyline(hp, Color("ff7aa8"), 6.0, true)
			10:  # CRUNCHY: ball with foam beads
				draw_circle(c, 24, Color("6fe36a"))
				for q in [Vector2(-9, -6), Vector2(8, -10), Vector2(10, 8), Vector2(-6, 11), Vector2(0, 0)]:
					draw_circle(c + q, 5, Color(1, 1, 1, 0.9))
			11:  # BUTTER: a pat of butter
				var r := Rect2(c + Vector2(-24, -12), Vector2(48, 30))
				draw_rect(r, Color("ffe08a"))
				draw_rect(Rect2(c + Vector2(-24, -18), Vector2(48, 10)), Color("fff2bf"))
			12:  # FLUFFY: pink puffs
				var pc := Color("ffb6de")
				draw_circle(c + Vector2(-12, 6), 12, pc)
				draw_circle(c + Vector2(2, -6), 15, pc)
				draw_circle(c + Vector2(15, 7), 11, pc)
				draw_rect(Rect2(c + Vector2(-12, 6), Vector2(27, 12)), pc)
				draw_circle(c + Vector2(-2, -10), 5, Color(1, 1, 1, 0.8))
			14:  # GLOW: moon-lit blob
				draw_circle(c, 26, Color("1d2140"))
				draw_circle(c, 17, Color("b9ff7a"))
				draw_circle(c, 11, Color("e9ffc4"))
			15:  # HOLO: rainbow diamond
				var cols := [Color("ff6b6b"), Color("ffd84d"), Color("6fe36a"), Color("4fb8ff"), Color("c58bff")]
				for i in 5:
					var y0 := -24.0 + i * 9.6
					draw_rect(Rect2(c + Vector2(-22, y0), Vector2(44, 9.6)), cols[i])
				draw_circle(c + Vector2(-9, -9), 5, Color(1, 1, 1, 0.8))
			16:  # MAGIC: colour wheel
				for i in 12:
					var a0 := TAU * i / 12.0
					var pts := PackedVector2Array([c])
					for k in 4:
						var a := a0 + TAU / 12.0 * k / 3.0
						pts.append(c + Vector2(cos(a), sin(a)) * 25.0)
					draw_colored_polygon(pts, Color.from_hsv(i / 12.0, 0.8, 1.0))
				draw_circle(c, 8, Color.WHITE)
			17:  # KNIFE
				draw_colored_polygon(PackedVector2Array([c + Vector2(-26, 10), c + Vector2(14, -22), c + Vector2(22, -14), c + Vector2(-12, 18)]), Color("d7dde8"))
				draw_colored_polygon(PackedVector2Array([c + Vector2(-26, 10), c + Vector2(-12, 18), c + Vector2(-20, 26), c + Vector2(-32, 18)]), Color("8a6a4a"))
			18:  # JARS: a jar
				draw_rect(Rect2(c + Vector2(-18, -10), Vector2(36, 34)), Color("cfe8ff"))
				draw_rect(Rect2(c + Vector2(-14, -22), Vector2(28, 10)), Color("7a8699"))
				draw_rect(Rect2(c + Vector2(-14, 2), Vector2(28, 18)), Color("ff8fcf"))
				draw_circle(c + Vector2(-9, -2), 4, Color(1, 1, 1, 0.8))
			19:  # BOWL: mixing bowl with spoon
				draw_circle(c + Vector2(0, 6), 26, Color("e9e2d6"))
				draw_circle(c + Vector2(0, 6), 20, Color("ff9ad5"))
				draw_line(c + Vector2(-4, 2), c + Vector2(22, -26), Color("8a6a4a"), 7.0, true)
			20:  # THEMES: three little scoops (ice cream)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-16, 6), c + Vector2(16, 6), c + Vector2(0, 30)]), Color("e0a86a"))
				draw_circle(c + Vector2(-10, -2), 12, Color("ff9ad5"))
				draw_circle(c + Vector2(10, -2), 12, Color("9fd8ff"))
				draw_circle(c + Vector2(0, -16), 12, Color("fff2bf"))
			21:  # SCENTS: strawberry
				draw_set_transform(c, 0.0, Vector2.ONE)
				ScentDraw.draw_icon(self, "strawberry", 0.95)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			13:  # CAMERA
				var body := Rect2(c + Vector2(-26, -14), Vector2(52, 36))
				draw_rect(body, Color("5a6478"))
				draw_rect(Rect2(c + Vector2(-10, -22), Vector2(20, 10)), Color("5a6478"))
				draw_circle(c + Vector2(0, 4), 12, Color("e8ecf4"))
				draw_circle(c + Vector2(0, 4), 7, Color("4fb8ff"))
