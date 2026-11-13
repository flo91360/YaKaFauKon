extends Node3D
## Le studio en 3D : pièce, jardin, lumière (cycle jour/nuit), caméra et objets.
## Tout est construit par calcul avec les briques de meshes.gd (aucun modèle externe).

const Furniture = preload("res://scripts/world/furniture.gd")
const M = preload("res://scripts/world/meshes.gd")
const Data = preload("res://scripts/core/data.gd")

const ROOM_MIN := Vector2(-5.0, -4.0) # (x, z)
const ROOM_MAX := Vector2(5.0, 4.0)
const WAYPOINTS := [Vector2(0.4, -0.6), Vector2(-2.6, -1.2), Vector2(2.6, -1.4), Vector2(-2.4, 1.6), Vector2(2.6, 1.8), Vector2(0.4, 1.6)]
const GROUND_Y := -0.3
## Terrasse (achat du magasin) : plancher en bois à droite de la pièce.
const TERRACE_MIN := Vector2(5.0, -3.2)
const TERRACE_MAX := Vector2(7.25, 0.2)
## Calques de lumière : la pièce (calque 1, par défaut pour tout ce qui est ajouté,
## personnage compris) n'est éclairée que par `inside_light` et les lampes ;
## le jardin (calque 2) par le soleil. Ainsi aucune ombre de soleil ne bouge dans la maison.
const LAYER_ROOM := 1
const LAYER_GARDEN := 2
## Directions fixes : des ombres immobiles, quelle que soit l'heure.
const SUN_DIR := Vector3(0.5, 0.78, 0.62)
const INSIDE_DIR := Vector3(0.32, 0.9, 0.45)

# Palette douce et chaleureuse
const CAM_HOME := Vector3(8.0, 9.4, 10.6)
const CAM_LOOK := Vector3(-0.15, 0.35, -0.25)
const CAM_FOCUS_DISTANCE := 8.6

const C_WOOD := Color(0.80, 0.60, 0.42)
const C_WOOD_LIGHT := Color(0.90, 0.74, 0.54)
const C_WOOD_DARK := Color(0.52, 0.37, 0.27)
const C_CREAM := Color(0.97, 0.93, 0.85)
const C_WHITE := Color(0.95, 0.95, 0.94)
const C_SAGE := Color(0.60, 0.74, 0.66)
const C_TEAL := Color(0.36, 0.62, 0.64)
const C_CORAL := Color(0.93, 0.52, 0.44)
const C_MUSTARD := Color(0.95, 0.74, 0.32)
const C_BLUE := Color(0.42, 0.56, 0.82)
const C_NAVY := Color(0.24, 0.29, 0.45)
const C_STEEL := Color(0.74, 0.77, 0.81)
const C_DARK := Color(0.2, 0.21, 0.25)
const C_LEAF := Color(0.36, 0.64, 0.38)
const C_LEAF_LIGHT := Color(0.52, 0.76, 0.42)

var furniture: Array = []
var camera: Camera3D
var floor_body: StaticBody3D
var sun: DirectionalLight3D
var inside_light: DirectionalLight3D # lumière de la pièce (le soleil n'éclaire que le jardin)
var env: Environment
var quality := 1 # 0 léger, 1 normal, 2 beau

var _lamps: Array = [] # {light, energy, shade}
var _lamps_level := 0.0
var _sway: Array = []
var _time := 0.0
var _minutes := 8.0 * 60.0
var _sleeping := false
var _rng := RandomNumberGenerator.new()
var _wood: Material
var _wood_light: Material
var _wood_dark: Material
var _steel: Material
var _fabric_n := "tissu_n"
var _fx: Array = [] # effets de l'activité en cours (particules, invités…)
var _belt_on := false
var _cam_focus = null # point regardé de près pendant une activité (Vector3) ou null
var _cam_lift := 0.85 # décalage du sujet vers le haut de l'écran (place pour le panneau de frappe)
var _cam_pos := CAM_HOME
var _cam_look := CAM_LOOK
var _purchased := {} # achats du magasin déjà construits : identifiant → true
var _terrace := false
var _hidden: Array = [] # objets cachés pendant une activité (la guitare sur son pied)


func _ready() -> void:
	_rng.seed = 2026
	_wood = M.tex_mat("bois", C_WOOD, 0.9, "bois_n", 0.6, 0.5)
	_wood_light = M.tex_mat("bois", C_WOOD_LIGHT, 0.9, "bois_n", 0.6, 0.5)
	_wood_dark = M.tex_mat("bois", C_WOOD_DARK, 0.9, "bois_n", 0.6, 0.5)
	_steel = M.mat(C_STEEL, 0.28, 0.35)
	_build_environment()
	_build_room()
	var first_garden := get_child_count()
	_build_garden()
	for i in range(first_garden, get_child_count()):
		_set_layers(get_child(i), LAYER_GARDEN)
	_build_furniture()
	_build_decor()
	set_time(_minutes, false, true)


func _process(delta: float) -> void:
	_time += delta
	for s in _sway:
		s["node"].rotation.z = sin(_time * s["speed"] + s["phase"]) * s["amp"]
		s["node"].rotation.x = cos(_time * s["speed"] * 0.8 + s["phase"]) * s["amp"] * 0.6
	# Les lampes s'allument et s'éteignent en douceur.
	var target := 1.0 if _lamps_wanted() else 0.0
	if absf(target - _lamps_level) > 0.001:
		_lamps_level = move_toward(_lamps_level, target, delta * 1.2)
		_apply_lamps()
	_move_camera(delta)
	if _belt_on: # la bande du tapis de course défile
		for c in get_object("tapis").get_children():
			if c.has_meta("belt"):
				c.position.z += delta * 1.5
				if c.position.z > 0.9:
					c.position.z -= 1.68


# --- Lumière, ciel et caméra --------------------------------------------------------------

func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# Le rendu de secours (OpenGL) est plus clair : on baisse un peu l'exposition.
	env.tonemap_exposure = 1.0 if RenderingServer.get_current_rendering_method() == "forward_plus" else 0.8
	env.tonemap_white = 1.6
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.04
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 26.0
	env.fog_depth_end = 95.0
	env.fog_density = 0.85
	env.fog_sky_affect = 0.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 42.0
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.2
	sun.light_angular_distance = 1.2
	sun.light_cull_mask = LAYER_GARDEN
	add_child(sun)
	sun.position = SUN_DIR.normalized() * 30.0
	sun.look_at(Vector3.ZERO, Vector3.UP)

	inside_light = DirectionalLight3D.new()
	inside_light.shadow_enabled = true
	inside_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	inside_light.directional_shadow_max_distance = 30.0
	inside_light.shadow_bias = 0.04
	inside_light.shadow_normal_bias = 1.2
	inside_light.shadow_opacity = 0.7
	inside_light.light_angular_distance = 2.5
	inside_light.light_cull_mask = LAYER_ROOM
	inside_light.shadow_caster_mask = LAYER_ROOM
	add_child(inside_light)
	inside_light.position = INSIDE_DIR.normalized() * 30.0
	inside_light.look_at(Vector3.ZERO, Vector3.UP)

	camera = Camera3D.new()
	camera.fov = 36.0
	camera.near = 0.3
	camera.far = 140.0
	add_child(camera)
	camera.position = CAM_HOME
	camera.look_at(CAM_LOOK, Vector3.UP)
	camera.current = true
	apply_quality(quality)


## Réglage « Qualité graphique » : 0 = léger, 1 = normal, 2 = beau.
func apply_quality(level: int) -> void:
	quality = level
	var forward := RenderingServer.get_current_rendering_method() == "forward_plus"
	env.ssao_enabled = level >= 1 and forward
	env.ssao_radius = 0.9
	env.ssao_intensity = 2.4
	env.ssao_power = 1.6
	env.ssil_enabled = level >= 2 and forward
	env.glow_enabled = level >= 1
	env.glow_intensity = 0.35
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.05
	sun.shadow_blur = [0.8, 1.2, 1.6][level]
	inside_light.shadow_blur = [1.2, 1.8, 2.4][level]
	RenderingServer.directional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, RenderingServer.SHADOW_QUALITY_SOFT_HIGH][level])
	RenderingServer.directional_shadow_atlas_set_size([2048, 4096, 8192][level], true)
	if is_inside_tree():
		get_viewport().msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][level]
		get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if level == 0 else Viewport.SCREEN_SPACE_AA_DISABLED
	for l in _lamps:
		l["light"].shadow_enabled = level >= 2 and l["shadow"]


func _set_layers(node: Node, layer: int) -> void:
	if node is VisualInstance3D:
		node.layers = layer
	for c in node.get_children():
		_set_layers(c, layer)


func _lamps_wanted() -> bool:
	return _daylight(_minutes) < 0.45 and not _sleeping


## Part de lumière du jour entre 0 (nuit) et 1 (plein jour).
func _daylight(minutes: float) -> float:
	var hour := fposmod(minutes / 60.0, 24.0)
	return smoothstep(5.6, 7.4, hour) * (1.0 - smoothstep(19.0, 20.8, hour))


## Met la lumière à l'heure du jeu (soleil qui tourne, couleurs, lampes).
func set_time(minutes: float, sleeping := false, instant := false) -> void:
	_minutes = minutes
	_sleeping = sleeping
	var hour := fposmod(minutes / 60.0, 24.0)
	var day := _daylight(minutes)
	var arc := clampf((hour - 6.0) / 14.5, 0.0, 1.0) # 6 h → 20 h 30
	var height := sin(arc * PI) # 0 à l'horizon, 1 au plus haut
	# Le soleil ne tourne pas (ses ombres resteraient en mouvement) : seules
	# sa couleur et sa force suivent l'heure.
	var warm := smoothstep(0.05, 0.85, height)
	var sun_col := Color(1.0, 0.56, 0.3).lerp(Color(1.0, 0.95, 0.86), warm)
	var moon_col := Color(0.55, 0.66, 1.0)
	sun.light_color = moon_col.lerp(sun_col, day)
	sun.light_energy = lerpf(0.32, lerpf(1.05, 1.4, warm), day)
	# Lumière intérieure : jour qui entre doucement par la fenêtre, faible la nuit
	# (les lampes prennent le relais).
	inside_light.light_color = Color(0.6, 0.68, 0.95).lerp(Color(1.0, 0.94, 0.86).lerp(Color(1.0, 0.86, 0.72), 1.0 - warm), day)
	inside_light.light_energy = lerpf(0.12, 0.95, day)
	var amb_day := Color(1.0, 0.8, 0.74).lerp(Color(0.84, 0.9, 1.0), warm)
	env.ambient_light_color = Color(0.38, 0.45, 0.78).lerp(amb_day, day)
	env.ambient_light_energy = lerpf(0.5, 0.52, day)
	var sky_day := Color(0.98, 0.78, 0.62).lerp(Color(0.70, 0.85, 0.96), warm)
	var sky := Color(0.07, 0.09, 0.2).lerp(sky_day, day)
	env.background_color = sky
	env.fog_light_color = sky
	if instant:
		_lamps_level = 1.0 if _lamps_wanted() else 0.0
		_apply_lamps()


func _apply_lamps() -> void:
	for l in _lamps:
		l["light"].light_energy = l["energy"] * _lamps_level
		l["light"].visible = _lamps_level > 0.01
		if l["shade"] != null:
			l["shade"].emission_energy_multiplier = 0.15 + 1.6 * _lamps_level


func _add_lamp(pos: Vector3, energy: float, radius: float, shade: StandardMaterial3D = null, shadow := false, color := Color(1.0, 0.8, 0.55)) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.omni_range = radius
	light.omni_attenuation = 1.3
	light.light_energy = 0.0
	light.shadow_enabled = false
	light.shadow_blur = 2.0
	add_child(light)
	_lamps.append({"light": light, "energy": energy, "shade": shade, "shadow": shadow})


# --- Pièce ---------------------------------------------------------------------------------

func _deco() -> Furniture:
	var d := Furniture.new()
	add_child(d)
	return d


func _build_room() -> void:
	var d := _deco()
	# Dalle + parquet
	d.box(Vector3(10.3, 0.3, 8.3), Color(0.83, 0.79, 0.73), Vector3(-0.15, -0.15, -0.15), 0.02)
	d.box(Vector3(10.0, 0.04, 8.0), M.tex_mat("parquet", Color(0.97, 0.93, 0.88), 0.4, "parquet_n", 0.5, 0.8), Vector3(0, -0.018, 0), 0.008)
	floor_body = StaticBody3D.new()
	floor_body.add_to_group("floor")
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(10, 0.2, 8)
	var floor_col := CollisionShape3D.new()
	floor_col.shape = floor_shape
	floor_col.position = Vector3(0, -0.1, 0)
	floor_body.add_child(floor_col)
	add_child(floor_body)
	# Carrelage du coin salle de bain
	d.box(Vector3(4.6, 0.03, 2.0), M.tex_mat("carrelage", Color(0.78, 0.9, 0.95), 0.5, "carrelage_n", 0.25, 0.7), Vector3(2.7, -0.004, -3.0), 0.006)
	d.box(Vector3(4.6, 0.025, 0.06), _steel, Vector3(2.7, 0.0, -1.99), 0.008)
	d.box(Vector3(0.06, 0.025, 2.0), _steel, Vector3(0.4, 0.0, -3.0), 0.008)

	# Murs : papier peint en haut, soubassement coloré en bas
	var wall := M.tex_mat("papier_peint", Color(0.99, 0.94, 0.85), 0.6, "crepi_n", 0.92, 0.35)
	var wall_out := M.tex_mat("crepi", Color(0.95, 0.9, 0.82), 0.5, "crepi_n", 0.95, 0.5)
	var wainscot := M.mat(Color(0.56, 0.72, 0.68), 0.7)
	var trim := M.mat(C_WHITE, 0.6)
	# Mur du fond
	d.box(Vector3(10.3, 2.8, 0.3), wall, Vector3(-0.15, 1.4, -4.15), 0.01)
	d.box(Vector3(5.4, 0.95, 0.04), wainscot, Vector3(-2.3, 0.475, -3.99), 0.008)
	d.box(Vector3(5.4, 0.07, 0.07), trim, Vector3(-2.3, 0.98, -3.98), 0.015)
	d.box(Vector3(5.4, 0.12, 0.05), trim, Vector3(-2.3, 0.06, -3.985), 0.012)
	# Faïence de la salle de bain (mur du fond)
	d.box(Vector3(4.6, 2.05, 0.04), M.tex_mat("carrelage", Color(0.93, 0.97, 0.98), 0.5, "carrelage_n", 0.22, 0.6), Vector3(2.7, 1.025, -3.99), 0.008)
	d.box(Vector3(4.6, 0.08, 0.06), M.mat(C_TEAL, 0.5), Vector3(2.7, 2.08, -3.985), 0.015)
	# Mur de gauche (en morceaux autour de la fenêtre)
	d.box(Vector3(0.3, 2.8, 2.75), wall, Vector3(-5.15, 1.4, -2.925), 0.01)
	d.box(Vector3(0.3, 2.8, 3.65), wall, Vector3(-5.15, 1.4, 2.175), 0.01)
	d.box(Vector3(0.3, 0.95, 1.9), wall, Vector3(-5.15, 0.475, -0.6), 0.01)
	d.box(Vector3(0.3, 0.55, 1.9), wall, Vector3(-5.15, 2.525, -0.6), 0.01)
	d.box(Vector3(0.04, 0.95, 8.0), wainscot, Vector3(-4.99, 0.475, 0.0), 0.008)
	d.box(Vector3(0.07, 0.07, 8.0), trim, Vector3(-4.98, 0.98, 0.0), 0.015)
	d.box(Vector3(0.05, 0.12, 8.0), trim, Vector3(-4.985, 0.06, 0.0), 0.012)
	# Dessus des murs
	d.box(Vector3(10.42, 0.09, 0.42), M.mat(Color(0.9, 0.84, 0.75), 0.8), Vector3(-0.15, 2.84, -4.15), 0.03)
	d.box(Vector3(0.42, 0.09, 8.42), M.mat(Color(0.9, 0.84, 0.75), 0.8), Vector3(-5.15, 2.84, -0.15), 0.03)
	# Face extérieure (visible sur les tranches)
	d.box(Vector3(0.02, 2.8, 0.3), wall_out, Vector3(5.0, 1.4, -4.15), 0.005)
	d.box(Vector3(0.3, 2.8, 0.02), wall_out, Vector3(-5.15, 1.4, 4.0), 0.005)

	# Fenêtre (mur de gauche) : cadre, croisillons, vitre, rebord, rideaux
	var wz := -0.6
	var wy := 1.6
	d.box(Vector3(0.34, 0.08, 2.02), trim, Vector3(-5.15, wy + 0.65, wz), 0.02)
	d.box(Vector3(0.34, 0.08, 2.02), trim, Vector3(-5.15, wy - 0.65, wz), 0.02)
	d.box(Vector3(0.34, 1.3, 0.08), trim, Vector3(-5.15, wy, wz - 0.95), 0.02)
	d.box(Vector3(0.34, 1.3, 0.08), trim, Vector3(-5.15, wy, wz + 0.95), 0.02)
	d.box(Vector3(0.06, 1.3, 0.06), trim, Vector3(-5.12, wy, wz), 0.015)
	d.box(Vector3(0.06, 0.06, 1.9), trim, Vector3(-5.12, wy + 0.15, wz), 0.015)
	d.box(Vector3(0.5, 0.06, 2.1), trim, Vector3(-5.02, wy - 0.7, wz), 0.02) # rebord
	var pane := d.box(Vector3(0.02, 1.26, 1.86), M.glass(Color(0.75, 0.9, 1.0), 0.16), Vector3(-5.14, wy, wz), 0.004)
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	d.cyl(0.025, 2.7, M.mat(C_WOOD_DARK, 0.5), Vector3(-4.9, wy + 0.86, wz), Vector3(90, 0, 0))
	for z_end in [wz - 1.36, wz + 1.36]:
		d.ball(0.05, M.mat(C_WOOD_DARK, 0.5), Vector3(-4.9, wy + 0.86, z_end))
	var curtain := M.tex_mat("tissu", C_MUSTARD, 3.0, _fabric_n, 0.9, 0.6)
	for side in [-1.0, 1.0]:
		for k in 4:
			var z: float = wz + side * (0.92 + k * 0.105)
			d.cap(0.075, 1.72, curtain, Vector3(-4.9, wy - 0.02 + (k % 2) * 0.012, z), Vector3.ZERO, Vector3(0.75, 1, 1))
	# Petit pot de fleurs sur le rebord
	_potted_plant(d, Vector3(-4.93, wy - 0.67, wz + 0.45), 0.5, C_CORAL)


# --- Jardin ---------------------------------------------------------------------------------

func _build_garden() -> void:
	var d := _deco()
	var grass := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(220, 220)
	grass.mesh = plane
	grass.material_override = M.tex_mat("herbe", Color(0.95, 1.0, 0.9), 0.14, "", 0.95)
	grass.position = Vector3(0, GROUND_Y, 0)
	add_child(grass)
	# Bordure de graviers autour de la maison
	d.box(Vector3(11.5, 0.08, 9.5), M.tex_mat("crepi", Color(0.86, 0.82, 0.76), 1.5, "crepi_n", 0.95, 1.0), Vector3(-0.15, GROUND_Y + 0.02, -0.15), 0.03)

	# Arbres (derrière les murs et au loin : ils ne cachent jamais la pièce)
	for t in [[-8.2, -7.4, 1.25], [-2.8, -8.6, 1.0], [3.4, -9.2, 1.35], [9.4, -8.0, 1.1], [-10.5, -1.8, 1.2], [-11.5, 4.5, 0.95],
			[13.5, -4.0, 1.2], [-15.0, -11.0, 1.4], [0.5, -15.0, 1.5], [8.0, -16.0, 1.3], [-7.0, -16.5, 1.2], [16.5, -12.0, 1.4], [-18.0, -3.0, 1.3], [20.0, -6.0, 1.2]]:
		_tree(Vector3(t[0], GROUND_Y, t[1]), t[2])
	# Buissons
	for b in [[-6.6, 1.2, 0.8], [-6.9, 2.6, 1.0], [-6.5, 3.9, 0.75], [-7.6, -4.6, 0.9], [6.6, -5.4, 0.9], [7.9, -5.0, 0.7], [-6.4, -5.8, 0.8], [11.2, -1.0, 0.8]]:
		_bush(Vector3(b[0], GROUND_Y, b[1]), b[2])
	# Massif de fleurs devant la maison
	var soil := M.mat(Color(0.45, 0.33, 0.26), 0.95)
	d.box(Vector3(6.4, 0.14, 0.62), soil, Vector3(-1.8, GROUND_Y + 0.05, 4.62), 0.06)
	var petals := [C_CORAL, C_MUSTARD, Color(0.98, 0.96, 0.92), Color(0.74, 0.56, 0.9)]
	for i in 26:
		var x := -4.8 + i * 0.24 + _rng.randf_range(-0.05, 0.05)
		var z := 4.62 + _rng.randf_range(-0.17, 0.17)
		var h := _rng.randf_range(0.16, 0.3)
		d.cyl(0.012, h, C_LEAF, Vector3(x, GROUND_Y + 0.1 + h / 2.0, z))
		d.ball(0.055, M.mat(petals[i % petals.size()], 0.7), Vector3(x, GROUND_Y + 0.12 + h, z), Vector3(1, 0.7, 1))
		d.ball(0.02, C_MUSTARD.darkened(0.1), Vector3(x, GROUND_Y + 0.15 + h, z))
		if i % 2 == 0:
			d.ball(0.07, C_LEAF_LIGHT, Vector3(x + 0.06, GROUND_Y + 0.14, z + 0.05), Vector3(1.2, 0.5, 0.8))
	# Dalles de pierre qui mènent à la maison
	var stone := M.tex_mat("crepi", Color(0.8, 0.79, 0.77), 1.2, "crepi_n", 0.9, 1.2)
	for i in 7:
		var p := Vector3(5.75 + i * 0.95, GROUND_Y + 0.02, 2.6 + sin(i * 0.9) * 0.35 - i * 0.12)
		d.lathe([Vector2(0.0, 0.0), Vector2(0.3, 0.0), Vector2(0.34, 0.03), Vector2(0.3, 0.06), Vector2(0.0, 0.06)], stone, p, Vector3(0, i * 40.0, 0), Vector3(1.0 + (i % 2) * 0.2, 1, 0.85))
	# Boîte aux lettres
	d.cyl(0.04, 1.0, M.mat(C_WOOD_DARK, 0.7), Vector3(6.1, GROUND_Y + 0.5, 3.9))
	d.box(Vector3(0.3, 0.24, 0.44), M.mat(C_CORAL, 0.5), Vector3(6.1, GROUND_Y + 1.1, 3.9), 0.1)
	d.box(Vector3(0.02, 0.14, 0.1), M.mat(C_WHITE, 0.5), Vector3(6.26, GROUND_Y + 1.14, 3.76), 0.008)
	# Petit potager
	d.box(Vector3(2.6, 0.2, 1.7), M.mat(C_WOOD, 0.8), Vector3(8.6, GROUND_Y + 0.06, -1.6), 0.04)
	d.box(Vector3(2.42, 0.2, 1.52), soil, Vector3(8.6, GROUND_Y + 0.09, -1.6), 0.04)
	for row in 3:
		for k in 6:
			var veg := Vector3(7.6 + k * 0.4, GROUND_Y + 0.24, -2.1 + row * 0.5)
			if row == 1:
				d.ball(0.1, M.mat(Color(0.93, 0.5, 0.2), 0.6), veg + Vector3(0, -0.02, 0), Vector3(1, 0.8, 1)) # citrouilles
				d.cyl(0.012, 0.06, C_LEAF, veg + Vector3(0, 0.07, 0))
			else:
				d.ball(0.09, C_LEAF_LIGHT if row == 0 else C_LEAF, veg, Vector3(1, 1.3 if row == 2 else 0.8, 1))
	# Mare
	d.lathe([Vector2(0.0, 0.0), Vector2(1.5, 0.0), Vector2(1.62, 0.04), Vector2(1.5, 0.08), Vector2(1.38, 0.05)], stone, Vector3(10.5, GROUND_Y, -6.3), Vector3.ZERO, Vector3(1.25, 1, 0.85))
	d.cyl(1.38, 0.03, M.mat(Color(0.38, 0.66, 0.84), 0.12, 0.2), Vector3(10.5, GROUND_Y + 0.045, -6.3), Vector3.ZERO).scale = Vector3(1.25, 1, 0.85)
	for lily in [[10.0, -6.5], [11.0, -6.0], [10.7, -6.8]]:
		d.cyl(0.16, 0.012, C_LEAF_LIGHT, Vector3(lily[0], GROUND_Y + 0.066, lily[1]))
	d.ball(0.05, M.mat(Color(0.99, 0.8, 0.86), 0.6), Vector3(11.0, GROUND_Y + 0.09, -6.0))
	# Clôture en bois au fond du jardin
	var fence := M.mat(Color(0.96, 0.94, 0.9), 0.75)
	for i in 34:
		var x := -24.0 + i * 1.45
		d.box(Vector3(0.14, 1.0, 0.07), fence, Vector3(x, GROUND_Y + 0.5, -12.4), 0.03)
	d.box(Vector3(48.0, 0.09, 0.05), fence, Vector3(0, GROUND_Y + 0.72, -12.36), 0.02)
	d.box(Vector3(48.0, 0.09, 0.05), fence, Vector3(0, GROUND_Y + 0.34, -12.36), 0.02)
	for i in 14:
		var z := -12.4 + i * 1.45
		d.box(Vector3(0.07, 1.0, 0.14), fence, Vector3(-13.4, GROUND_Y + 0.5, z), 0.03)
	d.box(Vector3(0.05, 0.09, 20.0), fence, Vector3(-13.36, GROUND_Y + 0.72, -2.9), 0.02)
	d.box(Vector3(0.05, 0.09, 20.0), fence, Vector3(-13.36, GROUND_Y + 0.34, -2.9), 0.02)
	_scatter_grass()


func _tree(pos: Vector3, s: float) -> void:
	var t := _deco()
	t.position = pos
	t.rotation.y = _rng.randf() * TAU
	t.lathe([Vector2(0.0, 0.0), Vector2(0.34 * s, 0.0), Vector2(0.22 * s, 0.5 * s), Vector2(0.17 * s, 2.3 * s), Vector2(0.0, 2.4 * s)], M.tex_mat("bois", Color(0.52, 0.38, 0.28), 1.2, "bois_n", 0.9, 0.8), Vector3.ZERO)
	var crown := Node3D.new()
	crown.position = Vector3(0, 2.2 * s, 0)
	t.add_child(crown)
	var greens := [M.mat(C_LEAF, 0.9), M.mat(C_LEAF_LIGHT, 0.9), M.mat(Color(0.3, 0.56, 0.36), 0.9)]
	for b in [[0.0, 1.1, 0.0, 1.5], [0.9, 0.7, 0.2, 1.05], [-0.8, 0.75, -0.3, 1.1], [0.2, 0.6, 0.9, 1.0], [-0.1, 0.65, -0.9, 0.95], [0.3, 1.9, 0.1, 0.95]]:
		M.add(crown, M.sphere(b[3] * s, 10), greens[_rng.randi() % 3], Vector3(b[0], b[1], b[2]) * s, Vector3.ZERO, Vector3(1, 0.88, 1))
	_sway.append({"node": crown, "speed": _rng.randf_range(0.5, 0.9), "phase": _rng.randf() * TAU, "amp": 0.022})


func _bush(pos: Vector3, s: float) -> void:
	var b := _deco()
	b.position = pos
	var greens := [M.mat(C_LEAF, 0.9), M.mat(C_LEAF_LIGHT, 0.9)]
	for k in [[0.0, 0.42, 0.0, 0.6], [0.5, 0.34, 0.1, 0.45], [-0.45, 0.36, -0.1, 0.48], [0.1, 0.32, 0.45, 0.4]]:
		b.ball(k[3] * s, greens[_rng.randi() % 2], Vector3(k[0], k[1], k[2]) * s, Vector3(1, 0.85, 1))
	if _rng.randf() < 0.6: # quelques fleurs
		for k in 5:
			var a := _rng.randf() * TAU
			b.ball(0.05, M.mat([C_CORAL, C_WHITE, C_MUSTARD][k % 3], 0.6), Vector3(cos(a) * 0.4, 0.62 + _rng.randf() * 0.2, sin(a) * 0.4) * s)


## Petites fleurs semées dans le jardin (un seul maillage répété).
func _scatter_grass() -> void:
	var flowers := MultiMeshInstance3D.new()
	var fm := MultiMesh.new()
	fm.transform_format = MultiMesh.TRANSFORM_3D
	fm.use_colors = true
	fm.mesh = M.sphere(0.07, 5)
	fm.instance_count = 220
	var cols := [Color(1, 1, 0.96), Color(1.0, 0.86, 0.4), Color(0.98, 0.66, 0.74), Color(0.78, 0.66, 0.98)]
	var placed := 0
	while placed < fm.instance_count:
		var p := Vector3(_rng.randf_range(-22, 22), 0, _rng.randf_range(-12, 10))
		if p.x > -6.2 and p.x < 5.9 and p.z > -5.2 and p.z < 5.2:
			continue
		fm.set_instance_transform(placed, Transform3D(Basis().scaled(Vector3(1, 0.6, 1)), p + Vector3(0, GROUND_Y + 0.08, 0)))
		fm.set_instance_color(placed, cols[_rng.randi() % cols.size()])
		placed += 1
	flowers.multimesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.vertex_color_use_as_albedo = true
	fmat.roughness = 0.8
	flowers.material_override = fmat
	flowers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flowers)


func _potted_plant(d: Furniture, pos: Vector3, s: float, pot_color: Color) -> void:
	d.lathe([Vector2(0.0, 0.0), Vector2(0.2, 0.0), Vector2(0.27, 0.36), Vector2(0.3, 0.38), Vector2(0.27, 0.42), Vector2(0.0, 0.36)], M.mat(pot_color, 0.6), pos, Vector3.ZERO, Vector3(s, s, s))
	var greens := [M.mat(C_LEAF, 0.85), M.mat(C_LEAF_LIGHT, 0.85)]
	for k in 7:
		var a := k * TAU / 7.0
		var lean := 0.34 if k % 2 == 0 else 0.2
		d.ball(0.2 * s, greens[k % 2], pos + Vector3(cos(a) * lean, 0.62 + (k % 3) * 0.13, sin(a) * lean) * s, Vector3(0.9, 1.25, 0.9))
	d.ball(0.24 * s, greens[0], pos + Vector3(0, 0.98, 0) * s, Vector3(0.9, 1.3, 0.9))


# --- Objets ---------------------------------------------------------------------------------

func _add_object(id: String, label: String, actions: Array, pos: Vector3, size: Vector3, use: Vector3) -> Furniture:
	var f := Furniture.new()
	f.setup(id, label, actions, pos, size)
	f.use_point = use
	f.face_point = pos
	add_child(f)
	furniture.append(f)
	return f


func get_object(id: String) -> Furniture:
	for f in furniture:
		if f.object_id == id:
			return f
	return null


func _build_furniture() -> void:
	_build_bed()
	_build_kitchen()
	_build_sink()
	_build_toilet()
	_build_shower()
	_build_desk()
	_build_mirror()
	_build_sofa()
	_build_treadmill()
	_build_easel()
	_build_workbench()


func _build_bed() -> void:
	var bed := _add_object("lit", "Lit", ["dormir"], Vector3(-4.0, 0, -2.7), Vector3(1.6, 0.7, 2.4), Vector3(-2.75, 0, -2.2))
	for x in [-0.72, 0.72]:
		for z in [-1.12, 1.12]:
			bed.cyl(0.06, 0.22, _wood_dark, Vector3(x, 0.11, z))
	bed.box(Vector3(1.62, 0.2, 2.4), _wood, Vector3(0, 0.3, 0), 0.05)
	bed.box(Vector3(1.66, 1.05, 0.12), _wood, Vector3(0, 0.62, -1.16), 0.06) # tête de lit
	bed.box(Vector3(1.4, 0.5, 0.05), _wood_light, Vector3(0, 0.82, -1.11), 0.04)
	bed.box(Vector3(1.66, 0.42, 0.1), _wood, Vector3(0, 0.36, 1.17), 0.05) # pied de lit
	bed.box(Vector3(1.5, 0.24, 2.24), M.tex_mat("tissu", Color(0.98, 0.97, 0.95), 3.0, _fabric_n, 0.9, 0.4), Vector3(0, 0.5, 0.0), 0.09) # matelas
	bed.box(Vector3(1.56, 0.12, 1.5), M.tex_mat("couette", Color.WHITE, 1.1, _fabric_n, 0.9, 0.5), Vector3(0, 0.63, 0.36), 0.055) # couette
	bed.box(Vector3(1.56, 0.1, 0.34), M.mat(Color(0.98, 0.97, 0.94), 0.9), Vector3(0, 0.655, -0.42), 0.045) # revers du drap
	bed.box(Vector3(0.74, 0.16, 0.44), M.tex_mat("tissu", Color(0.99, 0.98, 0.96), 4.0, _fabric_n, 0.9, 0.5), Vector3(0, 0.69, -0.84), 0.075) # oreiller
	bed.box(Vector3(1.6, 0.07, 0.42), M.tex_mat("tissu", C_CORAL, 3.0, _fabric_n, 0.9, 0.7), Vector3(0, 0.7, 0.86), 0.03) # plaid
	bed.pose = "allonge"
	bed.pose_point = Vector3(-4.0, 0.7, -1.82)
	bed.face_point = Vector3(-4.0, 0, -5.0)
	# Table de nuit + lampe de chevet
	var d := _deco()
	d.position = Vector3(-2.86, 0, -3.62)
	d.box(Vector3(0.5, 0.5, 0.46), _wood, Vector3(0, 0.3, 0), 0.04)
	d.box(Vector3(0.42, 0.16, 0.02), _wood_light, Vector3(0, 0.38, 0.235), 0.01)
	d.ball(0.025, _steel, Vector3(0, 0.38, 0.255))
	for x in [-0.2, 0.2]:
		for z in [-0.18, 0.18]:
			d.cyl(0.025, 0.08, _wood_dark, Vector3(x, 0.04, z))
	d.lathe([Vector2(0.0, 0.0), Vector2(0.1, 0.0), Vector2(0.11, 0.02), Vector2(0.03, 0.05), Vector2(0.025, 0.24), Vector2(0.0, 0.25)], M.mat(C_TEAL, 0.4), Vector3(0, 0.55, 0))
	var shade := M.glowing(Color(1.0, 0.9, 0.7), 0.2)
	d.lathe([Vector2(0.15, 0.0), Vector2(0.1, 0.2), Vector2(0.0, 0.2)], shade, Vector3(0, 0.76, 0))
	_add_lamp(Vector3(-2.86, 1.05, -3.5), 1.5, 4.5, shade)
	d.box(Vector3(0.16, 0.035, 0.22), M.mat(C_CORAL, 0.7), Vector3(0.1, 0.57, 0.08), 0.008, Vector3(0, 20, 0)) # livre


func _build_kitchen() -> void:
	var kitchen := _add_object("cuisine", "Cuisine", ["manger", "cuisiner"], Vector3(-1.3, 0, -3.6), Vector3(2.4, 1.0, 0.8), Vector3(-1.3, 0, -2.7))
	var cab := M.mat(C_SAGE, 0.55)
	var cab_dark := M.mat(C_SAGE.darkened(0.12), 0.55)
	var top := M.tex_mat("crepi", Color(0.97, 0.95, 0.9), 2.0, "", 0.35)
	# Meuble bas
	kitchen.box(Vector3(1.62, 0.08, 0.66), M.mat(C_DARK.lightened(0.2), 0.8), Vector3(0.4, 0.04, -0.03), 0.01)
	kitchen.box(Vector3(1.64, 0.8, 0.74), cab, Vector3(0.4, 0.48, 0), 0.03)
	for k in 3:
		var x := -0.14 + k * 0.54
		kitchen.box(Vector3(0.48, 0.66, 0.03), cab_dark if k == 1 else cab, Vector3(x, 0.47, 0.375), 0.02)
		kitchen.box(Vector3(0.44, 0.6, 0.012), M.mat(C_SAGE.lightened(0.1), 0.55), Vector3(x, 0.47, 0.392), 0.015)
		kitchen.cap(0.014, 0.16, _steel, Vector3(x, 0.72, 0.41), Vector3(0, 0, 90))
	kitchen.box(Vector3(1.7, 0.06, 0.8), top, Vector3(0.4, 0.91, 0), 0.025)
	# Plaque de cuisson + casserole + poêle
	kitchen.box(Vector3(0.62, 0.02, 0.5), M.mat(C_DARK, 0.25), Vector3(0.82, 0.945, 0.0), 0.008)
	for z in [-0.12, 0.12]:
		kitchen.ring(0.085, 0.008, M.mat(Color(0.5, 0.5, 0.55), 0.4), Vector3(0.68, 0.957, z))
		kitchen.ring(0.085, 0.008, M.mat(Color(0.5, 0.5, 0.55), 0.4), Vector3(0.96, 0.957, z))
	kitchen.lathe([Vector2(0.0, 0.0), Vector2(0.12, 0.0), Vector2(0.135, 0.02), Vector2(0.135, 0.13), Vector2(0.125, 0.13), Vector2(0.115, 0.03), Vector2(0.0, 0.03)], M.mat(C_CORAL, 0.35), Vector3(0.68, 0.96, -0.12))
	kitchen.cap(0.016, 0.1, M.mat(C_DARK, 0.5), Vector3(0.52, 1.07, -0.12), Vector3(0, 0, 90))
	kitchen.cap(0.016, 0.1, M.mat(C_DARK, 0.5), Vector3(0.84, 1.07, -0.12), Vector3(0, 0, 90))
	kitchen.cyl(0.1, 0.012, M.mat(Color(0.95, 0.8, 0.5), 0.6), Vector3(0.68, 1.065, -0.12)) # soupe
	kitchen.lathe([Vector2(0.0, 0.0), Vector2(0.11, 0.0), Vector2(0.14, 0.035), Vector2(0.13, 0.035), Vector2(0.1, 0.012), Vector2(0.0, 0.012)], M.mat(C_DARK, 0.35), Vector3(0.96, 0.96, 0.12))
	kitchen.cap(0.014, 0.2, M.mat(C_WOOD_DARK, 0.6), Vector3(1.14, 0.985, 0.22), Vector3(0, 45, 90))
	# Planche à découper, fruits, bouilloire
	kitchen.box(Vector3(0.3, 0.025, 0.22), _wood_light, Vector3(0.2, 0.952, 0.14), 0.01, Vector3(0, -12, 0))
	kitchen.ball(0.05, M.mat(Color(0.9, 0.3, 0.28), 0.4), Vector3(0.16, 1.0, 0.12))
	kitchen.ball(0.045, M.mat(Color(0.98, 0.78, 0.25), 0.5), Vector3(0.26, 0.995, 0.17), Vector3(1.3, 0.9, 0.9))
	kitchen.lathe([Vector2(0.0, 0.0), Vector2(0.14, 0.0), Vector2(0.17, 0.05), Vector2(0.16, 0.07), Vector2(0.13, 0.03), Vector2(0.0, 0.03)], M.mat(C_BLUE, 0.4), Vector3(-0.1, 0.94, -0.12)) # saladier
	for a in 4:
		kitchen.ball(0.05, M.mat([Color(0.95, 0.6, 0.2), Color(0.6, 0.78, 0.3), Color(0.9, 0.3, 0.28), Color(0.95, 0.6, 0.2)][a], 0.5), Vector3(-0.1 + cos(a * 1.6) * 0.06, 1.01, -0.12 + sin(a * 1.6) * 0.06))
	kitchen.lathe([Vector2(0.0, 0.0), Vector2(0.085, 0.0), Vector2(0.095, 0.08), Vector2(0.07, 0.19), Vector2(0.03, 0.21), Vector2(0.0, 0.21)], M.mat(C_MUSTARD, 0.3), Vector3(0.36, 0.94, -0.2)) # bouilloire
	kitchen.tube(M.arc_points(0.07, -70, 70, 8), 0.012, M.mat(C_DARK, 0.5), Vector3(0.44, 1.05, -0.2))
	# Réfrigérateur
	kitchen.box(Vector3(0.78, 1.92, 0.74), M.mat(C_CREAM, 0.35), Vector3(-0.8, 0.98, 0), 0.07)
	kitchen.box(Vector3(0.74, 0.02, 0.02), M.mat(Color(0.8, 0.78, 0.72), 0.5), Vector3(-0.8, 1.32, 0.372), 0.005)
	kitchen.cap(0.018, 0.34, _steel, Vector3(-0.5, 1.62, 0.4))
	kitchen.cap(0.018, 0.5, _steel, Vector3(-0.5, 0.95, 0.4))
	kitchen.box(Vector3(0.12, 0.1, 0.012), M.mat(C_CORAL, 0.6), Vector3(-0.95, 1.6, 0.375), 0.01, Vector3(0, 0, 8)) # aimants
	kitchen.box(Vector3(0.1, 0.13, 0.012), M.mat(C_MUSTARD, 0.6), Vector3(-0.78, 1.5, 0.375), 0.01, Vector3(0, 0, -6))
	kitchen.box(Vector3(0.78, 0.06, 0.7), M.mat(C_DARK.lightened(0.2), 0.8), Vector3(-0.8, 0.03, -0.02), 0.01)
	# Meubles hauts et crédence
	kitchen.box(Vector3(1.66, 0.62, 0.02), M.tex_mat("carrelage", Color(0.99, 0.93, 0.82), 2.0, "carrelage_n", 0.3, 0.5), Vector3(0.4, 1.26, -0.385), 0.005)
	kitchen.box(Vector3(1.66, 0.58, 0.36), cab, Vector3(0.4, 1.9, -0.2), 0.03)
	for k in 3:
		var x := -0.14 + k * 0.54
		kitchen.box(Vector3(0.48, 0.5, 0.02), M.mat(C_SAGE.lightened(0.1), 0.55), Vector3(x, 1.9, -0.012), 0.015)
		kitchen.ball(0.02, _steel, Vector3(x + 0.17, 1.72, 0.005))
	var strip := M.glowing(Color(1.0, 0.92, 0.75), 0.2)
	kitchen.box(Vector3(1.5, 0.02, 0.05), strip, Vector3(0.4, 1.6, -0.1), 0.008)
	_add_lamp(Vector3(-0.9, 1.5, -3.55), 0.9, 3.2, strip)
	# Vapeur (visible pendant la cuisine)
	kitchen.set_meta("fx_point", Vector3(0.68, 1.12, -0.12))


func _build_sink() -> void:
	var sink := _add_object("lavabo", "Lavabo", ["dents"], Vector3(0.8, 0, -3.75), Vector3(0.8, 1.0, 0.5), Vector3(0.8, 0, -3.0))
	var ceramic := M.mat(Color(0.98, 0.98, 0.97), 0.15)
	sink.lathe([Vector2(0.0, 0.0), Vector2(0.17, 0.0), Vector2(0.15, 0.04), Vector2(0.1, 0.12), Vector2(0.085, 0.6), Vector2(0.12, 0.72), Vector2(0.0, 0.72)], ceramic, Vector3(0, 0, -0.02))
	sink.lathe([Vector2(0.0, 0.0), Vector2(0.16, 0.0), Vector2(0.3, 0.06), Vector2(0.36, 0.16), Vector2(0.36, 0.2), Vector2(0.33, 0.2), Vector2(0.28, 0.1), Vector2(0.1, 0.05), Vector2(0.0, 0.05)], ceramic, Vector3(0, 0.7, 0.03), Vector3.ZERO, Vector3(1, 1, 0.82))
	sink.cyl(0.24, 0.01, M.mat(Color(0.7, 0.88, 0.95), 0.1), Vector3(0, 0.84, 0.03)).scale = Vector3(1, 1, 0.82) # eau
	sink.cyl(0.025, 0.14, _steel, Vector3(0, 0.96, -0.2))
	sink.tube([Vector3(0, 1.02, -0.2), Vector3(0, 1.08, -0.18), Vector3(0, 1.09, -0.1), Vector3(0, 1.05, -0.05)], 0.018, _steel)
	for x in [-0.09, 0.09]:
		sink.ball(0.028, M.mat(C_CORAL if x < 0 else C_BLUE, 0.4), Vector3(x, 0.93, -0.2))
	# Miroir rond
	sink.cyl(0.36, 0.035, _wood_light, Vector3(0, 1.72, -0.21), Vector3(90, 0, 0))
	sink.cyl(0.31, 0.04, M.mat(Color(0.8, 0.9, 0.96), 0.05, 0.3), Vector3(0, 1.72, -0.2), Vector3(90, 0, 0))
	sink.box(Vector3(0.05, 0.4, 0.004), M.mat(Color(1, 1, 1, 0.5), 0.1), Vector3(0.08, 1.74, -0.176), 0.002, Vector3(0, 0, -30)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Tablette, gobelet et brosses à dents
	sink.box(Vector3(0.56, 0.025, 0.12), M.mat(C_WHITE, 0.3), Vector3(0, 1.22, -0.18), 0.01)
	sink.cyl(0.04, 0.1, M.mat(C_MUSTARD, 0.4), Vector3(-0.16, 1.285, -0.18))
	sink.cap(0.008, 0.16, M.mat(C_CORAL, 0.4), Vector3(-0.17, 1.36, -0.18), Vector3(0, 0, 12))
	sink.cap(0.008, 0.16, M.mat(C_BLUE, 0.4), Vector3(-0.145, 1.36, -0.17), Vector3(0, 0, -14))
	sink.lathe([Vector2(0.0, 0.0), Vector2(0.035, 0.0), Vector2(0.04, 0.09), Vector2(0.015, 0.12), Vector2(0.015, 0.15), Vector2(0.0, 0.15)], M.mat(C_SAGE, 0.3), Vector3(0.16, 1.235, -0.18)) # savon
	# Applique lumineuse
	var shade := M.glowing(Color(1.0, 0.95, 0.85), 0.2)
	sink.cap(0.05, 0.42, shade, Vector3(0, 2.2, -0.19), Vector3(0, 0, 90))
	_add_lamp(Vector3(1.6, 2.1, -3.4), 1.1, 4.2, shade, false, Color(1.0, 0.92, 0.8))
	# Porte-serviette
	sink.cyl(0.012, 0.4, _steel, Vector3(0.62, 1.05, -0.2), Vector3(0, 0, 90))
	sink.box(Vector3(0.26, 0.42, 0.03), M.tex_mat("tissu", C_CORAL, 4.0, _fabric_n, 0.95, 0.8), Vector3(0.62, 0.86, -0.19), 0.012)
	sink.set_meta("fx_point", Vector3(0, 1.0, 0.0))


func _build_toilet() -> void:
	var wc := _add_object("toilettes", "Toilettes", ["toilettes"], Vector3(2.2, 0, -3.6), Vector3(0.6, 0.9, 0.8), Vector3(2.2, 0, -2.75))
	var ceramic := M.mat(Color(0.98, 0.98, 0.97), 0.15)
	wc.lathe([Vector2(0.0, 0.0), Vector2(0.17, 0.0), Vector2(0.16, 0.05), Vector2(0.12, 0.16), Vector2(0.14, 0.26), Vector2(0.22, 0.36), Vector2(0.235, 0.41), Vector2(0.0, 0.41)], ceramic, Vector3(0, 0, 0.1), Vector3.ZERO, Vector3(1, 1, 1.22))
	wc.lathe([Vector2(0.0, 0.0), Vector2(0.24, 0.0), Vector2(0.25, 0.02), Vector2(0.24, 0.04), Vector2(0.0, 0.05)], M.mat(C_TEAL, 0.35), Vector3(0, 0.41, 0.1), Vector3.ZERO, Vector3(1, 1, 1.22)) # abattant
	wc.box(Vector3(0.5, 0.44, 0.2), ceramic, Vector3(0, 0.63, -0.28), 0.06)
	wc.box(Vector3(0.54, 0.05, 0.24), ceramic, Vector3(0, 0.87, -0.28), 0.02)
	wc.cyl(0.035, 0.02, _steel, Vector3(0, 0.9, -0.28))
	# Papier, poubelle, tapis de bain
	wc.cyl(0.055, 0.1, M.mat(C_WHITE, 0.9), Vector3(0.48, 0.7, -0.33), Vector3(0, 0, 90))
	wc.cyl(0.012, 0.16, _steel, Vector3(0.48, 0.7, -0.33), Vector3(0, 0, 90))
	wc.lathe([Vector2(0.0, 0.0), Vector2(0.09, 0.0), Vector2(0.11, 0.24), Vector2(0.1, 0.25), Vector2(0.0, 0.25)], M.mat(C_MUSTARD, 0.5), Vector3(-0.42, 0, -0.25))
	wc.box(Vector3(0.62, 0.025, 0.42), M.tex_mat("tissu", C_CORAL.lightened(0.15), 4.0, _fabric_n, 0.98, 1.0), Vector3(0, 0.022, 0.72), 0.012)
	wc.pose = "assis"
	wc.pose_point = Vector3(2.2, 0.46, -3.47)
	wc.face_point = Vector3(2.2, 0, 0.0)


func _build_shower() -> void:
	var shower := _add_object("douche", "Douche", ["douche"], Vector3(3.95, 0, -3.35), Vector3(1.2, 2.2, 1.2), Vector3(3.95, 0, -3.3))
	shower.box(Vector3(1.24, 0.1, 1.24), M.mat(Color(0.98, 0.98, 0.97), 0.15), Vector3(0, 0.05, 0), 0.04)
	shower.box(Vector3(1.08, 0.02, 1.08), M.mat(Color(0.9, 0.93, 0.95), 0.2), Vector3(0, 0.1, 0), 0.01)
	shower.cyl(0.05, 0.01, _steel, Vector3(0, 0.115, 0))
	# Colonne de douche (contre le mur du fond)
	shower.cyl(0.02, 1.9, _steel, Vector3(0.0, 1.1, -0.56))
	shower.tube([Vector3(0.0, 2.02, -0.56), Vector3(0.0, 2.12, -0.5), Vector3(0.0, 2.14, -0.3), Vector3(0.0, 2.12, -0.2)], 0.02, _steel)
	shower.lathe([Vector2(0.0, 0.0), Vector2(0.17, 0.0), Vector2(0.16, 0.03), Vector2(0.03, 0.06), Vector2(0.0, 0.06)], _steel, Vector3(0.0, 2.05, -0.2))
	shower.ball(0.04, M.mat(C_CORAL, 0.4), Vector3(0.0, 1.15, -0.54))
	# Parois vitrées (côté gauche et devant)
	var glass := M.glass(Color(0.78, 0.92, 1.0), 0.2)
	for g in [shower.box(Vector3(0.025, 1.9, 1.16), glass, Vector3(-0.6, 1.07, 0), 0.008), shower.box(Vector3(0.6, 1.9, 0.025), glass, Vector3(-0.3, 1.07, 0.6), 0.008)]:
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shower.cyl(0.018, 1.95, _steel, Vector3(-0.6, 1.07, 0.6))
	shower.cyl(0.018, 1.95, _steel, Vector3(0.0, 1.07, 0.6))
	shower.box(Vector3(0.62, 0.03, 0.03), _steel, Vector3(-0.3, 2.03, 0.6), 0.01)
	shower.box(Vector3(0.03, 0.03, 1.2), _steel, Vector3(-0.6, 2.03, 0), 0.01)
	# Étagère et flacons
	shower.box(Vector3(0.4, 0.02, 0.12), _steel, Vector3(0.34, 1.2, -0.52), 0.008)
	shower.lathe([Vector2(0.0, 0.0), Vector2(0.035, 0.0), Vector2(0.035, 0.12), Vector2(0.012, 0.15), Vector2(0.012, 0.18), Vector2(0.0, 0.18)], M.mat(C_BLUE, 0.3), Vector3(0.25, 1.21, -0.52))
	shower.lathe([Vector2(0.0, 0.0), Vector2(0.04, 0.0), Vector2(0.04, 0.09), Vector2(0.015, 0.12), Vector2(0.0, 0.12)], M.mat(C_MUSTARD, 0.3), Vector3(0.36, 1.21, -0.52))
	shower.ball(0.045, M.mat(C_CORAL, 0.8), Vector3(0.46, 1.25, -0.52)) # éponge
	shower.pose_point = Vector3(3.95, 0.11, -3.3)
	shower.face_point = Vector3(3.95, 0, 0.0)
	shower.set_meta("fx_point", Vector3(0.0, 2.03, -0.2))
	# Panier à linge à côté
	var d := _deco()
	d.position = Vector3(3.05, 0, -3.65)
	d.lathe([Vector2(0.0, 0.0), Vector2(0.2, 0.0), Vector2(0.25, 0.5), Vector2(0.24, 0.52), Vector2(0.21, 0.5), Vector2(0.17, 0.04), Vector2(0.0, 0.04)], M.tex_mat("tissu", C_WOOD_LIGHT, 6.0, _fabric_n, 0.95, 1.5), Vector3.ZERO)
	d.ball(0.18, M.tex_mat("tissu", C_BLUE.lightened(0.2), 4.0, _fabric_n, 0.95, 0.8), Vector3(0, 0.46, 0), Vector3(1, 0.5, 1))


func _build_desk() -> void:
	var desk := _add_object("bureau", "Bureau", ["travail", "planning", "appeler"], Vector3(-4.45, 0, 0.9), Vector3(0.9, 1.3, 1.6), Vector3(-3.55, 0, 0.9))
	desk.box(Vector3(0.9, 0.06, 1.6), _wood, Vector3(0, 0.76, 0), 0.025)
	# Caisson à tiroirs + pieds
	desk.box(Vector3(0.8, 0.66, 0.44), M.mat(C_CREAM, 0.6), Vector3(0, 0.4, -0.54), 0.03)
	for k in 3:
		desk.box(Vector3(0.02, 0.17, 0.38), M.mat(C_WHITE, 0.6), Vector3(0.405, 0.6 - k * 0.2, -0.54), 0.008)
		desk.ball(0.022, _steel, Vector3(0.425, 0.6 - k * 0.2, -0.54))
	for x in [-0.38, 0.38]:
		desk.cyl(0.03, 0.74, _wood_dark, Vector3(x, 0.37, 0.72))
	# Écran, clavier, souris
	desk.box(Vector3(0.05, 0.46, 0.78), M.mat(C_DARK, 0.4), Vector3(-0.22, 1.14, 0.1), 0.02)
	var screen := M.glowing(Color(0.62, 0.82, 1.0), 0.55)
	desk.box(Vector3(0.01, 0.4, 0.72), screen, Vector3(-0.192, 1.14, 0.1), 0.004)
	desk.box(Vector3(0.004, 0.06, 0.4), M.glowing(Color(1, 1, 1), 0.5), Vector3(-0.186, 1.24, 0.1), 0.002)
	desk.box(Vector3(0.004, 0.035, 0.52), M.glowing(Color(1.0, 0.85, 0.5), 0.5), Vector3(-0.186, 1.13, 0.04), 0.002)
	desk.box(Vector3(0.004, 0.035, 0.34), M.glowing(Color(0.75, 0.95, 0.75), 0.5), Vector3(-0.186, 1.06, -0.05), 0.002)
	desk.cyl(0.03, 0.14, M.mat(C_DARK, 0.4), Vector3(-0.24, 0.86, 0.1))
	desk.cyl(0.13, 0.015, M.mat(C_DARK, 0.4), Vector3(-0.24, 0.797, 0.1))
	desk.box(Vector3(0.16, 0.022, 0.46), M.mat(C_WHITE, 0.5), Vector3(0.08, 0.8, 0.1), 0.01)
	for k in 3:
		desk.box(Vector3(0.03, 0.008, 0.4), M.mat(Color(0.82, 0.84, 0.88), 0.5), Vector3(0.04 + k * 0.04, 0.813, 0.1), 0.003)
	desk.ball(0.035, M.mat(C_WHITE, 0.3), Vector3(0.1, 0.805, 0.46), Vector3(1.3, 0.6, 0.85))
	# Téléphone, agenda, pot à crayons, lampe de bureau
	desk.box(Vector3(0.16, 0.014, 0.08), M.mat(C_NAVY, 0.25), Vector3(0.2, 0.797, 0.64), 0.012, Vector3(0, 15, 0))
	desk.box(Vector3(0.26, 0.03, 0.2), M.mat(C_CORAL, 0.6), Vector3(0.18, 0.805, -0.3), 0.012, Vector3(0, -8, 0))
	desk.box(Vector3(0.24, 0.004, 0.18), M.mat(C_WHITE, 0.8), Vector3(0.18, 0.822, -0.3), 0.002, Vector3(0, -8, 0))
	desk.cyl(0.045, 0.1, M.mat(C_TEAL, 0.5), Vector3(-0.28, 0.84, -0.5))
	for k in 3:
		desk.cap(0.008, 0.17, M.mat([C_MUSTARD, C_CORAL, C_BLUE][k], 0.5), Vector3(-0.28 + (k - 1) * 0.018, 0.93, -0.5 + (k - 1) * 0.012), Vector3((k - 1) * 9.0, 0, (k - 1) * -8.0))
	desk.cyl(0.07, 0.02, M.mat(C_MUSTARD, 0.4), Vector3(-0.3, 0.8, 0.66))
	desk.tube([Vector3(-0.3, 0.8, 0.66), Vector3(-0.3, 1.08, 0.7), Vector3(-0.16, 1.26, 0.58)], 0.014, M.mat(C_MUSTARD, 0.4))
	var shade := M.glowing(Color(1.0, 0.9, 0.7), 0.2)
	desk.lathe([Vector2(0.09, 0.0), Vector2(0.03, 0.1), Vector2(0.0, 0.1)], M.mat(C_MUSTARD, 0.4), Vector3(-0.14, 1.19, 0.56), Vector3(-30, 0, -35))
	desk.ball(0.035, shade, Vector3(-0.13, 1.2, 0.55))
	_add_lamp(Vector3(-4.3, 1.35, 1.35), 1.2, 3.4, shade)
	# Chaise de bureau
	var chair := M.tex_mat("tissu", C_MUSTARD, 3.0, _fabric_n, 0.9, 0.6)
	desk.box(Vector3(0.5, 0.1, 0.5), chair, Vector3(0.68, 0.48, 0), 0.045)
	desk.box(Vector3(0.1, 0.52, 0.46), chair, Vector3(0.93, 0.82, 0), 0.045)
	desk.cyl(0.03, 0.3, _steel, Vector3(0.68, 0.3, 0))
	for k in 5:
		var a := k * TAU / 5.0
		desk.cap(0.022, 0.3, M.mat(C_DARK, 0.5), Vector3(0.68 + cos(a) * 0.13, 0.08, sin(a) * 0.13), Vector3(90, -rad_to_deg(a) + 90, 0))
		desk.ball(0.035, M.mat(C_DARK, 0.5), Vector3(0.68 + cos(a) * 0.27, 0.035, sin(a) * 0.27))
	desk.pose = "assis"
	desk.pose_point = Vector3(-3.77, 0.53, 0.9)
	desk.face_point = Vector3(-5.0, 0, 0.9)
	# Tableau de planning + étagère au mur
	var d := _deco()
	d.box(Vector3(0.03, 0.62, 0.86), _wood_light, Vector3(-4.975, 1.75, 1.2), 0.012)
	d.box(Vector3(0.012, 0.54, 0.78), M.mat(Color(0.86, 0.72, 0.56), 0.95), Vector3(-4.96, 1.75, 1.2), 0.004)
	var notes := [C_MUSTARD, C_CORAL, C_SAGE, C_BLUE.lightened(0.3), C_WHITE, C_MUSTARD.lightened(0.3)]
	for k in 6:
		d.box(Vector3(0.006, 0.14, 0.14), M.mat(notes[k], 0.9), Vector3(-4.952, 1.88 - (k / 3) * 0.26, 0.93 + (k % 3) * 0.27), 0.003, Vector3((k * 37) % 13 - 6, 0, 0))
	d.box(Vector3(0.24, 0.04, 0.9), _wood, Vector3(-4.86, 2.3, 1.0), 0.015)
	var books := [C_CORAL, C_TEAL, C_MUSTARD, C_NAVY, C_SAGE, C_CORAL.lightened(0.2)]
	for k in 6:
		d.box(Vector3(0.16, 0.2 + (k % 3) * 0.03, 0.05), M.mat(books[k], 0.7), Vector3(-4.86, 2.42 + (k % 3) * 0.015, 0.68 + k * 0.058), 0.008)
	_potted_plant(d, Vector3(-4.86, 2.32, 1.3), 0.3, C_WHITE)


func _build_mirror() -> void:
	var mirror := _add_object("miroir", "Miroir", ["miroir", "look"], Vector3(-4.85, 0, 2.7), Vector3(0.25, 1.9, 0.9), Vector3(-3.95, 0, 2.7))
	mirror.box(Vector3(0.08, 1.86, 0.84), _wood_light, Vector3(0.0, 0.98, 0), 0.04, Vector3(0, 0, 4))
	var glass := mirror.box(Vector3(0.02, 1.68, 0.68), M.mat(Color(0.78, 0.88, 0.94), 0.05, 0.4), Vector3(0.042, 0.98, 0), 0.008, Vector3(0, 0, 4))
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for k in 2:
		var streak := mirror.box(Vector3(0.004, 0.9 - k * 0.3, 0.06 - k * 0.02), M.mat(Color(1, 1, 1, 0.42), 0.1), Vector3(0.056, 1.15 - k * 0.1, -0.12 + k * 0.14), 0.002, Vector3(-28, 0, 4))
		streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mirror.box(Vector3(0.3, 0.05, 0.9), _wood, Vector3(0.08, 0.03, 0), 0.02)


func _build_sofa() -> void:
	var sofa := _add_object("canape", "Canapé", ["inviter"], Vector3(0.4, 0, 3.3), Vector3(2.3, 0.9, 0.9), Vector3(0.4, 0, 2.45))
	var fabric := M.tex_mat("tissu", C_BLUE, 3.5, _fabric_n, 0.95, 0.9)
	var fabric_dark := M.tex_mat("tissu", C_BLUE.darkened(0.1), 3.5, _fabric_n, 0.95, 0.9)
	for x in [-1.0, 1.0]:
		for z in [-0.34, 0.34]:
			sofa.cyl(0.04, 0.12, _wood_dark, Vector3(x, 0.06, z))
	sofa.box(Vector3(2.3, 0.28, 0.9), fabric_dark, Vector3(0, 0.24, 0), 0.1)
	for x in [-0.5, 0.5]:
		sofa.box(Vector3(0.96, 0.2, 0.72), fabric, Vector3(x, 0.44, -0.07), 0.09) # assises
		sofa.box(Vector3(0.94, 0.52, 0.24), fabric, Vector3(x, 0.72, 0.3), 0.11) # dossiers
	for x in [-1.06, 1.06]:
		sofa.box(Vector3(0.24, 0.5, 0.92), fabric_dark, Vector3(x, 0.42, 0), 0.11)
	sofa.box(Vector3(0.4, 0.4, 0.14), M.tex_mat("tissu", C_MUSTARD, 4.0, _fabric_n, 0.95, 0.9), Vector3(-0.72, 0.68, 0.1), 0.07, Vector3(-14, 12, 6))
	sofa.box(Vector3(0.36, 0.36, 0.14), M.tex_mat("tissu", C_CORAL, 4.0, _fabric_n, 0.95, 0.9), Vector3(0.74, 0.67, 0.1), 0.07, Vector3(-14, -10, -8))
	sofa.pose = "assis"
	sofa.pose_point = Vector3(0.4, 0.56, 3.2)
	sofa.face_point = Vector3(0.4, 0, 0.0)
	sofa.set_meta("guest_points", [Vector3(-0.42, 0.56, 3.2), Vector3(1.22, 0.56, 3.2)])
	# Tapis rond (au sol, on marche dessus)
	var d := _deco()
	var rug := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(3.2, 3.2)
	rug.mesh = plane
	var rug_mat := M.uv_mat("tapis", Color.WHITE, 0.95, true)
	rug.material_override = rug_mat
	rug.position = Vector3(0.4, 0.012, 1.4)
	rug.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	d.add_child(rug)
	# Petite table + lampadaire à gauche du canapé
	d.cyl(0.26, 0.04, _wood_light, Vector3(-1.2, 0.5, 3.45))
	d.cyl(0.03, 0.5, _wood_dark, Vector3(-1.2, 0.25, 3.45))
	d.cyl(0.16, 0.03, _wood_dark, Vector3(-1.2, 0.015, 3.45))
	d.lathe([Vector2(0.0, 0.0), Vector2(0.05, 0.0), Vector2(0.06, 0.07), Vector2(0.05, 0.09), Vector2(0.0, 0.09)], M.mat(C_WHITE, 0.3), Vector3(-1.26, 0.52, 3.4)) # tasse
	d.box(Vector3(0.2, 0.03, 0.15), M.mat(C_TEAL, 0.7), Vector3(-1.12, 0.535, 3.52), 0.008, Vector3(0, 25, 0))
	d.cyl(0.2, 0.03, M.mat(C_DARK, 0.5), Vector3(-1.75, 0.015, 3.55))
	d.cyl(0.02, 1.6, M.mat(C_DARK, 0.5), Vector3(-1.75, 0.8, 3.55))
	var shade := M.glowing(Color(1.0, 0.88, 0.66), 0.2)
	d.lathe([Vector2(0.26, 0.0), Vector2(0.17, 0.3), Vector2(0.0, 0.3)], shade, Vector3(-1.75, 1.5, 3.55))
	_add_lamp(Vector3(-1.6, 1.7, 3.2), 2.4, 7.0, shade, true)


func _build_treadmill() -> void:
	var tread := _add_object("tapis", "Tapis de course", ["sport"], Vector3(4.1, 0, 0.6), Vector3(0.9, 1.3, 1.9), Vector3(4.1, 0, 0.75))
	var body := M.mat(Color(0.3, 0.32, 0.38), 0.45)
	tread.box(Vector3(0.86, 0.14, 1.84), body, Vector3(0, 0.08, 0.1), 0.06)
	var belt := StandardMaterial3D.new()
	belt.albedo_color = Color(0.13, 0.14, 0.16)
	belt.roughness = 0.9
	tread.box(Vector3(0.64, 0.02, 1.62), belt, Vector3(0, 0.155, 0.12), 0.008)
	for k in 7: # repères sur la bande (ils défilent pendant la course)
		var stripe := tread.box(Vector3(0.5, 0.004, 0.03), M.mat(Color(0.32, 0.34, 0.38), 0.9), Vector3(0, 0.167, -0.6 + k * 0.24), 0.002)
		stripe.set_meta("belt", true)
	for x in [-0.4, 0.4]:
		tread.box(Vector3(0.07, 0.03, 1.84), M.mat(C_TEAL, 0.4), Vector3(x, 0.155, 0.1), 0.012)
		tread.tube([Vector3(x, 0.14, -0.72), Vector3(x, 0.9, -0.82), Vector3(x, 1.12, -0.76), Vector3(x, 1.1, -0.36)], 0.03, _steel)
		tread.cap(0.036, 0.22, M.mat(C_DARK, 0.6), Vector3(x, 1.1, -0.42), Vector3(90, 0, 0))
	tread.box(Vector3(0.84, 0.28, 0.1), body, Vector3(0, 1.2, -0.8), 0.045, Vector3(-28, 0, 0))
	tread.box(Vector3(0.46, 0.16, 0.012), M.glowing(Color(0.5, 0.95, 0.75), 0.6), Vector3(0, 1.225, -0.752), 0.008, Vector3(-28, 0, 0))
	tread.pose = "course"
	tread.pose_point = Vector3(4.1, 0.165, 0.75)
	tread.face_point = Vector3(4.1, 0, -2.0)
	# Haltères et bouteille d'eau à côté
	var d := _deco()
	for k in 2:
		var p := Vector3(3.25, 0.07, 1.25 + k * 0.3)
		d.cyl(0.02, 0.26, _steel, p, Vector3(0, 0, 90))
		for side in [-0.11, 0.11]:
			d.cyl(0.07, 0.07, M.mat(C_CORAL if k == 0 else C_TEAL, 0.5), p + Vector3(side, 0, 0), Vector3(0, 0, 90))
	d.lathe([Vector2(0.0, 0.0), Vector2(0.04, 0.0), Vector2(0.04, 0.16), Vector2(0.018, 0.2), Vector2(0.018, 0.23), Vector2(0.0, 0.23)], M.mat(C_BLUE.lightened(0.2), 0.2), Vector3(3.3, 0, 0.1))


func _build_easel() -> void:
	# La toile regarde vers la droite : on la voit depuis la caméra, le peintre se place à côté.
	var easel := _add_object("chevalet", "Chevalet", ["peindre"], Vector3(2.4, 0, 3.4), Vector3(0.6, 1.7, 0.85), Vector3(3.2, 0, 3.4))
	easel.cap(0.025, 1.7, _wood_light, Vector3(0.0, 0.84, -0.3), Vector3(9, 0, 9))
	easel.cap(0.025, 1.7, _wood_light, Vector3(0.0, 0.84, 0.3), Vector3(-9, 0, 9))
	easel.cap(0.025, 1.6, _wood_light, Vector3(-0.3, 0.78, 0), Vector3(0, 0, -16))
	easel.box(Vector3(0.08, 0.04, 0.74), _wood_light, Vector3(0.1, 0.82, 0), 0.012)
	easel.box(Vector3(0.035, 0.6, 0.72), M.mat(C_WHITE, 0.9), Vector3(0.05, 1.15, 0), 0.008, Vector3(0, 0, 9))
	var canvas := StandardMaterial3D.new()
	canvas.albedo_texture = M.tex("toile_chevalet")
	canvas.roughness = 0.9
	var art := easel.flat(Vector2(0.66, 0.54), canvas, Vector3(0.071, 1.153, 0), Vector3(0, 90, 9))
	art.set_meta("canvas", true)
	easel.face_point = Vector3(2.4, 0, 3.4)
	# Tabouret avec palette et pot à pinceaux
	var d := _deco()
	d.position = Vector3(2.45, 0, 2.6)
	d.cyl(0.19, 0.04, _wood, Vector3(0, 0.5, 0))
	for k in 3:
		var a := k * TAU / 3.0
		d.cap(0.022, 0.52, _wood_dark, Vector3(cos(a) * 0.13, 0.25, sin(a) * 0.13), Vector3(sin(a) * 10.0, 0, -cos(a) * 10.0))
	d.cyl(0.15, 0.015, _wood_light, Vector3(0, 0.53, 0)).scale = Vector3(1, 1, 0.75)
	for k in 5:
		d.ball(0.03, M.mat([C_CORAL, C_MUSTARD, C_BLUE, C_SAGE, C_WHITE][k], 0.3), Vector3(cos(k * 1.1 + 0.4) * 0.09, 0.54, sin(k * 1.1 + 0.4) * 0.065), Vector3(1, 0.4, 1))
	d.lathe([Vector2(0.0, 0.0), Vector2(0.05, 0.0), Vector2(0.055, 0.12), Vector2(0.0, 0.12)], M.mat(C_TEAL, 0.4), Vector3(-0.3, 0, 0.12))
	for k in 3:
		d.cap(0.008, 0.26, _wood_light, Vector3(-0.3 + (k - 1) * 0.02, 0.2, 0.12), Vector3((k - 1) * 8.0, 0, (k - 1) * 10.0))


func _build_workbench() -> void:
	var bench := _add_object("etabli", "Établi", ["bois"], Vector3(4.3, 0, 3.35), Vector3(1.3, 1.0, 0.7), Vector3(4.3, 0, 2.55))
	bench.box(Vector3(1.34, 0.1, 0.72), _wood_light, Vector3(0, 0.86, 0), 0.025)
	for x in [-0.58, 0.58]:
		for z in [-0.28, 0.28]:
			bench.box(Vector3(0.1, 0.82, 0.1), _wood_dark, Vector3(x, 0.41, z), 0.02)
	bench.box(Vector3(1.2, 0.05, 0.6), _wood, Vector3(0, 0.26, 0), 0.015)
	bench.box(Vector3(1.26, 0.08, 0.06), _wood_dark, Vector3(0, 0.6, 0.3), 0.015)
	# Étau, planche, marteau, scie
	bench.box(Vector3(0.16, 0.12, 0.2), M.mat(C_TEAL.darkened(0.2), 0.4, 0.3), Vector3(-0.5, 0.97, -0.2), 0.02)
	bench.cyl(0.015, 0.26, _steel, Vector3(-0.5, 0.99, -0.02), Vector3(90, 0, 0))
	bench.box(Vector3(0.62, 0.05, 0.2), M.tex_mat("bois", Color(0.95, 0.82, 0.62), 1.6, "bois_n", 0.7, 0.6), Vector3(0.05, 0.935, -0.06), 0.01, Vector3(0, 10, 0))
	bench.cap(0.018, 0.28, _wood_dark, Vector3(0.44, 0.93, 0.12), Vector3(0, 30, 90))
	bench.box(Vector3(0.07, 0.07, 0.12), _steel, Vector3(0.55, 0.945, 0.06), 0.015, Vector3(0, 30, 0))
	bench.box(Vector3(0.4, 0.008, 0.11), _steel, Vector3(-0.08, 0.918, 0.22), 0.003, Vector3(0, -6, 0))
	bench.box(Vector3(0.12, 0.03, 0.1), M.mat(C_CORAL, 0.5), Vector3(-0.34, 0.925, 0.22), 0.012, Vector3(0, -6, 0))
	# Caisse à outils et bûches en dessous
	bench.box(Vector3(0.44, 0.2, 0.26), M.mat(C_CORAL, 0.4), Vector3(-0.3, 0.385, 0), 0.03)
	bench.cap(0.014, 0.26, _steel, Vector3(-0.3, 0.52, 0), Vector3(0, 0, 90))
	var log_mat := M.tex_mat("bois", Color(0.62, 0.46, 0.34), 2.0, "bois_n", 0.9, 1.0)
	var cut := M.mat(Color(0.93, 0.8, 0.6), 0.8)
	for k in 3:
		var p := Vector3(0.22 + (k % 2) * 0.2 + (0.1 if k == 2 else 0.0), 0.36 + (0.15 if k == 2 else 0.0), 0)
		bench.cyl(0.085, 0.5, log_mat, p, Vector3(90, 0, 0))
		bench.cyl(0.07, 0.505, cut, p, Vector3(90, 0, 0))
	bench.set_meta("fx_point", Vector3(0.05, 1.0, -0.06))


# --- Achats du magasin (la maison s'agrandit) ---------------------------------------------

## Construit les achats déjà faits (au chargement de la partie).
func set_purchases(ids: Array) -> void:
	for id in ids:
		add_purchase(str(id))


## Ajoute dans la maison ce qu'un achat du magasin apporte. Renvoie l'objet utilisable.
## `animate` : les nouveaux éléments apparaissent en grossissant.
func add_purchase(id: String, animate := false) -> Furniture:
	if not Data.SHOP.has(id):
		return null
	var object_id: String = Data.SHOP[id]["objet"]
	if _purchased.has(id):
		return get_object(object_id)
	_purchased[id] = true
	var first := get_child_count()
	match id:
		"lecture":
			_build_reading_corner()
		"jeux":
			_build_game_table()
		"guitare":
			_build_guitar()
		"terrasse":
			_build_terrace()
		"chat":
			_build_cat()
	for i in range(first, get_child_count()):
		var node := get_child(i)
		if id == "terrasse":
			_set_layers(node, LAYER_GARDEN)
		if animate:
			_pop_in(node)
	apply_quality(quality)
	_apply_lamps()
	return get_object(object_id)


func _pop_in(node: Node) -> void:
	for c in node.get_children():
		if c is MeshInstance3D:
			var final: Vector3 = c.scale
			c.scale = final * 0.01
			c.create_tween().tween_property(c, "scale", final, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			_pop_in(c)


## Coin lecture : fauteuil tourné vers la pièce et bibliothèque basse sous la fenêtre.
func _build_reading_corner() -> void:
	var chair := _add_object("lecture", "Coin lecture", ["lire"], Vector3(-4.0, 0, -0.6), Vector3(0.95, 1.0, 0.95), Vector3(-3.1, 0, -0.6))
	chair.footprint = Rect2(-4.97, -1.27, 1.45, 1.34)
	var fabric := M.tex_mat("tissu", C_TEAL.lightened(0.12), 3.5, _fabric_n, 0.95, 0.9)
	var fabric_dark := M.tex_mat("tissu", C_TEAL.darkened(0.08), 3.5, _fabric_n, 0.95, 0.9)
	for x in [-0.32, 0.32]:
		for z in [-0.34, 0.34]:
			chair.cyl(0.035, 0.14, _wood_dark, Vector3(x, 0.07, z))
	chair.box(Vector3(0.84, 0.22, 0.86), fabric_dark, Vector3(0, 0.25, 0), 0.09)
	chair.box(Vector3(0.6, 0.16, 0.6), fabric, Vector3(0.08, 0.4, 0), 0.07) # assise
	chair.box(Vector3(0.24, 0.72, 0.84), fabric, Vector3(-0.32, 0.66, 0), 0.11, Vector3(0, 0, 6)) # dossier
	for z in [-0.37, 0.37]:
		chair.box(Vector3(0.74, 0.34, 0.18), fabric_dark, Vector3(0.03, 0.5, z), 0.085) # accoudoirs
	chair.box(Vector3(0.12, 0.3, 0.32), M.tex_mat("tissu", C_MUSTARD, 4.0, _fabric_n, 0.95, 0.9), Vector3(-0.17, 0.62, 0.1), 0.055, Vector3(8, 0, 10)) # coussin
	chair.pose = "assis"
	chair.pose_point = Vector3(-3.95, 0.5, -0.6)
	chair.face_point = Vector3(0.0, 0, -0.6)
	# Bibliothèque basse contre le mur
	var bx := -0.78
	chair.box(Vector3(0.03, 0.8, 1.26), _wood_dark, Vector3(bx - 0.165, 0.42, 0), 0.008)
	for z in [-0.63, 0.63]:
		chair.box(Vector3(0.36, 0.84, 0.05), _wood, Vector3(bx, 0.42, z), 0.012)
	for y in [0.03, 0.43, 0.82]:
		chair.box(Vector3(0.36, 0.045, 1.3), _wood, Vector3(bx, y, 0), 0.012)
	var covers := [C_CORAL, C_TEAL, C_MUSTARD, C_NAVY, C_SAGE, C_BLUE, C_CORAL.lightened(0.25), Color(0.62, 0.48, 0.86)]
	for row in 2:
		var z := -0.56
		var k := row * 3
		while z < (0.5 if row == 0 else 0.18):
			var w := 0.055 + (k % 3) * 0.018
			var h := 0.26 + ((k * 7) % 4) * 0.025
			chair.box(Vector3(0.22, h, w), M.mat(covers[k % covers.size()], 0.7), Vector3(bx + 0.02, 0.06 + row * 0.4 + h / 2.0, z + w / 2.0), 0.008)
			z += w + 0.008
			k += 1
	chair.box(Vector3(0.24, 0.05, 0.17), M.mat(C_CORAL, 0.7), Vector3(bx + 0.02, 0.48, 0.4), 0.008, Vector3(0, 12, 0)) # livres posés à plat
	chair.box(Vector3(0.22, 0.045, 0.16), M.mat(C_NAVY, 0.7), Vector3(bx + 0.02, 0.53, 0.4), 0.008, Vector3(0, -8, 0))
	# Petite lampe et livre ouvert sur le dessus
	var shade := M.glowing(Color(1.0, 0.9, 0.7), 0.2)
	chair.lathe([Vector2(0.0, 0.0), Vector2(0.08, 0.0), Vector2(0.09, 0.02), Vector2(0.02, 0.05), Vector2(0.02, 0.2), Vector2(0.0, 0.2)], M.mat(C_CORAL, 0.4), Vector3(bx, 0.845, 0.48))
	chair.lathe([Vector2(0.13, 0.0), Vector2(0.08, 0.16), Vector2(0.0, 0.16)], shade, Vector3(bx, 1.02, 0.48))
	_add_lamp(Vector3(-4.6, 1.3, -0.2), 1.2, 3.4, shade)
	chair.box(Vector3(0.2, 0.02, 0.3), M.mat(C_WHITE, 0.8), Vector3(bx + 0.02, 0.855, -0.3), 0.006, Vector3(0, 14, 0))
	chair.box(Vector3(0.21, 0.012, 0.31), M.mat(C_BLUE, 0.7), Vector3(bx + 0.02, 0.847, -0.3), 0.004, Vector3(0, 14, 0))


## Table de jeux : table ronde, jeu de société et deux tabourets (un ami vient jouer).
func _build_game_table() -> void:
	var table := _add_object("jeux", "Table de jeux", ["jeu"], Vector3(-1.6, 0, 0.2), Vector3(1.05, 0.95, 1.05), Vector3(-2.95, 0, 0.2))
	table.footprint = Rect2(-2.65, -0.85, 1.6, 1.6)
	table.cyl(0.52, 0.05, _wood_light, Vector3(0, 0.72, 0))
	table.cyl(0.5, 0.03, _wood, Vector3(0, 0.685, 0))
	table.cyl(0.05, 0.66, _wood_dark, Vector3(0, 0.35, 0))
	table.lathe([Vector2(0.0, 0.0), Vector2(0.3, 0.0), Vector2(0.3, 0.03), Vector2(0.07, 0.07), Vector2(0.0, 0.07)], _wood_dark, Vector3.ZERO)
	# Plateau de jeu, pions, dé et cartes
	table.box(Vector3(0.5, 0.018, 0.5), M.mat(C_CREAM, 0.7), Vector3(0, 0.756, 0), 0.008, Vector3(0, 20, 0))
	var squares := [C_CORAL, C_TEAL, C_MUSTARD, C_BLUE]
	for k in 12: # cases de couleur autour du plateau
		var a := deg_to_rad(k * 30.0 + 20.0)
		table.box(Vector3(0.085, 0.006, 0.085), M.mat(squares[k % 4], 0.6), Vector3(cos(a) * 0.19, 0.768, sin(a) * 0.19), 0.004, Vector3(0, -k * 30.0 + 20.0, 0))
	for k in 3:
		var pawn := Vector3([-0.12, 0.06, 0.15][k], 0.766, [0.11, -0.16, 0.08][k])
		table.lathe([Vector2(0.0, 0.0), Vector2(0.028, 0.0), Vector2(0.012, 0.05), Vector2(0.0, 0.05)], M.mat([C_CORAL, C_BLUE, C_MUSTARD][k], 0.4), pawn)
		table.ball(0.018, M.mat([C_CORAL, C_BLUE, C_MUSTARD][k], 0.4), pawn + Vector3(0, 0.06, 0))
	table.box(Vector3(0.05, 0.05, 0.05), M.mat(C_WHITE, 0.4), Vector3(0.02, 0.79, 0.02), 0.01, Vector3(0, 30, 0))
	for k in 3:
		table.box(Vector3(0.09, 0.004, 0.13), M.mat([C_WHITE, C_CORAL.lightened(0.3), C_WHITE][k], 0.7), Vector3(0.3, 0.75 + k * 0.004, -0.22), 0.002, Vector3(0, 35.0 + k * 9.0, 0))
	# Tabourets : celui du joueur à gauche, celui de l'ami au fond (on voit leur visage)
	for seat in [Vector3(-0.8, 0, 0), Vector3(0, 0, -0.8)]:
		var sp: Vector3 = seat
		table.cyl(0.2, 0.05, _wood, sp + Vector3(0, 0.44, 0))
		table.cyl(0.19, 0.045, M.tex_mat("tissu", C_CORAL if sp.x < 0.0 else C_MUSTARD, 4.0, _fabric_n, 0.95, 0.9), sp + Vector3(0, 0.485, 0))
		for k in 3:
			var a := k * TAU / 3.0 + 0.5
			table.cap(0.022, 0.46, _wood_dark, sp + Vector3(cos(a) * 0.13, 0.22, sin(a) * 0.13), Vector3(sin(a) * 9.0, 0, -cos(a) * 9.0))
	table.pose = "assis"
	table.pose_point = Vector3(-2.4, 0.51, 0.2)
	table.face_point = Vector3(-1.6, 0, 0.2)
	table.set_meta("guest_seat", Vector3(-1.6, 0.51, -0.6))


## Guitare sur son pied, avec un petit ampli. Le personnage joue debout, face à nous.
func _build_guitar() -> void:
	var g := _add_object("guitare", "Guitare", ["musique"], Vector3(2.3, 0, -0.3), Vector3(0.8, 1.25, 0.6), Vector3(2.3, 0, 0.5))
	g.face_point = Vector3(8.0, 0, 8.0)
	var dark := M.mat(C_DARK, 0.5)
	# Pied : trois branches et un support
	for k in 3:
		var a := k * TAU / 3.0 + 0.6
		g.cap(0.016, 0.42, dark, Vector3(cos(a) * 0.15, 0.09, sin(a) * 0.15), Vector3(sin(a) * 62.0, 0, -cos(a) * 62.0))
	g.cyl(0.018, 0.78, dark, Vector3(0, 0.56, -0.03))
	g.box(Vector3(0.3, 0.03, 0.09), dark, Vector3(0, 0.3, 0.03), 0.012)
	g.cap(0.014, 0.12, dark, Vector3(0, 0.95, 0.0), Vector3(90, 0, 0))
	# La guitare (cachée pendant que le personnage joue)
	var guitar := Node3D.new()
	guitar.position = Vector3(0, 0.34, 0.07)
	guitar.rotation_degrees = Vector3(-9, 0, 0)
	g.add_child(guitar)
	for mi in M.guitar(guitar):
		g._reg(mi)
	g.set_meta("guitar", guitar)
	# Petit ampli
	g.box(Vector3(0.4, 0.42, 0.26), M.mat(C_CORAL.darkened(0.1), 0.6), Vector3(0.52, 0.22, -0.05), 0.04)
	g.box(Vector3(0.32, 0.26, 0.02), M.tex_mat("tissu", Color(0.3, 0.31, 0.36), 6.0, _fabric_n, 0.95, 1.2), Vector3(0.52, 0.19, 0.085), 0.02)
	g.box(Vector3(0.32, 0.05, 0.02), M.mat(C_CREAM, 0.5), Vector3(0.52, 0.38, 0.085), 0.01)
	for k in 3:
		g.ball(0.014, _steel, Vector3(0.43 + k * 0.09, 0.38, 0.1))
	g.cap(0.012, 0.2, dark, Vector3(0.52, 0.45, -0.05), Vector3(0, 0, 90))


## Terrasse en bois à droite de la maison : elle mène au potager, où l'on peut jardiner.
func _build_terrace() -> void:
	_terrace = true
	var size := TERRACE_MAX - TERRACE_MIN
	var center := Vector3((TERRACE_MIN.x + TERRACE_MAX.x) / 2.0, 0, (TERRACE_MIN.y + TERRACE_MAX.y) / 2.0)
	var body := StaticBody3D.new()
	body.add_to_group("floor")
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, 0.2, size.y)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = center + Vector3(0, -0.1, 0)
	body.add_child(col)
	add_child(body)
	var d := _deco()
	d.position = center
	d.box(Vector3(size.x, 0.27, size.y), _wood_dark, Vector3(0, -0.165, 0), 0.02)
	var planks := 9
	var pw := size.y / planks
	for i in planks:
		d.box(Vector3(size.x + 0.04, 0.05, pw - 0.025), _wood if i % 2 == 0 else _wood_light, Vector3(0, -0.024, -size.y / 2.0 + pw * (i + 0.5)), 0.012)
	# Barrière au fond
	var white := M.mat(Color(0.96, 0.94, 0.9), 0.75)
	var zb := -size.y / 2.0 + 0.06
	for x in [-size.x / 2.0 + 0.06, 0.0, size.x / 2.0 - 0.06]:
		d.box(Vector3(0.09, 0.9, 0.09), white, Vector3(x, 0.45, zb), 0.02)
	for y in [0.4, 0.82]:
		d.box(Vector3(size.x, 0.07, 0.06), white, Vector3(0, y, zb), 0.02)
	# Lanterne sur le poteau du coin
	var shade := M.glowing(Color(1.0, 0.88, 0.62), 0.25)
	d.box(Vector3(0.14, 0.18, 0.14), shade, Vector3(size.x / 2.0 - 0.06, 1.0, zb), 0.03)
	d.box(Vector3(0.18, 0.03, 0.18), M.mat(C_DARK, 0.5), Vector3(size.x / 2.0 - 0.06, 1.1, zb), 0.01)
	_add_lamp(center + Vector3(size.x / 2.0 - 0.2, 1.35, zb + 0.3), 1.8, 5.5, shade)
	# Jardinières fleuries le long de la barrière
	var soil := M.mat(Color(0.45, 0.33, 0.26), 0.95)
	var petals := [C_CORAL, C_MUSTARD, Color(0.98, 0.96, 0.92), Color(0.74, 0.56, 0.9)]
	for side in [-1.0, 1.0]:
		var px: float = side * 0.54
		d.box(Vector3(0.88, 0.3, 0.32), M.mat(C_TEAL if side < 0.0 else C_CORAL, 0.6), Vector3(px, 0.15, zb + 0.3), 0.04)
		d.box(Vector3(0.8, 0.04, 0.24), soil, Vector3(px, 0.29, zb + 0.3), 0.015)
		for k in 5:
			var fx := px - 0.32 + k * 0.16
			var h := 0.16 + ((k * 3) % 4) * 0.035
			d.cyl(0.011, h, C_LEAF, Vector3(fx, 0.31 + h / 2.0, zb + 0.3))
			d.ball(0.055, M.mat(petals[(k + (1 if side > 0.0 else 0)) % 4], 0.7), Vector3(fx, 0.33 + h, zb + 0.3), Vector3(1, 0.75, 1))
			d.ball(0.06, C_LEAF_LIGHT, Vector3(fx + 0.05, 0.33, zb + 0.34), Vector3(1.2, 0.5, 0.8))
	# Paillasson devant l'entrée
	d.box(Vector3(0.5, 0.02, 0.8), M.tex_mat("tissu", C_MUSTARD.darkened(0.1), 5.0, _fabric_n, 0.98, 1.2), Vector3(-size.x / 2.0 + 0.4, 0.01, 0.0), 0.008)

	# Le potager devient utilisable : pieds de tomates, panneau et arrosoir
	var bed := _add_object("potager", "Potager", ["jardiner"], Vector3(8.6, GROUND_Y, -1.6), Vector3(2.6, 0.9, 1.7), Vector3(TERRACE_MAX.x - 0.32, 0, -1.6))
	bed.face_point = Vector3(8.6, 0, -1.6)
	var tomato := M.mat(Color(0.9, 0.25, 0.22), 0.4)
	for k in 4:
		var p := Vector3(-0.8 + k * 0.53, 0.19, -0.26 if k % 2 == 0 else 0.26)
		bed.cyl(0.014, 0.75, _wood_light, p + Vector3(0, 0.37, 0))
		for j in 4:
			var a := j * 1.7 + k
			bed.ball(0.085, C_LEAF if j % 2 == 0 else C_LEAF_LIGHT, p + Vector3(cos(a) * 0.07, 0.14 + j * 0.15, sin(a) * 0.07), Vector3(1.1, 0.8, 1.1))
			if j > 0:
				bed.ball(0.04, tomato, p + Vector3(cos(a + 1.6) * 0.1, 0.1 + j * 0.15, sin(a + 1.6) * 0.1))
	bed.cyl(0.02, 0.5, _wood_dark, Vector3(-1.05, 0.4, 0.72))
	bed.box(Vector3(0.05, 0.2, 0.36), _wood_light, Vector3(-1.05, 0.62, 0.72), 0.02)
	# Arrosoir posé au bord de la terrasse
	var can_mat := M.mat(C_BLUE, 0.4, 0.2)
	var can := Node3D.new() # caché pendant que le personnage arrose
	can.position = Vector3(-1.52, 0.3, 0.75)
	bed.add_child(can)
	bed._reg(M.add(can, M.lathe([Vector2(0.0, 0.0), Vector2(0.1, 0.0), Vector2(0.11, 0.2), Vector2(0.09, 0.22), Vector2(0.0, 0.22)]), can_mat))
	bed._reg(M.add(can, M.capsule(0.02, 0.26), can_mat, Vector3(0.14, 0.14, 0), Vector3(0, 0, -50)))
	bed._reg(M.add(can, M.tube(M.arc_points(0.08, 20, 160, 8), 0.014), can_mat, Vector3(-0.1, 0.12, 0)))
	bed.set_meta("can", can)
	bed.set_meta("fx_point", Vector3(-1.1, 1.05, 0.0))


## Un chat dans son panier, avec sa gamelle.
func _build_cat() -> void:
	var home := _add_object("chat", "Chat", ["animal"], Vector3(-3.3, 0, 3.45), Vector3(0.95, 0.75, 0.8), Vector3(-3.85, 0, 2.9))
	var wicker := M.tex_mat("tissu", C_WOOD_LIGHT, 6.0, _fabric_n, 0.95, 1.5)
	home.lathe([Vector2(0.0, 0.0), Vector2(0.31, 0.0), Vector2(0.37, 0.08), Vector2(0.38, 0.2), Vector2(0.34, 0.22), Vector2(0.3, 0.1), Vector2(0.0, 0.08)], wicker, Vector3.ZERO)
	home.cyl(0.3, 0.07, M.tex_mat("tissu", C_CORAL.lightened(0.1), 4.0, _fabric_n, 0.95, 0.9), Vector3(0, 0.11, 0))
	# Le chat regarde vers nous
	var cat := Node3D.new()
	cat.position = Vector3(0, 0.13, 0)
	cat.rotation_degrees.y = 25.0
	home.add_child(cat)
	var fur := M.mat(Color(0.5, 0.52, 0.58), 0.85)
	var white := M.mat(Color(0.97, 0.96, 0.94), 0.85)
	var parts := []
	parts.append(M.add(cat, M.sphere(0.14, 12), fur, Vector3(0, 0.14, -0.03), Vector3.ZERO, Vector3(1.0, 1.15, 1.15)))
	parts.append(M.add(cat, M.sphere(0.085, 10), white, Vector3(0, 0.15, 0.085), Vector3.ZERO, Vector3(0.85, 1.15, 0.6)))
	for x in [-0.055, 0.055]:
		parts.append(M.add(cat, M.sphere(0.038, 8), white, Vector3(x, 0.03, 0.11), Vector3.ZERO, Vector3(1, 0.8, 1.3)))
	parts.append(M.add(cat, M.tube([Vector3(0.08, 0.04, -0.14), Vector3(0.2, 0.03, -0.08), Vector3(0.23, 0.04, 0.05), Vector3(0.15, 0.05, 0.15)], 0.028), fur))
	var head := Node3D.new()
	head.position = Vector3(0, 0.345, 0.04)
	cat.add_child(head)
	parts.append(M.add(head, M.sphere(0.11, 12), fur, Vector3.ZERO, Vector3.ZERO, Vector3(1.12, 0.95, 1.0)))
	for x in [-0.065, 0.065]:
		parts.append(M.add(head, M.cylinder(0.045, 0.085, 0.0, 10), fur, Vector3(x, 0.115, -0.005), Vector3(0, 0, -x * 220.0)))
		parts.append(M.add(head, M.cylinder(0.024, 0.05, 0.0, 8), M.mat(Color(0.98, 0.72, 0.76), 0.7), Vector3(x, 0.105, 0.012), Vector3(0, 0, -x * 220.0)))
		parts.append(M.add(head, M.sphere(0.022, 8), M.mat(Color(0.45, 0.75, 0.4), 0.2), Vector3(x * 0.72, 0.015, 0.093)))
		parts.append(M.add(head, M.sphere(0.012, 6), M.mat(Color(0.08, 0.08, 0.1), 0.2), Vector3(x * 0.72, 0.015, 0.11), Vector3.ZERO, Vector3(0.7, 1.3, 1)))
	parts.append(M.add(head, M.sphere(0.048, 8), white, Vector3(0, -0.03, 0.085), Vector3.ZERO, Vector3(1.25, 0.75, 0.8)))
	parts.append(M.add(head, M.sphere(0.014, 6), M.mat(Color(0.95, 0.55, 0.6), 0.4), Vector3(0, -0.012, 0.122)))
	for mi in parts:
		home._reg(mi)
	_sway.append({"node": head, "speed": 1.3, "phase": 0.0, "amp": 0.07})
	# Gamelle et petite balle
	home.lathe([Vector2(0.0, 0.0), Vector2(0.11, 0.0), Vector2(0.09, 0.06), Vector2(0.075, 0.06), Vector2(0.07, 0.025), Vector2(0.0, 0.025)], M.mat(C_BLUE, 0.3), Vector3(0.56, 0, -0.12))
	home.cyl(0.068, 0.02, M.mat(Color(0.6, 0.42, 0.28), 0.9), Vector3(0.56, 0.035, -0.12))
	home.ball(0.05, M.mat(C_MUSTARD, 0.5), Vector3(-0.5, 0.05, -0.2))


# --- Décor (sans action) -------------------------------------------------------------------

func _build_decor() -> void:
	var d := _deco()
	# Tableaux au-dessus du lit
	_framed(d, "tableau_paysage", Vector3(-4.0, 2.0, -3.985), Vector2(0.9, 0.66), 0.0)
	_framed(d, "tableau_abstrait", Vector3(-4.975, 1.9, 3.0), Vector2(0.6, 0.6), 90.0)
	# Horloge murale
	d.cyl(0.24, 0.05, _wood_dark, Vector3(-2.6, 2.25, -3.975), Vector3(90, 0, 0))
	d.cyl(0.21, 0.055, M.mat(C_CREAM, 0.5), Vector3(-2.6, 2.25, -3.972), Vector3(90, 0, 0))
	d.box(Vector3(0.02, 0.14, 0.012), M.mat(C_DARK, 0.5), Vector3(-2.6, 2.31, -3.94), 0.004)
	d.box(Vector3(0.1, 0.02, 0.012), M.mat(C_DARK, 0.5), Vector3(-2.56, 2.25, -3.94), 0.004)
	# Grande plante dans le coin
	_potted_plant(d, Vector3(-4.45, 0, 3.5), 1.05, C_CORAL)
	# Panier et petit pouf
	d.lathe([Vector2(0.0, 0.0), Vector2(0.3, 0.0), Vector2(0.36, 0.14), Vector2(0.34, 0.3), Vector2(0.22, 0.38), Vector2(0.0, 0.38)], M.tex_mat("tissu", C_MUSTARD, 4.0, _fabric_n, 0.95, 1.0), Vector3(-2.3, 0, 3.4))
	# Étagère murale au-dessus du lit avec quelques objets
	d.box(Vector3(0.9, 0.04, 0.2), _wood, Vector3(-4.0, 1.5, -3.9), 0.012)
	d.ball(0.09, M.mat(C_TEAL, 0.4), Vector3(-4.3, 1.6, -3.9))
	d.lathe([Vector2(0.0, 0.0), Vector2(0.05, 0.0), Vector2(0.07, 0.1), Vector2(0.03, 0.2), Vector2(0.04, 0.24), Vector2(0.0, 0.24)], M.mat(C_MUSTARD, 0.4), Vector3(-3.75, 1.52, -3.9))
	d.box(Vector3(0.14, 0.18, 0.02), _wood_light, Vector3(-4.02, 1.61, -3.92), 0.008, Vector3(-8, 0, 0))


func _framed(d: Furniture, texture: String, pos: Vector3, size: Vector2, yaw: float) -> void:
	var frame := Node3D.new()
	frame.position = pos
	frame.rotation_degrees.y = yaw
	d.add_child(frame)
	M.add(frame, M.rounded_box(Vector3(size.x + 0.1, size.y + 0.1, 0.05), 0.015), _wood_dark, Vector3(0, 0, 0.0))
	M.add(frame, M.rounded_box(Vector3(size.x + 0.02, size.y + 0.02, 0.03), 0.005), M.mat(C_WHITE, 0.8), Vector3(0, 0, 0.016))
	var pic := M.add(frame, M.quad(size - Vector2(0.06, 0.06)), M.uv_mat(texture, Color.WHITE, 0.8), Vector3(0, 0, 0.033))
	pic.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --- Déplacements --------------------------------------------------------------------------

## Chemin simple qui contourne les meubles en passant par des points de passage.
func compute_path(from: Vector3, to: Vector3, ignore = null) -> Array:
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	if _segment_clear(a, b, ignore):
		return [to]
	var best: Array = []
	var best_len := INF
	for w in WAYPOINTS:
		if _segment_clear(a, w, ignore) and _segment_clear(w, b, ignore):
			var length: float = a.distance_to(w) + w.distance_to(b)
			if length < best_len:
				best_len = length
				best = [Vector3(w.x, 0, w.y), to]
	if best.is_empty():
		for w1 in WAYPOINTS:
			for w2 in WAYPOINTS:
				if w1 != w2 and _segment_clear(a, w1, ignore) and _segment_clear(w1, w2, ignore) and _segment_clear(w2, b, ignore):
					var length: float = a.distance_to(w1) + w1.distance_to(w2) + w2.distance_to(b)
					if length < best_len:
						best_len = length
						best = [Vector3(w1.x, 0, w1.y), Vector3(w2.x, 0, w2.y), to]
	return best if not best.is_empty() else [to]


func _segment_clear(a: Vector2, b: Vector2, ignore) -> bool:
	var steps := maxi(int(a.distance_to(b) / 0.15), 1)
	for f in furniture:
		if f == ignore:
			continue
		var rect: Rect2 = f.footprint.grow(0.25)
		if rect.has_point(a) or rect.has_point(b):
			continue # on part de l'objet (ou on y va) : pas un obstacle
		for i in range(1, steps):
			var p := a.lerp(b, float(i) / steps)
			if rect.has_point(p):
				return false
	return true


func clamp_to_room(p: Vector3) -> Vector3:
	if _terrace and p.x > ROOM_MAX.x - 0.4 and p.z > TERRACE_MIN.y and p.z < TERRACE_MAX.y:
		return Vector3(minf(p.x, TERRACE_MAX.x - 0.35), 0, clampf(p.z, TERRACE_MIN.y + 0.35, TERRACE_MAX.y - 0.35))
	return Vector3(clampf(p.x, ROOM_MIN.x + 0.4, ROOM_MAX.x - 0.4), 0, clampf(p.z, ROOM_MIN.y + 0.4, ROOM_MAX.y - 0.4))


## Objet ou sol sous la souris : {"furniture": f} ou {"floor": position} ou {}.
func pick(screen_pos: Vector2) -> Dictionary:
	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * 100.0
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	if hit.is_empty():
		return {}
	if hit.collider is Furniture:
		return {"furniture": hit.collider}
	if hit.collider.is_in_group("floor"):
		return {"floor": hit.position}
	return {}


# --- Caméra ------------------------------------------------------------------------------------

## Rapproche la caméra d'un point pendant une activité. Le point est cadré dans
## la moitié haute de l'écran, au-dessus du panneau de frappe.
func focus_on(point: Vector3, lift := 0.85) -> void:
	_cam_focus = point
	_cam_lift = lift


func unfocus() -> void:
	_cam_focus = null


func _move_camera(delta: float) -> void:
	var want_pos := CAM_HOME
	var want_look := CAM_LOOK
	if _cam_focus != null:
		var dir := (CAM_HOME - CAM_LOOK).normalized()
		var up := dir.cross(Vector3.UP).cross(dir).normalized()
		var focus: Vector3 = _cam_focus
		want_look = focus + Vector3(0, 0.9, 0) - up * _cam_lift
		want_pos = want_look + dir * CAM_FOCUS_DISTANCE
	if _cam_pos.distance_to(want_pos) < 0.002 and _cam_look.distance_to(want_look) < 0.002:
		return
	var k := 1.0 - exp(-delta * 3.2)
	_cam_pos = _cam_pos.lerp(want_pos, k)
	_cam_look = _cam_look.lerp(want_look, k)
	camera.position = _cam_pos
	camera.look_at(_cam_look, Vector3.UP)


# --- Effets des activités ---------------------------------------------------------------------

## Lance les effets visuels d'une action sur un objet (eau, vapeur, invités, Zzz…).
func start_activity(f: Furniture, action_id: String) -> void:
	stop_activity()
	var fx_point: Vector3 = f.position + f.get_meta("fx_point", Vector3(0, f.height, 0))
	match action_id:
		"dormir":
			var head: Vector3 = f.pose_point + Vector3(0.1, 0.45, -0.75)
			for i in 3:
				var z := Label3D.new()
				z.text = "Z"
				z.font = load("res://fonts/Lexend.ttf")
				z.font_size = 96 + i * 24
				z.pixel_size = 0.0028
				z.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				z.modulate = Color(0.75, 0.82, 1.0)
				z.outline_modulate = Color(0.2, 0.25, 0.5)
				z.outline_size = 14
				z.no_depth_test = true
				add_child(z)
				_fx.append(z)
				var tween := z.create_tween().set_loops()
				tween.tween_property(z, "position", head + Vector3(0.45, 1.0, 0.0), 2.7).from(head)
				tween.parallel().tween_property(z, "modulate:a", 0.0, 2.7).from(1.0)
				tween.custom_step(i * 0.9)
		"cuisiner", "manger":
			if action_id == "cuisiner":
				_fx.append(_particles(fx_point, Color(1, 1, 1, 0.5), 14, 1.6, Vector3.UP, 12.0, 0.35, Vector3(0, 0.1, 0), 0.05))
		"dents":
			_fx.append(_particles(fx_point + Vector3(0, 0.12, -0.08), Color(0.6, 0.82, 1.0, 0.85), 24, 0.35, Vector3.DOWN, 3.0, 0.7, Vector3(0, -4.0, 0), 0.018))
		"douche":
			_fx.append(_particles(fx_point, Color(0.62, 0.84, 1.0, 0.8), 90, 0.75, Vector3.DOWN, 13.0, 1.6, Vector3(0, -6.0, 0), 0.02))
			_fx.append(_particles(f.position + Vector3(0, 0.5, 0), Color(1, 1, 1, 0.3), 12, 2.2, Vector3.UP, 30.0, 0.3, Vector3(0, 0.15, 0), 0.09))
		"sport":
			_belt_on = true
		"bois":
			_fx.append(_particles(fx_point, Color(0.86, 0.68, 0.45), 16, 0.7, Vector3.UP, 50.0, 1.3, Vector3(0, -5.0, 0), 0.018))
		"peindre":
			_fx.append(_particles(f.position + Vector3(0.1, 1.25, 0), Color(1.0, 0.85, 0.4, 0.9), 5, 1.2, Vector3.UP, 60.0, 0.25, Vector3(0, 0.2, 0), 0.02, true))
		"miroir", "appeler":
			_fx.append(_particles(f.use_point + Vector3(0, 1.85, 0), Color(1.0, 0.6, 0.72, 0.9), 4, 1.5, Vector3.UP, 35.0, 0.3, Vector3(0, 0.25, 0), 0.03, true))
		"inviter":
			# Un ami assis sur le canapé, deux amis debout en face (on voit leur visage).
			var seats: Array = f.get_meta("guest_points", [])
			_add_guest(seats[0] if not seats.is_empty() else f.use_point, "assis", "sit_chat", Vector3(0.4, 0, 0.0))
			_add_guest(f.position + Vector3(0.95, 0, -1.75), "debout", "talk", f.position)
			_add_guest(f.position + Vector3(-0.75, 0, -1.9), "debout", "wave", f.position)
			_fx.append(_particles(f.position + Vector3(0, 1.75, 0), Color(1.0, 0.6, 0.72, 0.9), 6, 1.5, Vector3.UP, 50.0, 0.3, Vector3(0, 0.25, 0), 0.03, true))
		"jeu": # un ami vient jouer, assis en face
			_add_guest(f.get_meta("guest_seat", f.use_point), "assis", "sit_play", f.position)
			_fx.append(_particles(f.position + Vector3(0, 1.7, 0), Color(1.0, 0.82, 0.35, 0.9), 4, 1.5, Vector3.UP, 45.0, 0.3, Vector3(0, 0.25, 0), 0.03, true))
		"musique": # la guitare quitte son pied ; des notes s'envolent
			var on_stand = f.get_meta("guitar", null)
			if on_stand != null:
				on_stand.visible = false
				_hidden.append(on_stand)
			_fx.append(_particles(f.use_point + Vector3(0.25, 1.75, 0), Color(1.0, 0.82, 0.35, 0.95), 4, 1.6, Vector3.UP, 40.0, 0.4, Vector3(0, 0.3, 0), 0.035, true))
			_fx.append(_particles(f.use_point + Vector3(-0.25, 1.65, 0), Color(0.5, 0.75, 1.0, 0.95), 3, 1.9, Vector3.UP, 40.0, 0.35, Vector3(0, 0.3, 0), 0.03, true))
		"jardiner": # l'arrosoir est dans la main ; l'eau coule
			var can = f.get_meta("can", null)
			if can != null:
				can.visible = false
				_hidden.append(can)
			_fx.append(_particles(fx_point, Color(0.6, 0.84, 1.0, 0.85), 26, 0.5, Vector3(0.5, -1, 0), 10.0, 1.2, Vector3(0, -5.0, 0), 0.018))
		"animal": # le chat est content
			_fx.append(_particles(f.position + Vector3(0, 0.95, 0), Color(1.0, 0.55, 0.68, 0.95), 4, 1.5, Vector3.UP, 30.0, 0.3, Vector3(0, 0.25, 0), 0.035, true))


## Un ami arrive pour l'activité (il repart à la fin).
func _add_guest(point: Vector3, pose: String, anim: String, look: Vector3) -> void:
	var Character = load("res://scripts/world/character.gd")
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var guest: Node3D = Character.new()
	add_child(guest)
	guest.build(Data.random_appearance(rng))
	guest.position = point
	guest.start_acting(pose, point, look, anim)
	guest.scale = Vector3.ONE * 0.01
	guest.create_tween().tween_property(guest, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_fx.append(guest)


func stop_activity() -> void:
	for node in _fx:
		if is_instance_valid(node):
			node.queue_free()
	_fx.clear()
	for node in _hidden:
		if is_instance_valid(node):
			node.visible = true
	_hidden.clear()
	_belt_on = false


## Petite pluie de confettis (niveau gagné, série terminée, objectif atteint).
func burst(pos: Vector3) -> void:
	var colors := [C_CORAL, C_MUSTARD, C_TEAL, Color(0.6, 0.48, 0.86), Color(0.36, 0.56, 0.86)]
	for color in colors:
		var c: Color = color
		var p := _particles(pos + Vector3(0, 1.7, 0), c, 14, 1.5, Vector3.UP, 65.0, 3.2, Vector3(0, -6.5, 0), 0.03, true)
		p.one_shot = true
		p.explosiveness = 0.95
		p.restart()
		get_tree().create_timer(2.5).timeout.connect(p.queue_free)


func _particles(pos: Vector3, color: Color, amount: int, lifetime: float, dir: Vector3, spread: float, speed: float, gravity: Vector3, size: float, glow := false) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = amount
	p.lifetime = lifetime
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = speed * 0.7
	p.initial_velocity_max = speed
	p.gravity = gravity
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.6))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 0.0))
	p.scale_amount_curve = curve
	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	p.mesh = mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p
