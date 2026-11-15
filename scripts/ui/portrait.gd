extends SubViewportContainer
## Portrait 3D d'un personnage (buste ou en pied), pour « Ma famille ».
## Chaque portrait a son petit monde 3D : lumière douce, fond transparent.

const Character = preload("res://scripts/world/character.gd")

var character: Node3D
var _camera: Camera3D
var _time := 0.0
var _spin := 0.0


## `full` : le personnage en entier (sinon la tête et les épaules).
func setup(appearance: Dictionary, age := "adulte", size := Vector2(180, 200), full := false, anim := "idle") -> void:
	custom_minimum_size = size
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, 25, 0)
	light.light_energy = 1.05
	viewport.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(1, 0.97, 0.92)
	env.environment.ambient_light_energy = 0.65
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	viewport.add_child(env)
	character = Character.new()
	viewport.add_child(character)
	character.build(appearance, age)
	character.rotation_degrees.y = 180.0
	character.play(anim)
	_camera = Camera3D.new()
	_camera.fov = 30
	viewport.add_child(_camera)
	# Hauteur de la tête, lue dans le squelette (l'enfant est plus petit, avec une plus grosse tête).
	var head_y := _head_height()
	var zoom: float = character._scale * (Character.CHILD_HEAD if age == "enfant" else 1.0)
	# (le portrait n'est pas encore dans l'arbre : on place la caméra sans look_at)
	var eye := Vector3(0, head_y + 0.05 * zoom, 1.8 * zoom)
	var target := Vector3(0, head_y - 0.12 * zoom, 0)
	if full:
		eye = Vector3(0, head_y * 0.6, 3.2 * character._scale + 0.8)
		target = Vector3(0, head_y * 0.52, 0)
	_camera.transform = Transform3D(Basis.looking_at(target - eye, Vector3.UP), eye)


func _head_height() -> float:
	var node: Node = character._joints.get("head")
	if node == null:
		return 1.52 * character._scale
	var t := Transform3D.IDENTITY
	while node != null and node != character:
		t = (node as Node3D).transform * t
		node = node.get_parent()
	return t.origin.y


func _process(delta: float) -> void:
	if character == null:
		return
	_time += delta
	# Le personnage se balance doucement pour avoir l'air vivant.
	character.rotation_degrees.y = 180.0 + sin(_time * 0.8) * 16.0
