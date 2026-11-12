extends Node3D
## Le personnage : corps articulé construit par calcul (taille, corpulence, visage,
## coiffure, tenue…), marche, poses et animations d'activités.

signal arrived

const Data = preload("res://scripts/core/data.gd")
const M = preload("res://scripts/world/meshes.gd")
const WALK_SPEED := 2.3 # mètres par seconde

const HIP_H := 0.72
const TORSO_H := 0.5
const UPPER_ARM := 0.25
const FOREARM := 0.23
const THIGH := 0.34
const SHIN := 0.31

var state := "idle" # idle / walk / act
var pose := "debout" # debout / assis / allonge / course
var anim := "idle"
var talking := false

var _appearance: Dictionary = {}
var _path: Array = []
var _time := 0.0
var _model: Node3D
var _joints := {} # nom → Node3D
var _current := {} # nom → Vector3 (degrés) pour les transitions douces
var _hips_base := Vector3.ZERO
var _hips_offset := Vector3.ZERO
var _eyes: Array = []
var _mouth: Node3D
var _skirt: Node3D
var _props := {} # nom → Node3D
var _blink := 0.0
var _next_blink := 2.0
var _scale := 1.0
var _one_shot := ""
var _one_shot_left := 0.0


# --- Construction -----------------------------------------------------------------------

func build(appearance: Dictionary) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_joints.clear()
	_current.clear()
	_eyes.clear()
	_props.clear()
	_skirt = null
	_appearance = Data.complete_appearance(appearance)
	var a := _appearance
	var male: bool = a["body"] == 1
	_scale = Data.HEIGHT_SCALES[a["height"]]
	var b: float = Data.BUILD_FACTORS[a["build"]]
	var limb := 0.92 + 0.45 * (b - 1.0)
	var skin: Color = Data.SKIN_COLORS[a["skin"]]
	var hair: Color = Data.HAIR_COLORS[a["hair"]]
	var top: Color = Data.OUTFIT_COLORS[a["outfit"]]
	var bottom: Color = Data.BOTTOM_COLORS[a["bottom"]]
	var shoes: Color = Data.SHOE_COLORS[a["shoes"]]
	var style: int = a["outfit_style"]
	var m_skin := M.mat(skin, 0.75)
	var m_top := M.mat(top, 0.85)
	var m_bottom := M.mat(bottom, 0.85)
	var m_shoes := M.mat(shoes, 0.6)

	_model = Node3D.new()
	_model.scale = Vector3.ONE * _scale
	add_child(_model)
	var hips := _joint("hips", _model, Vector3(0, HIP_H, 0))
	_hips_base = hips.position
	var spine := _joint("spine", hips, Vector3(0, 0.02, 0))

	# --- Tronc ---
	var shoulder := (0.2 if male else 0.182) * (0.93 + 0.5 * (b - 1.0))
	var waist := (0.165 if male else 0.148) * b
	var hip_w := (0.165 if male else 0.176) * b
	var belly := 0.0 if b <= 1.0 else (b - 1.0) * 0.16
	var profile := [Vector2(0.0, -0.09), Vector2(hip_w * 0.82, -0.075), Vector2(hip_w, -0.01), Vector2(waist + belly, 0.13),
		Vector2(waist + belly * 0.7, 0.22), Vector2(shoulder * 0.98, 0.36), Vector2(shoulder, 0.43), Vector2(shoulder * 0.72, 0.49), Vector2(0.075, 0.53), Vector2(0.0, 0.535)]
	var depth := 0.68 + 0.42 * (b - 1.0)
	var torso_mat := m_top if style != 3 else M.mat(top, 0.85)
	M.add(spine, M.lathe(profile, 24), torso_mat, Vector3.ZERO, Vector3.ZERO, Vector3(1, 1, depth))
	# Bassin (couleur du bas)
	if style != 3:
		M.add(hips, M.sphere(hip_w * 0.97, 12), m_bottom, Vector3(0, -0.03, 0), Vector3.ZERO, Vector3(1.0, 0.5, depth * 1.0))
	M.add(spine, M.cylinder(0.062, 0.1), m_skin, Vector3(0, 0.55, 0)) # cou
	_dress_torso(spine, hips, style, top, bottom, shoulder, waist + belly, hip_w, depth, b)

	# --- Bras ---
	for side in [-1.0, 1.0]:
		var s: float = side
		var tag := "l" if s < 0.0 else "r"
		var sh := _joint("sh_" + tag, spine, Vector3(s * (shoulder + 0.035 * limb), 0.42, 0))
		var long_sleeves: bool = style == 1 or style == 2
		var r_up := 0.058 * limb
		var r_fo := 0.05 * limb
		M.add(sh, M.sphere(r_up * 1.12, 10), m_top, Vector3.ZERO)
		M.add(sh, M.capsule(r_up, UPPER_ARM + r_up), m_top if long_sleeves else m_skin, Vector3(0, -UPPER_ARM / 2.0, 0))
		if not long_sleeves: # manche courte
			M.add(sh, M.capsule(r_up * 1.16, UPPER_ARM * 0.62 + r_up), m_top, Vector3(0, -UPPER_ARM * 0.26, 0))
		var el := _joint("el_" + tag, sh, Vector3(0, -UPPER_ARM, 0))
		M.add(el, M.capsule(r_fo, FOREARM + r_fo), m_top if long_sleeves else m_skin, Vector3(0, -FOREARM / 2.0, 0))
		if style == 1: # poignet du pull
			M.add(el, M.cylinder(r_fo * 1.22, 0.05), M.mat(top.darkened(0.12), 0.9), Vector3(0, -FOREARM + 0.03, 0))
		var hand := Node3D.new()
		hand.position = Vector3(0, -FOREARM - 0.03, 0)
		el.add_child(hand)
		M.add(hand, M.sphere(0.062 * (0.95 + 0.2 * (limb - 1.0)), 10), m_skin, Vector3.ZERO, Vector3.ZERO, Vector3(0.9, 1.05, 1.0))
		_joints["hand_" + tag] = hand

	# --- Jambes ---
	for side in [-1.0, 1.0]:
		var s: float = side
		var tag := "l" if s < 0.0 else "r"
		var hp := _joint("hp_" + tag, hips, Vector3(s * (0.085 + 0.02 * b), -0.04, 0))
		var bare_legs: bool = style == 3
		var short_legs: bool = style == 2
		var r_th := 0.078 * limb
		var r_sh := 0.062 * limb
		M.add(hp, M.capsule(r_th, THIGH + r_th), m_skin if bare_legs else m_bottom, Vector3(0, -THIGH / 2.0, 0))
		var kn := _joint("kn_" + tag, hp, Vector3(0, -THIGH, 0))
		M.add(kn, M.capsule(r_sh, SHIN + r_sh), m_skin if (bare_legs or short_legs) else m_bottom, Vector3(0, -SHIN / 2.0, 0))
		if bare_legs or short_legs: # chaussettes
			M.add(kn, M.cylinder(r_sh * 1.1, 0.07), M.mat(Color(0.97, 0.97, 0.95), 0.9), Vector3(0, -SHIN + 0.05, 0))
		M.add(kn, M.rounded_box(Vector3(0.12, 0.085, 0.22) * (0.95 + 0.2 * (limb - 1.0)), 0.04), m_shoes, Vector3(0, -SHIN - 0.02, -0.035))
		M.add(kn, M.rounded_box(Vector3(0.125, 0.025, 0.225), 0.012), M.mat(Color(0.96, 0.96, 0.94), 0.7), Vector3(0, -SHIN - 0.055, -0.035))

	# --- Tête ---
	var neck := _joint("neck", spine, Vector3(0, 0.6, 0))
	var head := Node3D.new()
	head.position = Vector3(0, 0.2, 0)
	neck.add_child(head)
	_joints["head"] = head
	_build_head(head, a, skin, hair)
	_build_props(top)
	_set_pose_transform()
	_apply_pose(_pose_for(anim, 0.0), 1.0)


func _joint(joint_name: String, parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	_joints[joint_name] = n
	_current[joint_name] = Vector3.ZERO
	return n


func _dress_torso(spine: Node3D, hips: Node3D, style: int, top: Color, bottom: Color, shoulder: float, waist: float, hip_w: float, depth: float, b: float) -> void:
	match style:
		0: # T-shirt : petit motif sur le devant
			M.add(spine, M.sphere(0.05, 8), M.mat(top.lightened(0.45), 0.8), Vector3(0, 0.3, -(waist + 0.03) * depth), Vector3.ZERO, Vector3(1, 1, 0.25))
		1: # Pull : col roulé et bord côtelé
			M.add(spine, M.torus(0.085, 0.03), M.mat(top.darkened(0.12), 0.9), Vector3(0, 0.525, 0))
			M.add(spine, M.torus(hip_w * 0.98, 0.022), M.mat(top.darkened(0.12), 0.9), Vector3(0, 0.0, 0), Vector3.ZERO, Vector3(1, 1, depth))
		2: # Chemise : col et boutons
			for sx in [-1.0, 1.0]:
				var s: float = sx
				M.add(spine, M.rounded_box(Vector3(0.09, 0.03, 0.07), 0.012), M.mat(top.lightened(0.3), 0.8), Vector3(s * 0.05, 0.5, -0.07), Vector3(20, s * -25.0, s * 20.0))
			for k in 3:
				M.add(spine, M.sphere(0.014, 6), M.mat(Color(0.98, 0.98, 0.96), 0.5), Vector3(0, 0.4 - k * 0.1, -(lerpf(shoulder, waist, k / 2.0) * depth + 0.004)))
		3: # Robe : jupe évasée + ceinture
			_skirt = Node3D.new()
			_skirt.position = Vector3(0, 0.0, 0)
			hips.add_child(_skirt)
			M.add(_skirt, M.lathe([Vector2(hip_w * 0.96, 0.04), Vector2(hip_w * 1.25, -0.12), Vector2(hip_w * 1.55, -0.3), Vector2(hip_w * 1.6, -0.34), Vector2(hip_w * 1.5, -0.34)], 24), M.mat(top, 0.85), Vector3.ZERO, Vector3.ZERO, Vector3(1, 1, depth * 1.08))
			M.add(spine, M.torus(waist * 1.0, 0.018), M.mat(top.darkened(0.25), 0.7), Vector3(0, 0.14, 0), Vector3.ZERO, Vector3(1, 1, depth))
		4: # Salopette : bavette et bretelles
			var m_b := M.mat(bottom, 0.85)
			M.add(spine, M.lathe([Vector2(0.0, -0.09), Vector2(hip_w * 0.86, -0.075), Vector2(hip_w * 1.04, -0.01), Vector2(waist * 1.05, 0.13), Vector2(waist * 1.04, 0.2), Vector2(0.0, 0.2)], 24), m_b, Vector3.ZERO, Vector3.ZERO, Vector3(1, 1, depth * 1.04))
			M.add(spine, M.rounded_box(Vector3(0.2, 0.2, 0.03), 0.012), m_b, Vector3(0, 0.29, -(lerpf(waist, shoulder, 0.5) * depth + 0.004)))
			for sx in [-1.0, 1.0]:
				var s: float = sx
				M.add(spine, M.tube([Vector3(s * 0.085, 0.38, -(shoulder * depth * 0.96)), Vector3(s * 0.11, 0.5, -0.03), Vector3(s * 0.1, 0.5, 0.05), Vector3(s * 0.08, 0.3, shoulder * depth * 0.98)], 0.02), m_b)
				M.add(spine, M.sphere(0.018, 6), M.mat(Color(0.95, 0.8, 0.35), 0.4), Vector3(s * 0.08, 0.37, -(shoulder * depth * 0.97 + 0.012)))


func _build_head(head: Node3D, a: Dictionary, skin: Color, hair: Color) -> void:
	var m_skin := M.mat(skin, 0.75)
	var m_hair := M.mat(hair, 0.65)
	var face: int = a["face"]
	var cheeks: int = a["cheeks"]
	var head_scale: Vector3 = [Vector3(1.0, 0.98, 1.0), Vector3(0.93, 1.05, 0.97), Vector3(1.0, 0.97, 1.0)][face]
	if cheeks == 0:
		head_scale.x *= 0.96
	var skull := Node3D.new()
	skull.scale = head_scale
	head.add_child(skull)
	M.add(skull, M.sphere(0.25, 20), m_skin)
	if face == 2: # mâchoire plus carrée
		M.add(skull, M.rounded_box(Vector3(0.43, 0.26, 0.4), 0.12), m_skin, Vector3(0, -0.1, -0.015))
	if cheeks == 2: # joues rondes
		for sx in [-1.0, 1.0]:
			var s: float = sx
			M.add(skull, M.sphere(0.082, 10), m_skin, Vector3(s * 0.118, -0.092, -0.128))
	for sx in [-1.0, 1.0]: # oreilles
		var s: float = sx
		M.add(skull, M.sphere(0.052, 8), m_skin, Vector3(s * 0.243, -0.02, 0.01), Vector3.ZERO, Vector3(0.5, 1.0, 0.8))

	# Yeux
	var eye_col: Color = Data.EYE_COLORS[a["eye_color"]]
	var shape: int = a["eye_shape"]
	var eye_scale: Vector2 = [Vector2(1.0, 1.0), Vector2(1.16, 0.8), Vector2(1.24, 1.24), Vector2(0.82, 0.82)][shape]
	for sx in [-1.0, 1.0]:
		var s: float = sx
		var eye := Node3D.new()
		eye.position = Vector3(s * 0.098 * head_scale.x, 0.005, -0.222)
		eye.rotation_degrees = Vector3(0, s * -18.0, s * (7.0 if shape == 1 else 0.0))
		eye.scale = Vector3(eye_scale.x, eye_scale.y, 1.0)
		head.add_child(eye)
		M.add(eye, M.sphere(0.05, 12), M.mat(Color(0.99, 0.99, 0.98), 0.3), Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 1.12, 0.38))
		M.add(eye, M.sphere(0.036, 12), M.mat(eye_col, 0.25), Vector3(0, -0.002, -0.012), Vector3.ZERO, Vector3(1.0, 1.08, 0.4))
		M.add(eye, M.sphere(0.021, 10), M.mat(Color(0.08, 0.08, 0.1), 0.2), Vector3(0, -0.002, -0.021), Vector3.ZERO, Vector3(1.0, 1.05, 0.4))
		M.add(eye, M.sphere(0.01, 6), M.glowing(Color(1, 1, 1), 0.6), Vector3(-0.012, 0.014, -0.029))
		_eyes.append({"node": eye, "sy": eye_scale.y})
		# Sourcils
		var brows: int = a["brows"]
		var brow_mat := M.mat(hair.darkened(0.25), 0.7)
		var brow_pos := Vector3(s * 0.1 * head_scale.x, 0.088 + 0.012 * (eye_scale.y - 1.0) * 4.0, -0.232)
		if brows == 2:
			var arc := M.add(head, M.tube(M.arc_points(0.05, 35.0, 145.0, 8, 0.55), 0.011), brow_mat, brow_pos + Vector3(0, -0.02, 0), Vector3(10, s * -18.0, 0))
			arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			M.add(head, M.capsule(0.011 if brows == 0 else 0.019, 0.1), brow_mat, brow_pos, Vector3(0, s * -18.0, 90.0 + s * 7.0))

	# Nez
	var nose_r: float = [0.026, 0.034, 0.044][a["nose"]]
	M.add(head, M.sphere(nose_r, 10), M.mat(skin.darkened(0.07), 0.75), Vector3(0, -0.05, -0.248), Vector3.ZERO, Vector3(1.0, 0.85, 0.8))

	# Bouche
	_mouth = Node3D.new()
	_mouth.position = Vector3(0, -0.108, -0.224)
	_mouth.rotation_degrees.x = -12.0
	head.add_child(_mouth)
	var lip := M.mat(Color(0.72, 0.28, 0.3), 0.5)
	match int(a["mouth"]):
		0:
			M.add(_mouth, M.tube(M.arc_points(0.065, 215.0, 325.0, 10), 0.011), lip, Vector3(0, 0.045, 0))
		1:
			M.add(_mouth, M.tube(M.arc_points(0.085, 205.0, 335.0, 12), 0.013), lip, Vector3(0, 0.055, 0))
			M.add(_mouth, M.sphere(0.05, 10), M.mat(Color(0.55, 0.16, 0.2), 0.5), Vector3(0, -0.008, 0.012), Vector3.ZERO, Vector3(1.25, 0.55, 0.3))
			M.add(_mouth, M.rounded_box(Vector3(0.085, 0.018, 0.012), 0.006), M.mat(Color(1, 1, 1), 0.3), Vector3(0, 0.006, -0.006))
		_:
			M.add(_mouth, M.tube(M.arc_points(0.036, 225.0, 315.0, 8), 0.011), lip, Vector3(0, 0.022, 0))

	# Rougeur des joues, taches de rousseur
	var blush: int = a["blush"]
	if blush > 0:
		var blush_mat := M.mat(Color(1.0, 0.5, 0.52, 0.42 if blush == 1 else 0.75), 0.9)
		for sx in [-1.0, 1.0]:
			var s: float = sx
			var disc := M.add(head, M.sphere(0.05, 8), blush_mat, Vector3(s * 0.158 * head_scale.x, -0.07, -0.2 if cheeks != 2 else -0.215), Vector3(0, s * -38.0, 0), Vector3(1.0, 0.7, 0.16))
			disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if a["freckles"] == 1:
		var freckle := M.mat(skin.darkened(0.3), 0.8)
		for p in [Vector3(-0.075, -0.062, -0.236), Vector3(-0.108, -0.078, -0.221), Vector3(-0.135, -0.058, -0.208), Vector3(0.075, -0.062, -0.236), Vector3(0.108, -0.078, -0.221), Vector3(0.135, -0.058, -0.208), Vector3(-0.04, -0.045, -0.246), Vector3(0.04, -0.045, -0.246)]:
			var pos: Vector3 = p
			M.add(head, M.sphere(0.008, 5), freckle, pos).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Lunettes
	var glasses: int = a["glasses"]
	if glasses > 0:
		var frame := M.mat(Color(0.18, 0.2, 0.28) if glasses == 1 else Color(0.75, 0.3, 0.3), 0.4)
		for sx in [-1.0, 1.0]:
			var s: float = sx
			var c := Vector3(s * 0.098 * head_scale.x, 0.005, -0.262)
			if glasses == 1:
				M.add(head, M.torus(0.064, 0.008), frame, c, Vector3(90, 0, 0))
			else:
				M.add(head, M.tube([Vector3(-0.07, -0.05, 0), Vector3(0.07, -0.05, 0), Vector3(0.075, 0.05, 0), Vector3(-0.075, 0.05, 0)], 0.008, 6, true), frame, c)
			M.add(head, M.tube([c + Vector3(s * 0.07, 0.01, 0.0), Vector3(s * 0.245 * head_scale.x, 0.02, -0.02)], 0.007, 6), frame)
		M.add(head, M.capsule(0.007, 0.07), frame, Vector3(0, 0.012, -0.268), Vector3(0, 0, 90))

	# Barbe ou moustache
	var beard: int = a["beard"]
	var m_beard := M.mat(hair.darkened(0.1), 0.8)
	if beard == 1:
		M.add(head, M.sphere(0.2, 12), m_beard, Vector3(0, -0.125, -0.07), Vector3.ZERO, Vector3(1.05 * head_scale.x, 0.62, 0.98))
		_mouth.position.z -= 0.022
	elif beard == 2:
		for sx in [-1.0, 1.0]:
			var s: float = sx
			M.add(head, M.capsule(0.016, 0.085), m_beard, Vector3(s * 0.035, -0.086, -0.243), Vector3(0, s * -12.0, 90.0 + s * 14.0))

	_build_hair(head, int(a["hair_style"]), m_hair, head_scale)


func _build_hair(head: Node3D, style: int, m: Material, hs: Vector3) -> void:
	var root := Node3D.new()
	root.scale = Vector3(hs.x, 1.0, hs.z)
	head.add_child(root)
	if style == 7: # très courts : simple calotte près du crâne
		M.add(root, M.sphere(0.256, 16), m, Vector3(0, 0.03, 0.022))
		return
	M.add(root, M.sphere(0.266, 16), m, Vector3(0, 0.058, 0.044))
	match style:
		0: # courts, petite frange
			for k in 5:
				M.add(root, M.sphere(0.075, 8), m, Vector3(-0.14 + k * 0.07, 0.185 - absf(k - 2) * 0.012, -0.165 + absf(k - 2) * 0.022))
			for sx in [-1.0, 1.0]:
				var s: float = sx
				M.add(root, M.sphere(0.07, 8), m, Vector3(s * 0.225, 0.07, -0.05), Vector3.ZERO, Vector3(0.7, 1.3, 1.0))
		1: # longs
			M.add(root, M.capsule(0.2, 0.7), m, Vector3(0, -0.2, 0.13), Vector3.ZERO, Vector3(1.22, 1.0, 0.58))
			for sx in [-1.0, 1.0]:
				var s: float = sx
				M.add(root, M.capsule(0.066, 0.5), m, Vector3(s * 0.225, -0.14, -0.02), Vector3(0, 0, s * 4.0))
				M.add(root, M.sphere(0.08, 8), m, Vector3(s * 0.12, 0.2, -0.16))
		2: # chignon
			M.add(root, M.sphere(0.115, 12), m, Vector3(0, 0.3, 0.13))
			M.add(root, M.torus(0.075, 0.016), M.mat(Color(0.93, 0.52, 0.44), 0.6), Vector3(0, 0.24, 0.115), Vector3(-25, 0, 0))
			for sx in [-1.0, 1.0]:
				var s: float = sx
				M.add(root, M.sphere(0.085, 8), m, Vector3(s * 0.1, 0.195, -0.16))
		3: # carré
			M.add(root, M.sphere(0.275, 14), m, Vector3(0, -0.035, 0.07), Vector3.ZERO, Vector3(1.1, 0.88, 0.92))
			for sx in [-1.0, 1.0]:
				var s: float = sx
				M.add(root, M.capsule(0.075, 0.34), m, Vector3(s * 0.225, -0.07, -0.04))
			for k in 5:
				M.add(root, M.sphere(0.072, 8), m, Vector3(-0.14 + k * 0.07, 0.16, -0.185 + absf(k - 2) * 0.02))
		4: # queue de cheval
			M.add(root, M.torus(0.05, 0.02), M.mat(Color(0.95, 0.74, 0.32), 0.6), Vector3(0, 0.17, 0.27), Vector3(60, 0, 0))
			M.add(root, M.capsule(0.075, 0.46), m, Vector3(0, -0.02, 0.37), Vector3(-22, 0, 0))
			M.add(root, M.sphere(0.085, 8), m, Vector3(0, 0.19, -0.17), Vector3.ZERO, Vector3(2.0, 0.9, 1.0))
		5: # couettes
			for sx in [-1.0, 1.0]:
				var s: float = sx
				M.add(root, M.sphere(0.03, 6), M.mat(Color(0.93, 0.52, 0.44), 0.6), Vector3(s * 0.26, 0.08, 0.05))
				M.add(root, M.capsule(0.078, 0.36), m, Vector3(s * 0.32, -0.07, 0.06), Vector3(0, 0, s * 16.0))
				M.add(root, M.sphere(0.08, 8), m, Vector3(s * 0.1, 0.195, -0.165))
		6: # bouclés
			for k in 14:
				var ang := k * 2.399963
				var up := 0.3 - k * 0.028
				var rad := sqrt(maxf(0.0, 0.085 - up * up * 0.6)) + 0.03
				M.add(root, M.sphere(0.1, 8), m, Vector3(cos(ang) * rad, 0.06 + up * 0.75, 0.05 + sin(ang) * rad))
			for k in 4:
				M.add(root, M.sphere(0.085, 8), m, Vector3(-0.13 + k * 0.087, 0.2, -0.17))
		8: # mèche sur le côté
			M.add(root, M.capsule(0.085, 0.34), m, Vector3(0.03, 0.19, -0.15), Vector3(10, 0, 72))
			M.add(root, M.sphere(0.09, 8), m, Vector3(-0.16, 0.14, -0.14))
			for sx in [-1.0, 1.0]:
				var s: float = sx
				M.add(root, M.sphere(0.07, 8), m, Vector3(s * 0.225, 0.06, -0.04), Vector3.ZERO, Vector3(0.7, 1.3, 1.0))


## Petits objets tenus en main pendant les activités (cachés par défaut).
func _build_props(top: Color) -> void:
	var hand_r: Node3D = _joints["hand_r"]
	var hand_l: Node3D = _joints["hand_l"]
	var wood := M.mat(Color(0.8, 0.6, 0.42), 0.7)
	var steel := M.mat(Color(0.74, 0.77, 0.81), 0.3, 0.3)
	_props["pinceau"] = _prop(hand_r, func(p):
		M.add(p, M.capsule(0.011, 0.26), wood, Vector3(0, -0.02, -0.11), Vector3(90, 0, 0))
		M.add(p, M.sphere(0.022, 6), M.mat(Color(0.3, 0.55, 0.9), 0.5), Vector3(0, -0.02, -0.25), Vector3.ZERO, Vector3(0.8, 0.8, 1.6)))
	_props["marteau"] = _prop(hand_r, func(p):
		M.add(p, M.capsule(0.016, 0.3), wood, Vector3(0, -0.02, -0.11), Vector3(90, 0, 0))
		M.add(p, M.rounded_box(Vector3(0.06, 0.14, 0.07), 0.015), steel, Vector3(0, -0.02, -0.26)))
	_props["telephone"] = _prop(hand_r, func(p):
		M.add(p, M.rounded_box(Vector3(0.022, 0.16, 0.085), 0.01), M.mat(Color(0.24, 0.29, 0.45), 0.3), Vector3(-0.03, 0.02, 0)))
	_props["brosse"] = _prop(hand_r, func(p):
		M.add(p, M.capsule(0.009, 0.2), M.mat(Color(0.93, 0.52, 0.44), 0.4), Vector3(0, -0.01, -0.08), Vector3(90, 0, 0))
		M.add(p, M.rounded_box(Vector3(0.018, 0.02, 0.04), 0.006), M.mat(Color(1, 1, 1), 0.5), Vector3(0, 0.005, -0.17)))
	_props["cuillere"] = _prop(hand_r, func(p):
		M.add(p, M.capsule(0.008, 0.18), steel, Vector3(0, -0.01, -0.07), Vector3(90, 0, 0))
		M.add(p, M.sphere(0.024, 6), steel, Vector3(0, -0.01, -0.17), Vector3.ZERO, Vector3(1, 0.4, 1.3)))
	_props["stylo"] = _prop(hand_r, func(p):
		M.add(p, M.capsule(0.009, 0.16), M.mat(Color(0.42, 0.56, 0.82), 0.4), Vector3(0, -0.05, -0.04), Vector3(35, 0, 0)))
	_props["bol"] = _prop(hand_l, func(p):
		M.add(p, M.lathe([Vector2(0.0, 0.0), Vector2(0.06, 0.0), Vector2(0.1, 0.06), Vector2(0.09, 0.065), Vector2(0.05, 0.015), Vector2(0.0, 0.015)], 16), M.mat(Color(0.97, 0.95, 0.9), 0.4), Vector3(0, -0.03, -0.09), Vector3(-80, 0, 0)))
	_props["palette"] = _prop(hand_l, func(p):
		var pal := Node3D.new()
		pal.position = Vector3(0, -0.02, -0.12)
		pal.rotation_degrees = Vector3(-75, 0, 0)
		p.add_child(pal)
		M.add(pal, M.cylinder(0.11, 0.012), wood, Vector3.ZERO, Vector3.ZERO, Vector3(1, 1, 0.75))
		for k in 4:
			M.add(pal, M.sphere(0.02, 6), M.mat([Color(0.93, 0.52, 0.44), Color(0.95, 0.74, 0.32), Color(0.42, 0.56, 0.82), Color(0.6, 0.74, 0.66)][k], 0.4), Vector3(cos(k * 1.3) * 0.06, 0.012, sin(k * 1.3) * 0.045), Vector3.ZERO, Vector3(1, 0.4, 1)))
	_props["livre"] = _prop(hand_l, func(p):
		M.add(p, M.rounded_box(Vector3(0.3, 0.02, 0.2), 0.008), M.mat(Color(0.36, 0.62, 0.64), 0.7), Vector3(0.12, -0.03, -0.06), Vector3(-60, 0, 0))
		M.add(p, M.rounded_box(Vector3(0.28, 0.012, 0.18), 0.004), M.mat(Color(0.98, 0.97, 0.93), 0.8), Vector3(0.12, -0.022, -0.068), Vector3(-60, 0, 0)))
	_props["serviette"] = _prop(hand_r, func(p):
		M.add(p, M.rounded_box(Vector3(0.2, 0.26, 0.04), 0.02), M.mat(top.lightened(0.5), 0.95), Vector3(0, -0.06, -0.05)))


func _prop(hand: Node3D, builder: Callable) -> Node3D:
	var p := Node3D.new()
	p.visible = false
	hand.add_child(p)
	builder.call(p)
	return p


# --- Déplacements et poses ------------------------------------------------------------------

func walk_path(path: Array) -> void:
	set_pose("debout")
	position.y = 0.0
	_path = path.duplicate()
	state = "walk" if not _path.is_empty() else "idle"
	_set_anim("walk" if state == "walk" else "idle")


func stop() -> void:
	_path.clear()
	state = "idle"
	set_pose("debout")
	position.y = 0.0
	talking = false
	_set_anim("idle")


## Le personnage s'installe (assis, allongé…) et joue l'animation de l'activité.
func start_acting(new_pose: String, pose_point, face_point: Vector3, anim_name := "") -> void:
	if pose_point != null:
		position = pose_point
	face(face_point)
	set_pose(new_pose)
	state = "act"
	if anim_name == "":
		anim_name = {"assis": "sit", "allonge": "sleep", "course": "run"}.get(new_pose, "idle")
	_set_anim(anim_name)


func play(anim_name: String) -> void:
	_set_anim(anim_name)


## Joue une animation un court instant (saut de joie, salut) puis revient à la précédente.
func play_once(anim_name: String, seconds := 1.4) -> void:
	_one_shot = anim_name
	_one_shot_left = seconds
	_show_props(anim_name)


func _set_anim(anim_name: String) -> void:
	anim = anim_name
	talking = anim_name in ["talk", "sit_phone", "sit_chat"]
	_show_props(anim_name)


func _show_props(anim_name: String) -> void:
	var wanted: Array = {"paint": ["pinceau", "palette"], "hammer": ["marteau"], "sit_phone": ["telephone"], "brush": ["brosse"],
		"eat": ["cuillere", "bol"], "cook": ["cuillere"], "sit_write": ["stylo"], "sit_read": ["livre"]}.get(anim_name, [])
	for key in _props:
		_props[key].visible = key in wanted


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
	_model.basis = Basis.IDENTITY.scaled(Vector3.ONE * _scale)
	_model.position = Vector3.ZERO
	match pose:
		"allonge": # sur le dos, la tête vers l'avant (vers la tête de lit)
			_model.basis = Basis(Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(0, -1, 0)).scaled(Vector3.ONE * _scale)
			_model.position = Vector3(0, 0.13, 0)
		"assis": # le bassin est posé sur le siège (pose_point = dessus du siège)
			_model.position = Vector3(0, -HIP_H * _scale + 0.11, 0)


# --- Animation ------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _model == null:
		return
	_time += delta
	if state == "walk":
		_walk(delta)
	var current_anim := anim
	if _one_shot_left > 0.0:
		_one_shot_left -= delta
		current_anim = _one_shot
		if _one_shot_left <= 0.0:
			_show_props(anim)
	_apply_pose(_pose_for(current_anim, _time), 1.0 - exp(-delta * 13.0))
	_animate_face(delta, current_anim)


func _apply_pose(p: Dictionary, k: float) -> void:
	for joint_name in _current:
		var target: Vector3 = p.get(joint_name, Vector3.ZERO)
		var cur: Vector3 = _current[joint_name]
		cur = cur.lerp(target, k)
		_current[joint_name] = cur
		(_joints[joint_name] as Node3D).rotation_degrees = cur
	_hips_offset = _hips_offset.lerp(p.get("offset", Vector3.ZERO), k)
	(_joints["hips"] as Node3D).position = _hips_base + _hips_offset
	if _skirt != null: # la jupe suit un peu les jambes (assis, marche)
		var legs: float = (_current["hp_l"].x + _current["hp_r"].x) * 0.5
		_skirt.rotation_degrees.x = legs * 0.62
		_skirt.scale = Vector3(1.0, 1.0, 1.0 + absf(_current["hp_l"].x - _current["hp_r"].x) / 160.0)


func _animate_face(delta: float, current_anim: String) -> void:
	var closed := current_anim == "sleep"
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink = 0.14
		_next_blink = randf_range(2.2, 5.0)
	_blink = maxf(_blink - delta, 0.0)
	var open := 0.1 if (closed or _blink > 0.0) else 1.0
	for e in _eyes:
		var node: Node3D = e["node"]
		node.scale.y = lerpf(node.scale.y, e["sy"] * open, 0.5)
	if _mouth != null:
		var target := 1.0 + (0.5 + 0.5 * sin(_time * 11.0)) * 0.9 if talking else 1.0
		_mouth.scale.y = lerpf(_mouth.scale.y, target, 0.4)


## Angles (en degrés) de chaque articulation pour une animation à l'instant t.
func _pose_for(anim_name: String, t: float) -> Dictionary:
	var p := {}
	var breathe := sin(t * 1.9)
	match anim_name:
		"walk":
			var w := t * 9.5
			p["hp_l"] = Vector3(sin(w) * 34.0, 0, 0)
			p["hp_r"] = Vector3(-sin(w) * 34.0, 0, 0)
			p["kn_l"] = Vector3(-(0.5 - 0.5 * cos(w + 0.9)) * 48.0, 0, 0)
			p["kn_r"] = Vector3(-(0.5 + 0.5 * cos(w + 0.9)) * 48.0, 0, 0)
			p["sh_l"] = Vector3(-sin(w) * 30.0, 0, -5)
			p["sh_r"] = Vector3(sin(w) * 30.0, 0, 5)
			p["el_l"] = Vector3(22, 0, 0)
			p["el_r"] = Vector3(22, 0, 0)
			p["spine"] = Vector3(4, sin(w) * 5.0, 0)
			p["offset"] = Vector3(0, absf(sin(w)) * 0.03 - 0.01, 0)
		"run":
			var w := t * 14.0
			p["hp_l"] = Vector3(sin(w) * 46.0 + 8.0, 0, 0)
			p["hp_r"] = Vector3(-sin(w) * 46.0 + 8.0, 0, 0)
			p["kn_l"] = Vector3(-(0.5 - 0.5 * cos(w + 0.9)) * 85.0 - 8.0, 0, 0)
			p["kn_r"] = Vector3(-(0.5 + 0.5 * cos(w + 0.9)) * 85.0 - 8.0, 0, 0)
			p["sh_l"] = Vector3(-sin(w) * 42.0, 0, -8)
			p["sh_r"] = Vector3(sin(w) * 42.0, 0, 8)
			p["el_l"] = Vector3(88, 0, 0)
			p["el_r"] = Vector3(88, 0, 0)
			p["spine"] = Vector3(11, sin(w) * 7.0, 0)
			p["offset"] = Vector3(0, absf(sin(w)) * 0.055, 0)
		"sleep":
			p["sh_l"] = Vector3(0, 0, -9)
			p["sh_r"] = Vector3(0, 0, 9)
			p["el_l"] = Vector3(8, 0, 0)
			p["el_r"] = Vector3(8, 0, 0)
			p["neck"] = Vector3(0, 0, 4)
			p["offset"] = Vector3(0, 0, -breathe * 0.006)
		"sit", "sit_type", "sit_write", "sit_phone", "sit_chat", "sit_read":
			p["hp_l"] = Vector3(86, 0, -5)
			p["hp_r"] = Vector3(86, 0, 5)
			p["kn_l"] = Vector3(-86, 0, 0)
			p["kn_r"] = Vector3(-86, 0, 0)
			p["spine"] = Vector3(2.0 + breathe * 0.8, 0, 0)
			p["sh_l"] = Vector3(38, 0, -6)
			p["sh_r"] = Vector3(38, 0, 6)
			p["el_l"] = Vector3(48, 0, 0)
			p["el_r"] = Vector3(48, 0, 0)
			match anim_name:
				"sit_type":
					p["sh_l"] = Vector3(46, 0, -4)
					p["sh_r"] = Vector3(46, 0, 4)
					p["el_l"] = Vector3(52.0 + sin(t * 13.0) * 7.0, 0, 0)
					p["el_r"] = Vector3(52.0 + sin(t * 13.0 + 2.1) * 7.0, 0, 0)
					p["neck"] = Vector3(-4, sin(t * 0.7) * 5.0, 0)
					p["spine"] = Vector3(7, 0, 0)
				"sit_write":
					p["sh_r"] = Vector3(50.0 + sin(t * 7.0) * 3.0, sin(t * 3.5) * 6.0, 4)
					p["el_r"] = Vector3(55.0 + cos(t * 7.0) * 5.0, 0, 0)
					p["sh_l"] = Vector3(44, 0, -14)
					p["el_l"] = Vector3(50, 0, 0)
					p["neck"] = Vector3(14, 0, 0)
					p["spine"] = Vector3(10, 0, 0)
				"sit_phone":
					p["sh_r"] = Vector3(38, 0, 28)
					p["el_r"] = Vector3(142, 0, 0)
					p["neck"] = Vector3(0, sin(t * 0.9) * 8.0, -9)
					p["sh_l"] = Vector3(24.0 + sin(t * 2.2) * 12.0, 0, -10)
					p["el_l"] = Vector3(62.0 + sin(t * 2.2 + 1.0) * 16.0, 0, 0)
				"sit_chat":
					p["sh_r"] = Vector3(34.0 + sin(t * 2.4) * 22.0, 0, 12)
					p["el_r"] = Vector3(72.0 + sin(t * 3.1) * 22.0, 0, 0)
					p["sh_l"] = Vector3(30.0 + sin(t * 1.7 + 2.0) * 14.0, 0, -10)
					p["el_l"] = Vector3(60.0 + sin(t * 2.3 + 1.0) * 14.0, 0, 0)
					p["neck"] = Vector3(sin(t * 3.0) * 3.0, sin(t * 0.7) * 34.0, 0)
					p["spine"] = Vector3(-4, sin(t * 0.7) * 8.0, 0)
				"sit_read":
					p["sh_l"] = Vector3(46, 0, 6)
					p["sh_r"] = Vector3(46, 0, -6)
					p["el_l"] = Vector3(72, 0, 0)
					p["el_r"] = Vector3(72, 0, 0)
					p["neck"] = Vector3(16.0 + sin(t * 0.6) * 3.0, 0, 0)
		"eat":
			var s := 0.5 + 0.5 * sin(t * 3.2)
			p["sh_l"] = Vector3(42, 0, 4)
			p["el_l"] = Vector3(78, 0, 0)
			p["sh_r"] = Vector3(40.0 + s * 28.0, 0, 6)
			p["el_r"] = Vector3(82.0 + s * 52.0, 0, 0)
			p["neck"] = Vector3(4.0 + s * 9.0, 0, 0)
			p["spine"] = Vector3(3, 0, 0)
		"cook":
			p["sh_r"] = Vector3(52.0 + sin(t * 5.0) * 6.0, cos(t * 5.0) * 12.0, 4)
			p["el_r"] = Vector3(40.0 + cos(t * 5.0) * 8.0, 0, 0)
			p["sh_l"] = Vector3(8, 0, -30)
			p["el_l"] = Vector3(95, 0, 0)
			p["neck"] = Vector3(12, sin(t * 0.8) * 8.0, 0)
			p["spine"] = Vector3(6, 0, 0)
		"brush":
			p["sh_r"] = Vector3(62, 0, 26)
			p["el_r"] = Vector3(124.0 + sin(t * 17.0) * 8.0, 0, 0)
			p["sh_l"] = Vector3(26, 0, -8)
			p["el_l"] = Vector3(34, 0, 0)
			p["neck"] = Vector3(0, sin(t * 17.0) * 2.0, 0)
		"shower":
			p["sh_l"] = Vector3(150.0 + sin(t * 6.0) * 9.0, 0, -18)
			p["sh_r"] = Vector3(150.0 + sin(t * 6.0 + 1.5) * 9.0, 0, 18)
			p["el_l"] = Vector3(112.0 + cos(t * 6.0) * 12.0, 0, 0)
			p["el_r"] = Vector3(112.0 + cos(t * 6.0 + 1.5) * 12.0, 0, 0)
			p["hips"] = Vector3(0, sin(t * 1.3) * 28.0, 0)
			p["neck"] = Vector3(-8, 0, 0)
		"paint":
			p["sh_r"] = Vector3(74.0 + sin(t * 2.3) * 15.0, sin(t * 1.7) * 14.0, 6)
			p["el_r"] = Vector3(24.0 + sin(t * 3.1) * 13.0, 0, 0)
			p["sh_l"] = Vector3(34, 0, -8)
			p["el_l"] = Vector3(86, 0, 0)
			p["neck"] = Vector3(-3.0 + sin(t * 2.3) * 4.0, sin(t * 1.7) * 6.0, sin(t * 0.9) * 5.0)
			p["spine"] = Vector3(2, sin(t * 1.7) * 4.0, 0)
		"talk":
			p["sh_r"] = Vector3(38.0 + sin(t * 2.6) * 26.0, 0, 12)
			p["el_r"] = Vector3(84.0 + sin(t * 3.3) * 22.0, 0, 0)
			p["sh_l"] = Vector3(34.0 + sin(t * 2.1 + 2.0) * 22.0, 0, -12)
			p["el_l"] = Vector3(78.0 + sin(t * 2.9 + 1.0) * 20.0, 0, 0)
			p["neck"] = Vector3(sin(t * 3.2) * 4.0, sin(t * 1.1) * 7.0, sin(t * 1.5) * 5.0)
			p["spine"] = Vector3(0, sin(t * 1.1) * 4.0, 0)
			p["offset"] = Vector3(0, absf(sin(t * 2.6)) * 0.012, 0)
		"hammer":
			var h := pow(0.5 + 0.5 * sin(t * 6.5), 2.0)
			p["sh_r"] = Vector3(48.0 + h * 62.0, 0, 8)
			p["el_r"] = Vector3(78.0 - h * 30.0, 0, 0)
			p["sh_l"] = Vector3(46, 0, -4)
			p["el_l"] = Vector3(36, 0, 0)
			p["spine"] = Vector3(13.0 - h * 4.0, 0, 0)
			p["neck"] = Vector3(12, 0, 0)
		"celebrate":
			var j := absf(sin(t * 8.0))
			p["sh_l"] = Vector3(168, 0, -22.0 - j * 10.0)
			p["sh_r"] = Vector3(168, 0, 22.0 + j * 10.0)
			p["el_l"] = Vector3(18, 0, 0)
			p["el_r"] = Vector3(18, 0, 0)
			p["hp_l"] = Vector3(-6.0 * j, 0, -8)
			p["hp_r"] = Vector3(-6.0 * j, 0, 8)
			p["neck"] = Vector3(-10, 0, 0)
			p["offset"] = Vector3(0, j * 0.14, 0)
		"wave":
			p["sh_r"] = Vector3(0, 0, 150.0 + sin(t * 10.0) * 16.0)
			p["el_r"] = Vector3(0, 0, 0)
			p["sh_l"] = Vector3(4, 0, -7)
			p["el_l"] = Vector3(12, 0, 0)
			p["neck"] = Vector3(0, 0, 6)
		_: # idle
			p["sh_l"] = Vector3(4.0 + breathe * 1.5, 0, -7.0 - breathe)
			p["sh_r"] = Vector3(4.0 + breathe * 1.5, 0, 7.0 + breathe)
			p["el_l"] = Vector3(12, 0, 0)
			p["el_r"] = Vector3(12, 0, 0)
			p["neck"] = Vector3(0, sin(t * 0.55) * 9.0, sin(t * 0.4) * 2.0)
			p["spine"] = Vector3(breathe * 0.8, 0, sin(t * 0.8) * 1.2)
			p["offset"] = Vector3(0, breathe * 0.004, 0)
	return p


func _walk(delta: float) -> void:
	if _path.is_empty():
		state = "idle"
		_set_anim("idle")
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
			_set_anim("idle")
			arrived.emit()
	else:
		position += to / dist * step
		_turn_toward(target, delta)


## Le personnage tourne en douceur vers sa destination.
func _turn_toward(target: Vector3, delta: float) -> void:
	var dir := Vector3(target.x - position.x, 0, target.z - position.z)
	if dir.length() < 0.01:
		return
	var wanted := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, wanted, 1.0 - exp(-delta * 12.0))
