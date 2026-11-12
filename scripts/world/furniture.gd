extends StaticBody3D
## Un objet du studio : il propose une ou plusieurs actions.
## Le personnage se place à `use_point`, regarde `face_point`,
## et peut s'installer à `pose_point` (lit, chaise, canapé…).
## Sans appel à setup(), ce nœud sert de simple support pour le décor.

const M = preload("res://scripts/world/meshes.gd")

var object_id := ""
var display_name := ""
var actions: Array = []
var use_point := Vector3.ZERO
var face_point := Vector3.ZERO
var pose := "debout" # debout / assis / allonge / course
var pose_point = null # Vector3 ou null
var footprint := Rect2() # emprise au sol (x, z) pour éviter de traverser l'objet
var height := 1.0

var _label: Label3D
var _marker: Node3D
var _visuals: Array = []
var _overlay: StandardMaterial3D
var _highlight := false
var _time := 0.0


func setup(id: String, p_name: String, p_actions: Array, pos: Vector3, size: Vector3) -> void:
	object_id = id
	display_name = p_name
	actions = p_actions
	position = pos
	height = size.y
	footprint = Rect2(pos.x - size.x / 2.0, pos.z - size.z / 2.0, size.x, size.z)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0, size.y / 2.0, 0)
	add_child(collision)
	_label = Label3D.new()
	_label.text = display_name
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font = load("res://fonts/Lexend.ttf")
	_label.font_size = 64
	_label.outline_size = 20
	_label.pixel_size = 0.0042
	_label.modulate = Color(1, 1, 1)
	_label.outline_modulate = Color(0.16, 0.2, 0.36)
	_label.position = Vector3(0, size.y + 0.5, 0)
	_label.visible = false
	_label.render_priority = 5
	add_child(_label)
	set_process(false)


# --- Mise en évidence (survol de la souris, tutoriel) ---------------------------------------

func set_highlight(on: bool) -> void:
	if _label == null or on == _highlight:
		return
	_highlight = on
	_label.visible = on or (_marker != null and _marker.visible)
	if on and _overlay == null:
		_overlay = StandardMaterial3D.new()
		_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_overlay.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_overlay.albedo_color = Color(1.0, 0.9, 0.55, 0.16)
		_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for v in _visuals:
		if is_instance_valid(v):
			v.material_overlay = _overlay if on else null
	_update_processing()


## Flèche qui rebondit au-dessus de l'objet (tutoriel, objectif en cours).
func set_marker(on: bool) -> void:
	if _label == null:
		return
	if on and _marker == null:
		_marker = Node3D.new()
		add_child(_marker)
		var gold := M.glowing(Color(1.0, 0.78, 0.25), 0.6)
		var cone := M.add(_marker, M.cylinder(0.0, 0.34, 0.17, 20), gold, Vector3(0, 0.0, 0))
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var stem := M.add(_marker, M.cylinder(0.07, 0.26, 0.07, 16), gold, Vector3(0, 0.3, 0))
		stem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _marker != null:
		_marker.visible = on
	_label.visible = on or _highlight
	_update_processing()


## Points (en 3D) de la flèche dorée et du nom, pour que l'interface ne les cache pas.
func marker_points() -> Array:
	if _marker == null or not _marker.visible:
		return []
	return [to_global(Vector3(0, height + 0.3, 0)), to_global(Vector3(0, height + 1.35, 0))]


func _update_processing() -> void:
	set_process(_highlight or (_marker != null and _marker.visible))


func _process(delta: float) -> void:
	_time += delta
	if _highlight and _overlay != null:
		_overlay.albedo_color.a = 0.13 + 0.07 * sin(_time * 5.0)
	if _marker != null and _marker.visible:
		_marker.position = Vector3(0, height + 0.95 + 0.12 * absf(sin(_time * 3.5)), 0)
		_marker.rotation.y = _time * 1.5


# --- Briques visuelles ------------------------------------------------------------------------
# `material` : un matériau (voir meshes.gd) ou simplement une couleur.

func _reg(mi: MeshInstance3D) -> MeshInstance3D:
	_visuals.append(mi)
	return mi


## Boîte aux bords arrondis.
func box(size: Vector3, material, pos: Vector3, radius := 0.03, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	return _reg(M.add(self, M.rounded_box(size, radius), material, pos, rot_deg))


func cyl(radius: float, h: float, material, pos: Vector3, rot_deg := Vector3.ZERO, top_radius := -1.0) -> MeshInstance3D:
	return _reg(M.add(self, M.cylinder(radius, h, top_radius), material, pos, rot_deg))


func ball(radius: float, material, pos: Vector3, scale_v := Vector3.ONE) -> MeshInstance3D:
	return _reg(M.add(self, M.sphere(radius), material, pos, Vector3.ZERO, scale_v))


func cap(radius: float, h: float, material, pos: Vector3, rot_deg := Vector3.ZERO, scale_v := Vector3.ONE) -> MeshInstance3D:
	return _reg(M.add(self, M.capsule(radius, h), material, pos, rot_deg, scale_v))


func lathe(profile: Array, material, pos: Vector3, rot_deg := Vector3.ZERO, scale_v := Vector3.ONE) -> MeshInstance3D:
	return _reg(M.add(self, M.lathe(profile), material, pos, rot_deg, scale_v))


func tube(path: Array, radius: float, material, pos := Vector3.ZERO, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	return _reg(M.add(self, M.tube(path, radius), material, pos, rot_deg))


func ring(ring_radius: float, thickness: float, material, pos: Vector3, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	return _reg(M.add(self, M.torus(ring_radius, thickness), material, pos, rot_deg))


## Rectangle plat (image, écran…). Par défaut il regarde vers +Z.
func flat(size: Vector2, material, pos: Vector3, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mi := _reg(M.add(self, M.quad(size), material, pos, rot_deg))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
