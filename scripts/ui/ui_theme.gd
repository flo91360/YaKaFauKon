extends RefCounted
## Thème visuel : police lisible (Lexend), gros texte, couleurs douces, coins arrondis.
## Plus quelques fonctions pour fabriquer rapidement les éléments d'interface.

const FONT_PATH := "res://fonts/Lexend.ttf"
const FONT_SIZE := 24

const COL_BG := Color(0.99, 0.97, 0.93)
const COL_TEXT := Color(0.18, 0.2, 0.28)
const COL_ACCENT := Color(0.36, 0.56, 0.86)
const COL_ACCENT_HOVER := Color(0.45, 0.64, 0.92)
const COL_SOFT := Color(0.9, 0.93, 0.98)
const COL_GOOD := Color(0.36, 0.72, 0.45)
const COL_WARN := Color(0.96, 0.7, 0.3)
const COL_BAD := Color(0.9, 0.36, 0.33)


static func build() -> Theme:
	var theme := Theme.new()
	var font: Font = load(FONT_PATH)
	theme.default_font = font
	theme.default_font_size = FONT_SIZE

	theme.set_color("font_color", "Label", COL_TEXT)
	theme.set_constant("line_spacing", "Label", 6)

	var panel := _box(COL_BG, 22)
	panel.shadow_color = Color(0, 0, 0, 0.18)
	panel.shadow_size = 10
	panel.content_margin_left = 24
	panel.content_margin_right = 24
	panel.content_margin_top = 20
	panel.content_margin_bottom = 20
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "Panel", panel)

	theme.set_stylebox("normal", "Button", _button_box(COL_ACCENT))
	theme.set_stylebox("hover", "Button", _button_box(COL_ACCENT_HOVER))
	theme.set_stylebox("pressed", "Button", _button_box(COL_ACCENT.darkened(0.15)))
	theme.set_stylebox("focus", "Button", _focus_box())
	theme.set_stylebox("disabled", "Button", _button_box(Color(0.75, 0.77, 0.8)))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(c, "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color(0.95, 0.95, 0.95))

	var edit := _box(Color.WHITE, 14)
	edit.border_color = COL_ACCENT
	edit.set_border_width_all(3)
	edit.content_margin_left = 16
	edit.content_margin_right = 16
	edit.content_margin_top = 10
	edit.content_margin_bottom = 10
	theme.set_stylebox("normal", "LineEdit", edit)
	var edit_focus := edit.duplicate()
	edit_focus.border_color = COL_ACCENT.darkened(0.2)
	edit_focus.set_border_width_all(4)
	theme.set_stylebox("focus", "LineEdit", edit_focus)
	theme.set_color("font_color", "LineEdit", COL_TEXT)
	theme.set_color("caret_color", "LineEdit", COL_TEXT)
	theme.set_constant("caret_width", "LineEdit", 3)

	theme.set_stylebox("background", "ProgressBar", _box(Color(0.86, 0.87, 0.9), 10))
	theme.set_stylebox("fill", "ProgressBar", _box(COL_GOOD, 10))

	theme.set_constant("separation", "VBoxContainer", 12)
	theme.set_constant("separation", "HBoxContainer", 12)
	return theme


static func _box(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	return box


static func _button_box(color: Color) -> StyleBoxFlat:
	var box := _box(color, 16)
	box.content_margin_left = 22
	box.content_margin_right = 22
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box


static func _focus_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = Color(1, 1, 1, 0.8)
	box.set_border_width_all(3)
	box.set_corner_radius_all(16)
	return box


# --- Fabriques d'éléments -------------------------------------------------------

static func label(text: String, size := FONT_SIZE, color := COL_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, color := COL_ACCENT, size := FONT_SIZE) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	if color != COL_ACCENT:
		b.add_theme_stylebox_override("normal", _button_box(color))
		b.add_theme_stylebox_override("hover", _button_box(color.lightened(0.12)))
		b.add_theme_stylebox_override("pressed", _button_box(color.darkened(0.15)))
	return b


## Bouton « Écouter » : lit le texte renvoyé par `text_func` avec la synthèse vocale.
static func speak_button(text_func: Callable) -> Button:
	var b := button("🔊 Écouter", Color(0.55, 0.45, 0.8), 20)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = "Lire à voix haute"
	b.pressed.connect(func():
		var game = b.get_tree().root.get_node("Game")
		if not game.speak(text_func.call()):
			b.text = "Voix indisponible")
	return b


## Panneau centré sur l'écran, ajouté à `parent` ; renvoie la VBox intérieure.
static func centered_panel(parent: Node, min_width := 640.0) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(min_width, 0)
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	return vbox


static func need_color(value: float) -> Color:
	if value < 25.0:
		return COL_BAD
	if value < 50.0:
		return COL_WARN
	return COL_GOOD
