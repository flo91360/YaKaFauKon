extends Node3D
## Le personnage de l'enfant : apparence, marche, poses et petites animations.

signal arrived

const Data = preload("res://scripts/core/data.gd")
const WALK_SPEED := 2.2 # mètres par seconde

var state := "idle" # idle / walk / act
var pose := "debout"
var _path: Array = []
var _time := 0.0
var _model: Node3D
var _body: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _head: Node3D


func build(appearance: Dictionary) -> void:
	for child in get_children():
		child.queue_free()
	var skin: Color = Data.SKIN_COLORS[clampi(appearance.get("skin", 0), 0, Data.SKIN_COLORS.size() - 1)]
	var hair: Color = Data.HAIR_COLORS[clampi(appearance.get("hair", 0), 0, Data.HAIR_COLORS.size() - 1)]
	var outfit: Color = Data.OUTFIT_COLORS[clampi(appearance.get("outfit", 0), 0, Data.OUTFIT_COLORS.size() - 1)]
	var style: int = appearance.get("hair_style", 0)
	var pants := Color(0.3, 0.33, 0.45)

	_model = Node3D.new()
	add_child(_model)
	_body = Node3D.new()
	_model.add_child(_body)
	_leg_l = _limb(_model, Vector3(-0.12, 0.62, 0), 0.09, 0.62, pants)
	_leg_r = _limb(_model, Vector3(0.12, 0.62, 0), 0.09, 0.62, pants)
	_mesh_capsule(_body, 0.24, 0.72, outfit, Vector3(0, 0.98, 0))
	_arm_l = _limb(_body, Vector3(-0.3, 1.22, 0), 0.065, 0.55, outfit.lightened(0.1))
	_arm_r = _limb(_body, Vector3(0.3, 1.22, 0), 0.065, 0.55, outfit.lightened(0.1))
	for arm in [_arm_l, _arm_r]:
		_mesh_sphere(arm, 0.07, skin, Vector3(0, -0.55, 0))
	_head = Node3D.new()
	_head.position = Vector3(0, 1.55, 0)
	_body.add_child(_head)
	_mesh_sphere(_head, 0.24, skin, Vector3.ZERO)
	for x in [-0.085, 0.085]:
		_mesh_sphere(_head, 0.035, Color(0.12, 0.12, 0.16), Vector3(x, 0.03, -0.235))
		var cheek := _mesh_sphere(_head, 0.045, Color(1.0, 0.65, 0.6), Vector3(x * 1.6, -0.06, -0.205))
		cheek.scale = Vector3(1, 0.6, 0.4)
	var hair_cap := _mesh_sphere(_head, 0.255, hair, Vector3(0, 0.05, 0.03))
	hair_cap.scale = Vector3(1.0, 0.85, 1.0)
	var face_front := _mesh_sphere(_head, 0.2, skin, Vector3(0, -0.02, -0.08))
	face_front.scale = Vector3(1.0, 0.95, 0.9)
	match style:
		1: # longs
			var long_hair := _mesh_capsule(_head, 0.2, 0.6, hair, Vector3(0, -0.2, 0.12))
			long_hair.scale = Vector3(1.15, 1, 0.6)
		2: # chignon
			_mesh_sphere(_head, 0.12, hair, Vector3(0, 0.22, 0.16))
	_set_pose_transform()


func _limb(parent: Node3D, pivot: Vector3, radius: float, length: float, color: Color) -> Node3D:
	var node := Node3D.new()
	node.position = pivot
	parent.add_child(node)
	_mesh_capsule(node, radius, length, color, Vector3(0, -length / 2.0, 0))
	return node


func _mesh_capsule(parent: Node3D, radius: float, height: float, color: Color, pos: Vector3) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.0)
	return _mesh(parent, mesh, color, pos)


func _mesh_sphere(parent: Node3D, radius: float, color: Color, pos: Vector3) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return _mesh(parent, mesh, color, pos)


func _mesh(parent: Node3D, mesh: PrimitiveMesh, color: Color, pos: Vector3) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)
	return mi


# --- Déplacements et poses -------------------------------------------------------------

func walk_path(path: Array) -> void:
	set_pose("debout")
	position.y = 0.0
	_path = path.duplicate()
	state = "walk" if not _path.is_empty() else "idle"


func stop() -> void:
	_path.clear()
	state = "idle"
	set_pose("debout")
	position.y = 0.0


func start_acting(new_pose: String, pose_point, face_point: Vector3) -> void:
	if pose_point != null:
		position = pose_point
	face(face_point)
	set_pose(new_pose)
	state = "act"


func face(point: Vector3) -> void:
	var flat := Vector3(point.x, position.y, point.z)
	if position.distance_to(flat) > 0.05:
		look_at(flat, Vector3.UP)


func set_pose(new_pose: String) -> void:
	pose = new_pose
	_set_pose_transform()


func _set_pose_transform() -> void:
	if _model == null:
		return
	_model.rotation = Vector3.ZERO
	_model.position = Vector3.ZERO
	_leg_l.rotation = Vector3.ZERO
	_leg_r.rotation = Vector3.ZERO
	match pose:
		"allonge":
			_model.rotation_degrees = Vector3(-90, 0, 0)
			_model.position = Vector3(0, 0.2, 0)
		"assis":
			_model.position = Vector3(0, -0.55, 0)
			_leg_l.rotation_degrees = Vector3(80, 0, 0)
			_leg_r.rotation_degrees = Vector3(80, 0, 0)


func _process(delta: float) -> void:
	if _model == null:
		return
	_time += delta
	match state:
		"walk":
			_walk(delta)
			_animate_limbs(9.0, 35.0)
		"act":
			if pose == "course":
				_animate_limbs(14.0, 45.0)
				_body.position.y = absf(sin(_time * 14.0)) * 0.05
			elif pose == "allonge":
				_animate_limbs(0.0, 0.0)
				_body.position.y = sin(_time * 1.5) * 0.01
			else:
				_animate_limbs(0.0, 0.0)
				_arm_r.rotation.x = -0.6 + sin(_time * 4.0) * 0.25
		_:
			_animate_limbs(0.0, 0.0)
			_body.position.y = sin(_time * 2.0) * 0.008


func _animate_limbs(speed: float, amplitude_deg: float) -> void:
	var swing := deg_to_rad(amplitude_deg) * sin(_time * speed)
	_arm_l.rotation.x = swing
	_arm_r.rotation.x = -swing
	if pose != "assis":
		_leg_l.rotation.x = -swing
		_leg_r.rotation.x = swing
	if speed == 0.0:
		_body.position.y = 0.0


func _walk(delta: float) -> void:
	if _path.is_empty():
		state = "idle"
		arrived.emit()
		return
	var target: Vector3 = _path[0]
	var to := Vector3(target.x - position.x, 0, target.z - position.z)
	var dist := to.length()
	var step := WALK_SPEED * delta
	if dist <= step:
		position = Vector3(target.x, 0, target.z)
		_path.pop_front()
		if _path.is_empty():
			state = "idle"
			arrived.emit()
	else:
		position += to / dist * step
		face(target)
		_body.position.y = absf(sin(_time * 9.0)) * 0.04
