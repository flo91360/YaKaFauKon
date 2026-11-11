extends Node3D
## Le studio en 3D : pièce, lumière, caméra et objets.
## Formes simples faites dans Godot (aucun modèle externe).

const Furniture = preload("res://scripts/world/furniture.gd")

const ROOM_MIN := Vector2(-5.0, -4.0) # (x, z)
const ROOM_MAX := Vector2(5.0, 4.0)
const WAYPOINTS := [Vector2(0.4, -0.6), Vector2(-2.6, -1.2), Vector2(2.6, -1.4), Vector2(-2.4, 1.6), Vector2(2.6, 1.8), Vector2(0.4, 1.6)]

var furniture: Array = []
var camera: Camera3D
var floor_body: StaticBody3D


func _ready() -> void:
	_build_environment()
	_build_room()
	_build_furniture()


# --- Lumière et caméra -------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.72, 0.84, 0.93)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.96, 0.9)
	env.ambient_light_energy = 0.22
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 0.5
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 30.0
	add_child(sun)

	var lamp := OmniLight3D.new() # lumière chaude au plafond
	lamp.position = Vector3(0, 3.2, 0)
	lamp.light_color = Color(1.0, 0.85, 0.65)
	lamp.light_energy = 0.15
	lamp.omni_range = 9.0
	add_child(lamp)

	camera = Camera3D.new()
	camera.fov = 38.0
	add_child(camera)
	camera.position = Vector3(7.6, 9.2, 10.2)
	camera.look_at(Vector3(-0.2, 0.2, -0.2), Vector3.UP)
	camera.current = true


# --- Pièce ---------------------------------------------------------------------------

func _build_room() -> void:
	var deco := Furniture.new() # simple support pour les éléments de décor
	add_child(deco)
	# Herbe autour
	deco.add_box(Vector3(40, 0.1, 40), Color(0.6, 0.78, 0.5), Vector3(0, -0.26, 0))
	# Sol en bois clair (cliquable)
	floor_body = StaticBody3D.new()
	floor_body.add_to_group("floor")
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(10, 0.2, 8)
	var floor_col := CollisionShape3D.new()
	floor_col.shape = floor_shape
	floor_col.position = Vector3(0, -0.1, 0)
	floor_body.add_child(floor_col)
	add_child(floor_body)
	deco.add_box(Vector3(10, 0.2, 8), Color(0.87, 0.74, 0.58), Vector3(0, -0.1, 0))
	for i in range(1, 10): # lames de parquet
		deco.add_box(Vector3(0.015, 0.005, 8), Color(0.8, 0.66, 0.5), Vector3(-5 + i, 0.002, 0))
	# Carrelage de la salle de bain
	deco.add_box(Vector3(4.6, 0.02, 2.0), Color(0.62, 0.8, 0.9), Vector3(2.7, 0.01, -3.0))
	# Tapis rond
	deco.add_cylinder(1.5, 0.03, Color(0.95, 0.78, 0.7), Vector3(0.4, 0.015, 1.4))
	deco.add_cylinder(1.1, 0.035, Color(0.98, 0.88, 0.8), Vector3(0.4, 0.016, 1.4))
	# Murs (fond et gauche), arrondis en haut
	var wall := Color(0.97, 0.93, 0.86)
	var wall2 := Color(0.94, 0.89, 0.82)
	deco.add_box(Vector3(10.3, 2.8, 0.3), wall, Vector3(0.15 - 0.15, 1.4, -4.15))
	deco.add_cylinder(0.15, 10.3, wall, Vector3(0, 2.8, -4.15), Vector3(0, 0, 90))
	deco.add_box(Vector3(0.3, 2.8, 8.0), wall2, Vector3(-5.15, 1.4, 0))
	deco.add_cylinder(0.15, 8.0, wall2, Vector3(-5.15, 2.8, 0), Vector3(90, 0, 0))
	# Plinthes
	deco.add_box(Vector3(10, 0.12, 0.05), Color(0.8, 0.72, 0.62), Vector3(0, 0.06, -3.98))
	deco.add_box(Vector3(0.05, 0.12, 8), Color(0.8, 0.72, 0.62), Vector3(-4.98, 0.06, 0))
	# Fenêtre sur le mur de gauche
	deco.add_box(Vector3(0.06, 1.3, 1.9), Color(0.98, 0.98, 1.0), Vector3(-4.98, 1.6, -0.6))
	deco.add_box(Vector3(0.08, 1.1, 1.7), Color(0.65, 0.85, 0.97), Vector3(-4.96, 1.6, -0.6))
	deco.add_box(Vector3(0.1, 1.1, 0.06), Color(0.98, 0.98, 1.0), Vector3(-4.95, 1.6, -0.6))
	# Cadre au mur du fond
	deco.add_box(Vector3(1.0, 0.7, 0.05), Color(0.55, 0.42, 0.32), Vector3(-1.4, 1.9, -3.98))
	deco.add_box(Vector3(0.85, 0.55, 0.06), Color(0.98, 0.8, 0.55), Vector3(-1.4, 1.9, -3.97))
	deco.add_sphere(0.12, Color(0.95, 0.55, 0.45), Vector3(-1.3, 1.95, -3.93))
	# Plante
	deco.add_cylinder(0.22, 0.4, Color(0.85, 0.55, 0.42), Vector3(-4.5, 0.2, 3.5))
	deco.add_sphere(0.4, Color(0.42, 0.7, 0.45), Vector3(-4.5, 0.75, 3.5), Vector3(1, 1.2, 1))
	deco.add_sphere(0.28, Color(0.5, 0.78, 0.5), Vector3(-4.35, 1.05, 3.4))


# --- Objets --------------------------------------------------------------------------

func _add_object(id: String, label: String, actions: Array, pos: Vector3, size: Vector3, use: Vector3) -> Furniture:
	var f := Furniture.new()
	f.setup(id, label, actions, pos, size)
	f.use_point = use
	f.face_point = pos
	add_child(f)
	furniture.append(f)
	return f


func _build_furniture() -> void:
	var wood := Color(0.72, 0.55, 0.4)
	var white := Color(0.97, 0.97, 0.98)

	# Lit
	var bed := _add_object("lit", "Lit", ["dormir"], Vector3(-4.0, 0, -2.7), Vector3(1.6, 0.7, 2.4), Vector3(-2.75, 0, -2.2))
	bed.add_soft_box(Vector3(1.6, 0.35, 2.4), wood, Vector3(0, 0.25, 0), 0.08)
	bed.add_soft_box(Vector3(1.5, 0.22, 2.25), Color(0.98, 0.97, 0.95), Vector3(0, 0.52, 0.03), 0.1)
	bed.add_soft_box(Vector3(1.52, 0.1, 1.4), Color(0.6, 0.72, 0.92), Vector3(0, 0.66, 0.38), 0.05)
	bed.add_capsule(0.14, 1.1, white, Vector3(0, 0.72, -0.88), Vector3(0, 0, 90))
	bed.add_soft_box(Vector3(1.6, 0.9, 0.12), wood.darkened(0.1), Vector3(0, 0.45, -1.18), 0.06)
	bed.pose = "allonge"
	bed.pose_point = Vector3(-4.0, 0.62, -1.75)
	bed.face_point = Vector3(-4.0, 0, -5.0)

	# Cuisine (plan de travail + frigo)
	var kitchen := _add_object("cuisine", "Cuisine", ["manger", "cuisiner"], Vector3(-1.3, 0, -3.6), Vector3(2.4, 1.0, 0.8), Vector3(-1.3, 0, -2.7))
	kitchen.add_soft_box(Vector3(1.6, 0.9, 0.75), Color(0.65, 0.8, 0.72), Vector3(0.4, 0.45, 0), 0.06)
	kitchen.add_soft_box(Vector3(1.66, 0.08, 0.8), Color(0.95, 0.93, 0.88), Vector3(0.4, 0.93, 0), 0.03)
	kitchen.add_cylinder(0.14, 0.03, Color(0.3, 0.3, 0.32), Vector3(0.65, 0.98, 0))
	kitchen.add_cylinder(0.14, 0.03, Color(0.3, 0.3, 0.32), Vector3(0.95, 0.98, 0))
	kitchen.add_cylinder(0.16, 0.14, Color(0.9, 0.45, 0.4), Vector3(0.1, 1.04, 0.05))
	kitchen.add_soft_box(Vector3(0.75, 1.9, 0.75), white, Vector3(-0.8, 0.95, 0), 0.1)
	kitchen.add_box(Vector3(0.05, 0.5, 0.05), Color(0.6, 0.6, 0.65), Vector3(-0.5, 1.3, 0.39))
	kitchen.add_box(Vector3(0.72, 0.02, 0.02), Color(0.85, 0.85, 0.88), Vector3(-0.8, 1.25, 0.38))

	# Lavabo
	var sink := _add_object("lavabo", "Lavabo", ["dents"], Vector3(0.8, 0, -3.75), Vector3(0.8, 1.0, 0.5), Vector3(0.8, 0, -3.0))
	sink.add_cylinder(0.12, 0.8, white, Vector3(0, 0.4, 0))
	sink.add_sphere(0.36, white, Vector3(0, 0.85, 0.02), Vector3(1, 0.35, 0.8))
	sink.add_box(Vector3(0.6, 0.8, 0.04), Color(0.8, 0.92, 0.98), Vector3(0, 1.65, -0.2))
	sink.add_cylinder(0.025, 0.2, Color(0.7, 0.7, 0.75), Vector3(0, 1.0, -0.15))

	# Toilettes
	var wc := _add_object("toilettes", "Toilettes", ["toilettes"], Vector3(2.2, 0, -3.6), Vector3(0.6, 0.9, 0.8), Vector3(2.2, 0, -2.75))
	wc.add_cylinder(0.2, 0.4, white, Vector3(0, 0.2, 0.08))
	wc.add_sphere(0.27, white, Vector3(0, 0.42, 0.1), Vector3(1, 0.25, 1.2))
	wc.add_soft_box(Vector3(0.5, 0.5, 0.2), white, Vector3(0, 0.65, -0.28), 0.06)
	wc.add_sphere(0.26, Color(0.75, 0.88, 0.95), Vector3(0, 0.48, 0.1), Vector3(1, 0.1, 1.2))

	# Douche
	var shower := _add_object("douche", "Douche", ["douche"], Vector3(3.95, 0, -3.35), Vector3(1.2, 2.2, 1.2), Vector3(3.95, 0, -3.3))
	shower.add_soft_box(Vector3(1.2, 0.12, 1.2), white, Vector3(0, 0.06, 0), 0.05)
	shower.add_cylinder(0.03, 2.1, Color(0.7, 0.7, 0.75), Vector3(0.5, 1.05, -0.5))
	shower.add_sphere(0.15, Color(0.7, 0.7, 0.75), Vector3(0.35, 2.05, -0.35), Vector3(1, 0.3, 1))
	var glass := shower.add_box(Vector3(0.03, 1.9, 1.2), Color(0.75, 0.9, 1.0), Vector3(-0.6, 1.07, 0))
	var glass_mat: StandardMaterial3D = glass.mesh.material
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.albedo_color.a = 0.35
	shower.pose_point = Vector3(3.95, 0.12, -3.3)
	shower.face_point = Vector3(5.0, 0, -3.3)

	# Bureau (ordinateur, téléphone, planning)
	var desk := _add_object("bureau", "Bureau", ["travail", "planning", "appeler"], Vector3(-4.45, 0, 0.9), Vector3(0.9, 1.3, 1.6), Vector3(-3.55, 0, 0.9))
	desk.add_soft_box(Vector3(0.9, 0.08, 1.6), wood, Vector3(0, 0.76, 0), 0.03)
	for z in [-0.7, 0.7]:
		desk.add_cylinder(0.04, 0.74, wood.darkened(0.2), Vector3(-0.35, 0.37, z))
		desk.add_cylinder(0.04, 0.74, wood.darkened(0.2), Vector3(0.35, 0.37, z))
	desk.add_soft_box(Vector3(0.06, 0.45, 0.75), Color(0.25, 0.27, 0.33), Vector3(-0.25, 1.1, 0), 0.03)
	desk.add_box(Vector3(0.02, 0.38, 0.67), Color(0.55, 0.78, 0.98), Vector3(-0.21, 1.1, 0))
	desk.add_cylinder(0.05, 0.15, Color(0.25, 0.27, 0.33), Vector3(-0.25, 0.86, 0))
	desk.add_soft_box(Vector3(0.18, 0.04, 0.5), Color(0.9, 0.9, 0.92), Vector3(0.1, 0.82, 0), 0.015)
	desk.add_soft_box(Vector3(0.16, 0.06, 0.1), Color(0.95, 0.5, 0.45), Vector3(0.1, 0.83, 0.6), 0.02)
	desk.add_soft_box(Vector3(0.28, 0.02, 0.2), Color(1.0, 0.95, 0.6), Vector3(0.1, 0.81, -0.55), 0.01)
	# Chaise
	desk.add_soft_box(Vector3(0.5, 0.08, 0.5), Color(0.95, 0.75, 0.45), Vector3(0.65, 0.48, 0), 0.03)
	desk.add_cylinder(0.05, 0.46, Color(0.4, 0.4, 0.45), Vector3(0.65, 0.23, 0))
	desk.add_soft_box(Vector3(0.08, 0.5, 0.5), Color(0.95, 0.75, 0.45), Vector3(0.9, 0.78, 0), 0.03)
	desk.pose = "assis"
	desk.pose_point = Vector3(-3.8, 0.5, 0.9)
	desk.face_point = Vector3(-5.0, 0, 0.9)

	# Miroir
	var mirror := _add_object("miroir", "Miroir", ["miroir"], Vector3(-4.85, 0, 2.7), Vector3(0.25, 1.9, 0.9), Vector3(-3.95, 0, 2.7))
	mirror.add_soft_box(Vector3(0.1, 1.8, 0.8), Color(0.85, 0.65, 0.5), Vector3(0, 0.95, 0), 0.05)
	mirror.add_box(Vector3(0.02, 1.6, 0.65), Color(0.85, 0.93, 0.98), Vector3(0.05, 0.95, 0))

	# Canapé
	var sofa := _add_object("canape", "Canapé", ["inviter"], Vector3(0.4, 0, 3.3), Vector3(2.3, 0.9, 0.9), Vector3(0.4, 0, 2.45))
	var sofa_col := Color(0.55, 0.65, 0.88)
	sofa.add_soft_box(Vector3(2.3, 0.4, 0.9), sofa_col, Vector3(0, 0.25, 0), 0.12)
	sofa.add_soft_box(Vector3(2.3, 0.55, 0.25), sofa_col.darkened(0.08), Vector3(0, 0.6, 0.33), 0.12)
	for x in [-1.05, 1.05]:
		sofa.add_soft_box(Vector3(0.22, 0.6, 0.9), sofa_col.darkened(0.08), Vector3(x, 0.35, 0), 0.1)
	sofa.add_soft_box(Vector3(0.45, 0.35, 0.12), Color(1.0, 0.8, 0.5), Vector3(-0.6, 0.6, 0.18), 0.06)
	sofa.pose = "assis"
	sofa.pose_point = Vector3(0.4, 0.42, 3.1)
	sofa.face_point = Vector3(0.4, 0, 0.0)

	# Tapis de course
	var tread := _add_object("tapis", "Tapis de course", ["sport"], Vector3(4.1, 0, 0.6), Vector3(0.9, 1.3, 1.9), Vector3(4.1, 0, 0.75))
	tread.add_soft_box(Vector3(0.85, 0.15, 1.8), Color(0.3, 0.32, 0.38), Vector3(0, 0.08, 0.1), 0.06)
	tread.add_box(Vector3(0.7, 0.02, 1.6), Color(0.15, 0.16, 0.18), Vector3(0, 0.16, 0.1))
	for x in [-0.4, 0.4]:
		tread.add_cylinder(0.035, 1.1, Color(0.75, 0.75, 0.8), Vector3(x, 0.65, -0.75))
	tread.add_soft_box(Vector3(0.85, 0.1, 0.25), Color(0.4, 0.75, 0.6), Vector3(0, 1.2, -0.75), 0.04)
	tread.pose = "course"
	tread.pose_point = Vector3(4.1, 0.17, 0.75)
	tread.face_point = Vector3(4.1, 0, -2.0)

	# Chevalet de peinture
	var easel := _add_object("chevalet", "Chevalet", ["peindre"], Vector3(2.4, 0, 3.45), Vector3(0.8, 1.7, 0.5), Vector3(2.4, 0, 2.7))
	easel.add_cylinder(0.03, 1.6, wood, Vector3(-0.25, 0.8, 0.05), Vector3(-8, 0, 8))
	easel.add_cylinder(0.03, 1.6, wood, Vector3(0.25, 0.8, 0.05), Vector3(-8, 0, -8))
	easel.add_cylinder(0.03, 1.5, wood, Vector3(0, 0.75, 0.25), Vector3(15, 0, 0))
	easel.add_box(Vector3(0.7, 0.55, 0.04), Color(1, 1, 0.98), Vector3(0, 1.15, -0.02), Vector3(-8, 0, 0))
	easel.add_sphere(0.1, Color(0.95, 0.5, 0.4), Vector3(-0.12, 1.2, -0.06), Vector3(1, 1, 0.2))
	easel.add_sphere(0.08, Color(0.4, 0.65, 0.95), Vector3(0.12, 1.1, -0.06), Vector3(1, 1, 0.2))

	# Établi
	var bench := _add_object("etabli", "Établi", ["bois"], Vector3(4.3, 0, 3.35), Vector3(1.3, 1.0, 0.7), Vector3(4.3, 0, 2.55))
	bench.add_soft_box(Vector3(1.3, 0.1, 0.7), wood.lightened(0.1), Vector3(0, 0.85, 0), 0.03)
	for x in [-0.55, 0.55]:
		bench.add_box(Vector3(0.08, 0.8, 0.6), wood.darkened(0.2), Vector3(x, 0.4, 0))
	bench.add_box(Vector3(1.1, 0.06, 0.55), wood.darkened(0.1), Vector3(0, 0.25, 0))
	bench.add_box(Vector3(0.5, 0.06, 0.15), Color(0.9, 0.75, 0.5), Vector3(-0.2, 0.93, 0))
	bench.add_cylinder(0.03, 0.3, Color(0.5, 0.35, 0.25), Vector3(0.35, 0.92, 0.1), Vector3(0, 0, 90))
	bench.add_box(Vector3(0.1, 0.08, 0.06), Color(0.55, 0.57, 0.62), Vector3(0.52, 0.92, 0.1))


# --- Déplacements --------------------------------------------------------------------

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
