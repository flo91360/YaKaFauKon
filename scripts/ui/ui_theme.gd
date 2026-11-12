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
const COL_GOLD := Color(0.97, 0.74, 0.22)
const COL_PURPLE := Color(0.6, 0.48, 0.84)
const COL_GREY := Color(0.6, 0.62, 0.68)
const COL_CORAL := Color(0.95, 0.5, 0.45)
const COL_ORANGE := Color(0.95, 0.6, 0.35)
const COL_TEAL := Color(0.25, 0.68, 0.68)

const SKILL_COLORS := {
	"physique": Color(0.93, 0.45, 0.38), "creativite": Color(0.62, 0.48, 0.86),
	"charisme": Color(0.93, 0.5, 0.68), "organisation": Color(0.25, 0.68, 0.68),
}


static func build() -> Theme:
	var theme := Theme.new()
	var font: Font = load(FONT_PATH)
	theme.default_font = font
	theme.default_font_size = FONT_SIZE

	theme.set_color("font_color", "Label", COL_TEXT)
	theme.set_constant("line_spacing", "Label", 6)

	var panel := _box(COL_BG, 22)
	panel.shadow_color = Color(0.1, 0.12, 0.25, 0.22)
	panel.shadow_size = 12
	panel.shadow_offset = Vector2(0, 4)
	panel.border_color = Color(1, 1, 1, 0.9)
	panel.set_border_width_all(3)
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

	theme.set_constant("h_separation", "Button", 10)
	theme.set_constant("icon_max_width", "Button", 30)
	var tip := _box(Color(0.16, 0.19, 0.3), 10)
	tip.content_margin_left = 12
	tip.content_margin_right = 12
	tip.content_margin_top = 6
	tip.content_margin_bottom = 6
	theme.set_stylebox("panel", "TooltipPanel", tip)
	theme.set_color("font_color", "TooltipLabel", Color.WHITE)
	theme.set_font_size("font_size", "TooltipLabel", 18)
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
	box.border_color = color.darkened(0.22)
	box.border_width_bottom = 4
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


# --- Pictogrammes, pastilles, barres, cartes ----------------------------------------

static func icon_texture(icon_name: String) -> Texture2D:
	var path := "res://icons/%s.png" % icon_name
	return load(path) if ResourceLoader.exists(path) else null


static func icon(icon_name: String, size := 28.0, color := Color.WHITE) -> TextureRect:
	var t := TextureRect.new()
	t.texture = icon_texture(icon_name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.modulate = color
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Pastille ronde colorée avec un pictogramme blanc.
static func badge(icon_name: String, color: Color, size := 40.0) -> PanelContainer:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(size / 2.0))
	style.anti_aliasing = true
	var pad := size * 0.19
	style.content_margin_left = pad
	style.content_margin_right = pad
	style.content_margin_top = pad
	style.content_margin_bottom = pad
	p.add_theme_stylebox_override("panel", style)
	p.custom_minimum_size = Vector2(size, size)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(icon(icon_name, size - pad * 2.0))
	p.set_meta("style", style)
	return p


static func icon_button(icon_name: String, text: String, color := COL_ACCENT, size := 20) -> Button:
	var b := button(text, color, size)
	b.icon = icon_texture(icon_name)
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", int(size * 1.35))
	return b


static func fill_box(color: Color, radius := 10) -> StyleBoxFlat:
	var box := _box(color, radius)
	box.border_color = color.lightened(0.25)
	box.border_width_top = 3
	return box


## Barre de progression colorée.
static func bar(color: Color, height := 20.0, max_value := 1.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.max_value = max_value
	b.step = 0.0
	b.custom_minimum_size = Vector2(0, height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var radius := int(height / 2.0)
	b.add_theme_stylebox_override("background", _box(Color(0.84, 0.86, 0.9), radius))
	b.add_theme_stylebox_override("fill", fill_box(color, radius))
	b.set_meta("color", color)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


static func set_bar_color(b: ProgressBar, color: Color) -> void:
	if b.get_meta("color", Color.BLACK) != color:
		b.set_meta("color", color)
		b.add_theme_stylebox_override("fill", fill_box(color, int(b.custom_minimum_size.y / 2.0)))


## Carte au fond doux (pour les listes) ; renvoie le panneau.
static func card(color := COL_SOFT, margin := 16) -> PanelContainer:
	var c := PanelContainer.new()
	var style := _box(color, 16)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin * 0.6
	style.content_margin_bottom = margin * 0.6
	c.add_theme_stylebox_override("panel", style)
	return c


## Voile sombre derrière un panneau (le jeu est en pause).
static func shade(parent: Control, alpha := 0.45) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.1, 0.12, 0.22, alpha)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(r)
	return r


## Ligne de titre avec un bouton « Fermer ».
static func header(box: Container, text: String, on_close: Callable, icon_name := "", color := COL_ACCENT) -> HBoxContainer:
	var row := HBoxContainer.new()
	box.add_child(row)
	if icon_name != "":
		row.add_child(badge(icon_name, color, 46))
	var title := label(text, 32)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var close := icon_button("croix", "Fermer", COL_GREY, 20)
	close.pressed.connect(on_close)
	row.add_child(close)
	return row


## Bouton « Écouter » : lit le texte renvoyé par `text_func` avec la synthèse vocale.
static func speak_button(text_func: Callable) -> Button:
	var b := icon_button("son", "Écouter", COL_PURPLE, 18)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = "Lire à voix haute"
	b.pressed.connect(func():
		var game = b.get_tree().root.get_node("Game")
		if not game.speak(text_func.call()):
			b.text = "Pas de voix")
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
