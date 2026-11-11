extends StaticBody3D
## Un objet du studio : il propose une ou plusieurs actions.
## Le personnage se place à `use_point`, regarde `face_point`,
## et peut prendre une pose (debout, assis, allongé) à `pose_point`.

var object_id := ""
var display_name := ""
var actions: Array = []
var use_point := Vector3.ZERO
var face_point := Vector3.ZERO
var pose := "debout" # debout / assis / allonge / course
var pose_point = null # Vector3 ou null
var footprint := Rect2() # emprise au sol (x, z) pour éviter de traverser l'objet

var _label: Label3D


func setup(id: String, p_name: String, p_actions: Array, pos: Vector3, size: Vector3) -> void:
	object_id = id
	display_name = p_name
	actions = p_actions
	position = pos
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
	_label.outline_size = 18
	_label.pixel_size = 0.004
	_label.modulate = Color(1, 1, 1)
	_label.outline_modulate = Color(0.2, 0.25, 0.4)
	_label.position = Vector3(0, size.y + 0.45, 0)
	_label.visible = false
	add_child(_label)


func set_highlight(on: bool) -> void:
	_label.visible = on


# --- Petites briques visuelles arrondies -------------------------------------------

static func material(color: Color, rough := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


func add_box(size: Vector3, color: Color, offset: Vector3, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add_mesh(mesh, color, offset, rot_deg)


## Boîte aux bords arrondis : une boîte un peu plus fine + des cylindres sur les arêtes.
func add_soft_box(size: Vector3, color: Color, offset: Vector3, radius := 0.08) -> void:
	var r := minf(radius, minf(size.x, minf(size.y, size.z)) * 0.45)
	add_box(Vector3(size.x, size.y - 2.0 * r, size.z), color, offset)
	add_box(Vector3(size.x - 2.0 * r, r * 2.0, size.z - 2.0 * r), color, offset + Vector3(0, size.y / 2.0 - r, 0))
	add_box(Vector3(size.x - 2.0 * r, r * 2.0, size.z - 2.0 * r), color, offset - Vector3(0, size.y / 2.0 - r, 0))
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			add_cylinder(r, size.z - 2.0 * r, color, offset + Vector3(sx * (size.x / 2.0 - r), sy * (size.y / 2.0 - r), 0), Vector3(90, 0, 0))
	for sz in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			add_cylinder(r, size.x - 2.0 * r, color, offset + Vector3(0, sy * (size.y / 2.0 - r), sz * (size.z / 2.0 - r)), Vector3(0, 0, 90))


func add_cylinder(radius: float, height: float, color: Color, offset: Vector3, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	return _add_mesh(mesh, color, offset, rot_deg)


func add_sphere(radius: float, color: Color, offset: Vector3, scale_v := Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var mi := _add_mesh(mesh, color, offset, Vector3.ZERO)
	mi.scale = scale_v
	return mi


func add_capsule(radius: float, height: float, color: Color, offset: Vector3, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	return _add_mesh(mesh, color, offset, rot_deg)


func _add_mesh(mesh: PrimitiveMesh, color: Color, offset: Vector3, rot_deg: Vector3) -> MeshInstance3D:
	mesh.material = material(color)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = offset
	mi.rotation_degrees = rot_deg
	add_child(mi)
	return mi
